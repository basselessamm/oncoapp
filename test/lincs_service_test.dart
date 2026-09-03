import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';
import 'package:onco_repurpose_ai/services/lincs_service.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';

class _MockHttp extends http.BaseClient {
  _MockHttp(this.handler);

  final Future<http.Response> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ResponseCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lincs_service_test');
    cache = ResponseCache(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ApiClient buildClient(_MockHttp mock, {bool consent = true}) {
    return ApiClient(
      hasConsent: () => consent,
      cache: cache,
      httpClient: mock,
      minRequestSpacing: Duration.zero,
      retryBackoff: const Duration(milliseconds: 1),
    );
  }

  group('LincsService', () {
    test('returns empty success if up and down genes are empty', () async {
      final mock = _MockHttp((_) async => http.Response('{}', 200));
      final client = buildClient(mock);
      final service = LincsService(client: client);

      final result = await service.fetchConnectivity(upGenes: [], downGenes: []);
      expect(result, isA<ApiSuccess<Map<String, LincsEvidence>>>());
      expect((result as ApiSuccess).data, isEmpty);
    });

    test('fetches and parses topn opposing and similar perturbagens', () async {
      final mock = _MockHttp((request) async {
        final path = request.url.path;
        if (path.endsWith('sig_search')) {
          return http.Response(
            jsonEncode({'result_id': 'test_res_123'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('result/topn/test_res_123')) {
          return http.Response(
            jsonEncode({
              'opposite': [
                {
                  'sig_id': 'CPC008_MCF7_24H:BRD-K93754473-001-01-4:10',
                  'scores': -0.62,
                  'pvals': 0.0001,
                  'qvals': 0.015,
                  'zscores': 2.45,
                  'combined_scores': -15.2,
                },
                {
                  'sig_id': 'CPC004_HCC515_6H:BRD-UNKNOWN-001-01-1:10',
                  'scores': -0.35,
                  'pvals': 0.002,
                  'qvals': 0.04,
                }
              ],
              'similar': [
                {
                  'sig_id': 'CPC001_HA1E_24H:BRD-A10188456-001-02-1:10',
                  'scores': 0.45,
                  'pvals': 0.001,
                  'qvals': 0.02,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('sig/CPC004_HCC515_6H:BRD-UNKNOWN-001-01-1:10')) {
          return http.Response(
            jsonEncode({'pert_desc': 'CUSTOM_DRUG', 'cell_id': 'HCC515'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = buildClient(mock);
      final service = LincsService(client: client);

      final result = await service.fetchConnectivity(
        upGenes: ['ESR1', 'GATA3'],
        downGenes: ['TP53'],
      );

      expect(result, isA<ApiSuccess<Map<String, LincsEvidence>>>());
      final data = (result as ApiSuccess<Map<String, LincsEvidence>>).data;

      // 1. TAMOXIFEN matched via known pert_id BRD-K93754473
      expect(data.containsKey('TAMOXIFEN'), isTrue);
      final tam = data['TAMOXIFEN']!;
      expect(tam.score, -0.62);
      expect(tam.tier, ReversalTier.strongReversal);
      expect(tam.cellLine, 'MCF7');
      expect(tam.durationHours, 24);

      // 2. CUSTOM_DRUG matched via sig/ lookup
      expect(data.containsKey('CUSTOM_DRUG'), isTrue);
      final custom = data['CUSTOM_DRUG']!;
      expect(custom.score, -0.35);
      expect(custom.tier, ReversalTier.strongReversal);

      // 3. DEXAMETHASONE matched via similar (mimic)
      expect(data.containsKey('DEXAMETHASONE'), isTrue);
      final dex = data['DEXAMETHASONE']!;
      expect(dex.score, 0.45);
      expect(dex.tier, ReversalTier.mimic);
    });

    test('handles API failure gracefully when sig_search fails', () async {
      final mock = _MockHttp((_) async => http.Response('Server Error', 500));
      final client = buildClient(mock);
      final service = LincsService(client: client);

      final result = await service.fetchConnectivity(
        upGenes: ['ESR1'],
        downGenes: ['TP53'],
      );

      expect(result, isA<ApiFailure<Map<String, LincsEvidence>>>());
      expect((result as ApiFailure).statusCode, 500);
    });
  });
}
