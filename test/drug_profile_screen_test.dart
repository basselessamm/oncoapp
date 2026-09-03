import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/drug_interaction.dart';
import 'package:onco_repurpose_ai/models/target_evidence.dart';
import 'package:onco_repurpose_ai/providers/connectivity_provider.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart';
import 'package:onco_repurpose_ai/providers/evidence_provider.dart';
import 'package:onco_repurpose_ai/screens/drug_profile_screen.dart';
import 'package:onco_repurpose_ai/services/lincs_service.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/network_consent.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/services/open_targets_service.dart';
import 'package:onco_repurpose_ai/widgets/evidence_widgets.dart';
import 'package:provider/provider.dart';

class _DummyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  const testInteraction = DrugInteraction(
    gene: 'TP53',
    drug: 'APR-246',
    interactionTypes: ['activator'],
    sources: ['ChEMBL'],
    score: 2.5,
    isApproved: false,
    targetCount: 1,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required EvidenceProvider evidenceProvider,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final dataProvider = DataProvider();
    final consent = NetworkConsent();
    final cache = ResponseCache();

    final connectivityProvider = ConnectivityProvider(
      lincsService: LincsService(
        client: ApiClient(
          hasConsent: () => true,
          cache: cache,
          httpClient: _DummyClient(),
        ),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DataProvider>.value(value: dataProvider),
          ChangeNotifierProvider<NetworkConsent>.value(value: consent),
          Provider<ResponseCache>.value(value: cache),
          ChangeNotifierProvider<EvidenceProvider>.value(value: evidenceProvider),
          ChangeNotifierProvider<ConnectivityProvider>.value(
              value: connectivityProvider),
        ],
        child: const MaterialApp(
          home: DrugProfileScreen(interaction: testInteraction),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays consent blocked note when consent is not granted', (tester) async {
    final client = ApiClient(
      hasConsent: () => false,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);
    final provider = EvidenceProvider(service: service);
    provider.status = LoadStatus.failed;
    provider.failureReason = NetworkFailureReason.consentNotGranted;

    await pumpScreen(tester, evidenceProvider: provider);

    expect(find.text('External evidence'), findsOneWidget);
    expect(find.byType(EvidenceUnavailableNote), findsOneWidget);
  });

  testWidgets('displays Open Targets evidence details when loaded', (tester) async {
    final client = ApiClient(
      hasConsent: () => true,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);
    final provider = EvidenceProvider(service: service);
    provider.evidenceByGene = {
      'TP53': const TargetEvidence(
        geneSymbol: 'TP53',
        associationScore: 0.8606,
        datatypeScores: {
          'somatic_mutation': 0.825,
          'genetic_association': 0.710,
        },
        tractability: [
          TractabilityBucket(
            label: 'Clinical Precedence',
            modality: 'SM',
            value: true,
          ),
        ],
        clinicalCandidates: [
          ClinicalCandidate(
            drugName: 'APR-246',
            stage: ClinicalStage.phase2,
            drugType: 'Small molecule',
            indications: ['MDS', 'AML'],
          ),
        ],
      ),
    };

    await pumpScreen(tester, evidenceProvider: provider);

    expect(find.text('External evidence'), findsOneWidget);
    expect(find.text('Strong (0.86)'), findsOneWidget);
    expect(find.textContaining('somatic mutation'), findsOneWidget);
    expect(find.text('0.825'), findsOneWidget);
    expect(find.text('Phase 2'), findsOneWidget);
    expect(find.textContaining('SM: Clinical Precedence'), findsOneWidget);
    expect(find.textContaining('MDS, AML'), findsOneWidget);
  });

  testWidgets('displays fallback card when target evidence is absent', (tester) async {
    final client = ApiClient(
      hasConsent: () => true,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);
    final provider = EvidenceProvider(service: service);
    provider.evidenceByGene = {};

    await pumpScreen(tester, evidenceProvider: provider);

    expect(find.text('External evidence'), findsOneWidget);
    expect(find.text('No external record'), findsOneWidget);
  });
}
