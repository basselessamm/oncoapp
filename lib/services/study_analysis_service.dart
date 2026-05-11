import 'dart:io';
import 'package:csv/csv.dart';
import '../models/cancer_signature.dart';

class StudyAnalysisService {
  /// Parses a TSV or CSV file and converts it into a [CancerSignature].
  /// [config] contains filtering parameters chosen by the user.
  static Future<CancerSignature> analyzeStudy({
    required File file,
    required String studyName,
    required String pmid,
    required int sampleSize,
    required AnalysisConfig config,
  }) async {
    final String content = await file.readAsString();
    
    // Determine delimiter (Tab for TSV, Comma for CSV)
    String delimiter = file.path.endsWith('.tsv') ? '\t' : ',';
    if (!file.path.endsWith('.tsv') && !file.path.endsWith('.csv')) {
      // Fallback detection
      if (content.contains('\t')) {
        delimiter = '\t';
      } else {
        delimiter = ',';
      }
    }

    final List<List<dynamic>> rows = const CsvToListConverter(
      shouldParseNumbers: true,
    ).convert(content, fieldDelimiter: delimiter);

    if (rows.isEmpty) throw Exception('The file is empty.');

    // 1. Detect Column Indices
    final List<dynamic> headers = rows[0];
    int symbolIdx = _findColumn(headers, ['gene', 'symbol', 'name']);
    int log2fcIdx = _findColumn(headers, ['log2fc', 'log2 ratio', 'logfc', 'ratio']);
    int pValueIdx = _findColumn(headers, ['p-value', 'pvalue', 'p.value', 'p_value']);
    int higherIdx = _findColumn(headers, ['higher expression in', 'higher_expression_in', 'direction']);

    if (symbolIdx == -1 || log2fcIdx == -1) {
      throw Exception('Could not find Gene and Log2FC columns. Please check file headers.');
    }

    // 2. Extract Data
    List<RawGeneEntry> allGenes = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= symbolIdx || row.length <= log2fcIdx) continue;

      final symbol = row[symbolIdx]?.toString().replaceAll('"', '').replaceAll("'", "").trim().toUpperCase() ?? '';
      if (symbol.isEmpty) continue;

      final log2fc = double.tryParse(row[log2fcIdx]?.toString() ?? '0') ?? 0.0;
      final pValueStr = pValueIdx != -1 ? row[pValueIdx]?.toString() ?? '1.0' : '1.0';
      final pValue = double.tryParse(pValueStr) ?? 1.0;
      final higherIn = higherIdx != -1 ? row[higherIdx]?.toString() ?? '' : '';

      allGenes.add(RawGeneEntry(
        symbol: symbol,
        log2fc: log2fc,
        pValue: pValue,
        higherExpressionIn: higherIn,
      ));
    }

    // 3. Apply Statistical Filters
    List<RawGeneEntry> filtered = allGenes.where((g) {
      bool passP = g.pValue <= config.pValueThreshold;
      bool passFC = g.log2fc.abs() >= config.minLog2FC;
      return passP && passFC;
    }).toList();

    // 4. Split into Up and Downregulated
    List<RawGeneEntry> upRegulated = filtered.where((g) => g.log2fc > 0).toList();
    List<RawGeneEntry> downRegulated = filtered.where((g) => g.log2fc < 0).toList();

    // Sort by absolute Log2FC descending
    upRegulated.sort((a, b) => b.log2fc.abs().compareTo(a.log2fc.abs()));
    downRegulated.sort((a, b) => b.log2fc.abs().compareTo(a.log2fc.abs()));

    // 5. Select Top N
    List<SignificantGene> finalGenes = [];
    
    // Take top Upregulated
    final upCount = config.upCount.clamp(0, upRegulated.length);
    for (var i = 0; i < upCount; i++) {
      final g = upRegulated[i];
      finalGenes.add(SignificantGene(
        symbol: g.symbol,
        frequency: g.log2fc.toStringAsFixed(2),
        type: 'Upregulated',
        pValue: g.pValue.toString(),
        log2fc: g.log2fc,
        higherExpressionIn: g.higherExpressionIn,
      ));
    }

    // Take top Downregulated
    final downCount = config.downCount.clamp(0, downRegulated.length);
    for (var i = 0; i < downCount; i++) {
      final g = downRegulated[i];
      finalGenes.add(SignificantGene(
        symbol: g.symbol,
        frequency: g.log2fc.toStringAsFixed(2),
        type: 'Downregulated',
        pValue: g.pValue.toString(),
        log2fc: g.log2fc,
        higherExpressionIn: g.higherExpressionIn,
      ));
    }

    return CancerSignature(
      cancerName: studyName,
      pmid: pmid,
      sampleSize: sampleSize,
      significantGenes: finalGenes,
    );
  }

  static int _findColumn(List<dynamic> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toString().toLowerCase();
      for (final kw in keywords) {
        if (header.contains(kw)) return i;
      }
    }
    return -1;
  }
}

class RawGeneEntry {
  final String symbol;
  final double log2fc;
  final double pValue;
  final String higherExpressionIn;

  RawGeneEntry({
    required this.symbol,
    required this.log2fc,
    required this.pValue,
    required this.higherExpressionIn,
  });
}

class AnalysisConfig {
  final int upCount;
  final int downCount;
  final double pValueThreshold;
  final double minLog2FC;

  AnalysisConfig({
    this.upCount = 25,
    this.downCount = 5,
    this.pValueThreshold = 0.05,
    this.minLog2FC = 1.0,
  });
}
