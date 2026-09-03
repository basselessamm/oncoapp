import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/cancer_signature.dart';
import 'package:onco_repurpose_ai/models/drug_candidate.dart';
import 'package:onco_repurpose_ai/models/drug_interaction.dart';
import 'package:onco_repurpose_ai/models/pharmacology.dart';

/// Tests for per-drug grouping and ranking.
///
/// The previous results list emitted one row per (gene, drug) pair, so a drug
/// hitting eight signature genes appeared as eight unrelated entries and
/// multi-target drugs were buried under single well-documented ones.
void main() {
  DrugInteraction interaction({
    required String gene,
    required String drug,
    List<String> types = const ['inhibitor'],
    List<String> sources = const ['ChEMBL'],
    double score = 1.0,
    bool approved = false,
  }) {
    return DrugInteraction(
      gene: gene,
      drug: drug,
      interactionTypes: types,
      sources: sources,
      score: score,
      isApproved: approved,
    );
  }

  SignificantGene gene(String symbol, double log2fc) => SignificantGene(
        symbol: symbol,
        type: log2fc > 0 ? 'Upregulated' : 'Downregulated',
        log2fc: log2fc,
        pValue: 0.001,
      );

  CancerSignature signatureOf(List<SignificantGene> genes) => CancerSignature(
        id: 'sig',
        cancerName: 'Test signature',
        pmid: '1',
        sampleSize: 10,
        significantGenes: genes,
      );

  group('grouping', () {
    test('collapses several genes of one drug into a single candidate', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'TP53', drug: 'DRUG_A'),
          interaction(gene: 'BRCA1', drug: 'DRUG_A'),
          interaction(gene: 'ESR1', drug: 'DRUG_A'),
        ],
        signature: signatureOf([
          gene('TP53', 3.0),
          gene('BRCA1', 2.0),
          gene('ESR1', 1.5),
        ]),
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.drug, 'DRUG_A');
      expect(candidates.single.targetCount, 3);
      expect(
        candidates.single.targets.map((hit) => hit.gene).toSet(),
        {'TP53', 'BRCA1', 'ESR1'},
      );
    });

    test('keeps distinct drugs separate', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'TP53', drug: 'DRUG_A'),
          interaction(gene: 'TP53', drug: 'DRUG_B'),
        ],
        signature: signatureOf([gene('TP53', 3.0)]),
      );
      expect(candidates, hasLength(2));
    });

    test('returns an empty list for no interactions', () {
      expect(DrugCandidate.group(const []), isEmpty);
    });

    test('resolves approval across the drug, not per row', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'PTH1R', drug: 'ABALOPARATIDE', approved: true),
          interaction(gene: 'PTH2R', drug: 'ABALOPARATIDE', approved: false),
        ],
        signature: signatureOf([gene('PTH1R', 2.0), gene('PTH2R', 2.0)]),
      );
      expect(candidates.single.isApproved, isTrue);
    });

    test('collects every source across the drug\'s interactions', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'TP53', drug: 'DRUG_A', sources: ['ChEMBL', 'TTD']),
          interaction(gene: 'BRCA1', drug: 'DRUG_A', sources: ['DTC']),
        ],
        signature: signatureOf([gene('TP53', 2.0), gene('BRCA1', 2.0)]),
      );
      expect(candidates.single.allSources, ['ChEMBL', 'DTC', 'TTD']);
      expect(candidates.single.maxSourceCount, 2);
    });

    test('strips the CHEMBL prefix for display', () {
      final candidates = DrugCandidate.group(
        [interaction(gene: 'TP53', drug: 'CHEMBL:CHEMBL101168')],
        signature: signatureOf([gene('TP53', 2.0)]),
      );
      expect(candidates.single.isUnnamedCompound, isTrue);
      expect(candidates.single.displayName, 'CHEMBL101168');
    });
  });

  group('directional verdicts', () {
    test('an inhibitor of an over-expressed gene opposes the change', () {
      final candidates = DrugCandidate.group(
        [interaction(gene: 'TP53', drug: 'DRUG_A', types: ['inhibitor'])],
        signature: signatureOf([gene('TP53', 3.0)]),
      );
      expect(candidates.single.opposingCount, 1);
      expect(candidates.single.reinforcingCount, 0);
      expect(candidates.single.overallDirection, CandidateDirection.opposing);
    });

    test('an inhibitor of an under-expressed gene reinforces the change', () {
      final candidates = DrugCandidate.group(
        [interaction(gene: 'TP53', drug: 'DRUG_A', types: ['inhibitor'])],
        signature: signatureOf([gene('TP53', -3.0)]),
      );
      expect(candidates.single.opposingCount, 0);
      expect(candidates.single.reinforcingCount, 1);
      expect(
          candidates.single.overallDirection, CandidateDirection.reinforcing);
    });

    test('opposing some genes and reinforcing others is reported as mixed', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'UP_GENE', drug: 'DRUG_A', types: ['inhibitor']),
          interaction(gene: 'DOWN_GENE', drug: 'DRUG_A', types: ['inhibitor']),
        ],
        signature: signatureOf([
          gene('UP_GENE', 3.0),
          gene('DOWN_GENE', -3.0),
        ]),
      );
      expect(candidates.single.overallDirection, CandidateDirection.mixed);
      expect(candidates.single.opposingCount, 1);
      expect(candidates.single.reinforcingCount, 1);
    });

    test('a manual gene list leaves every verdict undetermined', () {
      // No signature means no fold change, so no direction can be inferred.
      final candidates = DrugCandidate.group(
        [interaction(gene: 'TP53', drug: 'DRUG_A', types: ['inhibitor'])],
      );
      expect(candidates.single.opposingCount, 0);
      expect(candidates.single.reinforcingCount, 0);
      expect(
        candidates.single.overallDirection,
        CandidateDirection.undetermined,
      );
      expect(candidates.single.primaryTarget.regulation, isNull);
      expect(
        candidates.single.primaryTarget.match,
        DirectionalMatch.undetermined,
      );
    });

    test('a drug with no reported mechanism is undetermined, not favourable',
        () {
      final candidates = DrugCandidate.group(
        [interaction(gene: 'TP53', drug: 'DRUG_A', types: const [])],
        signature: signatureOf([gene('TP53', 3.0)]),
      );
      expect(
        candidates.single.overallDirection,
        CandidateDirection.undetermined,
      );
    });

    test('a gene outside the signature yields an undetermined verdict', () {
      // Search results can carry a gene the signature does not contain.
      final candidates = DrugCandidate.group(
        [interaction(gene: 'OTHER', drug: 'DRUG_A', types: ['inhibitor'])],
        signature: signatureOf([gene('TP53', 3.0)]),
      );
      expect(candidates.single.primaryTarget.regulation, isNull);
      expect(
        candidates.single.primaryTarget.match,
        DirectionalMatch.undetermined,
      );
    });

    test('gene symbols are matched case-insensitively against the signature',
        () {
      final candidates = DrugCandidate.group(
        [interaction(gene: 'tp53', drug: 'DRUG_A', types: ['inhibitor'])],
        signature: signatureOf([gene('TP53', 3.0)]),
      );
      expect(candidates.single.opposingCount, 1);
    });
  });

  group('ranking', () {
    test('more opposing targets outrank a higher documentation score', () {
      // This is the point of the model: two opposed targets is a stronger
      // hypothesis than one well-documented interaction. The old score-only
      // ordering could not express it.
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'G1', drug: 'MULTI', types: ['inhibitor'], score: 1),
          interaction(gene: 'G2', drug: 'MULTI', types: ['inhibitor'], score: 1),
          interaction(
              gene: 'G1', drug: 'HIGH_SCORE', types: ['inhibitor'], score: 90),
        ],
        signature: signatureOf([gene('G1', 3.0), gene('G2', 2.0)]),
      );
      expect(candidates.map((c) => c.drug), ['MULTI', 'HIGH_SCORE']);
    });

    test('corroboration breaks a tie on opposing count', () {
      final candidates = DrugCandidate.group(
        [
          interaction(
              gene: 'G1',
              drug: 'CORROBORATED',
              types: ['inhibitor'],
              sources: ['ChEMBL', 'TTD', 'DTC']),
          interaction(
              gene: 'G1',
              drug: 'SINGLE',
              types: ['inhibitor'],
              sources: ['ChEMBL'],
              score: 50),
        ],
        signature: signatureOf([gene('G1', 3.0)]),
      );
      expect(candidates.map((c) => c.drug), ['CORROBORATED', 'SINGLE']);
    });

    test('reinforcing-only candidates rank last', () {
      final candidates = DrugCandidate.group(
        [
          interaction(
              gene: 'DOWN', drug: 'REINFORCES', types: ['inhibitor'], score: 90),
          interaction(
              gene: 'UP', drug: 'OPPOSES', types: ['inhibitor'], score: 1),
        ],
        signature: signatureOf([gene('UP', 3.0), gene('DOWN', -3.0)]),
      );
      expect(candidates.map((c) => c.drug), ['OPPOSES', 'REINFORCES']);
    });

    test('name breaks a full tie, so ordering is deterministic', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'G1', drug: 'ZZZ', types: ['inhibitor']),
          interaction(gene: 'G1', drug: 'AAA', types: ['inhibitor']),
        ],
        signature: signatureOf([gene('G1', 3.0)]),
      );
      expect(candidates.map((c) => c.drug), ['AAA', 'ZZZ']);
    });

    test('within a candidate, opposing targets are listed first', () {
      final candidates = DrugCandidate.group(
        [
          interaction(gene: 'DOWN', drug: 'DRUG_A', types: ['inhibitor']),
          interaction(gene: 'UP', drug: 'DRUG_A', types: ['inhibitor']),
        ],
        signature: signatureOf([gene('UP', 3.0), gene('DOWN', -3.0)]),
      );
      expect(candidates.single.primaryTarget.gene, 'UP');
      expect(
        candidates.single.primaryTarget.match,
        DirectionalMatch.opposes,
      );
    });
  });
}
