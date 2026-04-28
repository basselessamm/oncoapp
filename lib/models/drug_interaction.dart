class DrugInteraction {
  final String gene;
  final String drug;
  final String interaction;
  final String targetCategory;
  final int isNovel;
  final double score;
  final double dockingScore;
  final String source;

  DrugInteraction({
    required this.gene,
    required this.drug,
    required this.interaction,
    required this.targetCategory,
    required this.isNovel,
    required this.score,
    required this.dockingScore,
    required this.source,
  });

  factory DrugInteraction.fromMap(Map<String, dynamic> map) {
    return DrugInteraction(
      gene: map['gene']?.toString() ?? '',
      drug: map['drug']?.toString() ?? '',
      interaction: map['interaction']?.toString() ?? '',
      targetCategory: map['target_category']?.toString() ?? '',
      isNovel: (map['is_novel'] is int) ? map['is_novel'] : int.tryParse(map['is_novel']?.toString() ?? '0') ?? 0,
      score: double.tryParse(map['score']?.toString() ?? '0') ?? 0.0,
      dockingScore: double.tryParse(map['docking_score']?.toString() ?? '-6.5') ?? -6.5,
      source: map['source']?.toString() ?? '',
    );
  }
}
