import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/cancer_signature.dart';

class LabStorageService {
  static const String _subDir = 'lab_studies';

  static Future<String> get _labPath async {
    Directory appDir;
    try {
      appDir = await getApplicationSupportDirectory();
    } catch (_) {
      appDir = await getApplicationDocumentsDirectory();
    }
    final path = join(appDir.path, _subDir);
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  /// Saves a signature as a JSON file locally.
  static Future<void> saveStudy(CancerSignature signature) async {
    final path = await _labPath;
    // Use a timestamp or unique ID for the filename to avoid collisions
    final filename = 'study_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(join(path, filename));
    
    // We wrap it in a list to match the current JSON structure expected by DataProvider
    final jsonContent = jsonEncode([_toJson(signature)]);
    await file.writeAsString(jsonContent);
  }

  /// Loads all locally saved lab studies.
  static Future<List<CancerSignature>> loadAllStudies() async {
    final path = await _labPath;
    final dir = Directory(path);
    final List<CancerSignature> studies = [];

    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

    for (var file in files) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(content);
        studies.addAll(jsonData.map((i) => CancerSignature.fromJson(i)).toList());
      } catch (e) {
        debugPrint("Error loading lab study ${file.path}: $e");
      }
    }
    return studies;
  }

  /// Deletes a specific study file.
  static Future<void> deleteStudy(String name) async {
    final path = await _labPath;
    final dir = Directory(path);
    final files = dir.listSync().whereType<File>();
    
    for (var file in files) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(content);
        if (jsonData.isNotEmpty && jsonData[0]['cancer_name'] == name) {
          await file.delete();
          break;
        }
      } catch (_) {}
    }
  }

  // Helper because CancerSignature might not have toJson yet
  static Map<String, dynamic> _toJson(CancerSignature sig) {
    return {
      'cancer_name': sig.cancerName,
      'pmid': sig.pmid,
      'sample_size': sig.sampleSize,
      'significant_genes': sig.significantGenes.map((g) => {
        'symbol': g.symbol,
        'frequency': g.frequency,
        'type': g.type,
        'p_value': g.pValue,
        'log2fc': g.log2fc,
        'higher_expression_in': g.higherExpressionIn,
      }).toList(),
    };
  }
}
