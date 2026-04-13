class OncologyData {
  final List<Dataset> datasets;
  final List<Rule> rules;

  OncologyData({required this.datasets, required this.rules});

  factory OncologyData.fromJson(Map<String, dynamic> json) {
    return OncologyData(
      datasets: (json['datasets'] as List)
          .map((item) => Dataset.fromJson(item))
          .toList(),
      rules: (json['rules'] as List)
          .map((item) => Rule.fromJson(item))
          .toList(),
    );
  }
}

class Dataset {
  final String id;
  final String cancerType;
  final String source;
  final Map<String, String> geneExpression;

  Dataset({
    required this.id,
    required this.cancerType,
    required this.source,
    required this.geneExpression,
  });

  factory Dataset.fromJson(Map<String, dynamic> json) {
    return Dataset(
      id: json['id'],
      cancerType: json['cancer_type'],
      source: json['source'],
      geneExpression: Map<String, String>.from(json['gene_expression']),
    );
  }
}

class Rule {
  final String targetGene;
  final String condition;
  final String recommendedDrug;
  final String mechanism;
  final List<String> pathways;
  final String dockingScore;
  final String evidenceLevel;
  final String proteinTarget;

  Rule({
    required this.targetGene,
    required this.condition,
    required this.recommendedDrug,
    required this.mechanism,
    required this.pathways,
    required this.dockingScore,
    required this.evidenceLevel,
    required this.proteinTarget,
  });

  factory Rule.fromJson(Map<String, dynamic> json) {
    return Rule(
      targetGene: json['target_gene'],
      condition: json['condition'],
      recommendedDrug: json['recommended_drug'],
      mechanism: json['mechanism'],
      pathways: List<String>.from(json['pathways']),
      dockingScore: json['docking_score'],
      evidenceLevel: json['evidence_level'],
      proteinTarget: json['protein_target'],
    );
  }
}
