import 'cancer_signature.dart';
import 'drug_interaction.dart';
import 'pharmacology.dart';

/// One drug, with every gene in the queried signature that it is recorded
/// against.
///
/// The previous results screen listed one row per (gene, drug) pair, so a drug
/// interacting with eight signature genes appeared as eight unrelated entries
/// with no combined view. That both buried the multi-target drugs - the ones
/// most worth looking at - and inflated the apparent result count.
class DrugCandidate {
  DrugCandidate({
    required this.drug,
    required this.targets,
    required this.isApproved,
  });

  /// Drug name as reported by the source databases.
  final String drug;

  /// Every interaction recorded between this drug and a gene in the query.
  ///
  /// Sorted with opposing targets first, then by corroboration, then by
  /// documentation score.
  final List<TargetHit> targets;

  /// Whether any source database marks the drug as regulatory approved.
  final bool isApproved;

  /// `true` when [drug] is a bare ChEMBL accession rather than a real name.
  bool get isUnnamedCompound => drug.startsWith('CHEMBL:');

  /// Display name, with the redundant `CHEMBL:` prefix stripped.
  String get displayName =>
      isUnnamedCompound ? drug.replaceFirst('CHEMBL:', '') : drug;

  String get approvalLabel =>
      isApproved ? 'Approved drug' : 'Not FDA-approved';

  /// Number of signature genes this drug is recorded against.
  int get targetCount => targets.length;

  /// Targets the drug acts against the direction of the observed change.
  ///
  /// This is the count that matters for a reversal hypothesis, and it is the
  /// primary ranking key.
  List<TargetHit> get opposingTargets => targets
      .where((hit) => hit.match == DirectionalMatch.opposes)
      .toList(growable: false);

  /// Targets the drug pushes further in the direction already observed.
  List<TargetHit> get reinforcingTargets => targets
      .where((hit) => hit.match == DirectionalMatch.reinforces)
      .toList(growable: false);

  int get opposingCount => opposingTargets.length;

  int get reinforcingCount => reinforcingTargets.length;

  /// Highest number of independent databases behind any one of this drug's
  /// interactions.
  int get maxSourceCount => targets.fold(
      0, (best, hit) => hit.interaction.sourceCount > best ? hit.interaction.sourceCount : best);

  /// Highest DGIdb documentation score across this drug's interactions.
  double get maxScore => targets.fold(
      0.0, (best, hit) => hit.interaction.score > best ? hit.interaction.score : best);

  /// Best-corroborated interaction, used as the headline detail.
  TargetHit get primaryTarget => targets.first;

  /// Every distinct source database behind any of this drug's interactions.
  List<String> get allSources {
    final sources = <String>{};
    for (final hit in targets) {
      sources.addAll(hit.interaction.sources);
    }
    final sorted = sources.toList()..sort();
    return sorted;
  }

  /// How this candidate relates to the signature overall.
  CandidateDirection get overallDirection {
    if (opposingCount > 0 && reinforcingCount > 0) {
      return CandidateDirection.mixed;
    }
    if (opposingCount > 0) return CandidateDirection.opposing;
    if (reinforcingCount > 0) return CandidateDirection.reinforcing;
    return CandidateDirection.undetermined;
  }

  /// Groups raw per-gene interactions into one candidate per drug.
  ///
  /// [signature] supplies each gene's fold change so a directional match can be
  /// computed. Pass `null` for a manually entered gene list: every match is
  /// then [DirectionalMatch.undetermined], which is honest rather than
  /// assuming a favourable direction.
  ///
  /// Results are ordered by opposing target count, then corroboration, then
  /// documentation score, then name. Ranking on opposing count first is the
  /// point of this whole model: a drug that acts against four dysregulated
  /// genes is a stronger hypothesis than one with a single well-documented
  /// interaction, and the old score-only ordering could not express that.
  static List<DrugCandidate> group(
    List<DrugInteraction> interactions, {
    CancerSignature? signature,
  }) {
    final regulationByGene = <String, GeneRegulation>{};
    if (signature != null) {
      for (final gene in signature.significantGenes) {
        regulationByGene[gene.symbol.toUpperCase()] =
            GeneRegulation.fromLog2FoldChange(gene.log2fc);
      }
    }

    final byDrug = <String, List<TargetHit>>{};
    final approvedByDrug = <String, bool>{};

    for (final interaction in interactions) {
      final regulation = regulationByGene[interaction.gene.toUpperCase()];
      final hit = TargetHit(
        interaction: interaction,
        regulation: regulation,
        match: DirectionalMatch.resolve(interaction.direction, regulation),
      );
      byDrug.putIfAbsent(interaction.drug, () => []).add(hit);
      // Approval is a property of the drug; any source reporting approval wins.
      approvedByDrug[interaction.drug] =
          (approvedByDrug[interaction.drug] ?? false) || interaction.isApproved;
    }

    final candidates = <DrugCandidate>[];
    for (final entry in byDrug.entries) {
      final hits = entry.value
        ..sort((a, b) {
          // Opposing targets lead, so the headline detail is the relevant one.
          final byMatch = _matchRank(a.match).compareTo(_matchRank(b.match));
          if (byMatch != 0) return byMatch;
          final bySources = b.interaction.sourceCount
              .compareTo(a.interaction.sourceCount);
          if (bySources != 0) return bySources;
          final byScore = b.interaction.score.compareTo(a.interaction.score);
          if (byScore != 0) return byScore;
          return a.interaction.gene.compareTo(b.interaction.gene);
        });
      candidates.add(DrugCandidate(
        drug: entry.key,
        targets: List.unmodifiable(hits),
        isApproved: approvedByDrug[entry.key] ?? false,
      ));
    }

    candidates.sort((a, b) {
      final byOpposing = b.opposingCount.compareTo(a.opposingCount);
      if (byOpposing != 0) return byOpposing;
      final bySources = b.maxSourceCount.compareTo(a.maxSourceCount);
      if (bySources != 0) return bySources;
      final byTargets = b.targetCount.compareTo(a.targetCount);
      if (byTargets != 0) return byTargets;
      final byScore = b.maxScore.compareTo(a.maxScore);
      if (byScore != 0) return byScore;
      return a.drug.compareTo(b.drug);
    });

    return candidates;
  }

  static int _matchRank(DirectionalMatch match) => switch (match) {
        DirectionalMatch.opposes => 0,
        DirectionalMatch.conflicting => 1,
        DirectionalMatch.undetermined => 2,
        DirectionalMatch.reinforces => 3,
      };
}

/// One gene a drug is recorded against, with the directional verdict.
class TargetHit {
  const TargetHit({
    required this.interaction,
    required this.regulation,
    required this.match,
  });

  final DrugInteraction interaction;

  /// How the gene moved in the study, or `null` for manual gene lists.
  final GeneRegulation? regulation;

  final DirectionalMatch match;

  String get gene => interaction.gene;
}

/// A candidate's overall relationship to the queried signature.
enum CandidateDirection {
  /// Acts against the observed change on at least one gene, and never with it.
  opposing(
    'Opposes dysregulation',
    'Acts against the direction of change on every matched gene.',
  ),

  /// Opposes some genes and reinforces others.
  ///
  /// Common for multi-target drugs and worth showing plainly: the net effect
  /// cannot be inferred from expression data alone.
  mixed(
    'Mixed effect',
    'Opposes the change on some genes and reinforces it on others. The net '
        'effect cannot be inferred from expression data.',
  ),

  /// Only reinforces the observed change.
  reinforcing(
    'Reinforces dysregulation',
    'Acts in the same direction the matched genes already moved, which works '
        'against a reversal hypothesis.',
  ),

  /// No direction could be established for any target.
  undetermined(
    'Direction undetermined',
    'No mechanism was reported, or the gene set carries no expression '
        'direction.',
  );

  const CandidateDirection(this.label, this.explanation);

  final String label;
  final String explanation;
}
