import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/drug_interaction.dart';

/// Thrown when the bundled drug database cannot be prepared or queried.
///
/// Callers should surface [message] to the user; the previous implementation
/// let raw sqflite exceptions escape into an empty result list, which the UI
/// then rendered as "no results found".
class DrugDatabaseException implements Exception {
  DrugDatabaseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DrugDatabaseException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Read-only access to the bundled DGIdb-derived gene-drug interaction
/// database.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  static Database? _database;
  static Future<Database>? _opening;

  /// Injects an already-open database, bypassing the asset copy.
  ///
  /// Used by tests to run the real SQL against a small in-memory fixture, so
  /// the aggregation and placeholder-exclusion logic is covered without
  /// shipping the 12 MB asset into the test environment.
  @visibleForTesting
  static set databaseOverride(Database? database) {
    _database = database;
    _opening = null;
  }

  /// Bumped whenever `assets/db/master_drugs.db` is rebuilt.
  ///
  /// The asset is copied to disk on first launch. Without a version marker the
  /// copy is permanent, so a rebuilt asset would never reach an existing
  /// install. The on-disk file is re-copied whenever this value is higher than
  /// the `user_version` recorded in it.
  static const int assetDatabaseVersion = 1;

  /// Maximum number of `?` placeholders bound in a single statement.
  ///
  /// SQLite's `SQLITE_MAX_VARIABLE_NUMBER` defaults to 999 on older builds.
  /// Signatures can carry far more genes than that - the bundled
  /// `basal_vs_normal_unfiltered.json` holds 19,499 - so gene lists are split
  /// into chunks of this size.
  @visibleForTesting
  static const int maxParametersPerQuery = 500;

  static const String _assetPath = 'assets/db/master_drugs.db';
  static const String _fileName = 'master_drugs.db';

  /// Placeholder rows to exclude from every query.
  ///
  /// The import used the four-character string `'NULL'` as a missing marker
  /// instead of SQL `NULL`, leaving 10,572 rows with no drug name and 8,177
  /// with no gene. They are not results and were previously shown as if they
  /// were.
  static const String _excludePlaceholders =
      "i.gene <> 'NULL' AND i.drug <> 'NULL' "
      "AND TRIM(i.gene) <> '' AND TRIM(i.drug) <> ''";

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    // Concurrent callers must await the same open, or the asset copy races.
    return _opening ??= _initDatabase().then((db) {
      _database = db;
      _opening = null;
      return db;
    }, onError: (Object error, StackTrace stack) {
      _opening = null;
      throw error;
    });
  }

  Future<Database> _initDatabase() async {
    try {
      Directory appDir;
      try {
        appDir = await getApplicationSupportDirectory();
      } catch (_) {
        appDir = await getApplicationDocumentsDirectory();
      }

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      final path = join(appDir.path, _fileName);
      final dbFile = File(path);

      var needsCopy = !await dbFile.exists();
      if (!needsCopy) {
        needsCopy = await _isStale(path);
      }

      if (needsCopy) {
        final ByteData data = await rootBundle.load(_assetPath);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        // Write to a temp file first so an interrupted copy cannot leave a
        // truncated database in place.
        final temp = File('$path.tmp');
        await temp.writeAsBytes(bytes, flush: true);
        if (await dbFile.exists()) await dbFile.delete();
        await temp.rename(path);
      }

      final db = await openDatabase(path, readOnly: false);

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_gene ON drug_interactions(gene)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_drug ON drug_interactions(drug)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_is_novel ON drug_interactions(is_novel)');

      if (needsCopy) {
        await db.execute('PRAGMA user_version = $assetDatabaseVersion');
      }

      return db;
    } on DrugDatabaseException {
      rethrow;
    } catch (error) {
      throw DrugDatabaseException(
        'Could not prepare the drug database. Reinstalling the app will '
        'restore it.',
        error,
      );
    }
  }

  /// Whether the on-disk copy predates [assetDatabaseVersion] or is unreadable.
  Future<bool> _isStale(String path) async {
    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true);
      final result = await probe.rawQuery('PRAGMA user_version');
      final version = Sqflite.firstIntValue(result) ?? 0;
      return version < assetDatabaseVersion;
    } catch (_) {
      // Unreadable or corrupt: replace it.
      return true;
    } finally {
      await probe?.close();
    }
  }

  /// Interactions reported for any of [genes].
  ///
  /// Results are grouped by (gene, drug) and aggregated across source
  /// databases. Each row therefore represents one gene-drug relationship, not
  /// one database record.
  ///
  /// [onlyUnapproved] keeps only drugs that no source database marks as
  /// approved. Note this means "not FDA-approved" - it includes
  /// investigational and abandoned compounds and is not a novelty judgement.
  ///
  /// [minScore] filters on the DGIdb interaction score, which measures how well
  /// documented an interaction is. [minSourceCount] filters on the number of
  /// independent databases reporting the pair, which is the stronger signal:
  /// only 9.2% of pairs are reported by two or more.
  ///
  /// Throws [DrugDatabaseException] on failure.
  Future<List<DrugInteraction>> getDrugsForGenes(
    List<String> genes, {
    bool onlyUnapproved = false,
    double minScore = 0.0,
    int minSourceCount = 1,
  }) async {
    final normalized = normalizeGenes(genes);
    if (normalized.isEmpty) return const [];

    final db = await database;
    final results = <DrugInteraction>[];

    try {
      for (final chunk in _chunk(normalized, maxParametersPerQuery)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final arguments = <Object?>[...chunk, minScore, minSourceCount];

        // `is_novel` is a property of the drug, not of one gene-drug row: 98
        // drugs carry conflicting flags across sources. The correlated
        // subquery resolves approval once per drug so a drug is never labelled
        // unapproved merely because the source reporting this gene lacked the
        // record.
        final rows = await db.rawQuery('''
          SELECT
            i.gene AS gene,
            i.drug AS drug,
            GROUP_CONCAT(DISTINCT NULLIF(TRIM(i.interaction), 'NULL'))
              AS interaction_types,
            GROUP_CONCAT(DISTINCT i.source) AS sources,
            MAX(i.score) AS score,
            (SELECT MIN(a.is_novel) FROM drug_interactions a
               WHERE a.drug = i.drug) AS is_novel
          FROM drug_interactions i
          WHERE i.gene IN ($placeholders)
            AND $_excludePlaceholders
          GROUP BY i.gene, i.drug
          HAVING MAX(i.score) >= ?
             AND COUNT(DISTINCT i.source) >= ?
        ''', arguments);

        results.addAll(rows.map(DrugInteraction.fromMap));
      }
    } catch (error) {
      throw DrugDatabaseException(
        'The drug database query failed. Try a smaller gene set.',
        error,
      );
    }

    // Chunking splits by gene and grouping is per (gene, drug), so chunks
    // cannot overlap; ordering is applied once over the merged result.
    if (onlyUnapproved) {
      results.removeWhere((interaction) => interaction.isApproved);
    }
    results.sort((a, b) {
      final byCorroboration = b.sourceCount.compareTo(a.sourceCount);
      if (byCorroboration != 0) return byCorroboration;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.drug.compareTo(b.drug);
    });
    return results;
  }

  /// Drugs whose name contains [query], one row per drug.
  ///
  /// Unlike [getDrugsForGenes] this aggregates across *all* genes a drug
  /// touches, so [DrugInteraction.targetCount] is populated and [
  /// DrugInteraction.gene] carries the single best-documented target. A drug
  /// hitting 141 genes is a promiscuity warning, not 141 separate findings.
  ///
  /// Approved and unapproved drugs are both returned. The previous
  /// implementation silently restricted this to `is_novel = 1`, so searching
  /// "Cisplatin" or "Aspirin" returned nothing or unrelated derivatives.
  ///
  /// Throws [DrugDatabaseException] on failure.
  Future<List<DrugInteraction>> searchDrugsByName(
    String query, {
    int limit = 50,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];

    final db = await database;

    try {
      final rows = await db.rawQuery('''
        SELECT
          (SELECT t.gene FROM drug_interactions t
             WHERE t.drug = i.drug AND t.gene <> 'NULL'
             ORDER BY t.score DESC, t.gene ASC LIMIT 1) AS gene,
          i.drug AS drug,
          GROUP_CONCAT(DISTINCT NULLIF(TRIM(i.interaction), 'NULL'))
            AS interaction_types,
          GROUP_CONCAT(DISTINCT i.source) AS sources,
          MAX(i.score) AS score,
          MIN(i.is_novel) AS is_novel,
          COUNT(DISTINCT i.gene) AS target_count
        FROM drug_interactions i
        WHERE i.drug LIKE ? ESCAPE '\\'
          AND $_excludePlaceholders
        GROUP BY i.drug
        ORDER BY score DESC, target_count DESC, i.drug ASC
        LIMIT ?
      ''', ['%${escapeLike(term)}%', limit]);

      return rows.map(DrugInteraction.fromMap).toList();
    } catch (error) {
      throw DrugDatabaseException('The drug search failed.', error);
    }
  }

  /// Uppercases, trims and de-duplicates gene symbols, dropping the `'NULL'`
  /// placeholder so a pasted export cannot query for it.
  @visibleForTesting
  static List<String> normalizeGenes(List<String> genes) {
    final seen = <String>{};
    for (final gene in genes) {
      final symbol = gene.trim().toUpperCase();
      if (symbol.isEmpty || symbol == 'NULL') continue;
      seen.add(symbol);
    }
    return seen.toList();
  }

  /// Escapes `LIKE` wildcards so a user searching `50%` does not match
  /// everything.
  @visibleForTesting
  static String escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static Iterable<List<T>> _chunk<T>(List<T> items, int size) sync* {
    for (var start = 0; start < items.length; start += size) {
      final end = start + size;
      yield items.sublist(start, end > items.length ? items.length : end);
    }
  }
}
