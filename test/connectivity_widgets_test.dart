import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';
import 'package:onco_repurpose_ai/widgets/evidence_widgets.dart';

void main() {
  group('ConnectivityScoreChip', () {
    testWidgets('renders strong reversal chip with formatted score',
        (tester) async {
      const evidence = LincsEvidence(
        drugName: 'TAMOXIFEN',
        score: -0.62,
        pval: 0.0001,
        qval: 0.012,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectivityScoreChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Strong Reversal -62.0%'), findsOneWidget);
      expect(find.byIcon(Icons.published_with_changes_rounded), findsOneWidget);
    });

    testWidgets('renders dense mode correctly', (tester) async {
      const evidence = LincsEvidence(
        drugName: 'TAMOXIFEN',
        score: -0.62,
        pval: 0.0001,
        qval: 0.012,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectivityScoreChip(evidence: evidence, dense: true),
          ),
        ),
      );

      expect(find.text('Reversal -62.0%'), findsOneWidget);
    });

    testWidgets('renders mimic warning chip when score is positive',
        (tester) async {
      const evidence = LincsEvidence(
        drugName: 'ESTRADIOL',
        score: 0.45,
        pval: 0.001,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectivityScoreChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Signature Mimic (+45%)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('LincsDetailsCard', () {
    testWidgets('renders complete metrics including cell line, duration and q-value',
        (tester) async {
      const evidence = LincsEvidence(
        drugName: 'DOXORUBICIN',
        score: -0.50,
        pval: 0.000006,
        qval: 0.0127,
        zscore: 1.79,
        cellLine: 'MCF7',
        durationHours: 24,
        dose: 10.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LincsDetailsCard(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Transcriptomic Reversal (LINCS L1000)'), findsOneWidget);
      expect(find.text('Connectivity Score: -0.500 (-50.0%)'), findsOneWidget);
      expect(find.text('Cell line: MCF7'), findsOneWidget);
      expect(find.text('Duration: 24h'), findsOneWidget);
      expect(find.text('Concentration: 10.0 μM'), findsOneWidget);
      expect(find.text('z-score: 1.79'), findsOneWidget);
    });
  });
}
