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
    // Use getApplicationSupportDirectory for desktop (AppData/Roaming on Windows)
    // Falls back to getApplicationDocumentsDirectory on mobile
    Directory appDir;
    try {
      appDir = await getApplicationSupportDirectory();
    } catch (_) {
      appDir = await getApplicationDocumentsDirectory();
    }
    
    String path = join(appDir.path, "master_drugs.db");

    // Ensure directory exists
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    // Copy DB from assets ONLY if it doesn't exist to avoid "file in use" errors
    final dbFile = File(path);
    if (!await dbFile.exists()) {
      ByteData data = await rootBundle.load('assets/db/master_drugs.db');
      List<int> bytes = 
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await dbFile.writeAsBytes(bytes, flush: true);
    }

    // Open the database
    final db = await openDatabase(path);
    
    // Ensure indexes exist for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gene ON drug_interactions(gene)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_is_novel ON drug_interactions(is_novel)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_drug ON drug_interactions(drug)');
    
    return db;
  }

  Future<List<DrugInteraction>> getDrugsForGenes(List<String> genes, {bool onlyNovel = false, double minScore = 0.0}) async {
    final db = await database;
    if (genes.isEmpty) return [];

    final placeholders = List.filled(genes.length, '?').join(',');
    
    // Build dynamic conditions
    String conditions = "gene IN ($placeholders)";
    if (onlyNovel) conditions += " AND is_novel = 1";
    if (minScore > 0) conditions += " AND score >= $minScore";

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
      WHERE $conditions
      GROUP BY drug, gene
      ORDER BY score DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, genes);

    return List.generate(maps.length, (i) {
      return DrugInteraction.fromMap(maps[i]);
    });
  }

  Future<List<DrugInteraction>> searchNovelDrugs(String query) async {
    if (query.isEmpty) return [];

    final db = await database;
    
    // البحث عن الأدوية الـ Novel فقط مع تجميع لفرز الأسماء بشكل فريد
    final sql = '''
      SELECT 
        gene, 
        drug, 
        interaction, 
        target_category, 
        is_novel, 
        score, 
        docking_score,
        source
      FROM drug_interactions 
      WHERE drug LIKE ? AND is_novel = 1
      GROUP BY drug
      ORDER BY score DESC
      LIMIT 20
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, ['%$query%']);

    return List.generate(maps.length, (i) {
      return DrugInteraction.fromMap(maps[i]);
    });
  }
}
