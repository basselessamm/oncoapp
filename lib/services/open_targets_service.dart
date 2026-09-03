import 'dart:convert';

import '../models/disease_option.dart';
import '../models/target_evidence.dart';
import 'network/api_client.dart';
import 'network/api_result.dart';

/// Client service for querying the Open Targets Platform GraphQL API.
///
/// Implements target mapping, target-disease evidence association, tractability,
/// clinical candidates retrieval, and ontology disease search.
class OpenTargetsService {
  OpenTargetsService({
    required ApiClient client,
    Uri? endpoint,
  })  : _client = client,
        _endpoint = endpoint ?? defaultEndpoint;

  final ApiClient _client;
  final Uri _endpoint;

  static final Uri defaultEndpoint =
      Uri.parse('https://api.platform.opentargets.org/api/v4/graphql');

  /// Maximum number of gene symbols to query in a single batch.
  static const int maxGenesPerBatch = 200;

  // ---------------------------------------------------------------------------
  // GraphQL Queries
  // ---------------------------------------------------------------------------

  /// 1. Map gene symbols to Ensembl IDs.
  static const String mapIdsQuery = r'''
query Map($terms: [String!]!) {
  mapIds(queryTerms: $terms, entityNames: ["target"]) {
    mappings { term hits { id object { ... on Target { approvedSymbol biotype } } } }
  }
}
''';

  // CRITICAL ARCHITECTURAL NOTE:
  // The forward query `target.associatedDiseases(Bs: [diseaseId])` is BROKEN in Open Targets
  // API v26.6.3 (data 26.06). It ignores the disease filter and returns fabricated scores
  // (e.g., ACTB housekeeping gene receives 0.9323, higher than breast cancer driver ESR1 0.8179).
  //
  // We MUST use the verified reverse query:
  // disease(efoId: $diseaseId).associatedTargets(Bs: $targets, enableIndirect: true)
  // `enableIndirect: true` is mandatory (e.g. TP53 gets 0.6626 without it and 0.8606 with it).
  static const String assocQuery = r'''
query Assoc($diseaseId: String!, $targets: [String!]!, $size: Int!) {
  disease(efoId: $diseaseId) {
    id name
    associatedTargets(Bs: $targets, enableIndirect: true, page: {index: 0, size: $size}) {
      count
      rows {
        score
        datatypeScores { id score }
        target { id approvedSymbol }
      }
    }
  }
}
''';

  /// 3. Druggability / Tractability and Clinical drug candidates.
  static const String targetsQuery = r'''
query Targets($ids: [String!]!) {
  targets(ensemblIds: $ids) {
    id approvedSymbol approvedName biotype
    tractability { label modality value }
    drugAndClinicalCandidates {
      count
      rows {
        maxClinicalStage
        drug { id name drugType maximumClinicalStage }
        diseases { diseaseFromSource disease { id name } }
      }
    }
  }
}
''';

  /// 4. Ontology search for disease terms.
  static const String diseaseSearchQuery = r'''
query DiseaseSearch($q: String!) {
  search(queryString: $q, entityNames: ["disease"], page: {index: 0, size: 10}) {
    hits { id name description object { ... on Disease { therapeuticAreas { id name } } } }
  }
}
''';

  // ---------------------------------------------------------------------------
  // Public Methods
  // ---------------------------------------------------------------------------

  /// Fetches target-disease evidence for a list of gene symbols in a disease context.
  ///
  /// Symbols are normalized and sorted so that cache entries remain stable regardless
  /// of symbol order. If [geneSymbols] exceeds [maxGenesPerBatch], requests are batched.
  Future<ApiResult<Map<String, TargetEvidence>>> fetchEvidence({
    required List<String> geneSymbols,
    required String diseaseId,
  }) async {
    final cleanSymbols = geneSymbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    if (cleanSymbols.isEmpty) {
      return ApiSuccess(
        data: const {},
        freshness: DataFreshness.network,
        retrievedAt: DateTime.now(),
      );
    }

    final sortedSymbols = List<String>.from(cleanSymbols)..sort();
    final cacheKey = 'ot:v1:evidence:$diseaseId:${sortedSymbols.join(",")}';

    // Check top-level cache first
    final cached = await _client.cache.read(cacheKey);
    if (cached != null && cached.isFresh) {
      final decoded = _decodeEvidenceMap(cached.body);
      if (decoded != null) {
        return ApiSuccess(
          data: decoded,
          freshness: DataFreshness.freshCache,
          retrievedAt: cached.retrievedAt,
        );
      }
    }

    final results = <String, TargetEvidence>{};
    DataFreshness overallFreshness = DataFreshness.network;
    DateTime? oldestRetrievedAt;

    for (var i = 0; i < sortedSymbols.length; i += maxGenesPerBatch) {
      final batchSymbols = sortedSymbols.sublist(
        i,
        (i + maxGenesPerBatch).clamp(0, sortedSymbols.length),
      );

      final batchResult = await _fetchBatchEvidence(
        batchSymbols: batchSymbols,
        diseaseId: diseaseId,
      );

      switch (batchResult) {
        case ApiFailure(:final reason, :final message, :final statusCode, :final cause):
          if (cached != null &&
              (reason == NetworkFailureReason.consentNotGranted || reason.isTransient)) {
            final decoded = _decodeEvidenceMap(cached.body);
            if (decoded != null) {
              return ApiSuccess(
                data: decoded,
                freshness: DataFreshness.staleCache,
                retrievedAt: cached.retrievedAt,
              );
            }
          }
          return ApiFailure(
            reason: reason,
            message: message,
            statusCode: statusCode,
            cause: cause,
          );

        case ApiSuccess(:final data, :final freshness, :final retrievedAt):
          results.addAll(data);
          if (freshness == DataFreshness.staleCache) {
            overallFreshness = DataFreshness.staleCache;
          } else if (freshness == DataFreshness.freshCache &&
              overallFreshness != DataFreshness.staleCache) {
            overallFreshness = DataFreshness.freshCache;
          }
          if (retrievedAt != null) {
            if (oldestRetrievedAt == null || retrievedAt.isBefore(oldestRetrievedAt)) {
              oldestRetrievedAt = retrievedAt;
            }
          }
      }
    }

    await _client.cache.write(cacheKey, _encodeEvidenceMap(results));

    return ApiSuccess(
      data: results,
      freshness: overallFreshness,
      retrievedAt: oldestRetrievedAt ?? DateTime.now(),
    );
  }

  /// Searches the Open Targets disease ontology for disease matching [query].
  Future<ApiResult<List<DiseaseOption>>> searchDiseases(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return const ApiSuccess(
        data: DiseaseOption.breastCancerDefaults,
        freshness: DataFreshness.network,
      );
    }

    final result = await _client.postJson(
      url: _endpoint,
      body: {
        'query': diseaseSearchQuery,
        'variables': {'q': clean},
      },
      cacheKey: 'ot:v1:search:${clean.toLowerCase()}',
    );

    switch (result) {
      case ApiFailure(:final reason, :final message, :final statusCode, :final cause):
        return ApiFailure(
          reason: reason,
          message: message,
          statusCode: statusCode,
          cause: cause,
        );

      case ApiSuccess(:final data, :final freshness, :final retrievedAt):
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          return ApiFailure(
            reason: NetworkFailureReason.invalidResponse,
            message: _firstErrorMessage(errors),
          );
        }

        final searchData = data['data'] as Map<String, dynamic>?;
        final hits = searchData?['search']?['hits'] as List<dynamic>? ?? const [];
        final options = hits.map((h) {
          final id = h['id'] as String? ?? '';
          final name = h['name'] as String? ?? '';
          final description = h['description'] as String? ?? '';
          final obj = h['object'] as Map<String, dynamic>?;
          final areasRaw = obj?['therapeuticAreas'] as List<dynamic>? ?? const [];
          final areas = areasRaw
              .map((a) => a['name'] as String? ?? a['id'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .toList();

          return DiseaseOption(
            id: id,
            name: name,
            description: description,
            therapeuticAreas: areas,
          );
        }).where((opt) => opt.id.isNotEmpty).toList();

        return ApiSuccess(
          data: options,
          freshness: freshness,
          retrievedAt: retrievedAt,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Pipeline Batch Implementation
  // ---------------------------------------------------------------------------

  Future<ApiResult<Map<String, TargetEvidence>>> _fetchBatchEvidence({
    required List<String> batchSymbols,
    required String diseaseId,
  }) async {
    // 1. mapIds: Gene symbols -> Ensembl IDs
    final mapResult = await _client.postJson(
      url: _endpoint,
      body: {
        'query': mapIdsQuery,
        'variables': {'terms': batchSymbols},
      },
      cacheKey: 'ot:v1:map:${batchSymbols.join(",")}',
    );

    if (mapResult is ApiFailure<Map<String, dynamic>>) {
      return ApiFailure(
        reason: mapResult.reason,
        message: mapResult.message,
        statusCode: mapResult.statusCode,
        cause: mapResult.cause,
      );
    }

    final mapData = (mapResult as ApiSuccess<Map<String, dynamic>>).data;
    final mapErrors = mapData['errors'];
    if (mapErrors is List && mapErrors.isNotEmpty) {
      return ApiFailure(
        reason: NetworkFailureReason.invalidResponse,
        message: _firstErrorMessage(mapErrors),
      );
    }

    final mappings =
        mapData['data']?['mapIds']?['mappings'] as List<dynamic>? ?? const [];

    final symbolToEnsemblId = <String, String>{};
    final ensemblIdToBiotype = <String, String>{};

    for (final m in mappings) {
      final term = (m['term'] as String?)?.toUpperCase();
      final hits = m['hits'] as List<dynamic>? ?? const [];
      if (term != null && hits.isNotEmpty) {
        final firstHit = hits.first as Map<String, dynamic>;
        final ensemblId = firstHit['id'] as String?;
        final obj = firstHit['object'] as Map<String, dynamic>?;
        final approvedSymbol =
            (obj?['approvedSymbol'] as String?)?.toUpperCase() ?? term;
        final biotype = obj?['biotype'] as String?;

        if (ensemblId != null) {
          symbolToEnsemblId[term] = ensemblId;
          symbolToEnsemblId[approvedSymbol] = ensemblId;
          if (biotype != null) ensemblIdToBiotype[ensemblId] = biotype;
        }
      }
    }

    // Identify resolved Ensembl IDs
    final targetIds = symbolToEnsemblId.values.toSet().toList()..sort();

    // If none of the symbols resolved, return all as unresolved
    if (targetIds.isEmpty) {
      final unresolvedOnly = <String, TargetEvidence>{
        for (final sym in batchSymbols)
          sym: TargetEvidence(
            geneSymbol: sym,
            ensemblId: null,
            associationScore: null,
          ),
      };
      return ApiSuccess(
        data: unresolvedOnly,
        freshness: mapResult.freshness,
        retrievedAt: mapResult.retrievedAt,
      );
    }

    // 2. associatedTargets: Target-Disease association scores
    final assocResult = await _client.postJson(
      url: _endpoint,
      body: {
        'query': assocQuery,
        'variables': {
          'diseaseId': diseaseId,
          'targets': targetIds,
          'size': targetIds.length,
        },
      },
      cacheKey: 'ot:v1:assoc:$diseaseId:${targetIds.join(",")}',
    );

    if (assocResult is ApiFailure<Map<String, dynamic>>) {
      return ApiFailure(
        reason: assocResult.reason,
        message: assocResult.message,
        statusCode: assocResult.statusCode,
        cause: assocResult.cause,
      );
    }

    final assocData = (assocResult as ApiSuccess<Map<String, dynamic>>).data;
    final assocErrors = assocData['errors'];
    if (assocErrors is List && assocErrors.isNotEmpty) {
      return ApiFailure(
        reason: NetworkFailureReason.invalidResponse,
        message: _firstErrorMessage(assocErrors),
      );
    }

    final diseaseData = assocData['data'] as Map<String, dynamic>?;
    if (diseaseData != null &&
        diseaseData.containsKey('disease') &&
        diseaseData['disease'] == null) {
      return ApiFailure(
        reason: NetworkFailureReason.badRequest,
        message: 'Disease id not recognised: $diseaseId',
      );
    }

    final assocRows = diseaseData?['disease']?['associatedTargets']?['rows']
            as List<dynamic>? ??
        const [];

    final ensemblAssoc = <String, _AssocPayload>{};
    for (final row in assocRows) {
      final target = row['target'] as Map<String, dynamic>?;
      final id = target?['id'] as String?;
      final score = (row['score'] as num?)?.toDouble();
      final dtList = row['datatypeScores'] as List<dynamic>? ?? const [];
      final dtMap = <String, double>{};
      for (final dt in dtList) {
        final dtId = dt['id'] as String?;
        final dtScore = (dt['score'] as num?)?.toDouble();
        if (dtId != null && dtScore != null) {
          dtMap[dtId] = dtScore;
        }
      }
      if (id != null && score != null) {
        ensemblAssoc[id] = _AssocPayload(score: score, datatypeScores: dtMap);
      }
    }

    // 3. targets: Tractability and clinical candidates
    final targetsResult = await _client.postJson(
      url: _endpoint,
      body: {
        'query': targetsQuery,
        'variables': {'ids': targetIds},
      },
      cacheKey: 'ot:v1:targets:${targetIds.join(",")}',
    );

    if (targetsResult is ApiFailure<Map<String, dynamic>>) {
      return ApiFailure(
        reason: targetsResult.reason,
        message: targetsResult.message,
        statusCode: targetsResult.statusCode,
        cause: targetsResult.cause,
      );
    }

    final targetsData = (targetsResult as ApiSuccess<Map<String, dynamic>>).data;
    final targetsErrors = targetsData['errors'];
    if (targetsErrors is List && targetsErrors.isNotEmpty) {
      return ApiFailure(
        reason: NetworkFailureReason.invalidResponse,
        message: _firstErrorMessage(targetsErrors),
      );
    }

    final targetsList =
        targetsData['data']?['targets'] as List<dynamic>? ?? const [];

    final ensemblTargetDetails = <String, _TargetDetails>{};
    for (final t in targetsList) {
      final id = t['id'] as String?;
      if (id == null) continue;

      final approvedName = t['approvedName'] as String?;
      final biotype = (t['biotype'] as String?) ?? ensemblIdToBiotype[id];

      final tractRaw = t['tractability'] as List<dynamic>? ?? const [];
      final tractList = tractRaw.map((b) {
        return TractabilityBucket(
          label: b['label'] as String? ?? '',
          modality: b['modality'] as String? ?? '',
          value: b['value'] as bool? ?? false,
        );
      }).toList();

      final dcc = t['drugAndClinicalCandidates'] as Map<String, dynamic>?;
      final candCount = dcc?['count'] as int? ?? 0;
      final candRows = dcc?['rows'] as List<dynamic>? ?? const [];

      final candidates = candRows.map((r) {
        final maxStage = r['maxClinicalStage'] as String?;
        final drug = r['drug'] as Map<String, dynamic>?;
        final drugStage = drug?['maximumClinicalStage'] as String?;
        final effectiveStage =
            ClinicalStage.fromApiValue(maxStage ?? drugStage);

        final diseases = r['diseases'] as List<dynamic>? ?? const [];
        final indications = <String>[];
        for (final d in diseases) {
          final name = d['disease']?['name'] as String? ??
              d['diseaseFromSource'] as String?;
          if (name != null && !indications.contains(name)) {
            indications.add(name);
          }
        }

        return ClinicalCandidate(
          drugId: drug?['id'] as String?,
          drugName: drug?['name'] as String?,
          drugType: drug?['drugType'] as String?,
          stage: effectiveStage,
          indications: indications,
        );
      }).toList();

      ensemblTargetDetails[id] = _TargetDetails(
        approvedName: approvedName,
        biotype: biotype,
        tractability: tractList,
        clinicalCandidates: candidates,
        clinicalCandidateCount: candCount,
      );
    }

    // 4. Assemble final TargetEvidence per symbol in batch
    final batchEvidence = <String, TargetEvidence>{};
    for (final sym in batchSymbols) {
      final ensemblId = symbolToEnsemblId[sym];
      if (ensemblId == null) {
        batchEvidence[sym] = TargetEvidence(
          geneSymbol: sym,
          ensemblId: null,
          associationScore: null,
        );
        continue;
      }

      final assoc = ensemblAssoc[ensemblId];
      final details = ensemblTargetDetails[ensemblId];

      batchEvidence[sym] = TargetEvidence(
        geneSymbol: sym,
        ensemblId: ensemblId,
        approvedName: details?.approvedName,
        biotype: details?.biotype ?? ensemblIdToBiotype[ensemblId],
        associationScore: assoc?.score,
        datatypeScores: assoc?.datatypeScores ?? const {},
        tractability: details?.tractability ?? const [],
        clinicalCandidates: details?.clinicalCandidates ?? const [],
        clinicalCandidateCount: details?.clinicalCandidateCount ?? 0,
      );
    }

    // Determine batch freshness
    DataFreshness batchFreshness = DataFreshness.network;
    if (mapResult.freshness == DataFreshness.staleCache ||
        assocResult.freshness == DataFreshness.staleCache ||
        targetsResult.freshness == DataFreshness.staleCache) {
      batchFreshness = DataFreshness.staleCache;
    } else if (mapResult.freshness == DataFreshness.freshCache &&
        assocResult.freshness == DataFreshness.freshCache &&
        targetsResult.freshness == DataFreshness.freshCache) {
      batchFreshness = DataFreshness.freshCache;
    }

    return ApiSuccess(
      data: batchEvidence,
      freshness: batchFreshness,
      retrievedAt: mapResult.retrievedAt ?? DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _firstErrorMessage(List<dynamic> errors) {
    if (errors.isEmpty) return 'GraphQL error occurred.';
    final first = errors.first;
    if (first is Map && first['message'] is String) {
      return first['message'] as String;
    }
    return errors.first.toString();
  }

  static String _encodeEvidenceMap(Map<String, TargetEvidence> map) {
    final encoded = map.map((k, v) => MapEntry(k, v.toJson()));
    return jsonEncode(encoded);
  }

  static Map<String, TargetEvidence>? _decodeEvidenceMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded.map(
        (k, v) => MapEntry(k, TargetEvidence.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return null;
    }
  }
}

class _AssocPayload {
  const _AssocPayload({required this.score, required this.datatypeScores});

  final double score;
  final Map<String, double> datatypeScores;
}

class _TargetDetails {
  const _TargetDetails({
    this.approvedName,
    this.biotype,
    required this.tractability,
    required this.clinicalCandidates,
    required this.clinicalCandidateCount,
  });

  final String? approvedName;
  final String? biotype;
  final List<TractabilityBucket> tractability;
  final List<ClinicalCandidate> clinicalCandidates;
  final int clinicalCandidateCount;
}
