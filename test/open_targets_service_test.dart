import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/target_evidence.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/services/open_targets_service.dart';

class _StubClient extends http.BaseClient {
  _StubClient(this.handler);

  final Future<http.StreamedResponse> Function(int attempt, http.BaseRequest)
      handler;

  final List<DateTime> requestTimes = [];
  final List<String> requestBodies = [];

  int get callCount => requestTimes.length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestTimes.add(DateTime.now());
    if (request is http.Request) requestBodies.add(request.body);
    return handler(requestTimes.length, request);
  }
}

http.StreamedResponse _response(
  String body, {
  int status = 200,
}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: bytes.length,
  );
}

void main() {
  late Directory tempDir;
  late ResponseCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('open_targets_service_test');
    cache = ResponseCache(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ApiClient buildClient(
    _StubClient stub, {
    bool consent = true,
  }) {
    return ApiClient(
      hasConsent: () => consent,
      cache: cache,
      httpClient: stub,
      minRequestSpacing: Duration.zero,
      retryBackoff: const Duration(milliseconds: 1),
    );
  }

  // Sample fixtures mimicking real Open Targets responses
  const mapIdsSuccessResponse = '''
{
  "data": {
    "mapIds": {
      "mappings": [
        {
          "term": "TP53",
          "hits": [
            {
              "id": "ENSG00000141510",
              "object": {
                "approvedSymbol": "TP53",
                "biotype": "protein_coding"
              }
            }
          ]
        },
        {
          "term": "ESR1",
          "hits": [
            {
              "id": "ENSG00000091831",
              "object": {
                "approvedSymbol": "ESR1",
                "biotype": "protein_coding"
              }
            }
          ]
        },
        {
          "term": "UNKNOWN_GENE",
          "hits": []
        }
      ]
    }
  }
}
''';

  const assocSuccessResponse = '''
{
  "data": {
    "disease": {
      "id": "MONDO_0004989",
      "name": "breast carcinoma",
      "associatedTargets": {
        "count": 2,
        "rows": [
          {
            "score": 0.8606,
            "datatypeScores": [
              {"id": "somatic_mutation", "score": 0.74},
              {"id": "genetic_association", "score": 0.81}
            ],
            "target": {
              "id": "ENSG00000141510",
              "approvedSymbol": "TP53"
            }
          },
          {
            "score": 0.8179,
            "datatypeScores": [
              {"id": "known_drug", "score": 0.90},
              {"id": "rna_expression", "score": 0.65}
            ],
            "target": {
              "id": "ENSG00000091831",
              "approvedSymbol": "ESR1"
            }
          }
        ]
      }
    }
  }
}
''';

  const targetsSuccessResponse = '''
{
  "data": {
    "targets": [
      {
        "id": "ENSG00000141510",
        "approvedSymbol": "TP53",
        "approvedName": "tumor protein p53",
        "biotype": "protein_coding",
        "tractability": [
          {"label": "Clinical Precedence", "modality": "SM", "value": true},
          {"label": "Predicted Druggable", "modality": "AB", "value": false}
        ],
        "drugAndClinicalCandidates": {
          "count": 1,
          "rows": [
            {
              "maxClinicalStage": "PHASE_2",
              "drug": {
                "id": "CHEMBL253441",
                "name": "APR-246",
                "drugType": "Small molecule",
                "maximumClinicalStage": "PHASE_2"
              },
              "diseases": [
                {
                  "diseaseFromSource": "Myelodysplastic Syndrome",
                  "disease": {"id": "MONDO_0018881", "name": "myelodysplastic syndrome"}
                }
              ]
            }
          ]
        }
      },
      {
        "id": "ENSG00000091831",
        "approvedSymbol": "ESR1",
        "approvedName": "estrogen receptor 1",
        "biotype": "protein_coding",
        "tractability": [
          {"label": "Approved Drug", "modality": "SM", "value": true}
        ],
        "drugAndClinicalCandidates": {
          "count": 5,
          "rows": [
            {
              "maxClinicalStage": "APPROVAL",
              "drug": {
                "id": "CHEMBL83",
                "name": "Tamoxifen",
                "drugType": "Small molecule",
                "maximumClinicalStage": "APPROVAL"
              },
              "diseases": [
                {
                  "diseaseFromSource": "Breast Neoplasms",
                  "disease": {"id": "MONDO_0004989", "name": "breast carcinoma"}
                }
              ]
            }
          ]
        }
      }
    ]
  }
}
''';

  group('Guard tests against broken API query', () {
    test('OpenTargetsService must NEVER use associatedDiseases(', () {
      // Critical guard test: target.associatedDiseases(Bs:) ignores disease filtering
      // and returns false scores. Ensure it is absent from all queries.
      expect(OpenTargetsService.assocQuery.contains('associatedDiseases('), isFalse);
      expect(OpenTargetsService.mapIdsQuery.contains('associatedDiseases('), isFalse);
      expect(OpenTargetsService.targetsQuery.contains('associatedDiseases('), isFalse);
      expect(OpenTargetsService.diseaseSearchQuery.contains('associatedDiseases('), isFalse);
    });

    test('Assoc query explicitly includes enableIndirect: true', () {
      expect(OpenTargetsService.assocQuery.contains('enableIndirect: true'), isTrue);
      expect(OpenTargetsService.assocQuery.contains('associatedTargets('), isTrue);
    });
  });

  group('fetchEvidence pipeline', () {
    test('successfully executes 3-step pipeline and combines data', () async {
      final stub = _StubClient((attempt, request) async {
        final body = (request as http.Request).body;
        if (body.contains('query Map')) return _response(mapIdsSuccessResponse);
        if (body.contains('query Assoc')) return _response(assocSuccessResponse);
        if (body.contains('query Targets')) return _response(targetsSuccessResponse);
        return _response('{}');
      });

      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: ['TP53', 'ESR1', 'UNKNOWN_GENE'],
        diseaseId: 'MONDO_0004989',
      );

      expect(result.isSuccess, isTrue);
      final data = (result as ApiSuccess<Map<String, TargetEvidence>>).data;

      expect(data.length, 3);

      // TP53 checks
      final tp53 = data['TP53']!;
      expect(tp53.isResolved, isTrue);
      expect(tp53.ensemblId, 'ENSG00000141510');
      expect(tp53.approvedName, 'tumor protein p53');
      expect(tp53.associationScore, 0.8606);
      expect(tp53.associationStrength, AssociationStrength.strong);
      expect(tp53.datatypeScores['somatic_mutation'], 0.74);
      expect(tp53.datatypeScores['genetic_association'], 0.81);
      expect(tp53.tractability.length, 2);
      expect(tp53.clinicalCandidateCount, 1);
      expect(tp53.mostAdvancedCandidate?.drugName, 'APR-246');
      expect(tp53.mostAdvancedCandidate?.stage, ClinicalStage.phase2);
      expect(tp53.mostAdvancedCandidate?.indications, contains('myelodysplastic syndrome'));
      expect(tp53.bestTractability, TractabilityTier.advancedClinical);
      expect(tp53.isLikelyPassenger, isFalse);

      // ESR1 checks
      final esr1 = data['ESR1']!;
      expect(esr1.isResolved, isTrue);
      expect(esr1.associationScore, 0.8179);
      expect(esr1.associationStrength, AssociationStrength.strong);
      expect(esr1.bestTractability, TractabilityTier.approvedDrug);
      expect(esr1.mostAdvancedCandidate?.stage, ClinicalStage.approval);
      expect(esr1.isLikelyPassenger, isFalse);

      // Unresolved gene checks
      final unknown = data['UNKNOWN_GENE']!;
      expect(unknown.isResolved, isFalse);
      expect(unknown.ensemblId, isNull);
      expect(unknown.associationScore, isNull);
      expect(unknown.hasAssociation, isFalse);
      expect(unknown.isLikelyPassenger, isTrue);
    });

    test('returns empty map immediately when gene list is empty', () async {
      final stub = _StubClient((_, __) async => _response('{}'));
      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: [],
        diseaseId: 'MONDO_0004989',
      );

      expect(stub.callCount, 0);
      expect(result.dataOrNull, isEmpty);
    });

    test('retains genes without association row with associationScore == null', () async {
      const mapOne = '''
{
  "data": {
    "mapIds": {
      "mappings": [
        {
          "term": "OR4F5",
          "hits": [{"id": "ENSG00000186092", "object": {"approvedSymbol": "OR4F5"}}]
        }
      ]
    }
  }
}
''';
      const assocEmpty = '''
{
  "data": {
    "disease": {
      "id": "MONDO_0004989",
      "associatedTargets": {"count": 0, "rows": []}
    }
  }
}
''';
      const targetsEmpty = '''
{
  "data": {
    "targets": [
      {
        "id": "ENSG00000186092",
        "approvedSymbol": "OR4F5",
        "approvedName": "olfactory receptor family 4 subfamily F member 5",
        "tractability": [],
        "drugAndClinicalCandidates": {"count": 0, "rows": []}
      }
    ]
  }
}
''';

      final stub = _StubClient((_, request) async {
        final body = (request as http.Request).body;
        if (body.contains('query Map')) return _response(mapOne);
        if (body.contains('query Assoc')) return _response(assocEmpty);
        return _response(targetsEmpty);
      });

      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: ['OR4F5'],
        diseaseId: 'MONDO_0004989',
      );

      final evidence = result.dataOrNull!['OR4F5']!;
      expect(evidence.isResolved, isTrue);
      expect(evidence.associationScore, isNull);
      expect(evidence.associationStrength, AssociationStrength.notReported);
      expect(evidence.isLikelyPassenger, isTrue);
    });
  });

  group('GraphQL error handling', () {
    test('maps errors field in 200 response to invalidResponse', () async {
      const errorJson = '''
{
  "errors": [
    {"message": "Cannot query field 'invalidField' on type 'Target'."}
  ]
}
''';
      final stub = _StubClient((_, __) async => _response(errorJson));
      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: ['TP53'],
        diseaseId: 'MONDO_0004989',
      );

      expect(result, isA<ApiFailure>());
      final failure = result as ApiFailure;
      expect(failure.reason, NetworkFailureReason.invalidResponse);
      expect(failure.message, contains('Cannot query field'));
    });

    test('maps data.disease == null to badRequest', () async {
      const nullDiseaseJson = '''
{
  "data": {
    "disease": null
  }
}
''';
      final stub = _StubClient((_, request) async {
        final body = (request as http.Request).body;
        if (body.contains('query Map')) return _response(mapIdsSuccessResponse);
        return _response(nullDiseaseJson);
      });

      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: ['TP53'],
        diseaseId: 'INVALID_DISEASE_ID',
      );

      expect(result, isA<ApiFailure>());
      final failure = result as ApiFailure;
      expect(failure.reason, NetworkFailureReason.badRequest);
      expect(failure.message, contains('Disease id not recognised: INVALID_DISEASE_ID'));
    });
  });

  group('batching and caching', () {
    test('splits requests exceeding maxGenesPerBatch into multiple batches', () async {
      final genes = List.generate(205, (i) => 'GENE_$i');

      final stub = _StubClient((_, request) async {
        final body = (request as http.Request).body;
        if (body.contains('query Map')) {
          // Check that terms in variables <= 200
          final decoded = jsonDecode(body);
          final terms = decoded['variables']['terms'] as List;
          expect(terms.length, lessThanOrEqualTo(200));
          return _response('{"data":{"mapIds":{"mappings":[]}}}');
        }
        return _response('{}');
      });

      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.fetchEvidence(
        geneSymbols: genes,
        diseaseId: 'MONDO_0004989',
      );

      expect(result.isSuccess, isTrue);
      // 205 genes split into batch of 200 and batch of 5: mapIds called twice
      expect(stub.callCount, 2);
    });

    test('cache key is stable under symbol reordering', () async {
      final stub = _StubClient((_, request) async {
        final body = (request as http.Request).body;
        if (body.contains('query Map')) return _response(mapIdsSuccessResponse);
        if (body.contains('query Assoc')) return _response(assocSuccessResponse);
        if (body.contains('query Targets')) return _response(targetsSuccessResponse);
        return _response('{}');
      });

      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      // First call with ['TP53', 'ESR1']
      await service.fetchEvidence(
        geneSymbols: ['TP53', 'ESR1'],
        diseaseId: 'MONDO_0004989',
      );
      final callsAfterFirst = stub.callCount;
      expect(callsAfterFirst, 3); // Map, Assoc, Targets

      // Second call with reverse order: ['ESR1', 'TP53']
      final secondResult = await service.fetchEvidence(
        geneSymbols: ['ESR1', 'TP53'],
        diseaseId: 'MONDO_0004989',
      );

      // Must hit top-level cache and make zero new requests
      expect(stub.callCount, callsAfterFirst);
      expect(secondResult.isSuccess, isTrue);
      final success = secondResult as ApiSuccess<Map<String, TargetEvidence>>;
      expect(success.freshness, DataFreshness.freshCache);
    });
  });

  group('searchDiseases', () {
    test('returns default breast cancer diseases for empty query', () async {
      final stub = _StubClient((_, __) async => _response('{}'));
      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.searchDiseases('');
      expect(stub.callCount, 0);
      expect(result.dataOrNull?.length, 3);
      expect(result.dataOrNull?.first.id, 'MONDO_0004989');
    });

    test('parses disease search hits into DiseaseOption', () async {
      const searchResponse = '''
{
  "data": {
    "search": {
      "hits": [
        {
          "id": "MONDO_0004989",
          "name": "breast carcinoma",
          "description": "Malignant neoplasm of the breast.",
          "object": {
            "therapeuticAreas": [
              {"id": "MONDO_0000001", "name": "neoplasm"}
            ]
          }
        }
      ]
    }
  }
}
''';
      final stub = _StubClient((_, __) async => _response(searchResponse));
      final client = buildClient(stub);
      final service = OpenTargetsService(client: client);

      final result = await service.searchDiseases('breast');
      expect(result.isSuccess, isTrue);
      final list = result.dataOrNull!;
      expect(list.length, 1);
      expect(list.first.id, 'MONDO_0004989');
      expect(list.first.name, 'breast carcinoma');
      expect(list.first.description, contains('Malignant'));
      expect(list.first.therapeuticAreas, contains('neoplasm'));
    });
  });
}
