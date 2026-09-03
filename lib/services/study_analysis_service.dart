import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

import '../models/cancer_signature.dart';

/// Thrown when an uploaded study file cannot be interpreted.
class StudyAnalysisException implements Exception {
  StudyAnalysisException(this.message);

  final String message;

  @override
  String toString() => 'StudyAnalysisException: $message';
}

/// Multiple-testing correction applied to the p-value column.
enum MultipleTestingCorrection {
  /// Benjamini-Hochberg false discovery rate control.
  ///
  /// The correct default for transcriptome-wide tables. Without it, filtering
  /// 19,000 genes at p <= 0.05 admits roughly 950 genes by chance alone.
  benjaminiHochberg(
    'Benjamini-Hochberg (FDR)',
    'Controls the expected proportion of false positives. Recommended for '
        'whole-transcriptome tables.',
  ),

  /// No correction; the raw p-value column is thresholded directly.
  ///
  /// Appropriate only when the uploaded file is already a filtered or adjusted
  /// result set.
  none(
    'None (raw p-values)',
    'Use only if the file already contains adjusted p-values or a pre-filtered '
        'gene list.',
  );

  const MultipleTestingCorrection(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// Filtering parameters for [StudyAnalysisService.analyzeStudy].
@immutable
class AnalysisConfig {
  const AnalysisConfig({
    this.upCount = 25,
    this.downCount = 25,
    this.pValueThreshold = 0.05,
    this.minLog2FC = 1.0,
    this.correction = MultipleTestingCorrection.benjaminiHochberg,
  });

  /// How many top up-regulated genes to keep.
  final int upCount;

  /// How many top down-regulated genes to keep.
  ///
  /// Defaults to match [upCount]. The previous default of 5 against 25
  /// up-regulated genes had no stated justification and silently biased every
  /// signature toward over-expression.
  final int downCount;

  /// Significance cutoff, applied to adjusted p-values when [correction] is
  /// not [MultipleTestingCorrection.none].
  final double pValueThreshold;

  /// Minimum absolute log2 fold change.
  final double minLog2FC;

  final MultipleTestingCorrection correction;

  AnalysisConfig copyWith({
    int? upCount,
    int? downCount,
    double? pValueThreshold,
    double? minLog2FC,
    MultipleTestingCorrection? correction,
  }) {
    return AnalysisConfig(
      upCount: upCount ?? this.upCount,
      downCount: downCount ?? this.downCount,
      pValueThreshold: pValueThreshold ?? this.pValueThreshold,
      minLog2FC: minLog2FC ?? this.minLog2FC,
      correction: correction ?? this.correction,
    );
  }
}

/// Turns a differential-expression table (CSV/TSV) into a [CancerSignature].
///
/// This is the only genuine statistical code in the app: it parses, applies
/// multiple-testing correction, filters on significance and effect size, then
/// keeps the strongest genes in each direction.
class StudyAnalysisService {
  const StudyAnalysisService._();

  /// Header keywords used to locate each column, matched case-insensitively as
  /// substrings.
  static const List<String> _symbolKeywords = [
    'gene symbol',
    'gene_symbol',
    'symbol',
    'gene',
    'name',
  ];
  static const List<String> _log2fcKeywords = [
    'log2 fold change',
    'log2foldchange',
    'log2fc',
    'log2 ratio',
    'logfc',
    'fold change',
    'ratio',
  ];
  static const List<String> _pValueKeywords = [
    'p-value',
    'pvalue',
    'p.value',
    'p_value',
    'p val',
  ];
  static const List<String> _adjustedPKeywords = [
    'adj.p.val',
    'adj_p_val',
    'adjusted p',
    'padj',
    'p.adj',
    'q-value',
    'qvalue',
    'fdr',
  ];
  static const List<String> _directionKeywords = [
    'higher expression in',
    'higher_expression_in',
    'direction',
  ];

  /// Reads and analyses [file].
  ///
  /// Parsing runs on a background isolate, so a multi-megabyte table does not
  /// freeze the UI.
  static Future<CancerSignature> analyzeStudy({
    required File file,
    required String studyName,
    required String pmid,
    required int sampleSize,
    required AnalysisConfig config,
  }) async {
    final String content;
    try {
      content = await file.readAsString();
    } catch (error) {
      throw StudyAnalysisException(
        'Could not read the file. Check that it is a text CSV or TSV export.',
      );
    }

    final fileName = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;

    final parsed = await compute(
      _parseAndFilter,
      _AnalysisRequest(
        content: content,
        fileName: fileName,
        isTabSeparated: fileName.toLowerCase().endsWith('.tsv'),
        upCount: config.upCount,
        downCount: config.downCount,
        pValueThreshold: config.pValueThreshold,
        minLog2FC: config.minLog2FC,
        applyFdr: config.correction == MultipleTestingCorrection.benjaminiHochberg,
      ),
    );

    if (parsed.errorMessage != null) {
      throw StudyAnalysisException(parsed.errorMessage!);
    }

    return CancerSignature(
      id: 'lab_${DateTime.now().microsecondsSinceEpoch}',
      cancerName: studyName,
      pmid: pmid,
      sampleSize: sampleSize,
      significantGenes: parsed.genes,
      provenance: AnalysisProvenance(
        sourceFileName: fileName,
        analyzedAt: DateTime.now(),
        genesInFile: parsed.genesInFile,
        genesPassingFilters: parsed.genesPassingFilters,
        pValueThreshold: config.pValueThreshold,
        minLog2FC: config.minLog2FC,
        usedFdrCorrection: parsed.usedFdrCorrection,
        rowsSkipped: parsed.rowsSkipped,
      ),
    );
  }

  /// Benjamini-Hochberg adjusted p-values, in the order of [pValues].
  ///
  /// Ranks ascending, scales each p-value by `n / rank`, then enforces
  /// monotonicity from the largest rank downward and clamps at 1.0.
  ///
  /// Exposed for testing.
  @visibleForTesting
  static List<double> benjaminiHochberg(List<double> pValues) {
    final n = pValues.length;
    if (n == 0) return const [];

    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => pValues[a].compareTo(pValues[b]));

    final adjusted = List<double>.filled(n, 1.0);
    var previous = 1.0;
    for (var rank = n; rank >= 1; rank--) {
      final index = order[rank - 1];
      final scaled = pValues[index] * n / rank;
      previous = scaled < previous ? scaled : previous;
      adjusted[index] = previous > 1.0 ? 1.0 : previous;
    }
    return adjusted;
  }

  /// Locates a column by keyword, preferring the earliest keyword in the list
  /// so that a more specific match wins over a generic one.
  @visibleForTesting
  static int findColumn(List<dynamic> headers, List<String> keywords) {
    final normalized =
        headers.map((h) => h.toString().trim().toLowerCase()).toList();
    for (final keyword in keywords) {
      for (var i = 0; i < normalized.length; i++) {
        if (normalized[i] == keyword) return i;
      }
    }
    for (final keyword in keywords) {
      for (var i = 0; i < normalized.length; i++) {
        if (normalized[i].contains(keyword)) return i;
      }
    }
    return -1;
  }

  /// Runs on a background isolate.
  static _AnalysisOutcome _parseAndFilter(_AnalysisRequest request) {
    var delimiter = request.isTabSeparated ? '\t' : ',';
    if (!request.isTabSeparated && !request.fileName.toLowerCase().endsWith('.csv')) {
      delimiter = request.content.contains('\t') ? '\t' : ',';
    }

    // `CsvToListConverter` defaults to CRLF. A Unix-formatted export - the
    // normal output of R, Bioconductor and most command-line pipelines - then
    // parses as one enormous single row, and every data line is lost.
    final eol = _detectEol(request.content);

    late final List<List<dynamic>> rows;
    try {
      rows = CsvToListConverter(shouldParseNumbers: true, eol: eol)
          .convert(request.content, fieldDelimiter: delimiter);
    } catch (error) {
      return _AnalysisOutcome.failure(
        'The file could not be parsed as ${delimiter == '\t' ? 'TSV' : 'CSV'}.',
      );
    }

    if (rows.isEmpty) {
      return const _AnalysisOutcome.failure('The file is empty.');
    }

    final headers = rows.first;
    final symbolIdx = findColumn(headers, _symbolKeywords);
    final log2fcIdx = findColumn(headers, _log2fcKeywords);
    final rawPIdx = findColumn(headers, _pValueKeywords);
    final adjustedPIdx = findColumn(headers, _adjustedPKeywords);
    final directionIdx = findColumn(headers, _directionKeywords);

    if (symbolIdx == -1 || log2fcIdx == -1) {
      final found = headers.map((h) => h.toString()).take(8).join(', ');
      return _AnalysisOutcome.failure(
        'Could not find a gene symbol column and a log2 fold change column. '
        'Headers found: $found',
      );
    }

    final symbols = <String>[];
    final log2fcs = <double>[];
    final rawPValues = <double>[];
    final suppliedAdjusted = <double?>[];
    final directions = <String>[];
    var rowsSkipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= symbolIdx || row.length <= log2fcIdx) {
        rowsSkipped++;
        continue;
      }

      final symbol = row[symbolIdx]
          ?.toString()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim()
          .toUpperCase();
      if (symbol == null || symbol.isEmpty || symbol == 'NA' || symbol == 'NULL') {
        rowsSkipped++;
        continue;
      }

      // A row whose fold change cannot be read is unusable data, not a
      // fold change of zero. The previous implementation defaulted it to 0.0
      // and a p-value of 1.0, silently converting malformed rows into valid
      // non-significant genes.
      final log2fc = _parseNumber(row[log2fcIdx]);
      if (log2fc == null) {
        rowsSkipped++;
        continue;
      }

      final rawP = rawPIdx == -1 ? null : _parseNumber(row[rawPIdx]);
      final adjustedP =
          adjustedPIdx == -1 ? null : _parseNumber(row[adjustedPIdx]);

      // A significance threshold cannot be applied to a row with no p-value.
      if (rawP == null && adjustedP == null) {
        rowsSkipped++;
        continue;
      }

      symbols.add(symbol);
      log2fcs.add(log2fc);
      rawPValues.add(rawP ?? adjustedP!);
      suppliedAdjusted.add(adjustedP);
      directions.add(directionIdx == -1 || row.length <= directionIdx
          ? ''
          : row[directionIdx]?.toString().trim() ?? '');
    }

    final total = symbols.length;
    if (total == 0) {
      return const _AnalysisOutcome.failure(
        'No usable rows found. Every row was missing a gene symbol, a fold '
        'change, or a p-value.',
      );
    }

    // If the file already carries adjusted p-values for every row, respect
    // them rather than re-correcting an already-corrected column.
    final fileHasAdjusted = suppliedAdjusted.every((value) => value != null);
    final useFdr = request.applyFdr && !fileHasAdjusted;

    final List<double> effectiveP;
    if (fileHasAdjusted) {
      effectiveP = suppliedAdjusted.map((value) => value!).toList();
    } else if (useFdr) {
      effectiveP = benjaminiHochberg(rawPValues);
    } else {
      effectiveP = rawPValues;
    }

    final passing = <int>[];
    for (var i = 0; i < total; i++) {
      if (effectiveP[i] <= request.pValueThreshold &&
          log2fcs[i].abs() >= request.minLog2FC) {
        passing.add(i);
      }
    }

    final up = passing.where((i) => log2fcs[i] > 0).toList()
      ..sort((a, b) => log2fcs[b].abs().compareTo(log2fcs[a].abs()));
    final down = passing.where((i) => log2fcs[i] < 0).toList()
      ..sort((a, b) => log2fcs[b].abs().compareTo(log2fcs[a].abs()));

    final genes = <SignificantGene>[];
    void take(List<int> indices, int count, String type) {
      final limit = count.clamp(0, indices.length);
      for (var k = 0; k < limit; k++) {
        final i = indices[k];
        genes.add(SignificantGene(
          symbol: symbols[i],
          type: type,
          log2fc: log2fcs[i],
          pValue: rawPValues[i],
          adjustedPValue:
              fileHasAdjusted || useFdr ? effectiveP[i] : null,
          higherExpressionIn: directions[i],
        ));
      }
    }

    take(up, request.upCount, 'Upregulated');
    take(down, request.downCount, 'Downregulated');

    return _AnalysisOutcome(
      genes: genes,
      genesInFile: total,
      genesPassingFilters: passing.length,
      rowsSkipped: rowsSkipped,
      usedFdrCorrection: fileHasAdjusted || useFdr,
    );
  }

  /// Line ending used by [content]: CRLF for Windows exports, LF otherwise.
  static String _detectEol(String content) =>
      content.contains('\r\n') ? '\r\n' : '\n';

  static double? _parseNumber(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return value.isFinite ? value.toDouble() : null;
    }
    final text = value.toString().trim().replaceAll('"', '');
    if (text.isEmpty ||
        text == 'NA' ||
        text == 'NaN' ||
        text == 'NULL' ||
        text == '-') {
      return null;
    }
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }
}

/// Isolate payload.
@immutable
class _AnalysisRequest {
  const _AnalysisRequest({
    required this.content,
    required this.fileName,
    required this.isTabSeparated,
    required this.upCount,
    required this.downCount,
    required this.pValueThreshold,
    required this.minLog2FC,
    required this.applyFdr,
  });

  final String content;
  final String fileName;
  final bool isTabSeparated;
  final int upCount;
  final int downCount;
  final double pValueThreshold;
  final double minLog2FC;
  final bool applyFdr;
}

/// Isolate result. Errors are returned rather than thrown so the message
/// crosses the isolate boundary intact.
@immutable
class _AnalysisOutcome {
  const _AnalysisOutcome({
    required this.genes,
    required this.genesInFile,
    required this.genesPassingFilters,
    required this.rowsSkipped,
    required this.usedFdrCorrection,
  }) : errorMessage = null;

  const _AnalysisOutcome.failure(String message)
      : genes = const [],
        genesInFile = 0,
        genesPassingFilters = 0,
        rowsSkipped = 0,
        usedFdrCorrection = false,
        errorMessage = message;

  final List<SignificantGene> genes;
  final int genesInFile;
  final int genesPassingFilters;
  final int rowsSkipped;
  final bool usedFdrCorrection;
  final String? errorMessage;
}
