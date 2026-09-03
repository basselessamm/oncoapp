import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk cache for external API responses.
///
/// Responses are stored as individual JSON files keyed by a hash of the request,
/// each carrying the time it was retrieved. Two windows apply:
///
/// * within [freshFor], a cached entry is served without touching the network;
/// * after that but within [keepFor], the entry is only served when the network
///   is unreachable, and is labelled as an offline copy.
///
/// Beyond [keepFor] entries are deleted. Nothing is cached in memory only, so a
/// user who looked something up before a flight still has it.
class ResponseCache {
  ResponseCache({
    this.freshFor = const Duration(hours: 12),
    this.keepFor = const Duration(days: 30),
    this.maxEntries = 500,
    Directory? directoryOverride,
  }) : _directoryOverride = directoryOverride;

  /// How long a cached response is considered current.
  ///
  /// Target-disease association evidence changes on Open Targets' release
  /// schedule (roughly quarterly), so hours rather than minutes is the right
  /// order of magnitude. It is short enough that a stale entry is not silently
  /// used for a whole working session.
  final Duration freshFor;

  /// How long an expired response is kept as an offline fallback.
  final Duration keepFor;

  /// Cap on stored entries, evicted oldest-first.
  ///
  /// A gene-by-gene lookup over a 30-gene signature writes 30 entries, so a few
  /// hundred covers normal use without unbounded growth.
  final int maxEntries;

  final Directory? _directoryOverride;
  Directory? _resolved;

  static const String _subDir = 'api_cache';

  /// Cache directory, created on first use.
  Future<Directory> directory() async {
    final existing = _resolved;
    if (existing != null) return existing;

    final override = _directoryOverride;
    if (override != null) {
      if (!await override.exists()) await override.create(recursive: true);
      return _resolved = override;
    }

    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory(p.join(base.path, _subDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return _resolved = dir;
  }

  /// Filename-safe key derived from a cache key.
  ///
  /// A GraphQL cache key contains a whole query body, so it is hashed rather
  /// than sanitised: sanitising would collide on long keys differing only past
  /// the filename length limit.
  ///
  /// Two independent 32-bit FNV-1a passes are combined instead of one 64-bit
  /// pass, because Dart's `int` is signed 64-bit: a full-width FNV overflows
  /// into negative values and `toRadixString` then emits a leading `-`.
  /// Not cryptographic - this only needs to avoid accidental collisions, and
  /// [read] verifies the stored key anyway.
  @visibleForTesting
  static String fileNameFor(String key) {
    var high = 0x811c9dc5;
    var low = 0x01000193;
    for (final byte in utf8.encode(key)) {
      high = ((high ^ byte) * 0x01000193) & 0xFFFFFFFF;
      low = ((low ^ byte) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return '${high.toRadixString(16).padLeft(8, '0')}'
        '${low.toRadixString(16).padLeft(8, '0')}.json';
  }

  /// Reads a cached entry, or `null` when absent, unreadable, or past
  /// [keepFor].
  Future<CachedResponse?> read(String key) async {
    File? file;
    try {
      file = File(p.join((await directory()).path, fileNameFor(key)));
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        await _deleteQuietly(file);
        return null;
      }

      final retrievedAt =
          DateTime.tryParse(decoded['retrieved_at']?.toString() ?? '');
      final body = decoded['body'];
      // A key mismatch means a hash collision; treat it as a miss rather than
      // returning another request's payload.
      final storedKey = decoded['key']?.toString();
      if (retrievedAt == null || body is! String || storedKey != key) {
        await _deleteQuietly(file);
        return null;
      }

      final age = DateTime.now().difference(retrievedAt);
      if (age > keepFor) {
        await _deleteQuietly(file);
        return null;
      }

      return CachedResponse(
        body: body,
        retrievedAt: retrievedAt,
        isFresh: age <= freshFor,
      );
    } catch (error) {
      debugPrint('Cache read failed for $key: $error');
      // An unparseable file fails identically on every launch, so remove it
      // rather than paying for the read again.
      if (file != null) await _deleteQuietly(file);
      return null;
    }
  }

  /// Stores [body] against [key].
  ///
  /// Cache failures are logged and swallowed: a full disk should degrade the
  /// app to network-only, not break the feature.
  Future<void> write(String key, String body) async {
    try {
      final dir = await directory();
      final file = File(p.join(dir.path, fileNameFor(key)));
      final payload = jsonEncode({
        'key': key,
        'retrieved_at': DateTime.now().toIso8601String(),
        'body': body,
      });
      // Write to a temporary file first so an interrupted write cannot leave
      // truncated JSON that later reads as a miss on every launch.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);

      await _evictIfNeeded(dir);
    } catch (error) {
      debugPrint('Cache write failed for $key: $error');
    }
  }

  /// Deletes every cached entry.
  ///
  /// Exposed in settings: a user who revokes consent should be able to remove
  /// what was already fetched.
  Future<void> clear() async {
    try {
      final dir = await directory();
      if (!await dir.exists()) return;
      for (final entity in await dir.list().toList()) {
        if (entity is File) await entity.delete();
      }
    } catch (error) {
      debugPrint('Cache clear failed: $error');
    }
  }

  /// Number of stored entries and their total size, for display in settings.
  Future<CacheStats> stats() async {
    try {
      final dir = await directory();
      if (!await dir.exists()) return const CacheStats(entries: 0, bytes: 0);

      var entries = 0;
      var bytes = 0;
      for (final entity in await dir.list().toList()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        entries++;
        bytes += await entity.length();
      }
      return CacheStats(entries: entries, bytes: bytes);
    } catch (error) {
      debugPrint('Cache stats failed: $error');
      return const CacheStats(entries: 0, bytes: 0);
    }
  }

  Future<void> _evictIfNeeded(Directory dir) async {
    final files = <File>[];
    for (final entity in await dir.list().toList()) {
      if (entity is File && entity.path.endsWith('.json')) files.add(entity);
    }
    if (files.length <= maxEntries) return;

    // Ordered by the timestamp inside each entry rather than by filesystem
    // mtime: writes go through a temp file and a rename, and mtime granularity
    // is coarse enough on some filesystems to make several writes look
    // simultaneous.
    final withTimes = <(File, DateTime)>[];
    for (final file in files) {
      withTimes.add((file, await _retrievedAtOf(file)));
    }
    withTimes.sort((a, b) => a.$2.compareTo(b.$2));

    for (var i = 0; i < withTimes.length - maxEntries; i++) {
      await _deleteQuietly(withTimes[i].$1);
    }
  }

  /// Timestamp recorded inside an entry, falling back to the epoch so an
  /// unreadable file is evicted first.
  Future<DateTime> _retrievedAtOf(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final parsed =
            DateTime.tryParse(decoded['retrieved_at']?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    } catch (_) {
      // Fall through.
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Another isolate may have removed it, or the path may not be a file.
    }
  }
}

/// A cached response body with its age.
class CachedResponse {
  const CachedResponse({
    required this.body,
    required this.retrievedAt,
    required this.isFresh,
  });

  final String body;
  final DateTime retrievedAt;

  /// Whether the entry is within the cache's freshness window.
  final bool isFresh;

  Duration get age => DateTime.now().difference(retrievedAt);
}

/// Cache size, for display in settings.
class CacheStats {
  const CacheStats({required this.entries, required this.bytes});

  final int entries;
  final int bytes;

  bool get isEmpty => entries == 0;

  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
