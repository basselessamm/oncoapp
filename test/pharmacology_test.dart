import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/pharmacology.dart';

/// Tests for the direction inference that Phase 1 adds.
///
/// The DGIdb `interaction` column was previously displayed as text and never
/// interpreted, so a drug suppressing an over-expressed gene ranked identically
/// to one suppressing an under-expressed gene.
void main() {
  group('PharmacologicDirection.fromInteractionTypes', () {
    test('classifies suppressing terms', () {
      for (final term in [
        'inhibitor',
        'blocker',
        'antagonist',
        'inverse agonist',
        'negative modulator',
        'antisense oligonucleotide',
        'cleavage',
      ]) {
        expect(
          PharmacologicDirection.fromInteractionTypes([term]),
          PharmacologicDirection.suppresses,
          reason: term,
        );
      }
    });

    test('classifies activating terms', () {
      for (final term in [
        'agonist',
        'activator',
        'positive modulator',
        'potentiator',
      ]) {
        expect(
          PharmacologicDirection.fromInteractionTypes([term]),
          PharmacologicDirection.activates,
          reason: term,
        );
      }
    });

    test('is case and whitespace insensitive', () {
      expect(
        PharmacologicDirection.fromInteractionTypes(['  INHIBITOR ']),
        PharmacologicDirection.suppresses,
      );
    });

    test('reports a conflict when both directions are present', () {
      // Real for 275 gene-drug pairs in the bundled database.
      expect(
        PharmacologicDirection.fromInteractionTypes(['inhibitor', 'agonist']),
        PharmacologicDirection.conflicting,
      );
    });

    test('treats modality-only terms as unspecified', () {
      // An antibody can be blocking or agonising; assuming suppression would be
      // a guess dressed up as a finding.
      for (final term in [
        'antibody',
        'vaccine',
        'immunotherapy',
        'binder',
        'modulator',
        'other/unknown',
      ]) {
        expect(
          PharmacologicDirection.fromInteractionTypes([term]),
          PharmacologicDirection.unspecified,
          reason: term,
        );
      }
    });

    test('a directional term wins over an accompanying modality term', () {
      expect(
        PharmacologicDirection.fromInteractionTypes(['antibody', 'inhibitor']),
        PharmacologicDirection.suppresses,
      );
    });

    test('handles empty input and the NULL sentinel', () {
      expect(
        PharmacologicDirection.fromInteractionTypes([]),
        PharmacologicDirection.unspecified,
      );
      expect(
        PharmacologicDirection.fromInteractionTypes(['NULL', '', '  ']),
        PharmacologicDirection.unspecified,
      );
    });

    test('an unrecognised term does not silently become a direction', () {
      expect(
        PharmacologicDirection.fromInteractionTypes(['gibberish']),
        PharmacologicDirection.unspecified,
      );
    });

    test('suppressing and activating term sets do not overlap', () {
      expect(
        PharmacologicDirection.suppressingTerms
            .intersection(PharmacologicDirection.activatingTerms),
        isEmpty,
      );
    });

    test('covers every directional term present in the bundled database', () {
      // Measured with SELECT DISTINCT interaction FROM drug_interactions.
      const suppressing = ['inhibitor', 'blocker', 'inverse agonist',
          'negative modulator', 'cleavage', 'antisense oligonucleotide'];
      const activating = ['agonist', 'activator', 'positive modulator',
          'potentiator'];

      for (final term in suppressing) {
        expect(PharmacologicDirection.suppressingTerms, contains(term));
      }
      for (final term in activating) {
        expect(PharmacologicDirection.activatingTerms, contains(term));
      }
    });
  });

  group('GeneRegulation.fromLog2FoldChange', () {
    test('reads direction from the sign of the fold change', () {
      expect(GeneRegulation.fromLog2FoldChange(3.2), GeneRegulation.up);
      expect(GeneRegulation.fromLog2FoldChange(-1.4), GeneRegulation.down);
    });

    test('treats zero as down rather than crashing', () {
      // No bundled signature gene has log2fc == 0; this pins the behaviour.
      expect(GeneRegulation.fromLog2FoldChange(0.0), GeneRegulation.down);
    });
  });

  group('DirectionalMatch.resolve', () {
    test('suppressing an over-expressed gene opposes the change', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.suppresses, GeneRegulation.up),
        DirectionalMatch.opposes,
      );
    });

    test('activating an under-expressed gene opposes the change', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.activates, GeneRegulation.down),
        DirectionalMatch.opposes,
      );
    });

    test('suppressing an under-expressed gene reinforces the change', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.suppresses, GeneRegulation.down),
        DirectionalMatch.reinforces,
      );
    });

    test('activating an over-expressed gene reinforces the change', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.activates, GeneRegulation.up),
        DirectionalMatch.reinforces,
      );
    });

    test('propagates a conflicting drug direction', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.conflicting, GeneRegulation.up),
        DirectionalMatch.conflicting,
      );
    });

    test('an unspecified drug direction yields undetermined', () {
      expect(
        DirectionalMatch.resolve(
            PharmacologicDirection.unspecified, GeneRegulation.up),
        DirectionalMatch.undetermined,
      );
    });

    test('a missing gene regulation yields undetermined, not a favourable '
        'guess', () {
      // Manual gene lists carry no fold change.
      for (final direction in PharmacologicDirection.values) {
        expect(
          DirectionalMatch.resolve(direction, null),
          DirectionalMatch.undetermined,
          reason: direction.name,
        );
      }
    });
  });
}
