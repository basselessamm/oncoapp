import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/cancer_signature.dart';
import 'package:onco_repurpose_ai/models/target_evidence.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart';
import 'package:onco_repurpose_ai/providers/evidence_provider.dart';
import 'package:onco_repurpose_ai/screens/genomic_data_screen.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/services/open_targets_service.dart';
import 'package:provider/provider.dart';

class _DummyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  const testSignature = CancerSignature(
    id: 'sig_1',
    cancerName: 'TNBC Subtype',
    pmid: '99999',
    sampleSize: 50,
    significantGenes: [
      SignificantGene(
        symbol: 'TP53',
        type: 'Upregulated',
        log2fc: 2.8,
        pValue: 0.0001,
      ),
      SignificantGene(
        symbol: 'HORMAD1',
        type: 'Upregulated',
        log2fc: 3.5,
        pValue: 0.0002,
      ),
    ],
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required DataProvider dataProvider,
    required EvidenceProvider evidenceProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DataProvider>.value(value: dataProvider),
          ChangeNotifierProvider<EvidenceProvider>.value(value: evidenceProvider),
        ],
        child: const MaterialApp(
          home: GenomicDataScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays genes and Open Targets association chips', (tester) async {
    final dataProvider = DataProvider();
    dataProvider.selectedDataset = testSignature;

    final client = ApiClient(
      hasConsent: () => true,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);
    final evidenceProvider = EvidenceProvider(service: service);
    evidenceProvider.evidenceByGene = {
      'TP53': const TargetEvidence(
        geneSymbol: 'TP53',
        associationScore: 0.8606,
      ),
      'HORMAD1': const TargetEvidence(
        geneSymbol: 'HORMAD1',
        associationScore: 0.0998,
      ),
    };

    await pumpScreen(
      tester,
      dataProvider: dataProvider,
      evidenceProvider: evidenceProvider,
    );

    expect(find.text('TNBC Subtype'), findsOneWidget);
    expect(find.text('TP53'), findsOneWidget);
    expect(find.text('HORMAD1'), findsOneWidget);

    // Dense association chips in gene list
    expect(find.text('OT: 0.86'), findsOneWidget);
    expect(find.text('OT: 0.10'), findsOneWidget);
  });

  testWidgets('shows empty state when no dataset is selected', (tester) async {
    final dataProvider = DataProvider();
    dataProvider.selectedDataset = null;

    final client = ApiClient(
      hasConsent: () => true,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);
    final evidenceProvider = EvidenceProvider(service: service);

    await pumpScreen(
      tester,
      dataProvider: dataProvider,
      evidenceProvider: evidenceProvider,
    );

    expect(find.text('No signature selected'), findsOneWidget);
  });
}
