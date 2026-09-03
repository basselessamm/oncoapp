import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';

/// Service for querying LINCS L1000 transcriptomic perturbation signatures
/// via the NIH LINCS L1000FWD REST API (Ma'ayan Laboratory).
class LincsService {
  LincsService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  static const String _baseUrl = 'https://maayanlab.cloud/l1000fwd/';

  /// Curated dictionary mapping frequent LINCS Broad perturbation IDs to standard uppercase drug names.
  static const Map<String, String> _knownPertIdToDrug = {
    'BRD-K93754473': 'TAMOXIFEN',
    'BRD-K04210847': 'TAMOXIFEN',
    'BRD-K43744935': 'TAMOXIFEN',
    'BRD-A52530684': 'DOXORUBICIN',
    'BRD-K61468417': 'DOXORUBICIN',
    'BRD-A73909368': 'DACTINOMYCIN',
    'BRD-A10188456': 'DEXAMETHASONE',
    'BRD-A35108200': 'DEXAMETHASONE',
    'BRD-A69951442': 'DEXAMETHASONE',
    'BRD-A93424738': 'DEXAMETHASONE',
    'BRD-K38775274': 'DEXAMETHASONE',
    'BRD-K47635719': 'DEXAMETHASONE',
    'BRD-K07265709': 'DEXRAZOXANE',
    'BRD-A46747628': 'PACLITAXEL',
    'BRD-K80348542': 'CISPLATIN',
    'BRD-A93236127': 'GEMCITABINE',
    'BRD-K23478508': 'BORTEZOMIB',
    'BRD-K91370081': 'LAPATINIB',
    'BRD-K18518344': 'GEFITINIB',
    'BRD-A89434049': 'ERLOTINIB',
    'BRD-K84595254': 'IMATINIB',
    'BRD-K01976263': 'FULVESTRANT',
    'BRD-K76674262': 'VORINOSTAT',
    'BRD-K31843556': 'VINBLASTINE',
    'BRD-K52075040': 'METHOTREXATE',
    'BRD-A68009927': 'SIROLIMUS',
    'BRD-K01896723': 'EVEROLIMUS',
    'BRD-K85853281': 'SORAFENIB',
    'BRD-K79090631': 'SUNITINIB',
  };

  /// Computes whole-signature transcriptomic connectivity scores for up/down gene sets.
  ///
  /// Returns a map of normalized uppercase drug names to their [LincsEvidence].
  Future<ApiResult<Map<String, LincsEvidence>>> fetchConnectivity({
    required List<String> upGenes,
    required List<String> downGenes,
  }) async {
    final cleanUp = upGenes
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final cleanDown = downGenes
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (cleanUp.isEmpty && cleanDown.isEmpty) {
      return ApiSuccess(
        data: const {},
        freshness: DataFreshness.network,
        retrievedAt: DateTime.now(),
      );
    }

    final cacheKey =
        'lincs:v1:sig:${cleanUp.join(",")}:${cleanDown.join(",")}';

    // Step 1: Submit up and down gene sets to sig_search
    final searchResult = await _client.postJson(
      url: Uri.parse('${_baseUrl}sig_search'),
      body: {
        'up_genes': cleanUp,
        'down_genes': cleanDown,
      },
      cacheKey: '$cacheKey:search',
    );

    switch (searchResult) {
      case ApiFailure(:final reason, :final message, :final statusCode, :final cause):
        return ApiFailure(
          reason: reason,
          message: message,
          statusCode: statusCode,
          cause: cause,
        );

      case ApiSuccess(:final data, :final freshness, :final retrievedAt):
        final resultId = data['result_id'] as String?;
        if (resultId == null || resultId.isEmpty) {
          return const ApiFailure(
            reason: NetworkFailureReason.invalidResponse,
            message: 'L1000FWD did not return a valid result identifier.',
          );
        }

        // Step 2: Retrieve top opposing and similar perturbagen signatures
        final topnResult = await _client.getJson(
          url: Uri.parse('${_baseUrl}result/topn/$resultId'),
          cacheKey: 'lincs:v1:topn:$resultId',
        );

        switch (topnResult) {
          case ApiFailure(:final reason, :final message, :final statusCode, :final cause):
            return ApiFailure(
              reason: reason,
              message: message,
              statusCode: statusCode,
              cause: cause,
            );

          case ApiSuccess(data: final topnData):
            final evidenceMap = await _processTopnData(topnData);

            return ApiSuccess(
              data: evidenceMap,
              freshness: freshness == DataFreshness.staleCache ||
                      topnResult.freshness == DataFreshness.staleCache
                  ? DataFreshness.staleCache
                  : freshness == DataFreshness.freshCache &&
                          topnResult.freshness == DataFreshness.freshCache
                      ? DataFreshness.freshCache
                      : DataFreshness.network,
              retrievedAt: retrievedAt ?? DateTime.now(),
            );
        }
    }
  }

  /// Processes the topn JSON payload from L1000FWD into a mapped dictionary of [LincsEvidence].
  Future<Map<String, LincsEvidence>> _processTopnData(
      Map<String, dynamic> topnData) async {
    final evidenceByDrug = <String, LincsEvidence>{};

    final oppositeList = (topnData['opposite'] as List<dynamic>?) ?? const [];
    final similarList = (topnData['similar'] as List<dynamic>?) ?? const [];

    // Process reversal / opposing hits first (primary therapeutic focus)
    for (final item in oppositeList) {
      if (item is! Map<String, dynamic>) continue;
      final ev = await _parseHit(item, isOpposite: true);
      if (ev != null) {
        final existing = evidenceByDrug[ev.drugName];
        if (existing == null || ev.score < existing.score) {
          evidenceByDrug[ev.drugName] = ev;
        }
      }
    }

    // Process mimicking hits (for warning if a drug mimics the cancer signature)
    for (final item in similarList) {
      if (item is! Map<String, dynamic>) continue;
      final ev = await _parseHit(item, isOpposite: false);
      if (ev != null) {
        final existing = evidenceByDrug[ev.drugName];
        if (existing == null) {
          evidenceByDrug[ev.drugName] = ev;
        }
      }
    }

    return evidenceByDrug;
  }

  Future<LincsEvidence?> _parseHit(Map<String, dynamic> item,
      {required bool isOpposite}) async {
    final sigId = item['sig_id'] as String? ?? '';
    final score = (item['scores'] as num?)?.toDouble() ?? 0.0;
    final pval = (item['pvals'] as num?)?.toDouble();
    final qval = (item['qvals'] as num?)?.toDouble();
    final zscore = (item['zscores'] as num?)?.toDouble();
    final combined = (item['combined_scores'] as num?)?.toDouble();

    final meta = LincsEvidence.parseSigIdMetadata(sigId);

    // Resolve drug name
    final drugName = await _resolveDrugName(sigId);
    if (drugName == null || drugName.isEmpty) return null;

    return LincsEvidence(
      drugName: drugName,
      score: score,
      pval: pval,
      qval: qval,
      zscore: zscore,
      combinedScore: combined,
      sigId: sigId,
      cellLine: meta.cellLine,
      durationHours: meta.durationHours,
      dose: meta.dose,
    );
  }

  /// Resolves the drug name from a signature ID.
  ///
  /// Uses known dictionary first, otherwise fetches metadata from `sig/<sig_id>`.
  Future<String?> _resolveDrugName(String sigId) async {
    // 1. Extract pert_id prefix
    final parts = sigId.split(':');
    if (parts.length >= 2) {
      final pertSub = parts[1];
      final pertIdParts = pertSub.split('-');
      if (pertIdParts.length >= 2) {
        final pertId = '${pertIdParts[0]}-${pertIdParts[1]}';
        if (_knownPertIdToDrug.containsKey(pertId)) {
          return _knownPertIdToDrug[pertId];
        }
      }
    }

    // 2. Query /sig/<sig_id> with disk caching
    final metaResult = await _client.getJson(
      url: Uri.parse('${_baseUrl}sig/$sigId'),
      cacheKey: 'lincs:v1:sig_meta:$sigId',
    );

    if (metaResult is ApiSuccess<Map<String, dynamic>>) {
      final pertDesc = metaResult.data['pert_desc'] as String?;
      if (pertDesc != null && pertDesc.isNotEmpty) {
        return pertDesc.trim().toUpperCase();
      }
    }

    return null;
  }
}
