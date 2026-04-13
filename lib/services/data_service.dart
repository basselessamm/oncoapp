import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/oncology_data.dart';

class DataService {
  static const String _dataPath = 'assets/oncology_data.json';

  Future<OncologyData> loadOncologyData() async {
    try {
      final String jsonString = await rootBundle.loadString(_dataPath);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return OncologyData.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to load oncology data: $e');
    }
  }
}
