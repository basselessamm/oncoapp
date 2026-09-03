import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';

void main() {
  late Directory tempDir;
  late ResponseCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onco_cache_test');
    cache = ResponseCache(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Writes an entry with a back-dated timestamp, to exercise the freshness and
  /// retention windows without waiting.
  Future<void> writeAged(String key, String body, Duration age) async {
    final file =
        File('${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor(key)}');
    await file.writeAsString(jsonEncode({
      'key': key,
      'retrieved_at':
          DateTime.now().subtract(age).toIso8601String(),
      'body': body,
    }));
  }

  group('fileNameFor', () {
    test('produces a fixed-length filename regardless of key length', () {
      final short = ResponseCache.fileNameFor('a');
      final long = ResponseCache.fileNameFor('x' * 10000);
      expect(short, matches(RegExp(r'^[0-9a-f]{16}\.json$')));
      expect(long, matches(RegExp(r'^[0-9a-f]{16}\.json$')));
    });

    test('is stable across calls', () {
      expect(ResponseCache.fileNameFor('query|vars'),
          ResponseCache.fileNameFor('query|vars'));
    });

    test('differs for keys that differ only at the end', () {
      // Sanitising a long key would truncate and collide here.
      final a = ResponseCache.fileNameFor('${'x' * 5000}A');
      final b = ResponseCache.fileNameFor('${'x' * 5000}B');
      expect(a, isNot(b));
    });

    test('contains no path separators or query characters', () {
      final name = ResponseCache.fileNameFor('https://x/y?z={"a":1}');
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('\\')));
      expect(name, isNot(contains('?')));
      expect(name, isNot(contains(':')));
    });
  });

  group('read and write', () {
    test('returns null for a key never written', () async {
      expect(await cache.read('absent'), isNull);
    });

    test('round-trips a body', () async {
      await cache.write('k', '{"hello":"world"}');
      final entry = await cache.read('k');

      expect(entry, isNotNull);
      expect(entry!.body, '{"hello":"world"}');
      expect(entry.isFresh, isTrue);
      expect(entry.age, lessThan(const Duration(seconds: 5)));
    });

    test('overwrites an existing entry', () async {
      await cache.write('k', 'first');
      await cache.write('k', 'second');
      expect((await cache.read('k'))!.body, 'second');
    });

    test('keeps distinct keys separate', () async {
      await cache.write('a', 'A');
      await cache.write('b', 'B');
      expect((await cache.read('a'))!.body, 'A');
      expect((await cache.read('b'))!.body, 'B');
    });

    test('leaves no temporary files behind', () async {
      await cache.write('k', 'body');
      final leftovers = (await tempDir.list().toList())
          .where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });
  });

  group('freshness window', () {
    test('an entry inside freshFor is fresh', () async {
      final c = ResponseCache(
        directoryOverride: tempDir,
        freshFor: const Duration(hours: 12),
      );
      await writeAged('k', 'body', const Duration(hours: 1));

      final entry = await c.read('k');
      expect(entry!.isFresh, isTrue);
    });

    test('an entry past freshFor is retained but not fresh', () async {
      // This is the offline-copy case: still served, but the UI must label it.
      final c = ResponseCache(
        directoryOverride: tempDir,
        freshFor: const Duration(hours: 12),
        keepFor: const Duration(days: 30),
      );
      await writeAged('k', 'body', const Duration(days: 2));

      final entry = await c.read('k');
      expect(entry, isNotNull);
      expect(entry!.isFresh, isFalse);
      expect(entry.age.inDays, 2);
    });

    test('an entry past keepFor is treated as a miss and deleted', () async {
      final c = ResponseCache(
        directoryOverride: tempDir,
        keepFor: const Duration(days: 30),
      );
      await writeAged('k', 'body', const Duration(days: 31));

      expect(await c.read('k'), isNull);
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      expect(await file.exists(), isFalse);
    });

    test('reports the retrieval time so the UI can state the age', () async {
      final c = ResponseCache(directoryOverride: tempDir);
      await writeAged('k', 'body', const Duration(hours: 30));

      final entry = await c.read('k');
      expect(entry!.retrievedAt.isBefore(DateTime.now()), isTrue);
      expect(entry.age.inHours, closeTo(30, 1));
    });
  });

  group('corrupt and malformed entries', () {
    test('treats truncated JSON as a miss', () async {
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      await file.writeAsString('{"key":"k","retrieved_at":');

      expect(await cache.read('k'), isNull);
    });

    test('treats a non-object payload as a miss', () async {
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      await file.writeAsString('[1,2,3]');

      expect(await cache.read('k'), isNull);
    });

    test('treats a missing timestamp as a miss', () async {
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      await file.writeAsString(jsonEncode({'key': 'k', 'body': 'x'}));

      expect(await cache.read('k'), isNull);
    });

    test('rejects an entry whose stored key does not match', () async {
      // A hash collision must read as a miss rather than return another
      // request's payload.
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      await file.writeAsString(jsonEncode({
        'key': 'a-different-key',
        'retrieved_at': DateTime.now().toIso8601String(),
        'body': 'someone elses data',
      }));

      expect(await cache.read('k'), isNull);
    });

    test('deletes a corrupt entry so it is not re-read every launch', () async {
      final file = File(
          '${tempDir.path}${Platform.pathSeparator}${ResponseCache.fileNameFor('k')}');
      await file.writeAsString('not json at all');

      await cache.read('k');
      expect(await file.exists(), isFalse);
    });
  });

  group('eviction', () {
    test('caps the number of stored entries', () async {
      final c = ResponseCache(directoryOverride: tempDir, maxEntries: 5);
      for (var i = 0; i < 12; i++) {
        await c.write('key$i', 'body$i');
      }

      final stats = await c.stats();
      expect(stats.entries, lessThanOrEqualTo(5));
    });

    test('evicts the oldest entries first', () async {
      final c = ResponseCache(directoryOverride: tempDir, maxEntries: 3);
      // Ages are set explicitly rather than relying on write order, so the test
      // does not depend on filesystem timestamp granularity.
      await writeAged('old0', 'body', const Duration(hours: 5));
      await writeAged('old1', 'body', const Duration(hours: 4));
      await writeAged('old2', 'body', const Duration(hours: 3));
      await c.write('newest', 'body');

      expect((await c.stats()).entries, 3);
      expect(await c.read('newest'), isNotNull);
      expect(await c.read('old0'), isNull, reason: 'oldest must go first');
      expect(await c.read('old2'), isNotNull);
    });
  });

  group('clear and stats', () {
    test('reports an empty cache', () async {
      final stats = await cache.stats();
      expect(stats.entries, 0);
      expect(stats.isEmpty, isTrue);
    });

    test('counts entries and bytes', () async {
      await cache.write('a', 'x' * 100);
      await cache.write('b', 'y' * 100);

      final stats = await cache.stats();
      expect(stats.entries, 2);
      expect(stats.bytes, greaterThan(200));
      expect(stats.isEmpty, isFalse);
    });

    test('formats a human-readable size', () {
      expect(const CacheStats(entries: 1, bytes: 512).sizeLabel, '512 B');
      expect(const CacheStats(entries: 1, bytes: 2048).sizeLabel, '2 KB');
      expect(
        const CacheStats(entries: 1, bytes: 3 * 1024 * 1024).sizeLabel,
        '3.0 MB',
      );
    });

    test('clear removes every entry', () async {
      await cache.write('a', 'A');
      await cache.write('b', 'B');

      await cache.clear();

      expect((await cache.stats()).entries, 0);
      expect(await cache.read('a'), isNull);
    });

    test('clear on an empty cache is a no-op', () async {
      await cache.clear();
      expect((await cache.stats()).entries, 0);
    });
  });

  group('resilience', () {
    test('creates the cache directory when absent', () async {
      final missing = Directory(
          '${tempDir.path}${Platform.pathSeparator}nested${Platform.pathSeparator}deeper');
      final c = ResponseCache(directoryOverride: missing);

      await c.write('k', 'body');
      expect((await c.read('k'))!.body, 'body');
    });

    test('a write failure does not throw', () async {
      // Pointing the cache at a path occupied by a file makes directory
      // creation fail; the app must degrade to network-only, not crash.
      final blocker =
          File('${tempDir.path}${Platform.pathSeparator}blocker');
      await blocker.writeAsString('x');
      final c = ResponseCache(directoryOverride: Directory(blocker.path));

      await expectLater(c.write('k', 'body'), completes);
      expect(await c.read('k'), isNull);
      await expectLater(c.clear(), completes);
      expect((await c.stats()).entries, 0);
    });
  });
}
