import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/oncology_data.dart';
import '../models/cancer_signature.dart';

class DataService {
  static const String _dataPath = 'assets/oncology_data.json';
  static const String _signaturesPath = 'assets/data/tcga_signatures.json';

  Future<OncologyData> loadOncologyData() async {
    try {
      final String jsonString = await rootBundle.loadString(_dataPath);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return OncologyData.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to load oncology data: $e');
    }
  }

  Future<List<CancerSignature>> loadCancerSignatures() async {
    try {
      final String jsonString = await rootBundle.loadString(_signaturesPath);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => CancerSignature.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load cancer signatures: $e');
    }
  }
}
