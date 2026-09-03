import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/drug_interaction.dart';

/// Tests covering the data-quality handling that the UI depends on.
///
/// The bundled database uses the four-character string `'NULL'` as a missing
/// marker and encodes approval as an inverted flag, so these conversions are
/// what stop placeholder values reaching the screen.
void main() {
  group('normalizeNullable', () {
    test("converts the 'NULL' string sentinel to null", () {
      expect(DrugInteraction.normalizeNullable('NULL'), isNull);
    });

    test('converts blank and whitespace-only values to null', () {
      expect(DrugInteraction.normalizeNullable(''), isNull);
      expect(DrugInteraction.normalizeNullable('   '), isNull);
      expect(DrugInteraction.normalizeNullable(null), isNull);
    });

    test('trims and preserves real values', () {
      expect(DrugInteraction.normalizeNullable('  inhibitor '), 'inhibitor');
    });
  });

  group('fromMap', () {
    Map<String, dynamic> row({
      String? gene = 'TP53',
      String? drug = 'DOXORUBICIN',
      String? interactionTypes = 'inhibitor',
      String? sources = 'ChEMBL',
      Object? score = 2.5,
      Object? isNovel = 0,
      Object? targetCount,
    }) {
      return {
        'gene': gene,
        'drug': drug,
        'interaction_types': interactionTypes,
        'sources': sources,
        'score': score,
        'is_novel': isNovel,
        if (targetCount != null) 'target_count': targetCount,
      };
    }

    test('maps a well-formed row', () {
      final interaction = DrugInteraction.fromMap(row());
      expect(interaction.gene, 'TP53');
      expect(interaction.drug, 'DOXORUBICIN');
      expect(interaction.interactionTypes, ['inhibitor']);
      expect(interaction.sources, ['ChEMBL']);
      expect(interaction.score, 2.5);
      expect(interaction.isApproved, isTrue);
      expect(interaction.targetCount, isNull);
    });

    test("treats an interaction of 'NULL' as an unknown mechanism", () {
      final interaction =
          DrugInteraction.fromMap(row(interactionTypes: 'NULL'));
      expect(interaction.interactionTypes, isEmpty);
      expect(interaction.hasUnknownMechanism, isTrue);
      expect(interaction.mechanismLabel, isNull);
    });

    test('treats a genuinely absent interaction column as unknown', () {
      final interaction =
          DrugInteraction.fromMap(row(interactionTypes: null));
      expect(interaction.hasUnknownMechanism, isTrue);
    });

    test('splits, de-duplicates and sorts a GROUP_CONCAT list', () {
      final interaction = DrugInteraction.fromMap(
        row(interactionTypes: 'inhibitor,blocker,inhibitor'),
      );
      expect(interaction.interactionTypes, ['blocker', 'inhibitor']);
      expect(interaction.mechanismLabel, 'blocker, inhibitor');
    });

    test("drops a 'NULL' entry mixed into a concatenated list", () {
      final interaction = DrugInteraction.fromMap(
        row(interactionTypes: 'NULL,agonist'),
      );
      expect(interaction.interactionTypes, ['agonist']);
    });

    test('inverts is_novel into an approval flag', () {
      // 0 means DGIdb reported the drug as approved.
      expect(DrugInteraction.fromMap(row(isNovel: 0)).isApproved, isTrue);
      expect(DrugInteraction.fromMap(row(isNovel: 1)).isApproved, isFalse);
    });

    test('defaults to unapproved when the flag is missing or unreadable', () {
      expect(DrugInteraction.fromMap(row(isNovel: null)).isApproved, isFalse);
      expect(DrugInteraction.fromMap(row(isNovel: 'x')).isApproved, isFalse);
    });

    test('parses an is_novel value arriving as a string', () {
      expect(DrugInteraction.fromMap(row(isNovel: '0')).isApproved, isTrue);
    });

    test('states approval in words rather than a novelty claim', () {
      expect(DrugInteraction.fromMap(row(isNovel: 1)).approvalLabel,
          'Not FDA-approved');
      expect(DrugInteraction.fromMap(row(isNovel: 0)).approvalLabel,
          'Approved drug');
    });

    test('defaults an unparseable score to zero', () {
      expect(DrugInteraction.fromMap(row(score: 'abc')).score, 0.0);
      expect(DrugInteraction.fromMap(row(score: null)).score, 0.0);
    });

    test('parses target_count when present', () {
      expect(DrugInteraction.fromMap(row(targetCount: 141)).targetCount, 141);
      expect(DrugInteraction.fromMap(row(targetCount: '141')).targetCount, 141);
    });

    test('counts sources for corroboration', () {
      final interaction =
          DrugInteraction.fromMap(row(sources: 'ChEMBL,TTD,DTC'));
      expect(interaction.sourceCount, 3);
      expect(interaction.sources, ['ChEMBL', 'DTC', 'TTD']);
    });

    test('flags a bare ChEMBL accession as an unnamed compound', () {
      expect(
        DrugInteraction.fromMap(row(drug: 'CHEMBL:CHEMBL101168'))
            .isUnnamedCompound,
        isTrue,
      );
      expect(
        DrugInteraction.fromMap(row(drug: 'DOXORUBICIN')).isUnnamedCompound,
        isFalse,
      );
    });
  });

  group('EvidenceStrength', () {
    test('classifies by the measured percentiles of the bundled data', () {
      // p95 = 5.25, p75 = 0.73 over 69,018 aggregated (gene, drug) pairs.
      expect(EvidenceStrength.forScore(157.5),
          EvidenceStrength.wellDocumented);
      expect(EvidenceStrength.forScore(5.25),
          EvidenceStrength.wellDocumented);
      expect(EvidenceStrength.forScore(2.0),
          EvidenceStrength.moderatelyDocumented);
      expect(EvidenceStrength.forScore(0.73),
          EvidenceStrength.moderatelyDocumented);
      expect(EvidenceStrength.forScore(0.15),
          EvidenceStrength.sparselyDocumented);
      expect(EvidenceStrength.forScore(0.0),
          EvidenceStrength.sparselyDocumented);
    });

    test('describes what it measures without claiming clinical confidence', () {
      for (final strength in EvidenceStrength.values) {
        expect(strength.label.toLowerCase(), isNot(contains('clinical')));
        expect(strength.explanation, isNotEmpty);
      }
    });
  });

  group('Corroboration', () {
    test('classifies by source count', () {
      expect(Corroboration.forSourceCount(18), Corroboration.corroborated);
      expect(Corroboration.forSourceCount(3), Corroboration.corroborated);
      expect(Corroboration.forSourceCount(2), Corroboration.replicated);
      expect(Corroboration.forSourceCount(1), Corroboration.single);
      expect(Corroboration.forSourceCount(0), Corroboration.none);
    });
  });
}
