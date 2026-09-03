import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onco_repurpose_ai/models/disease_option.dart';
import 'package:onco_repurpose_ai/providers/evidence_provider.dart';
import 'package:onco_repurpose_ai/screens/disease_picker_screen.dart';
import 'package:onco_repurpose_ai/services/network/api_client.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/services/open_targets_service.dart';
import 'package:provider/provider.dart';

class _FakeOpenTargetsService extends OpenTargetsService {
  _FakeOpenTargetsService()
      : super(
          client: ApiClient(
            hasConsent: () => true,
            cache: ResponseCache(),
            httpClient: _EmptyClient(),
          ),
        );

  List<DiseaseOption> searchResult = const [];
  bool shouldFail = false;
  String? lastSearchQuery;

  @override
  Future<ApiResult<List<DiseaseOption>>> searchDiseases(String query) async {
    lastSearchQuery = query;
    if (shouldFail) {
      return const ApiFailure(
        reason: NetworkFailureReason.offline,
        message: 'No network',
      );
    }
    return ApiSuccess(data: searchResult, freshness: DataFreshness.network);
  }
}

class _EmptyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  late _FakeOpenTargetsService service;
  late EvidenceProvider provider;

  setUp(() {
    service = _FakeOpenTargetsService();
    provider = EvidenceProvider(service: service);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OpenTargetsService>.value(value: service),
          ChangeNotifierProvider<EvidenceProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: DiseasePickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders curated breast cancer defaults', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Curated Breast Oncology Defaults'), findsOneWidget);
    expect(find.text('Breast carcinoma'), findsOneWidget);
    expect(find.text('Triple-negative breast carcinoma'), findsOneWidget);
    expect(find.text('Invasive breast carcinoma'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('selecting a curated disease updates provider', (tester) async {
    await pumpScreen(tester);

    expect(provider.selectedDisease?.id, 'MONDO_0004989');

    await tester.tap(find.text('Triple-negative breast carcinoma'));
    await tester.pumpAndSettle();

    expect(provider.selectedDisease?.id, 'MONDO_0005494');
  });

  testWidgets('typing a query executes search and displays results', (tester) async {
    service.searchResult = const [
      DiseaseOption(
        id: 'MONDO_0008315',
        name: 'Prostate carcinoma',
        description: 'Malignant tumour of the prostate.',
      ),
    ];

    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'prostate');
    // Fast-forward debounce timer (350ms)
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(service.lastSearchQuery, 'prostate');
    expect(find.text('Prostate carcinoma'), findsOneWidget);
    expect(find.text('MONDO_0008315'), findsOneWidget);

    await tester.tap(find.text('Prostate carcinoma'));
    await tester.pumpAndSettle();

    expect(provider.selectedDisease?.id, 'MONDO_0008315');
  });

  testWidgets('displays error status when search fails', (tester) async {
    service.shouldFail = true;

    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'error test');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Search unavailable'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('clearing search resets to curated defaults', (tester) async {
    service.searchResult = const [
      DiseaseOption(id: 'MONDO_TEST', name: 'Test neoplasm'),
    ];

    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Test neoplasm'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Curated Breast Oncology Defaults'), findsOneWidget);
  });
}
