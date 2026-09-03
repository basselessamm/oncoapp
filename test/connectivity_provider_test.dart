import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';
import 'package:onco_repurpose_ai/providers/connectivity_provider.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart' show LoadStatus;
import 'package:onco_repurpose_ai/services/lincs_service.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';

class _FakeLincsService extends LincsService {
  _FakeLincsService({required this.result})
      : super(
          client: ApiClient(
            hasConsent: () => true,
            cache: ResponseCache(directoryOverride: null),
            httpClient: null,
          ),
        );

  final ApiResult<Map<String, LincsEvidence>> result;

  @override
  Future<ApiResult<Map<String, LincsEvidence>>> fetchConnectivity({
    required List<String> upGenes,
    required List<String> downGenes,
  }) async {
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityProvider', () {
    test('starts in idle state', () {
      final provider = ConnectivityProvider(
        lincsService: _FakeLincsService(
          result: const ApiSuccess(
            data: {},
            freshness: DataFreshness.network,
          ),
        ),
      );

      expect(provider.status, LoadStatus.idle);
      expect(provider.evidenceByDrug, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    test('stores evidence on success and allows case-insensitive lookup', () async {
      final provider = ConnectivityProvider(
        lincsService: _FakeLincsService(
          result: const ApiSuccess(
            data: {
              'TAMOXIFEN': LincsEvidence(
                drugName: 'TAMOXIFEN',
                score: -0.65,
                qval: 0.01,
              ),
            },
            freshness: DataFreshness.network,
          ),
        ),
      );

      await provider.fetchForSignature(
        signatureKey: 'sig_1',
        upGenes: ['ESR1'],
        downGenes: ['TP53'],
      );

      expect(provider.status, LoadStatus.ready);
      expect(provider.evidenceByDrug.length, 1);

      final tam = provider.getEvidenceForDrug('tamoxifen');
      expect(tam, isNotNull);
      expect(tam!.score, -0.65);
      expect(tam.tier, ReversalTier.strongReversal);
    });

    test('handles failure state properly', () async {
      final provider = ConnectivityProvider(
        lincsService: _FakeLincsService(
          result: const ApiFailure(
            reason: NetworkFailureReason.serverError,
            message: 'Server unreachable',
            statusCode: 503,
          ),
        ),
      );

      await provider.fetchForSignature(
        signatureKey: 'sig_1',
        upGenes: ['ESR1'],
        downGenes: ['TP53'],
      );

      expect(provider.status, LoadStatus.failed);
      expect(provider.errorMessage, 'Server unreachable');
      expect(provider.evidenceByDrug, isEmpty);
      expect(provider.isConsentBlocked, isFalse);
    });

    test('detects consent blocked failure', () async {
      final provider = ConnectivityProvider(
        lincsService: _FakeLincsService(
          result: const ApiFailure(
            reason: NetworkFailureReason.consentNotGranted,
            message: 'Consent not granted',
          ),
        ),
      );

      await provider.fetchForSignature(
        signatureKey: 'sig_1',
        upGenes: ['ESR1'],
        downGenes: ['TP53'],
      );

      expect(provider.status, LoadStatus.failed);
      expect(provider.isConsentBlocked, isTrue);
    });
  });
}
