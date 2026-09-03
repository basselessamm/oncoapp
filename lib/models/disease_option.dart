/// Representation of a disease or phenotype entity from the Open Targets ontology.
class DiseaseOption {
  const DiseaseOption({
    required this.id,
    required this.name,
    this.description = '',
    this.therapeuticAreas = const [],
  });

  /// Ontology identifier, typically a MONDO or EFO identifier (e.g., "MONDO_0004989").
  final String id;

  /// Human-readable disease name (e.g., "breast carcinoma").
  final String name;

  /// Medical or ontological description of the disease entity.
  final String description;

  /// Top-level therapeutic areas (e.g., ["neoplasm", "cancer"]).
  final List<String> therapeuticAreas;

  /// Default curated breast cancer disease options verified against Open Targets 26.6.3 / 26.06.
  static const List<DiseaseOption> breastCancerDefaults = [
    DiseaseOption(
      id: 'MONDO_0004989',
      name: 'Breast carcinoma',
      description:
          'A malignant neoplasm arising from epithelial cells of the breast parenchyma. '
          'Primary default for general breast oncology queries.',
      therapeuticAreas: ['neoplasm', 'cancer or benign tumor'],
    ),
    DiseaseOption(
      id: 'MONDO_0005494',
      name: 'Triple-negative breast carcinoma',
      description:
          'An aggressive breast carcinoma subtype lacking estrogen receptors, '
          'progesterone receptors, and HER2/neu amplification.',
      therapeuticAreas: ['neoplasm', 'cancer or benign tumor'],
    ),
    DiseaseOption(
      id: 'MONDO_0006256',
      name: 'Invasive breast carcinoma',
      description:
          'A carcinoma of the breast that has invaded beyond the basement membrane '
          'into surrounding stroma.',
      therapeuticAreas: ['neoplasm', 'cancer or benign tumor'],
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiseaseOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DiseaseOption($id, $name)';
}
