import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart';

/// Verifies the bundled signature assets load and parse.
///
/// Kept separate from the widget tests: `testWidgets` runs in a fake-async zone
/// where real asset I/O never completes, so this uses a plain `test` with the
/// asset bundle initialised.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('every declared signature asset loads and parses', () async {
    final provider = DataProvider();
    await provider.loadData();

    expect(provider.datasetStatus, LoadStatus.ready);
    expect(provider.datasets, hasLength(DataProvider.signatureAssets.length));
    expect(provider.selectedDataset, isNotNull);

    // `path_provider` has no implementation in the test host, so loading saved
    // lab studies always fails here. Any *other* warning means a bundled asset
    // is missing or malformed, which must not pass silently.
    final warning = provider.datasetError;
    if (warning != null) {
      expect(warning, 'Could not load: saved lab studies.',
          reason: 'a missing or malformed asset must be reported, not silent');
    }
  });

  test('parsed signatures carry usable genes and numeric p-values', () async {
    final provider = DataProvider();
    await provider.loadData();

    for (final signature in provider.datasets) {
      expect(signature.cancerName, isNotEmpty);
      expect(signature.significantGenes, isNotEmpty,
          reason: '${signature.cancerName} has no genes');

      for (final gene in signature.significantGenes) {
        expect(gene.symbol, isNotEmpty);
        expect(gene.symbol, gene.symbol.toUpperCase(),
            reason: 'symbols must be normalised for database matching');
      }

      // The assets store p-values as strings in scientific notation
      // ("1.01e-18"); they must arrive as numbers so they can be thresholded.
      final withPValues = signature.significantGenes
          .where((gene) => gene.pValue != null)
          .toList();
      expect(withPValues, isNotEmpty,
          reason: '${signature.cancerName} parsed no p-values');
      for (final gene in withPValues) {
        expect(gene.pValue, isA<double>());
        expect(gene.pValue, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('the active gene set is derived from the selected signature', () async {
    final provider = DataProvider();
    await provider.loadData();

    final selected = provider.selectedDataset!;
    expect(provider.activeGenes, hasLength(selected.significantGenes.length));
    expect(provider.activeGenes.first,
        selected.significantGenes.first.symbol.toUpperCase());
  });

  test('the 4.1 MB unfiltered signature is not bundled', () {
    // 19,499 unfiltered genes with no direction column. It was declared via a
    // directory glob, shipped in every build, and never loaded.
    expect(
      DataProvider.signatureAssets,
      isNot(contains(contains('basal_vs_normal_unfiltered'))),
    );
  });
}
