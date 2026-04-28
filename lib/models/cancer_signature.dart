class SignificantGene {
  final String symbol;
  final String frequency;
  final String type;
  final String pValue;
  final double log2fc;
  final String higherExpressionIn;

  SignificantGene({
    required this.symbol,
    required this.frequency,
    required this.type,
    this.pValue = '',
    this.log2fc = 0.0,
    this.higherExpressionIn = '',
  });

  factory SignificantGene.fromJson(Map<String, dynamic> json) {
    return SignificantGene(
      symbol: json['symbol']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      pValue: json['p_value']?.toString() ?? '',
      log2fc: (json['log2fc'] as num?)?.toDouble() ?? 0.0,
      higherExpressionIn: json['higher_expression_in']?.toString() ?? '',
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
      cancerName: json['cancer_name']?.toString() ?? 'Unknown',
      pmid: json['pmid']?.toString() ?? '',
      sampleSize: json['sample_size'] as int? ?? 0,
      significantGenes: genes,
    );
  }
}
