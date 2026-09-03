import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/target_evidence.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';
import 'package:onco_repurpose_ai/widgets/evidence_widgets.dart';

void main() {
  group('AssociationChip', () {
    testWidgets('renders score and strength label', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'TP53',
        associationScore: 0.8606,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssociationChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Strong (0.86)'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);
    });

    testWidgets('renders dense mode label', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'ESR1',
        associationScore: 0.8179,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssociationChip(evidence: evidence, dense: true),
          ),
        ),
      );

      expect(find.text('OT: 0.82'), findsOneWidget);
    });

    testWidgets('renders Not reported for null association score', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'OR4F5',
        associationScore: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssociationChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Not reported'), findsOneWidget);
    });
  });

  group('TractabilityChip', () {
    testWidgets('displays the best tractability tier label', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'ESR1',
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.approval),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TractabilityChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Approved Drug'), findsOneWidget);
    });

    testWidgets('displays Preclinical Evidence when bucket is true', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'GENE_X',
        tractability: [
          TractabilityBucket(label: 'Druggable', modality: 'SM', value: true),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TractabilityChip(evidence: evidence),
          ),
        ),
      );

      expect(find.text('Preclinical Evidence'), findsOneWidget);
    });
  });

  group('ClinicalStageChip', () {
    testWidgets('displays candidate clinical stage', (tester) async {
      const candidate = ClinicalCandidate(
        drugName: 'APR-246',
        stage: ClinicalStage.phase2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClinicalStageChip(candidate: candidate),
          ),
        ),
      );

      expect(find.text('Phase 2'), findsOneWidget);
      expect(find.byIcon(Icons.local_hospital_outlined), findsOneWidget);
    });
  });

  group('PassengerWarning', () {
    testWidgets('displays passenger hypothesis guidance', (tester) async {
      const evidence = TargetEvidence(
        geneSymbol: 'HORMAD1',
        associationScore: 0.05,
        clinicalCandidateCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PassengerWarning(evidence: evidence),
          ),
        ),
      );

      expect(find.textContaining('لا يوجد دليل منشور يربط هذا الجين'), findsOneWidget);
      expect(find.textContaining('consequence of tumourigenesis rather than a cause'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('EvidenceUnavailableNote', () {
    testWidgets('shows consent guidance and triggers settings action', (tester) async {
      var enabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceUnavailableNote(
              reason: NetworkFailureReason.consentNotGranted,
              onEnable: () => enabled = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('External target evidence is disabled'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      expect(enabled, isTrue);
    });

    testWidgets('shows retry button on network outage and triggers retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceUnavailableNote(
              reason: NetworkFailureReason.offline,
              onEnable: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Unable to retrieve Open Targets evidence'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
