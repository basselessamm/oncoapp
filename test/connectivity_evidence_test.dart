import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';

void main() {
  group('LincsEvidence ReversalTier Classification', () {
    test('classifies strong reversal when q <= 0.05 and score <= -0.30', () {
      const evidence = LincsEvidence(
        drugName: 'TAMOXIFEN',
        score: -0.52,
        pval: 0.0001,
        qval: 0.012,
      );

      expect(evidence.tier, ReversalTier.strongReversal);
      expect(evidence.isSignificantReversal, isTrue);
      expect(evidence.isReversal, isTrue);
      expect(evidence.formattedScore, '-52.0%');
    });

    test('classifies moderate reversal when q <= 0.10 and score < 0', () {
      const evidence = LincsEvidence(
        drugName: 'DOXORUBICIN',
        score: -0.22,
        pval: 0.005,
        qval: 0.08,
      );

      expect(evidence.tier, ReversalTier.moderateReversal);
      expect(evidence.isSignificantReversal, isTrue);
      expect(evidence.isReversal, isTrue);
    });

    test('classifies nominal reversal when only p <= 0.05 or score < 0 without FDR', () {
      const evidence = LincsEvidence(
        drugName: 'FULVESTRANT',
        score: -0.15,
        pval: 0.04,
        qval: 0.25,
      );

      expect(evidence.tier, ReversalTier.nominalReversal);
      expect(evidence.isSignificantReversal, isFalse);
      expect(evidence.isReversal, isTrue);
    });

    test('classifies mimic when score > 0', () {
      const evidence = LincsEvidence(
        drugName: 'ESTRADIOL',
        score: 0.65,
        pval: 0.0001,
        qval: 0.001,
      );

      expect(evidence.tier, ReversalTier.mimic);
      expect(evidence.isSignificantReversal, isFalse);
      expect(evidence.isReversal, isFalse);
    });
  });

  group('LincsEvidence JSON serialization', () {
    test('serializes and deserializes correctly', () {
      const original = LincsEvidence(
        drugName: 'TAMOXIFEN',
        score: -0.48,
        pval: 0.0003,
        qval: 0.015,
        zscore: 2.35,
        combinedScore: -12.4,
        sigId: 'CPC008_MCF7_24H:BRD-K93754473:10',
        cellLine: 'MCF7',
        durationHours: 24,
        dose: 10.0,
      );

      final json = original.toJson();
      final recovered = LincsEvidence.fromJson(json);

      expect(recovered.drugName, 'TAMOXIFEN');
      expect(recovered.score, -0.48);
      expect(recovered.pval, 0.0003);
      expect(recovered.qval, 0.015);
      expect(recovered.zscore, 2.35);
      expect(recovered.combinedScore, -12.4);
      expect(recovered.sigId, 'CPC008_MCF7_24H:BRD-K93754473:10');
      expect(recovered.cellLine, 'MCF7');
      expect(recovered.durationHours, 24);
      expect(recovered.dose, 10.0);
      expect(recovered.tier, ReversalTier.strongReversal);
    });
  });

  group('parseSigIdMetadata', () {
    test('extracts cell line, duration, and dose from standard sig_id', () {
      final meta = LincsEvidence.parseSigIdMetadata(
          'CPC008_MCF7_24H:BRD-K93754473-001-01-4:10.0');

      expect(meta.cellLine, 'MCF7');
      expect(meta.durationHours, 24);
      expect(meta.dose, 10.0);
    });

    test('handles malformed sig_id gracefully', () {
      final meta = LincsEvidence.parseSigIdMetadata('INVALID_ID');
      expect(meta.cellLine, isNull);
      expect(meta.durationHours, isNull);
      expect(meta.dose, isNull);
    });
  });
}
