import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/disease_option.dart';
import 'package:onco_repurpose_ai/models/target_evidence.dart';

void main() {
  group('AssociationStrength thresholds', () {
    test('classifies null score as notReported', () {
      expect(AssociationStrength.forScore(null), AssociationStrength.notReported);
    });

    test('classifies score >= 0.30 as strong', () {
      expect(AssociationStrength.forScore(0.30), AssociationStrength.strong);
      expect(AssociationStrength.forScore(0.387), AssociationStrength.strong);
      expect(AssociationStrength.forScore(0.8606), AssociationStrength.strong);
      expect(AssociationStrength.forScore(1.0), AssociationStrength.strong);
    });

    test('classifies 0.10 <= score < 0.30 as moderate', () {
      expect(AssociationStrength.forScore(0.10), AssociationStrength.moderate);
      expect(AssociationStrength.forScore(0.123), AssociationStrength.moderate);
      expect(AssociationStrength.forScore(0.2999), AssociationStrength.moderate);
    });

    test('classifies 0.01 <= score < 0.10 as weak', () {
      expect(AssociationStrength.forScore(0.01), AssociationStrength.weak);
      expect(AssociationStrength.forScore(0.063), AssociationStrength.weak);
      expect(AssociationStrength.forScore(0.0998), AssociationStrength.weak);
    });

    test('classifies score < 0.01 as negligible', () {
      expect(AssociationStrength.forScore(0.0099), AssociationStrength.negligible);
      expect(AssociationStrength.forScore(0.004), AssociationStrength.negligible);
      expect(AssociationStrength.forScore(0.0), AssociationStrength.negligible);
    });
  });

  group('ClinicalStage parsing and ranking', () {
    test('maps APPROVAL to ClinicalStage.approval with rank 5', () {
      final stage = ClinicalStage.fromApiValue('APPROVAL');
      expect(stage, ClinicalStage.approval);
      expect(stage.rank, 5);
    });

    test('maps PREAPPROVAL to ClinicalStage.preApproval with rank 4', () {
      final stage = ClinicalStage.fromApiValue('PREAPPROVAL');
      expect(stage, ClinicalStage.preApproval);
      expect(stage.rank, 4);
    });

    test('maps PHASE_3 and PHASE_2_3 to ClinicalStage.phase3 with rank 3', () {
      expect(ClinicalStage.fromApiValue('PHASE_3'), ClinicalStage.phase3);
      expect(ClinicalStage.fromApiValue('PHASE_2_3'), ClinicalStage.phase3);
      expect(ClinicalStage.phase3.rank, 3);
    });

    test('maps PHASE_2 and PHASE_1_2 to ClinicalStage.phase2 with rank 2', () {
      expect(ClinicalStage.fromApiValue('PHASE_2'), ClinicalStage.phase2);
      expect(ClinicalStage.fromApiValue('PHASE_1_2'), ClinicalStage.phase2);
      expect(ClinicalStage.phase2.rank, 2);
    });

    test('maps PHASE_1 to ClinicalStage.phase1 with rank 1', () {
      final stage = ClinicalStage.fromApiValue('PHASE_1');
      expect(stage, ClinicalStage.phase1);
      expect(stage.rank, 1);
    });

    test('maps unknown or null strings to ClinicalStage.unknown with rank 0', () {
      expect(ClinicalStage.fromApiValue('UNKNOWN'), ClinicalStage.unknown);
      expect(ClinicalStage.fromApiValue(null), ClinicalStage.unknown);
      expect(ClinicalStage.fromApiValue('DISCONTINUED'), ClinicalStage.unknown);
      expect(ClinicalStage.unknown.rank, 0);
    });
  });

  group('TractabilityTier resolution', () {
    test('resolves to approvedDrug if any candidate is approved', () {
      const evidence = TargetEvidence(
        geneSymbol: 'ESR1',
        clinicalCandidates: [
          ClinicalCandidate(
            drugName: 'Tamoxifen',
            stage: ClinicalStage.approval,
          ),
          ClinicalCandidate(
            drugName: 'Investigational',
            stage: ClinicalStage.phase1,
          ),
        ],
      );
      expect(evidence.bestTractability, TractabilityTier.approvedDrug);
    });

    test('resolves to advancedClinical for Phase 2 or Phase 3 / Pre-approval', () {
      const p3 = TargetEvidence(
        geneSymbol: 'GENE_A',
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.phase3),
        ],
      );
      expect(p3.bestTractability, TractabilityTier.advancedClinical);

      const p2 = TargetEvidence(
        geneSymbol: 'GENE_B',
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.phase2),
        ],
      );
      expect(p2.bestTractability, TractabilityTier.advancedClinical);

      const pre = TargetEvidence(
        geneSymbol: 'GENE_C',
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.preApproval),
        ],
      );
      expect(pre.bestTractability, TractabilityTier.advancedClinical);
    });

    test('resolves to phase1Clinical for Phase 1 candidate without advanced ones', () {
      const evidence = TargetEvidence(
        geneSymbol: 'GENE_D',
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.phase1),
        ],
      );
      expect(evidence.bestTractability, TractabilityTier.phase1Clinical);
    });

    test('resolves to preclinicalEvidence if no clinical candidate but tractability bucket is true', () {
      const evidence = TargetEvidence(
        geneSymbol: 'GENE_E',
        tractability: [
          TractabilityBucket(label: 'Predicted Druggable', modality: 'SM', value: true),
          TractabilityBucket(label: 'Clinical Precedence', modality: 'AB', value: false),
        ],
      );
      expect(evidence.bestTractability, TractabilityTier.preclinicalEvidence);
    });

    test('resolves to noEvidence when all buckets are false and no clinical candidate', () {
      const evidence = TargetEvidence(
        geneSymbol: 'GENE_F',
        tractability: [
          TractabilityBucket(label: 'Discovery Precedence', modality: 'SM', value: false),
        ],
      );
      expect(evidence.bestTractability, TractabilityTier.noEvidence);
    });
  });

  group('mostAdvancedCandidate', () {
    test('returns null when clinicalCandidates is empty', () {
      const evidence = TargetEvidence(geneSymbol: 'TP53');
      expect(evidence.mostAdvancedCandidate, isNull);
    });

    test('returns candidate with the highest clinical rank', () {
      const c1 = ClinicalCandidate(drugName: 'EarlyDrug', stage: ClinicalStage.phase1);
      const c2 = ClinicalCandidate(drugName: 'LateDrug', stage: ClinicalStage.phase3);
      const c3 = ClinicalCandidate(drugName: 'MidDrug', stage: ClinicalStage.phase2);

      const evidence = TargetEvidence(
        geneSymbol: 'TP53',
        clinicalCandidates: [c1, c2, c3],
      );

      expect(evidence.mostAdvancedCandidate?.drugName, 'LateDrug');
    });
  });

  group('isLikelyPassenger classification', () {
    test('flags true when score < 0.10, count == 0, and preclinical evidence', () {
      const evidence = TargetEvidence(
        geneSymbol: 'HORMAD1',
        associationScore: 0.0998,
        clinicalCandidateCount: 0,
        tractability: [
          TractabilityBucket(label: 'Predicted Druggable', modality: 'SM', value: true),
        ],
      );
      expect(evidence.isLikelyPassenger, isTrue);
    });

    test('flags true when score is null (no published row), count == 0, and no evidence', () {
      const evidence = TargetEvidence(
        geneSymbol: 'OR4F5',
        associationScore: null,
        clinicalCandidateCount: 0,
      );
      expect(evidence.isLikelyPassenger, isTrue);
    });

    test('flags false if association score >= 0.10', () {
      const evidence = TargetEvidence(
        geneSymbol: 'TFF1',
        associationScore: 0.123,
        clinicalCandidateCount: 0,
      );
      expect(evidence.isLikelyPassenger, isFalse);
    });

    test('flags false if clinical candidate count > 0', () {
      const evidence = TargetEvidence(
        geneSymbol: 'TARGET_X',
        associationScore: 0.04,
        clinicalCandidateCount: 2,
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.phase1),
        ],
      );
      expect(evidence.isLikelyPassenger, isFalse);
    });

    test('flags false if best tractability is phase1Clinical or higher', () {
      const evidence = TargetEvidence(
        geneSymbol: 'TARGET_Y',
        associationScore: 0.04,
        clinicalCandidateCount: 0,
        clinicalCandidates: [
          ClinicalCandidate(stage: ClinicalStage.phase1),
        ],
      );
      expect(evidence.bestTractability, TractabilityTier.phase1Clinical);
      expect(evidence.isLikelyPassenger, isFalse);
    });
  });

  group('isResolved and hasAssociation flags', () {
    test('correctly reflects resolution and association state', () {
      const resolvedWithAssoc = TargetEvidence(
        geneSymbol: 'TP53',
        ensemblId: 'ENSG00000141510',
        associationScore: 0.8606,
      );
      expect(resolvedWithAssoc.isResolved, isTrue);
      expect(resolvedWithAssoc.hasAssociation, isTrue);

      const resolvedNoAssoc = TargetEvidence(
        geneSymbol: 'OR4F5',
        ensemblId: 'ENSG00000186092',
        associationScore: null,
      );
      expect(resolvedNoAssoc.isResolved, isTrue);
      expect(resolvedNoAssoc.hasAssociation, isFalse);

      const unresolved = TargetEvidence(
        geneSymbol: 'UNKNOWN_GENE',
        ensemblId: null,
        associationScore: null,
      );
      expect(unresolved.isResolved, isFalse);
      expect(unresolved.hasAssociation, isFalse);
    });
  });

  group('DiseaseOption defaults', () {
    test('provides three curated breast cancer default options', () {
      const defaults = DiseaseOption.breastCancerDefaults;
      expect(defaults.length, 3);
      expect(defaults[0].id, 'MONDO_0004989');
      expect(defaults[0].name, 'Breast carcinoma');
      expect(defaults[1].id, 'MONDO_0005494');
      expect(defaults[1].name, 'Triple-negative breast carcinoma');
      expect(defaults[2].id, 'MONDO_0006256');
      expect(defaults[2].name, 'Invasive breast carcinoma');
    });

    test('equality is based on id', () {
      const d1 = DiseaseOption(id: 'MONDO_0004989', name: 'A');
      const d2 = DiseaseOption(id: 'MONDO_0004989', name: 'B');
      const d3 = DiseaseOption(id: 'MONDO_0005494', name: 'A');

      expect(d1, equals(d2));
      expect(d1, isNot(equals(d3)));
      expect(d1.hashCode, d2.hashCode);
    });
  });
}
