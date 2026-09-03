import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cancer_signature.dart';

/// Thrown when a saved study cannot be written, read, or removed.
class LabStorageException implements Exception {
  LabStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'LabStorageException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Persists user-derived signatures as JSON files in the app's support
/// directory.
class LabStorageService {
  const LabStorageService._();

  static const String _subDir = 'lab_studies';

  static Future<Directory> _labDirectory() async {
    Directory appDir;
    try {
      appDir = await getApplicationSupportDirectory();
    } catch (_) {
      appDir = await getApplicationDocumentsDirectory();
    }
    final dir = Directory(join(appDir.path, _subDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// File name for a study, derived from its stable id.
  ///
  /// Studies were previously written under a timestamp and located by matching
  /// `cancer_name`, so deleting one of two identically named studies removed
  /// whichever the directory listing happened to yield first.
  static String _fileNameFor(String id) {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'study_$safe.json';
  }

  /// Writes [signature] to disk, replacing any study with the same id.
  static Future<void> saveStudy(CancerSignature signature) async {
    try {
      final dir = await _labDirectory();
      final file = File(join(dir.path, _fileNameFor(signature.id)));
      // A single object, not a list: the list wrapper only existed to mimic the
      // bundled asset shape.
      await file.writeAsString(jsonEncode(signature.toJson()), flush: true);
    } catch (error) {
      throw LabStorageException('Could not save the study to disk.', error);
    }
  }

  /// Loads every saved study, skipping any file that fails to parse.
  static Future<List<CancerSignature>> loadAllStudies() async {
    final dir = await _labDirectory();

    // Async listing: the previous `listSync()` blocked the UI isolate.
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final studies = <CancerSignature>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        // Accept both the current single-object format and the legacy
        // single-element list written by earlier versions.
        final map = decoded is List
            ? (decoded.isEmpty ? null : decoded.first as Map<String, dynamic>)
            : decoded as Map<String, dynamic>;
        if (map == null) continue;
        studies.add(CancerSignature.fromJson(map));
      } catch (error) {
        debugPrint('Skipping unreadable lab study ${file.path}: $error');
      }
    }
    return studies;
  }

  /// Deletes the study with the given [id].
  static Future<void> deleteStudy(String id) async {
    try {
      final dir = await _labDirectory();
      final file = File(join(dir.path, _fileNameFor(id)));
      if (await file.exists()) {
        await file.delete();
        return;
      }
      // Legacy files were named by timestamp; fall back to a content scan so
      // studies saved by an earlier version can still be removed.
      await _deleteLegacyStudy(dir, id);
    } catch (error) {
      throw LabStorageException('Could not delete the study.', error);
    }
  }

  static Future<void> _deleteLegacyStudy(Directory dir, String id) async {
    final entities = await dir.list().toList();
    for (final file in entities.whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await file.readAsString());
        final map = decoded is List
            ? (decoded.isEmpty ? null : decoded.first as Map<String, dynamic>)
            : decoded as Map<String, dynamic>;
        if (map == null) continue;
        final fileId = map['id']?.toString() ?? map['cancer_name']?.toString();
        if (fileId == id) {
          await file.delete();
          return;
        }
      } catch (error) {
        debugPrint('Skipping unreadable lab study ${file.path}: $error');
      }
    }
  }
}
