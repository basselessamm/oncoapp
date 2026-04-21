import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/drug_interaction.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  
  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "breast_cancer_clean.db");

    bool exists = await databaseExists(path);

    if (!exists) {
      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load("assets/db/breast_cancer_clean.db");
      List<int> bytes = 
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
    }

    // Open the database
    return await openDatabase(path);
  }

  Future<List<DrugInteraction>> getDrugsForGenes(List<String> genes) async {
    if (genes.isEmpty) return [];

    final db = await database;
    
    // Create placeholders for the IN clause (?, ?, ?)
    final placeholders = List.filled(genes.length, '?').join(',');
    
    // استعلام ذكي بيمنع التكرار (GROUP BY) وبيجمع الأصناف مع بعض
    final query = '''
      SELECT 
        gene, 
        drug, 
        interaction, 
        GROUP_CONCAT(DISTINCT target_category) AS target_category, 
        MAX(is_novel) as is_novel, 
        MAX(score) as score, 
        MAX(docking_score) as docking_score,
        source
      FROM drug_interactions 
      WHERE gene IN ($placeholders) AND is_novel = 1
      GROUP BY drug, gene
      ORDER BY score DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, genes);

    return List.generate(maps.length, (i) {
      return DrugInteraction.fromMap(maps[i]);
    });
  }
}
