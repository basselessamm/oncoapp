import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/cancer_signature.dart';
import 'package:onco_repurpose_ai/services/study_analysis_service.dart';

/// Tests for the only genuine statistical code in the app.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onco_analysis_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> writeFile(String name, String content) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content);
    return file;
  }

  Future<CancerSignature> analyze(
    File file, {
    AnalysisConfig config = const AnalysisConfig(),
  }) {
    return StudyAnalysisService.analyzeStudy(
      file: file,
      studyName: 'Test study',
      pmid: '12345',
      sampleSize: 42,
      config: config,
    );
  }

  group('benjaminiHochberg', () {
    test('returns an empty list for no input', () {
      expect(StudyAnalysisService.benjaminiHochberg([]), isEmpty);
    });

    test('scales each p-value by n/rank', () {
      // n = 4. Ranks 1..4 for [0.01, 0.02, 0.03, 0.04].
      // Raw scaling: 0.04, 0.04, 0.04, 0.04 -> already monotone.
      final adjusted =
          StudyAnalysisService.benjaminiHochberg([0.01, 0.02, 0.03, 0.04]);
      expect(adjusted, hasLength(4));
      for (final value in adjusted) {
        expect(value, closeTo(0.04, 1e-12));
      }
    });

    test('enforces monotonicity so a later rank cannot fall below an earlier '
        'one', () {
      // n = 3, sorted [0.001, 0.9, 0.95].
      // Rank 3: 0.95 * 3/3 = 0.95
      // Rank 2: 0.9  * 3/2 = 1.35 -> clamped by monotonicity to 0.95
      // Rank 1: 0.001 * 3/1 = 0.003
      final adjusted =
          StudyAnalysisService.benjaminiHochberg([0.001, 0.9, 0.95]);
      expect(adjusted[0], closeTo(0.003, 1e-12));
      expect(adjusted[1], closeTo(0.95, 1e-12));
      expect(adjusted[2], closeTo(0.95, 1e-12));
    });

    test('never exceeds 1.0', () {
      final adjusted =
          StudyAnalysisService.benjaminiHochberg([0.5, 0.8, 0.99]);
      expect(adjusted.every((value) => value <= 1.0), isTrue);
    });

    test('preserves input order rather than sorted order', () {
      final adjusted =
          StudyAnalysisService.benjaminiHochberg([0.9, 0.001, 0.5]);
      // The smallest raw p-value sits at index 1 and must stay there.
      expect(adjusted[1], lessThan(adjusted[0]));
      expect(adjusted[1], lessThan(adjusted[2]));
    });

    test('matches R p.adjust(method="BH") on a known vector', () {
      // R: p.adjust(c(0.001,0.008,0.039,0.041,0.042,0.06,0.074,0.205), "BH")
      //  -> 0.008 0.032 0.0672 0.0672 0.0672 0.08 0.0845714 0.205
      final adjusted = StudyAnalysisService.benjaminiHochberg(
          [0.001, 0.008, 0.039, 0.041, 0.042, 0.06, 0.074, 0.205]);
      const expected = [
        0.008,
        0.032,
        0.0672,
        0.0672,
        0.0672,
        0.08,
        0.08457142857,
        0.205,
      ];
      for (var i = 0; i < expected.length; i++) {
        expect(adjusted[i], closeTo(expected[i], 1e-9),
            reason: 'index $i');
      }
    });
  });

  group('findColumn', () {
    test('prefers an exact header match over a substring match', () {
      // 'gene' appears inside 'gene_id', but a column named exactly 'symbol'
      // is the better answer for the symbol keyword list.
      final index = StudyAnalysisService.findColumn(
        ['gene_id', 'symbol', 'log2FoldChange'],
        ['symbol', 'gene'],
      );
      expect(index, 1);
    });

    test('falls back to substring matching', () {
      final index = StudyAnalysisService.findColumn(
        ['Gene Symbol', 'log2FC'],
        ['symbol'],
      );
      expect(index, 0);
    });

    test('is case and whitespace insensitive', () {
      final index = StudyAnalysisService.findColumn(
        ['  LOG2FC  '],
        ['log2fc'],
      );
      expect(index, 0);
    });

    test('returns -1 when nothing matches', () {
      expect(
        StudyAnalysisService.findColumn(['a', 'b'], ['symbol']),
        -1,
      );
    });
  });

  group('analyzeStudy parsing', () {
    test('reads a TSV and keeps genes passing both thresholds', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'AAA\t3.0\t0.0001',
        'BBB\t-2.5\t0.0002',
        'CCC\t0.2\t0.0001', // fails the fold-change filter
        'DDD\t4.0\t0.9', // fails the significance filter
      ].join('\n'));

      final signature = await analyze(
        file,
        // FDR on four rows would inflate p-values past the cutoff; this test
        // targets the filtering logic, so correction is disabled.
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );

      expect(
        signature.significantGenes.map((gene) => gene.symbol),
        ['AAA', 'BBB'],
      );
      expect(signature.upregulatedCount, 1);
      expect(signature.downregulatedCount, 1);
      expect(signature.provenance!.genesInFile, 4);
      expect(signature.provenance!.genesPassingFilters, 2);
    });

    test('reads a CSV', () async {
      final file = await writeFile('study.csv', [
        'Gene Symbol,log2 Fold Change,P-Value',
        'AAA,3.0,0.001',
        'BBB,-3.0,0.001',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(signature.significantGenes, hasLength(2));
    });

    test('uppercases and de-quotes gene symbols', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        '"brca1"\t3.0\t0.001',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(signature.significantGenes.single.symbol, 'BRCA1');
    });

    test('parses p-values written in scientific notation', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'AAA\t5.18\t1.01e-18',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(signature.significantGenes.single.pValue, closeTo(1.01e-18, 1e-30));
    });

    test('ranks by absolute fold change and truncates to the configured '
        'counts', () async {
      final rows = <String>['symbol\tlog2FC\tp_value'];
      for (var i = 1; i <= 6; i++) {
        rows.add('UP$i\t${i + 1}.0\t0.001');
        rows.add('DOWN$i\t-${i + 1}.0\t0.001');
      }
      final file = await writeFile('study.tsv', rows.join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          upCount: 2,
          downCount: 3,
          correction: MultipleTestingCorrection.none,
        ),
      );

      final symbols =
          signature.significantGenes.map((gene) => gene.symbol).toList();
      // Strongest first within each direction.
      expect(symbols, ['UP6', 'UP5', 'DOWN6', 'DOWN5', 'DOWN4']);
    });

    test('defaults to symmetric up and down counts', () {
      const config = AnalysisConfig();
      expect(config.upCount, config.downCount);
    });
  });

  group('analyzeStudy correction behaviour', () {
    test('applies FDR correction by default and records it', () async {
      // 100 genes with p-values spread evenly over 0.01..1.00. For rank i the
      // BH factor is n/i, so every adjusted value is (i/100) * (100/i) = 1.0
      // and nothing survives a 0.05 cutoff. Without correction the five genes
      // at p <= 0.05 pass. Identical p-values would make BH a no-op, so the
      // spread matters here.
      final rows = <String>['symbol\tlog2FC\tp_value'];
      for (var i = 1; i <= 100; i++) {
        rows.add('G$i\t3.0\t${i / 100}');
      }
      final file = await writeFile('study.tsv', rows.join('\n'));

      final corrected = await analyze(file);
      expect(corrected.provenance!.usedFdrCorrection, isTrue);
      expect(corrected.provenance!.genesInFile, 100);
      expect(corrected.significantGenes, isEmpty);

      final uncorrected = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(uncorrected.provenance!.usedFdrCorrection, isFalse);
      expect(uncorrected.provenance!.genesPassingFilters, 5);
      expect(
        uncorrected.significantGenes.map((gene) => gene.symbol),
        ['G1', 'G2', 'G3', 'G4', 'G5'],
      );
    });

    test('respects an adjusted p-value column instead of re-correcting it',
        () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value\tpadj',
        'AAA\t3.0\t0.0001\t0.01',
        'BBB\t3.0\t0.0002\t0.30',
      ].join('\n'));

      final signature = await analyze(file);

      expect(signature.provenance!.usedFdrCorrection, isTrue);
      // BBB fails on its supplied adjusted p-value of 0.30.
      expect(
        signature.significantGenes.map((gene) => gene.symbol),
        ['AAA'],
      );
      final gene = signature.significantGenes.single;
      expect(gene.pValue, closeTo(0.0001, 1e-12));
      expect(gene.adjustedPValue, closeTo(0.01, 1e-12));
    });
  });

  group('analyzeStudy malformed input', () {
    test('skips rows with an unparseable fold change instead of treating them '
        'as zero', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'GOOD\t3.0\t0.001',
        'BAD\tNA\t0.001',
        'ALSOBAD\t\t0.001',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );

      expect(signature.significantGenes.map((gene) => gene.symbol), ['GOOD']);
      expect(signature.provenance!.rowsSkipped, 2);
      expect(signature.provenance!.genesInFile, 1);
    });

    test('skips rows with no p-value at all', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'GOOD\t3.0\t0.001',
        'NOP\t4.0\tNA',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(signature.significantGenes.map((gene) => gene.symbol), ['GOOD']);
      expect(signature.provenance!.rowsSkipped, 1);
    });

    test('skips rows with a blank or placeholder gene symbol', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'GOOD\t3.0\t0.001',
        '\t3.0\t0.001',
        'NULL\t3.0\t0.001',
      ].join('\n'));

      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      expect(signature.significantGenes.map((gene) => gene.symbol), ['GOOD']);
      expect(signature.provenance!.rowsSkipped, 2);
    });

    test('throws a descriptive error when the fold-change column is missing',
        () async {
      final file = await writeFile('study.tsv', [
        'symbol\tp_value',
        'AAA\t0.001',
      ].join('\n'));

      await expectLater(
        analyze(file),
        throwsA(isA<StudyAnalysisException>().having(
          (error) => error.message,
          'message',
          contains('log2 fold change'),
        )),
      );
    });

    test('throws when the file is empty', () async {
      final file = await writeFile('study.tsv', '');
      await expectLater(
        analyze(file),
        throwsA(isA<StudyAnalysisException>()),
      );
    });

    test('throws when no row is usable', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value',
        'AAA\tNA\tNA',
      ].join('\n'));

      await expectLater(
        analyze(file),
        throwsA(isA<StudyAnalysisException>().having(
          (error) => error.message,
          'message',
          contains('No usable rows'),
        )),
      );
    });

    test('throws when the file does not exist', () async {
      final missing =
          File('${tempDir.path}${Platform.pathSeparator}absent.tsv');
      await expectLater(
        analyze(missing),
        throwsA(isA<StudyAnalysisException>()),
      );
    });
  });

  group('provenance', () {
    test('records the file name, thresholds and timing', () async {
      final file = await writeFile('my_study.tsv', [
        'symbol\tlog2FC\tp_value',
        'AAA\t3.0\t0.001',
      ].join('\n'));

      final before = DateTime.now();
      final signature = await analyze(
        file,
        config: const AnalysisConfig(
          pValueThreshold: 0.01,
          minLog2FC: 2.0,
          correction: MultipleTestingCorrection.none,
        ),
      );
      final provenance = signature.provenance!;

      expect(provenance.sourceFileName, 'my_study.tsv');
      expect(provenance.pValueThreshold, 0.01);
      expect(provenance.minLog2FC, 2.0);
      expect(
        provenance.analyzedAt.isBefore(before.subtract(const Duration(
          seconds: 1,
        ))),
        isFalse,
      );
    });

    test('survives a JSON round trip', () async {
      final file = await writeFile('study.tsv', [
        'symbol\tlog2FC\tp_value\thigher expression in',
        'AAA\t3.0\t0.001\tGroup A',
        'BBB\t-3.0\t0.002\tGroup B',
      ].join('\n'));

      final original = await analyze(
        file,
        config: const AnalysisConfig(
          correction: MultipleTestingCorrection.none,
        ),
      );
      final restored = CancerSignature.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.cancerName, original.cancerName);
      expect(restored.pmid, original.pmid);
      expect(restored.sampleSize, original.sampleSize);
      expect(restored.significantGenes, hasLength(2));
      expect(restored.significantGenes.first.symbol, 'AAA');
      expect(restored.significantGenes.first.higherExpressionIn, 'Group A');
      expect(restored.significantGenes.first.log2fc,
          original.significantGenes.first.log2fc);
      expect(restored.provenance!.sourceFileName, 'study.tsv');
      expect(restored.provenance!.rowsSkipped, 0);
    });
  });
}
