/// Models for target-disease evidence, tractability, and clinical candidates
/// retrieved from the Open Targets Platform API.
library;

/// Evidence linking a gene target to a specific disease context in Open Targets.
class TargetEvidence {
  const TargetEvidence({
    required this.geneSymbol,
    this.ensemblId,
    this.approvedName,
    this.biotype,
    this.associationScore,
    this.datatypeScores = const {},
    this.tractability = const [],
    this.clinicalCandidates = const [],
    this.clinicalCandidateCount = 0,
  });

  /// The queried gene symbol (e.g., "TP53", "ESR1").
  final String geneSymbol;

  /// Ensembl gene identifier (e.g., "ENSG00000141510").
  /// `null` indicates the symbol could not be resolved to an Ensembl target.
  final String? ensemblId;

  /// Approved gene name (e.g., "tumor protein p53").
  final String? approvedName;

  /// Biological type (e.g., "protein_coding").
  final String? biotype;

  /// Overall target-disease association score in the range [0.0, 1.0].
  /// `null` indicates no association was recorded for this disease.
  final double? associationScore;

  /// Association breakdown across evidence data types.
  /// Keys: genetic_association, somatic_mutation, known_drug, affected_pathway,
  /// literature, rna_expression, animal_model, genetic_literature, clinical.
  final Map<String, double> datatypeScores;

  /// Druggability assessments across modalities (SM, AB, PR, OC).
  final List<TractabilityBucket> tractability;

  /// Clinical drug candidates hitting this target.
  final List<ClinicalCandidate> clinicalCandidates;

  /// Total count of clinical candidates recorded in Open Targets.
  final int clinicalCandidateCount;

  /// Whether the gene symbol resolved to a known Ensembl target.
  bool get isResolved => ensemblId != null;

  /// Whether an association score exists for this target-disease pair.
  bool get hasAssociation => associationScore != null;

  /// Categorical strength of the association based on calibrated thresholds.
  AssociationStrength get associationStrength =>
      AssociationStrength.forScore(associationScore);

  /// Best tractability tier achieved across clinical candidates and preclinical buckets.
  TractabilityTier get bestTractability {
    // 1. Check clinical candidates first (highest tiers)
    var highestClinicalRank = -1;
    for (final candidate in clinicalCandidates) {
      if (candidate.stage.rank > highestClinicalRank) {
        highestClinicalRank = candidate.stage.rank;
      }
    }

    if (highestClinicalRank >= ClinicalStage.approval.rank) {
      return TractabilityTier.approvedDrug;
    }
    if (highestClinicalRank >= ClinicalStage.phase2.rank) {
      return TractabilityTier.advancedClinical;
    }
    if (highestClinicalRank >= ClinicalStage.phase1.rank) {
      return TractabilityTier.phase1Clinical;
    }

    // 2. Check preclinical tractability buckets
    final hasPreclinical = tractability.any((bucket) => bucket.value);
    if (hasPreclinical) {
      return TractabilityTier.preclinicalEvidence;
    }

    return TractabilityTier.noEvidence;
  }

  /// Clinical candidate with the highest clinical trial stage.
  ClinicalCandidate? get mostAdvancedCandidate {
    if (clinicalCandidates.isEmpty) return null;
    ClinicalCandidate? best;
    for (final candidate in clinicalCandidates) {
      if (best == null || candidate.stage.rank > best.stage.rank) {
        best = candidate;
      }
    }
    return best;
  }

  /// Whether this target exhibits characteristics of a passenger rather than a driver:
  /// low or no published disease association (< 0.10), no clinical candidates,
  /// and preclinical or no tractability evidence.
  ///
  /// This is treated as a probabilistic indicator, not a definitive verdict.
  bool get isLikelyPassenger {
    final scoreLow = associationScore == null || associationScore! < 0.10;
    final noCandidates = clinicalCandidateCount == 0;
    final tier = bestTractability;
    final lowTractability =
        tier == TractabilityTier.preclinicalEvidence || tier == TractabilityTier.noEvidence;

    return scoreLow && noCandidates && lowTractability;
  }

  Map<String, dynamic> toJson() => {
        'geneSymbol': geneSymbol,
        'ensemblId': ensemblId,
        'approvedName': approvedName,
        'biotype': biotype,
        'associationScore': associationScore,
        'datatypeScores': datatypeScores,
        'tractability': tractability.map((b) => b.toJson()).toList(),
        'clinicalCandidates': clinicalCandidates.map((c) => c.toJson()).toList(),
        'clinicalCandidateCount': clinicalCandidateCount,
      };

  factory TargetEvidence.fromJson(Map<String, dynamic> json) => TargetEvidence(
        geneSymbol: json['geneSymbol'] as String,
        ensemblId: json['ensemblId'] as String?,
        approvedName: json['approvedName'] as String?,
        biotype: json['biotype'] as String?,
        associationScore: (json['associationScore'] as num?)?.toDouble(),
        datatypeScores: (json['datatypeScores'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            const {},
        tractability: (json['tractability'] as List<dynamic>?)
                ?.map((b) => TractabilityBucket.fromJson(b as Map<String, dynamic>))
                .toList() ??
            const [],
        clinicalCandidates: (json['clinicalCandidates'] as List<dynamic>?)
                ?.map((c) => ClinicalCandidate.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        clinicalCandidateCount: json['clinicalCandidateCount'] as int? ?? 0,
      );
}

/// A tractability category assessing target druggability for a specific modality.
class TractabilityBucket {
  const TractabilityBucket({
    required this.label,
    required this.modality,
    required this.value,
  });

  /// e.g., "Approved Drug", "Clinical Precedence", "Discovery Precedence".
  final String label;

  /// Modality code: SM (Small Molecule), AB (Antibody), PR (PROTAC), OC (Other Modalities).
  final String modality;

  /// Whether the target qualifies for this tractability tier.
  final bool value;

  Map<String, dynamic> toJson() => {
        'label': label,
        'modality': modality,
        'value': value,
      };

  factory TractabilityBucket.fromJson(Map<String, dynamic> json) => TractabilityBucket(
        label: json['label'] as String,
        modality: json['modality'] as String,
        value: json['value'] as bool,
      );
}

/// A drug candidate in development or approved for this target.
class ClinicalCandidate {
  const ClinicalCandidate({
    this.drugId,
    this.drugName,
    this.drugType,
    required this.stage,
    this.indications = const [],
  });

  final String? drugId;
  final String? drugName;
  final String? drugType;
  final ClinicalStage stage;
  final List<String> indications;

  Map<String, dynamic> toJson() => {
        'drugId': drugId,
        'drugName': drugName,
        'drugType': drugType,
        'stage': stage.name,
        'indications': indications,
      };

  factory ClinicalCandidate.fromJson(Map<String, dynamic> json) => ClinicalCandidate(
        drugId: json['drugId'] as String?,
        drugName: json['drugName'] as String?,
        drugType: json['drugType'] as String?,
        stage: ClinicalStage.values.firstWhere(
          (s) => s.name == json['stage'],
          orElse: () => ClinicalStage.fromApiValue(json['stage'] as String?),
        ),
        indications: (json['indications'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

/// Association score strength based on empirical Open Targets distributions.
enum AssociationStrength {
  strong(
    'Strong',
    'High confidence association supported by robust literature or genetic evidence (score >= 0.30).',
  ),
  moderate(
    'Moderate',
    'Moderate evidence of association in public databases (score 0.10 - 0.29).',
  ),
  weak(
    'Weak',
    'Limited published evidence linking this target to the disease (score 0.01 - 0.09).',
  ),
  negligible(
    'Negligible',
    'Minimal reported association (score < 0.01).',
  ),
  notReported(
    'Not reported',
    'No target-disease association recorded in Open Targets.',
  );

  const AssociationStrength(this.label, this.explanation);

  final String label;
  final String explanation;

  /// Categorises an association score into its calibrated strength tier.
  static AssociationStrength forScore(double? score) {
    if (score == null) return AssociationStrength.notReported;
    if (score >= 0.30) return AssociationStrength.strong;
    if (score >= 0.10) return AssociationStrength.moderate;
    if (score >= 0.01) return AssociationStrength.weak;
    return AssociationStrength.negligible;
  }
}

/// Overall druggability tier synthesized from clinical stages and tractability evidence.
enum TractabilityTier {
  approvedDrug(
    'Approved Drug',
    'At least one approved therapeutic targeting this gene is recorded.',
  ),
  advancedClinical(
    'Advanced Clinical',
    'Candidates targeting this gene are in Phase 2, Phase 3, or pre-approval.',
  ),
  phase1Clinical(
    'Phase 1 Clinical',
    'Candidates targeting this gene have entered early clinical evaluation.',
  ),
  preclinicalEvidence(
    'Preclinical Evidence',
    'Biochemical or structural evidence suggests druggability, but no active clinical pipeline is recorded.',
  ),
  noEvidence(
    'No Evidence',
    'No druggability or clinical precedence recorded.',
  );

  const TractabilityTier(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// Clinical trial stage for a drug candidate in Open Targets.
enum ClinicalStage {
  approval('Approved', 5),
  preApproval('Pre-approval', 4),
  phase3('Phase 3', 3),
  phase2('Phase 2', 2),
  phase1('Phase 1', 1),
  unknown('Unknown', 0);

  const ClinicalStage(this.label, this.rank);

  final String label;
  final int rank;

  /// Maps Open Targets `maximumClinicalStage` or `maxClinicalStage` strings.
  static ClinicalStage fromApiValue(String? value) {
    if (value == null) return ClinicalStage.unknown;
    return switch (value.toUpperCase()) {
      'APPROVAL' => ClinicalStage.approval,
      'PREAPPROVAL' => ClinicalStage.preApproval,
      'PHASE_3' || 'PHASE_2_3' => ClinicalStage.phase3,
      'PHASE_2' || 'PHASE_1_2' => ClinicalStage.phase2,
      'PHASE_1' => ClinicalStage.phase1,
      _ => ClinicalStage.unknown,
    };
  }
}
