import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/drug_interaction.dart';
import 'package:onco_repurpose_ai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the production SQL against an in-memory fixture that reproduces the
/// bundled database's quirks: `'NULL'` string sentinels, one row per source
/// database, and approval encoded as an inverted flag.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseService service;

  /// Mirrors the schema of `assets/db/master_drugs.db`.
  Future<void> insert({
    required String gene,
    required String drug,
    String interaction = 'inhibitor',
    int isNovel = 1,
    double score = 1.0,
    String source = 'ChEMBL',
  }) {
    return db.insert('drug_interactions', {
      'gene': gene,
      'drug': drug,
      'interaction': interaction,
      'target_category': 'TARGET',
      'is_novel': isNovel,
      'score': score,
      'source': source,
      'docking_score': -5.0,
    });
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE drug_interactions (
        gene TEXT, drug TEXT, interaction TEXT, target_category TEXT,
        is_novel INTEGER, score REAL, source TEXT, docking_score REAL
      )
    ''');
    DatabaseService.databaseOverride = db;
    service = DatabaseService();
  });

  tearDown(() async {
    DatabaseService.databaseOverride = null;
    await db.close();
  });

  group('normalizeGenes', () {
    test('uppercases, trims and de-duplicates', () {
      expect(
        DatabaseService.normalizeGenes([' tp53 ', 'TP53', 'brca1']),
        ['TP53', 'BRCA1'],
      );
    });

    test("drops blanks and the 'NULL' placeholder", () {
      expect(
        DatabaseService.normalizeGenes(['', '   ', 'NULL', 'null', 'TP53']),
        ['TP53'],
      );
    });
  });

  group('escapeLike', () {
    test('escapes wildcards so they match literally', () {
      expect(DatabaseService.escapeLike('50%'), r'50\%');
      expect(DatabaseService.escapeLike('a_b'), r'a\_b');
      expect(DatabaseService.escapeLike(r'a\b'), r'a\\b');
    });
  });

  group('getDrugsForGenes', () {
    test('returns nothing for an empty or placeholder-only gene list',
        () async {
      expect(await service.getDrugsForGenes([]), isEmpty);
      expect(await service.getDrugsForGenes(['', 'NULL']), isEmpty);
    });

    test('matches genes case-insensitively via normalisation', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A');
      final results = await service.getDrugsForGenes(['tp53']);
      expect(results.map((r) => r.drug), ['DRUG_A']);
    });

    test('collapses one row per source into a single result', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A', source: 'ChEMBL');
      await insert(gene: 'TP53', drug: 'DRUG_A', source: 'TTD');
      await insert(gene: 'TP53', drug: 'DRUG_A', source: 'DTC');

      final results = await service.getDrugsForGenes(['TP53']);
      expect(results, hasLength(1));
      expect(results.single.sourceCount, 3);
      expect(results.single.sources, ['ChEMBL', 'DTC', 'TTD']);
      expect(results.single.corroboration, Corroboration.corroborated);
    });

    test('takes the highest score across sources', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A', score: 0.5, source: 'ChEMBL');
      await insert(gene: 'TP53', drug: 'DRUG_A', score: 9.5, source: 'TTD');

      final results = await service.getDrugsForGenes(['TP53']);
      expect(results.single.score, 9.5);
    });

    test('merges distinct interaction types and drops the NULL sentinel',
        () async {
      await insert(
          gene: 'TP53', drug: 'DRUG_A', interaction: 'NULL', source: 'ChEMBL');
      await insert(
          gene: 'TP53', drug: 'DRUG_A', interaction: 'blocker', source: 'TTD');
      await insert(
          gene: 'TP53',
          drug: 'DRUG_A',
          interaction: 'inhibitor',
          source: 'DTC');

      final results = await service.getDrugsForGenes(['TP53']);
      expect(results.single.interactionTypes, ['blocker', 'inhibitor']);
      expect(results.single.hasUnknownMechanism, isFalse);
    });

    test('reports an unknown mechanism when every source says NULL', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A', interaction: 'NULL');
      final results = await service.getDrugsForGenes(['TP53']);
      expect(results.single.hasUnknownMechanism, isTrue);
      expect(results.single.mechanismLabel, isNull);
    });

    test("excludes rows whose drug is the 'NULL' placeholder", () async {
      await insert(gene: 'TP53', drug: 'NULL');
      await insert(gene: 'TP53', drug: 'DRUG_A');

      final results = await service.getDrugsForGenes(['TP53']);
      expect(results.map((r) => r.drug), ['DRUG_A']);
    });

    test("excludes rows whose gene is the 'NULL' placeholder", () async {
      // Such a row cannot match a real query, but the exclusion also guards
      // the drug-level approval subquery below.
      await insert(gene: 'NULL', drug: 'DRUG_A');
      final results = await service.getDrugsForGenes(['NULL']);
      expect(results, isEmpty);
    });

    test('resolves approval per drug, not per row', () async {
      // 98 drugs in the bundled data carry conflicting flags across sources.
      // One source reporting approval is authoritative.
      await insert(
          gene: 'PTH1R', drug: 'ABALOPARATIDE', isNovel: 0, source: 'TTD');
      await insert(
          gene: 'PTH2R', drug: 'ABALOPARATIDE', isNovel: 1, source: 'TTD');

      final results = await service.getDrugsForGenes(['PTH2R']);
      expect(results.single.isApproved, isTrue,
          reason: 'approval recorded against another gene must still apply');
    });

    test('onlyUnapproved removes drugs approved by any source', () async {
      await insert(gene: 'TP53', drug: 'APPROVED_DRUG', isNovel: 0);
      await insert(gene: 'TP53', drug: 'INVESTIGATIONAL', isNovel: 1);

      final all = await service.getDrugsForGenes(['TP53']);
      expect(all, hasLength(2));

      final filtered =
          await service.getDrugsForGenes(['TP53'], onlyUnapproved: true);
      expect(filtered.map((r) => r.drug), ['INVESTIGATIONAL']);
    });

    test('minScore filters on the aggregated score', () async {
      await insert(gene: 'TP53', drug: 'LOW', score: 0.2);
      await insert(gene: 'TP53', drug: 'HIGH', score: 6.0);

      final results =
          await service.getDrugsForGenes(['TP53'], minScore: 5.0);
      expect(results.map((r) => r.drug), ['HIGH']);
    });

    test('minScore is bound as a parameter, not interpolated', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A', score: 1.0);
      // A non-finite value would break a string-interpolated SQL fragment.
      final results =
          await service.getDrugsForGenes(['TP53'], minScore: double.infinity);
      expect(results, isEmpty);
    });

    test('minSourceCount filters on corroboration', () async {
      await insert(gene: 'TP53', drug: 'SINGLE', source: 'ChEMBL');
      await insert(gene: 'TP53', drug: 'DOUBLE', source: 'ChEMBL');
      await insert(gene: 'TP53', drug: 'DOUBLE', source: 'TTD');

      final results =
          await service.getDrugsForGenes(['TP53'], minSourceCount: 2);
      expect(results.map((r) => r.drug), ['DOUBLE']);
    });

    test('returns one row per gene-drug pair when a drug hits several genes',
        () async {
      await insert(gene: 'TP53', drug: 'DRUG_A');
      await insert(gene: 'BRCA1', drug: 'DRUG_A');

      final results = await service.getDrugsForGenes(['TP53', 'BRCA1']);
      expect(results, hasLength(2));
      expect(results.map((r) => r.gene).toSet(), {'TP53', 'BRCA1'});
    });

    test('orders by corroboration, then score, then name', () async {
      await insert(gene: 'TP53', drug: 'B_HIGH_SCORE', score: 50.0);
      await insert(gene: 'TP53', drug: 'A_CORROBORATED', score: 1.0);
      await insert(
          gene: 'TP53', drug: 'A_CORROBORATED', score: 1.0, source: 'TTD');

      final results = await service.getDrugsForGenes(['TP53']);
      expect(results.map((r) => r.drug), ['A_CORROBORATED', 'B_HIGH_SCORE']);
    });

    test('chunks a gene list larger than the parameter limit', () async {
      final genes = <String>[];
      for (var i = 0; i < DatabaseService.maxParametersPerQuery + 250; i++) {
        final gene = 'GENE$i';
        genes.add(gene);
        await insert(gene: gene, drug: 'DRUG_$i');
      }

      final results = await service.getDrugsForGenes(genes);
      expect(results, hasLength(genes.length),
          reason: 'every chunk must be queried and merged');
    });

    test('does not duplicate results across chunk boundaries', () async {
      // Grouping is per (gene, drug) and chunking splits by gene, so a drug
      // shared between two chunks must still yield one row per gene.
      final genes = <String>[];
      for (var i = 0; i < DatabaseService.maxParametersPerQuery + 10; i++) {
        final gene = 'GENE$i';
        genes.add(gene);
        await insert(gene: gene, drug: 'SHARED_DRUG');
      }

      final results = await service.getDrugsForGenes(genes);
      expect(results, hasLength(genes.length));
      expect(results.map((r) => r.gene).toSet(), hasLength(genes.length));
    });
  });

  group('searchDrugsByName', () {
    test('returns nothing for a blank query', () async {
      expect(await service.searchDrugsByName(''), isEmpty);
      expect(await service.searchDrugsByName('   '), isEmpty);
    });

    test('matches on a substring, case-insensitively', () async {
      await insert(gene: 'ESR1', drug: 'TAMOXIFEN');
      final results = await service.searchDrugsByName('tamox');
      expect(results.map((r) => r.drug), ['TAMOXIFEN']);
    });

    test('includes approved drugs', () async {
      // The old query hardcoded `is_novel = 1`, so Cisplatin was unfindable.
      await insert(gene: 'CSNK2A3', drug: 'CISPLATIN', isNovel: 0);
      final results = await service.searchDrugsByName('cisplatin');
      expect(results, hasLength(1));
      expect(results.single.isApproved, isTrue);
    });

    test('reports how many genes a drug targets', () async {
      await insert(gene: 'GENE_A', drug: 'PROMISCUOUS');
      await insert(gene: 'GENE_B', drug: 'PROMISCUOUS');
      await insert(gene: 'GENE_C', drug: 'PROMISCUOUS');

      final results = await service.searchDrugsByName('promiscuous');
      expect(results, hasLength(1), reason: 'one row per drug');
      expect(results.single.targetCount, 3);
    });

    test('names the best-documented target gene', () async {
      await insert(gene: 'WEAK_TARGET', drug: 'DRUG_A', score: 0.1);
      await insert(gene: 'BEST_TARGET', drug: 'DRUG_A', score: 9.9);

      final results = await service.searchDrugsByName('drug_a');
      expect(results.single.gene, 'BEST_TARGET');
    });

    test('treats a percent sign in the query as a literal', () async {
      await insert(gene: 'TP53', drug: 'DRUG_A');
      await insert(gene: 'TP53', drug: 'DRUG 50% SOLUTION');

      final results = await service.searchDrugsByName('50%');
      expect(results.map((r) => r.drug), ['DRUG 50% SOLUTION']);
    });

    test('treats an underscore in the query as a literal', () async {
      await insert(gene: 'TP53', drug: 'AXB');
      await insert(gene: 'TP53', drug: 'A_B');

      final results = await service.searchDrugsByName('a_b');
      expect(results.map((r) => r.drug), ['A_B']);
    });

    test("excludes 'NULL' placeholder drugs from search results", () async {
      await insert(gene: 'TP53', drug: 'NULL');
      final results = await service.searchDrugsByName('NULL');
      expect(results, isEmpty);
    });

    test('respects the row limit', () async {
      for (var i = 0; i < 10; i++) {
        await insert(gene: 'TP53', drug: 'DRUG_$i');
      }
      final results = await service.searchDrugsByName('drug', limit: 4);
      expect(results, hasLength(4));
    });
  });

  group('error reporting', () {
    test('throws DrugDatabaseException when the table is missing', () async {
      await db.execute('DROP TABLE drug_interactions');

      await expectLater(
        service.getDrugsForGenes(['TP53']),
        throwsA(isA<DrugDatabaseException>()),
      );
      await expectLater(
        service.searchDrugsByName('anything'),
        throwsA(isA<DrugDatabaseException>()),
      );
    });
  });
}
