import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/disease_option.dart';
import 'package:onco_repurpose_ai/models/target_evidence.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart' show LoadStatus;
import 'package:onco_repurpose_ai/providers/evidence_provider.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/services/open_targets_service.dart';

class _FakeService extends OpenTargetsService {
  _FakeService({
    required super.client,
    this.fetchEvidenceHandler,
  });

  Future<ApiResult<Map<String, TargetEvidence>>> Function(
    List<String> symbols,
    String diseaseId,
  )? fetchEvidenceHandler;

  @override
  Future<ApiResult<Map<String, TargetEvidence>>> fetchEvidence({
    required List<String> geneSymbols,
    required String diseaseId,
  }) async {
    if (fetchEvidenceHandler != null) {
      return fetchEvidenceHandler!(geneSymbols, diseaseId);
    }
    return ApiSuccess(
      data: {
        for (final s in geneSymbols)
          s.toUpperCase(): TargetEvidence(
            geneSymbol: s.toUpperCase(),
            associationScore: 0.5,
          ),
      },
      freshness: DataFreshness.network,
      retrievedAt: DateTime.now(),
    );
  }
}

class _DummyHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  late Directory tempDir;
  late ResponseCache cache;
  late ApiClient apiClient;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('evidence_provider_test');
    cache = ResponseCache(directoryOverride: tempDir);
    apiClient = ApiClient(
      hasConsent: () => true,
      cache: cache,
      httpClient: _DummyHttpClient(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('EvidenceProvider state lifecycle', () {
    test('initializes with idle status, default disease, and empty evidence', () {
      final service = _FakeService(client: apiClient);
      final provider = EvidenceProvider(service: service);

      expect(provider.status, LoadStatus.idle);
      expect(provider.evidenceByGene, isEmpty);
      expect(provider.error, isNull);
      expect(provider.failureReason, isNull);
      expect(provider.isConsentBlocked, isFalse);
      expect(provider.selectedDisease?.id, 'MONDO_0004989');
    });

    test('loadEvidence with empty list completes immediately with empty map', () async {
      final service = _FakeService(client: apiClient);
      final provider = EvidenceProvider(service: service);

      await provider.loadEvidence([]);

      expect(provider.status, LoadStatus.ready);
      expect(provider.evidenceByGene, isEmpty);
      expect(provider.error, isNull);
    });

    test('transitions to ready on successful evidence fetch', () async {
      final service = _FakeService(client: apiClient);
      final provider = EvidenceProvider(service: service);

      final future = provider.loadEvidence(['TP53', 'esr1']);
      expect(provider.status, LoadStatus.loading);

      await future;

      expect(provider.status, LoadStatus.ready);
      expect(provider.evidenceByGene.length, 2);
      expect(provider.evidenceFor('tp53')?.geneSymbol, 'TP53');
      expect(provider.evidenceFor('ESR1')?.geneSymbol, 'ESR1');
      expect(provider.freshness, DataFreshness.network);
      expect(provider.retrievedAt, isNotNull);
    });

    test('transitions to failed and sets isConsentBlocked on consentNotGranted', () async {
      final service = _FakeService(
        client: apiClient,
        fetchEvidenceHandler: (symbols, diseaseId) async {
          return const ApiFailure(
            reason: NetworkFailureReason.consentNotGranted,
            message: 'External lookups are turned off in Settings.',
          );
        },
      );

      final provider = EvidenceProvider(service: service);
      await provider.loadEvidence(['TP53']);

      expect(provider.status, LoadStatus.failed);
      expect(provider.failureReason, NetworkFailureReason.consentNotGranted);
      expect(provider.isConsentBlocked, isTrue);
      expect(provider.error, contains('Settings'));
    });

    test('transitions to failed on network offline without blocking consent', () async {
      final service = _FakeService(
        client: apiClient,
        fetchEvidenceHandler: (symbols, diseaseId) async {
          return const ApiFailure(
            reason: NetworkFailureReason.offline,
            message: 'No network connection.',
          );
        },
      );

      final provider = EvidenceProvider(service: service);
      await provider.loadEvidence(['TP53']);

      expect(provider.status, LoadStatus.failed);
      expect(provider.failureReason, NetworkFailureReason.offline);
      expect(provider.isConsentBlocked, isFalse);
      expect(provider.error, contains('No network connection'));
    });

    test('passes through staleCache freshness and timestamp', () async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final service = _FakeService(
        client: apiClient,
        fetchEvidenceHandler: (symbols, diseaseId) async {
          return ApiSuccess(
            data: {
              'TP53': const TargetEvidence(
                geneSymbol: 'TP53',
                associationScore: 0.86,
              ),
            },
            freshness: DataFreshness.staleCache,
            retrievedAt: past,
          );
        },
      );

      final provider = EvidenceProvider(service: service);
      await provider.loadEvidence(['TP53']);

      expect(provider.freshness, DataFreshness.staleCache);
      expect(provider.retrievedAt, past);
    });

    test('selectDisease updates disease, clears evidence, and refetches active genes', () async {
      String? queriedDisease;
      final service = _FakeService(
        client: apiClient,
        fetchEvidenceHandler: (symbols, diseaseId) async {
          queriedDisease = diseaseId;
          return ApiSuccess(
            data: {
              'TP53': TargetEvidence(
                geneSymbol: 'TP53',
                associationScore: diseaseId == 'MONDO_0005494' ? 0.75 : 0.86,
              ),
            },
            freshness: DataFreshness.network,
          );
        },
      );

      final provider = EvidenceProvider(service: service);
      await provider.loadEvidence(['TP53']);
      expect(queriedDisease, 'MONDO_0004989');
      expect(provider.evidenceFor('TP53')?.associationScore, 0.86);

      // Select new disease: Triple-negative breast carcinoma
      const tnbc = DiseaseOption(
        id: 'MONDO_0005494',
        name: 'Triple-negative breast carcinoma',
      );
      provider.selectDisease(tnbc);

      expect(provider.selectedDisease?.id, 'MONDO_0005494');
      // Wait for refetch to complete
      await pumpEventQueue();

      expect(queriedDisease, 'MONDO_0005494');
      expect(provider.evidenceFor('TP53')?.associationScore, 0.75);
    });

    test('selectDisease does not refetch if no genes were previously queried', () async {
      var callCount = 0;
      final service = _FakeService(
        client: apiClient,
        fetchEvidenceHandler: (symbols, diseaseId) async {
          callCount++;
          return const ApiSuccess(data: {}, freshness: DataFreshness.network);
        },
      );

      final provider = EvidenceProvider(service: service);
      const newDisease = DiseaseOption(id: 'MONDO_0006256', name: 'Invasive');
      provider.selectDisease(newDisease);

      expect(callCount, 0);
      expect(provider.selectedDisease?.id, 'MONDO_0006256');
      expect(provider.status, LoadStatus.idle);
    });
  });
}
