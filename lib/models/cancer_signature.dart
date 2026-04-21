class SignificantGene {
  final String symbol;
  final String frequency;
  final String type;

  SignificantGene({
    required this.symbol,
    required this.frequency,
    required this.type,
  });

  factory SignificantGene.fromJson(Map<String, dynamic> json) {
    return SignificantGene(
      symbol: json['symbol']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class CancerSignature {
  final String cancerName;
  final String pmid;
  final int sampleSize;
  final List<SignificantGene> significantGenes;

  CancerSignature({
    required this.cancerName,
    required this.pmid,
    required this.sampleSize,
    required this.significantGenes,
  });

  factory CancerSignature.fromJson(Map<String, dynamic> json) {
    var list = json['significant_genes'] as List? ?? [];
    List<SignificantGene> genes = 
        list.map((i) => SignificantGene.fromJson(i)).toList();

    return CancerSignature(
      cancerName: json['cancer_name']?.toString() ?? '',
      pmid: json['pmid']?.toString() ?? '',
      sampleSize: json['sample_size'] as int? ?? 0,
      significantGenes: genes,
    );
  }
}
