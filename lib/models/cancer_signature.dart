/// One gene from a differential-expression result.
class SignificantGene {
  /// HGNC gene symbol, uppercased.
  final String symbol;

  /// `'Upregulated'` or `'Downregulated'`.
  final String type;

  /// Log2 fold change. Positive means higher in the first group compared.
  final double log2fc;

  /// Raw, uncorrected p-value, or `null` when the source did not report one.
  ///
  /// Stored as a number rather than a string so it can be sorted and
  /// thresholded. The previous model typed this as `String`, which made
  /// multiple-testing correction impossible without re-parsing.
  final double? pValue;

  /// Benjamini-Hochberg adjusted p-value, or `null` when not computed.
  ///
  /// Populated by [StudyAnalysisService] for user-uploaded studies. The bundled
  /// signatures predate this field and carry `null`.
  final double? adjustedPValue;

  /// Which group the gene is higher in, as reported by the source.
  final String higherExpressionIn;

  const SignificantGene({
    required this.symbol,
    required this.type,
    this.log2fc = 0.0,
    this.pValue,
    this.adjustedPValue,
    this.higherExpressionIn = '',
  });

  bool get isUpregulated => log2fc > 0;

  /// The most stringent p-value available for this gene.
  double? get effectivePValue => adjustedPValue ?? pValue;

  factory SignificantGene.fromJson(Map<String, dynamic> json) {
    return SignificantGene(
      symbol: (json['symbol']?.toString() ?? '').trim().toUpperCase(),
      type: json['type']?.toString() ?? '',
      log2fc: _toDouble(json['log2fc']) ?? 0.0,
      pValue: _toDouble(json['p_value']),
      adjustedPValue: _toDouble(json['adjusted_p_value']),
      higherExpressionIn: json['higher_expression_in']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'type': type,
        'log2fc': log2fc,
        if (pValue != null) 'p_value': pValue,
        if (adjustedPValue != null) 'adjusted_p_value': adjustedPValue,
        if (higherExpressionIn.isNotEmpty)
          'higher_expression_in': higherExpressionIn,
      };

  /// Parses numbers written either as JSON numbers or as strings in scientific
  /// notation, which is how the bundled assets store p-values (`"1.01e-18"`).
  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty || text == 'NULL') return null;
    return double.tryParse(text);
  }
}

/// A named gene expression signature, either bundled with the app or derived
/// from a study the user uploaded.
class CancerSignature {
  /// Stable identifier, used for selection and deletion.
  ///
  /// Signatures were previously matched by display name, so two studies sharing
  /// a name would collide and deleting one could remove the other.
  final String id;

  final String cancerName;

  /// PubMed ID of the source publication, if known.
  final String pmid;

  final int sampleSize;

  final List<SignificantGene> significantGenes;

  /// Provenance and filtering parameters, recorded so a saved study can be
  /// reproduced. `null` for bundled signatures.
  final AnalysisProvenance? provenance;

  const CancerSignature({
    required this.id,
    required this.cancerName,
    required this.pmid,
    required this.sampleSize,
    required this.significantGenes,
    this.provenance,
  });

  int get upregulatedCount =>
      significantGenes.where((gene) => gene.isUpregulated).length;

  int get downregulatedCount =>
      significantGenes.where((gene) => !gene.isUpregulated).length;

  factory CancerSignature.fromJson(Map<String, dynamic> json) {
    final genes = (json['significant_genes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SignificantGene.fromJson)
        .toList();

    final name = json['cancer_name']?.toString() ?? 'Unknown signature';

    return CancerSignature(
      // Bundled assets have no id; fall back to the name so they stay stable
      // across launches.
      id: json['id']?.toString() ?? name,
      cancerName: name,
      pmid: json['pmid']?.toString() ?? '',
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      significantGenes: genes,
      provenance: json['provenance'] == null
          ? null
          : AnalysisProvenance.fromJson(
              json['provenance'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cancer_name': cancerName,
        'pmid': pmid,
        'sample_size': sampleSize,
        'significant_genes':
            significantGenes.map((gene) => gene.toJson()).toList(),
        if (provenance != null) 'provenance': provenance!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is CancerSignature && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// How a user-uploaded signature was derived, so the numbers on screen can be
/// traced back to the file and thresholds that produced them.
class AnalysisProvenance {
  const AnalysisProvenance({
    required this.sourceFileName,
    required this.analyzedAt,
    required this.genesInFile,
    required this.genesPassingFilters,
    required this.pValueThreshold,
    required this.minLog2FC,
    required this.usedFdrCorrection,
    required this.rowsSkipped,
  });

  final String sourceFileName;
  final DateTime analyzedAt;

  /// Rows successfully parsed from the file.
  final int genesInFile;

  /// Genes passing the significance and effect-size thresholds, before the
  /// top-N truncation.
  final int genesPassingFilters;

  final double pValueThreshold;
  final double minLog2FC;

  /// Whether [pValueThreshold] was applied to Benjamini-Hochberg adjusted
  /// p-values rather than raw ones.
  final bool usedFdrCorrection;

  /// Rows dropped because a required column was missing or unparseable.
  ///
  /// Previously such rows were silently coerced to `log2fc = 0, p = 1`, which
  /// turned malformed data into valid non-significant genes.
  final int rowsSkipped;

  factory AnalysisProvenance.fromJson(Map<String, dynamic> json) {
    return AnalysisProvenance(
      sourceFileName: json['source_file_name']?.toString() ?? '',
      analyzedAt: DateTime.tryParse(json['analyzed_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      genesInFile: (json['genes_in_file'] as num?)?.toInt() ?? 0,
      genesPassingFilters:
          (json['genes_passing_filters'] as num?)?.toInt() ?? 0,
      pValueThreshold: (json['p_value_threshold'] as num?)?.toDouble() ?? 0.05,
      minLog2FC: (json['min_log2fc'] as num?)?.toDouble() ?? 0.0,
      usedFdrCorrection: json['used_fdr_correction'] == true,
      rowsSkipped: (json['rows_skipped'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'source_file_name': sourceFileName,
        'analyzed_at': analyzedAt.toIso8601String(),
        'genes_in_file': genesInFile,
        'genes_passing_filters': genesPassingFilters,
        'p_value_threshold': pValueThreshold,
        'min_log2fc': minLog2FC,
        'used_fdr_correction': usedFdrCorrection,
        'rows_skipped': rowsSkipped,
      };
}
