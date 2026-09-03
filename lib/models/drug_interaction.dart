import 'pharmacology.dart';

/// A gene-drug interaction record sourced from DGIdb (Drug Gene Interaction
/// Database), aggregated across the source databases that report it.
///
/// ## Honesty notes about the underlying data
///
/// The bundled `master_drugs.db` is a flattened import of DGIdb interaction
/// claims. Two columns that earlier versions of this app displayed as findings
/// were never real measurements and have been removed from this model:
///
/// * `docking_score` was the constant `-5.0` for all 98,239 rows. No docking
///   was ever performed. It is not read anymore.
/// * `target_category` was the constant string `'TARGET'` for all rows and
///   carried no information. It is not read anymore.
///
/// Three further data-quality facts are handled explicitly below:
///
/// * `interaction`, `gene`, and `drug` use the four-character *string* `'NULL'`
///   as a missing marker rather than SQL `NULL`. [normalizeNullable] converts
///   it to a real `null` so the UI can say "not reported" instead of "NULL".
/// * `is_novel` is the inverse of DGIdb's `approved` flag. It means
///   "not FDA-approved", which includes investigational and abandoned
///   compounds. It does *not* mean "novel repurposing candidate". This model
///   exposes it as [isApproved] to stop that misreading.
/// * 1,960 distinct drugs are bare `CHEMBL:CHEMBLxxxxxx` accessions with no
///   common name. [isUnnamedCompound] flags them.
class DrugInteraction {
  /// HGNC gene symbol of the interaction target.
  final String gene;

  /// Drug or compound name as reported by the source database.
  final String drug;

  /// Distinct interaction types reported for this gene-drug pair, e.g.
  /// `['inhibitor', 'blocker']`. Empty when no source reported a mechanism,
  /// which is the case for 64% of rows in the bundled database.
  final List<String> interactionTypes;

  /// Whether at least one source database marks this drug as regulatory
  /// approved.
  ///
  /// Derived from `MIN(is_novel) == 0`. 98 drugs carry conflicting flags
  /// across sources; for those, one source reporting approval is treated as
  /// authoritative, because a drug cannot be un-approved by a database that
  /// simply lacks the record.
  final bool isApproved;

  /// DGIdb interaction score.
  ///
  /// This measures how well *documented* the interaction is, weighted against
  /// how promiscuous the gene and the drug are. It is not a measure of
  /// efficacy, potency, or clinical confidence. Range in the bundled data is
  /// 0.0004 to 157.5, with a median of 0.15 - see [EvidenceStrength].
  final double score;

  /// Source databases reporting this pair, e.g. `['ChEMBL', 'TTD']`.
  final List<String> sources;

  /// Number of distinct genes this drug interacts with across the whole
  /// database. Only populated by drug-name search; `null` for gene-driven
  /// queries.
  ///
  /// High values indicate a promiscuous or poorly characterised compound
  /// (aspirin hits 141 genes), which is context the user needs when judging a
  /// single target.
  final int? targetCount;

  const DrugInteraction({
    required this.gene,
    required this.drug,
    required this.interactionTypes,
    required this.isApproved,
    required this.score,
    required this.sources,
    this.targetCount,
  });

  /// Number of independent source databases corroborating this pair.
  int get sourceCount => sources.length;

  /// `true` when no source database reported a mechanism of action.
  bool get hasUnknownMechanism => interactionTypes.isEmpty;

  /// `true` when [drug] is a bare ChEMBL accession rather than a real name.
  bool get isUnnamedCompound => drug.startsWith('CHEMBL:');

  /// How well documented this interaction is, expressed as a rank within the
  /// database's own score distribution.
  EvidenceStrength get evidenceStrength => EvidenceStrength.forScore(score);

  /// How many independent databases corroborate the pair.
  Corroboration get corroboration => Corroboration.forSourceCount(sourceCount);

  /// Direction in which the drug acts on this target, inferred from the
  /// reported interaction types.
  PharmacologicDirection get direction =>
      PharmacologicDirection.fromInteractionTypes(interactionTypes);

  /// Mechanism of action for display, or `null` when none was reported.
  String? get mechanismLabel =>
      interactionTypes.isEmpty ? null : interactionTypes.join(', ');

  /// Regulatory status for display.
  String get approvalLabel =>
      isApproved ? 'Approved drug' : 'Not FDA-approved';

  /// Converts the database's `'NULL'` string sentinel and blank strings into a
  /// real `null`.
  static String? normalizeNullable(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'NULL') return null;
    return text;
  }

  /// Splits a `GROUP_CONCAT` result into a de-duplicated, sorted list.
  static List<String> _splitConcat(Object? value) {
    final text = normalizeNullable(value);
    if (text == null) return const [];
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != 'NULL')
        .toSet()
        .toList()
      ..sort();
    return parts;
  }

  factory DrugInteraction.fromMap(Map<String, dynamic> map) {
    // `is_novel` is the inverse of DGIdb's `approved` column. The query
    // aggregates it with MIN(), so 0 means "approved by at least one source".
    final novelFlag = map['is_novel'];
    final novel = novelFlag is int
        ? novelFlag
        : int.tryParse(novelFlag?.toString() ?? '1') ?? 1;

    final targetCount = map['target_count'];

    return DrugInteraction(
      gene: normalizeNullable(map['gene']) ?? '',
      drug: normalizeNullable(map['drug']) ?? '',
      interactionTypes: _splitConcat(map['interaction_types']),
      isApproved: novel == 0,
      score: double.tryParse(map['score']?.toString() ?? '') ?? 0.0,
      sources: _splitConcat(map['sources']),
      targetCount: targetCount == null
          ? null
          : (targetCount is int
              ? targetCount
              : int.tryParse(targetCount.toString())),
    );
  }
}

/// Describes a DGIdb interaction score by its percentile rank within the
/// bundled database, rather than asserting a clinical confidence level.
///
/// Thresholds are the measured percentiles of `MAX(score)` grouped by
/// (gene, drug) over the 69,018 non-placeholder pairs in `master_drugs.db`:
/// p25 = 0.04, p50 = 0.15, p75 = 0.73, p90 = 2.63, p95 = 5.25, p99 = 26.25.
///
/// The previous implementation labelled `score > 5.0` as "Clinical / High
/// Confidence", which described 5% of the data and claimed a clinical meaning
/// the score does not carry.
enum EvidenceStrength {
  /// Top 5% of interaction records by documentation depth.
  wellDocumented('Well documented', 'Top 5% of records in this database'),

  /// Top 25%, below the 95th percentile.
  moderatelyDocumented(
    'Moderately documented',
    'Top 25% of records in this database',
  ),

  /// At or below the median.
  sparselyDocumented(
    'Sparsely documented',
    'Below the median record in this database',
  );

  const EvidenceStrength(this.label, this.explanation);

  /// Short label for display.
  final String label;

  /// One-line explanation of what the label is measuring.
  final String explanation;

  /// 95th percentile of the aggregated score distribution.
  static const double wellDocumentedThreshold = 5.25;

  /// 75th percentile of the aggregated score distribution.
  static const double moderatelyDocumentedThreshold = 0.73;

  static EvidenceStrength forScore(double score) {
    if (score >= wellDocumentedThreshold) return wellDocumented;
    if (score >= moderatelyDocumentedThreshold) return moderatelyDocumented;
    return sparselyDocumented;
  }
}

/// Number of independent source databases reporting a gene-drug pair.
///
/// Measured over the bundled data: 90.8% of pairs come from a single database,
/// 9.2% from two or more, 3.8% from three or more. This is the strongest real
/// corroboration signal available in the dataset, and it was previously unused.
enum Corroboration {
  /// Three or more independent databases (3.8% of pairs).
  corroborated('Corroborated', 'Reported by 3 or more independent databases'),

  /// Exactly two independent databases.
  replicated('Replicated', 'Reported by 2 independent databases'),

  /// A single database.
  single('Single source', 'Reported by only 1 database'),

  /// No source recorded.
  none('Source not recorded', 'No source database was recorded');

  const Corroboration(this.label, this.explanation);

  final String label;
  final String explanation;

  static Corroboration forSourceCount(int count) {
    if (count >= 3) return corroborated;
    if (count == 2) return replicated;
    if (count == 1) return single;
    return none;
  }
}
