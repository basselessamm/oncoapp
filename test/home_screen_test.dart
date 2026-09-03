import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/main.dart';
import 'package:onco_repurpose_ai/models/cancer_signature.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart';
import 'package:onco_repurpose_ai/providers/evidence_provider.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
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

/// Home screen behaviour, driven by in-memory fixtures.
///
/// This replaces the Flutter counter template test, which asserted on a `'0'`
/// label and an `Icons.add` button that never existed in this app, and which
/// pumped `OncoApp` without the provider its screens require.
///
/// State is assigned directly rather than loaded from assets: `testWidgets`
/// runs in a fake-async zone, so real file and platform-channel I/O never
/// completes. Asset loading is covered separately in
/// `data_provider_assets_test.dart`.
void main() {
  CancerSignature fixture() => const CancerSignature(
        id: 'fixture',
        cancerName: 'Test Carcinoma',
        pmid: '12345',
        sampleSize: 100,
        significantGenes: [
          SignificantGene(
              symbol: 'TP53', type: 'Upregulated', log2fc: 3.0, pValue: 0.001),
          SignificantGene(
              symbol: 'BRCA1', type: 'Upregulated', log2fc: 2.0, pValue: 0.002),
          SignificantGene(
              symbol: 'ESR1',
              type: 'Downregulated',
              log2fc: -2.5,
              pValue: 0.003),
        ],
      );

  DataProvider readyProvider() {
    final provider = DataProvider();
    provider.datasets = [fixture()];
    provider.selectedDataset = fixture();
    provider.datasetStatus = LoadStatus.ready;
    return provider;
  }

  Future<void> pumpHome(WidgetTester tester, DataProvider provider) async {
    final client = ApiClient(
      hasConsent: () => false,
      cache: ResponseCache(),
      httpClient: _DummyClient(),
    );
    final service = OpenTargetsService(client: client);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DataProvider>.value(value: provider),
          // The app bar reads these to open Settings.
          ChangeNotifierProvider<NetworkConsent>(
              create: (_) => NetworkConsent()),
          Provider<ResponseCache>(create: (_) => ResponseCache()),
          Provider<ApiClient>.value(value: client),
          Provider<OpenTargetsService>.value(value: service),
          ChangeNotifierProvider<EvidenceProvider>(
            create: (_) => EvidenceProvider(service: service),
          ),
        ],
        child: const OncoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view and taps it.
  ///
  /// The home screen is taller than the test viewport, so the lookup button
  /// starts off-screen and a bare `tap()` would miss it.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while reference data loads', (tester) async {
    final provider = DataProvider();
    provider.datasetStatus = LoadStatus.loading;
    // Not pumpAndSettle: the progress indicator animates indefinitely.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DataProvider>.value(value: provider),
          ChangeNotifierProvider<NetworkConsent>(
              create: (_) => NetworkConsent()),
          Provider<ResponseCache>(create: (_) => ResponseCache()),
        ],
        child: const OncoApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('states research-use scope on the home screen', (tester) async {
    await pumpHome(tester, readyProvider());

    expect(find.byType(ResearchUseBanner), findsOneWidget);
    expect(find.textContaining('Research use only'), findsOneWidget);
  });

  testWidgets('describes the lookup without claiming a prediction',
      (tester) async {
    await pumpHome(tester, readyProvider());

    expect(find.textContaining('Queries DGIdb'), findsOneWidget);
    expect(find.textContaining('acts against the direction'), findsOneWidget);
    // The former "Analyze with AI" button overstated what the app does.
    expect(find.textContaining('AI'), findsNothing);
  });

  testWidgets('reports the selected signature gene counts', (tester) async {
    await pumpHome(tester, readyProvider());

    // Signature summary line under the dropdown.
    expect(find.textContaining('2 up, 1 down'), findsOneWidget);
  });

  testWidgets('labels the lookup button with the active gene count',
      (tester) async {
    await pumpHome(tester, readyProvider());

    expect(find.text('Search interactions for 3 genes'), findsOneWidget);
  });

  testWidgets('disables the lookup button when no genes are active',
      (tester) async {
    final provider = DataProvider();
    provider.datasetStatus = LoadStatus.ready;
    await pumpHome(tester, provider);

    expect(find.text('Select genes to search'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Select genes to search'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('switches to manual mode when gene symbols are typed',
      (tester) async {
    final provider = readyProvider();
    await pumpHome(tester, provider);

    await tester.enterText(
      find.widgetWithText(TextField, 'PIK3CA, TP53, ERBB2'),
      'tp53, brca1',
    );
    await tester.pumpAndSettle();

    expect(provider.isManualMode, isTrue);
    expect(provider.manualGenes, ['TP53', 'BRCA1']);
    expect(provider.activeGenes, ['TP53', 'BRCA1']);
    expect(find.text('2 gene(s) recognised'), findsOneWidget);
  });

  testWidgets('clearing the gene field returns to signature mode',
      (tester) async {
    final provider = readyProvider();
    await pumpHome(tester, provider);

    await tester.enterText(
      find.widgetWithText(TextField, 'PIK3CA, TP53, ERBB2'),
      'TP53',
    );
    await tester.pumpAndSettle();
    expect(provider.isManualMode, isTrue);

    await tester.tap(find.byTooltip('Clear gene list'));
    await tester.pumpAndSettle();

    expect(provider.isManualMode, isFalse);
    expect(provider.manualGenes, isEmpty);
    // Falls back to the selected signature's genes.
    expect(provider.activeGenes, ['TP53', 'BRCA1', 'ESR1']);
  });

  testWidgets('surfaces a retry action when reference data fails to load',
      (tester) async {
    final provider = DataProvider();
    // Failure is a distinct state from an empty list. The previous
    // implementation could not tell them apart.
    provider.datasetStatus = LoadStatus.failed;
    provider.datasetError = 'Simulated failure';
    await pumpHome(tester, provider);

    expect(find.text('Could not load reference data'), findsOneWidget);
    expect(find.text('Simulated failure'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('warns about partially loaded data without blocking the screen',
      (tester) async {
    final provider = readyProvider();
    provider.datasetError = 'Could not load: one_file.json.';
    await pumpHome(tester, provider);

    expect(find.text('Could not load: one_file.json.'), findsOneWidget);
    // The rest of the screen still works.
    expect(find.text('Search interactions for 3 genes'), findsOneWidget);
  });

  testWidgets('opens the filter sheet before running a lookup', (tester) async {
    await pumpHome(tester, readyProvider());

    await scrollAndTap(tester, find.text('Search interactions for 3 genes'));

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Exclude approved drugs'), findsOneWidget);
    // Corroboration is offered as a filter because it is the only real
    // replication signal in the data.
    expect(find.text('Minimum corroboration'), findsOneWidget);
    expect(find.text('2+ sources'), findsOneWidget);
  });

  testWidgets('offers the directional filter when a signature is selected',
      (tester) async {
    await pumpHome(tester, readyProvider());
    await scrollAndTap(tester, find.text('Search interactions for 3 genes'));

    expect(find.text('Opposing drugs only'), findsOneWidget);
  });

  testWidgets('hides the directional filter for a manual gene list',
      (tester) async {
    final provider = readyProvider();
    provider.setManualGenes('TP53, BRCA1');
    await pumpHome(tester, provider);

    await scrollAndTap(tester, find.text('Search interactions for 2 genes'));

    // A typed gene list carries no fold change, so the filter is meaningless.
    expect(find.text('Opposing drugs only'), findsNothing);
    expect(
      find.textContaining('no expression direction is available'),
      findsOneWidget,
    );
  });

  testWidgets('filter sheet explains what "not approved" means',
      (tester) async {
    await pumpHome(tester, readyProvider());
    await scrollAndTap(tester, find.text('Search interactions for 3 genes'));

    expect(
      find.textContaining('not FDA-approved'),
      findsOneWidget,
      reason: 'the flag must not be presented as a novelty judgement',
    );
  });
}
