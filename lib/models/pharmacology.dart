/// Direction in which a drug acts on its target protein.
///
/// Derived from the DGIdb `interaction` column, which the app previously
/// displayed as text but never interpreted. Classifying it is what makes it
/// possible to say whether a drug pushes a gene's activity *against* the change
/// observed in the tumour or *along with* it.
enum PharmacologicDirection {
  /// Reduces target activity: inhibitor, blocker, antagonist, inverse agonist,
  /// negative modulator, degrader, antisense knockdown.
  suppresses('Suppresses target'),

  /// Increases target activity: agonist, activator, positive modulator,
  /// potentiator.
  activates('Activates target'),

  /// Sources disagree - at least one reports suppression and another
  /// activation. Real for 275 gene-drug pairs in the bundled database, usually
  /// tissue- or isoform-dependent behaviour.
  conflicting('Conflicting reports'),

  /// No direction can be inferred. Either no mechanism was reported (64% of
  /// rows) or the reported term names a modality rather than a direction
  /// ("antibody", "vaccine", "binder").
  unspecified('Direction not reported');

  const PharmacologicDirection(this.label);

  final String label;

  /// Interaction terms that reduce target activity.
  ///
  /// Covers every suppressing value present in the bundled data plus common
  /// DGIdb terms not currently represented, so a database refresh does not
  /// silently fall through to [unspecified].
  static const Set<String> suppressingTerms = {
    'inhibitor',
    'blocker',
    'antagonist',
    'inverse agonist',
    'negative modulator',
    'inhibitory allosteric modulator',
    'antisense oligonucleotide',
    'cleavage',
    'degrader',
    'suppressor',
    'inactivator',
  };

  /// Interaction terms that increase target activity.
  static const Set<String> activatingTerms = {
    'agonist',
    'activator',
    'positive modulator',
    'positive allosteric modulator',
    'potentiator',
    'partial agonist',
    'inducer',
    'stimulator',
  };

  /// Classifies the set of interaction terms reported for one gene-drug pair.
  ///
  /// Terms naming a modality rather than a direction - "antibody", "vaccine",
  /// "immunotherapy", "binder", bare "modulator", "other/unknown" - are
  /// ignored when a directional term is also present, and yield [unspecified]
  /// when they are all that is reported. An antibody can be blocking or
  /// agonising, so treating it as suppression would be a guess.
  static PharmacologicDirection fromInteractionTypes(Iterable<String> types) {
    var suppressing = false;
    var activating = false;

    for (final type in types) {
      final term = type.trim().toLowerCase();
      if (term.isEmpty || term == 'null') continue;
      if (suppressingTerms.contains(term)) {
        suppressing = true;
      } else if (activatingTerms.contains(term)) {
        activating = true;
      }
    }

    if (suppressing && activating) return conflicting;
    if (suppressing) return suppresses;
    if (activating) return activates;
    return unspecified;
  }
}

/// Whether a gene was over- or under-expressed in the study.
enum GeneRegulation {
  up('Over-expressed'),
  down('Under-expressed');

  const GeneRegulation(this.label);

  final String label;

  /// Reads the direction from a signature gene's fold change.
  static GeneRegulation fromLog2FoldChange(double log2fc) =>
      log2fc > 0 ? up : down;
}

/// Relationship between a drug's direction of action and the direction a gene
/// moved in the tumour.
///
/// This is the core of what the app can honestly infer, and it is a
/// *directional consistency check*, not a therapeutic prediction. Three limits
/// apply to every value below:
///
/// 1. mRNA abundance is not protein activity. A gene can be over-expressed
///    while its protein is inactive, and vice versa.
/// 2. A differentially expressed gene may be a driver of the tumour or a
///    passenger, or a compensatory response to it. Reversing a passenger
///    achieves nothing; reversing a compensatory response can be harmful.
/// 3. The check treats each gene in isolation. It does not model pathways,
///    feedback loops, or the drug's other targets.
enum DirectionalMatch {
  /// The drug pushes the gene's activity against the observed change:
  /// suppresses an over-expressed gene, or activates an under-expressed one.
  opposes(
    'Opposes the observed change',
    'The drug acts against the direction this gene moved in the study.',
  ),

  /// The drug pushes further in the same direction as the observed change.
  ///
  /// Surfaced rather than hidden: it is a genuine counter-indication signal for
  /// a repurposing hypothesis, and it is also the state the app previously
  /// presented identically to [opposes].
  reinforces(
    'Reinforces the observed change',
    'The drug acts in the same direction this gene already moved, which works '
        'against a reversal hypothesis.',
  ),

  /// Sources report both directions for this pair.
  conflicting(
    'Conflicting direction',
    'Source databases disagree on whether the drug suppresses or activates '
        'this target.',
  ),

  /// The drug's direction, the gene's direction, or both are unknown.
  undetermined(
    'Direction undetermined',
    'Either no mechanism was reported for the drug, or the gene set carries no '
        'expression direction.',
  );

  const DirectionalMatch(this.label, this.explanation);

  final String label;
  final String explanation;

  /// Combines a drug's direction of action with a gene's regulation.
  ///
  /// [regulation] is `null` for manually entered gene lists, which carry no
  /// fold change; every match is then [undetermined] rather than being silently
  /// treated as favourable.
  static DirectionalMatch resolve(
    PharmacologicDirection direction,
    GeneRegulation? regulation,
  ) {
    if (regulation == null) return undetermined;

    switch (direction) {
      case PharmacologicDirection.conflicting:
        return DirectionalMatch.conflicting;
      case PharmacologicDirection.unspecified:
        return undetermined;
      case PharmacologicDirection.suppresses:
        return regulation == GeneRegulation.up ? opposes : reinforces;
      case PharmacologicDirection.activates:
        return regulation == GeneRegulation.down ? opposes : reinforces;
    }
  }
}
