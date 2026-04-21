import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ملفات الداتا بيز والموديل بتاعتك
import 'services/database_service.dart';
import 'models/drug_interaction.dart';

// ==========================================
// 1. DATA MODELS (متفصلة على ملف tcga_signatures.json)
// ==========================================
class SignificantGene {
  final String symbol;
  final String frequency;
  final String type;
  final String pValue;
  final double log2fc;

  SignificantGene({required this.symbol, required this.frequency, required this.type, this.pValue = '', this.log2fc = 0.0});

  factory SignificantGene.fromJson(Map<String, dynamic> json) {
    return SignificantGene(
      symbol: json['symbol'] ?? '',
      frequency: json['frequency'] ?? '',
      type: json['type'] ?? '',
      pValue: json['p_value'] ?? '',
      log2fc: (json['log2fc'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Dataset {
  final String cancerName;
  final String pmid;
  final int sampleSize;
  final List<SignificantGene> significantGenes;

  Dataset({required this.cancerName, required this.pmid, required this.sampleSize, required this.significantGenes});

  factory Dataset.fromJson(Map<String, dynamic> json) {
    return Dataset(
      cancerName: json['cancer_name'] ?? 'Unknown',
      pmid: json['pmid'] ?? '',
      sampleSize: json['sample_size'] ?? 0,
      significantGenes: (json['significant_genes'] as List)
          .map((i) => SignificantGene.fromJson(i))
          .toList(),
    );
  }
}

// ==========================================
// 2. STATE PROVIDER
// ==========================================
class DataProvider with ChangeNotifier {
  List<Dataset> datasets = [];
  Dataset? selectedDataset;
  bool isLoading = true;
  List<String> manualGenes = [];
  bool isManualMode = false;
  
  List<DrugInteraction> aiRecommendations = []; 

  // الدالة دي بتقرأ ملف الـ JSON بتاعك
  Future<void> loadData() async {
    print("📂 Attempting to load JSON from assets...");
    isLoading = true;
    notifyListeners();

    try {
      // بنسحب ملف tcga_signatures (Fixed the path to match pubspec.yaml)
      String jsonString = await rootBundle.loadString('assets/data/tcga_signatures.json');
      
      // الملف بتاعك عبارة عن Array مباشر مش Object
      final List<dynamic> jsonData = json.decode(jsonString);

      datasets = jsonData.map((i) => Dataset.fromJson(i)).toList();
      print("✅ Loaded ${datasets.length} datasets from JSON.");

      if (datasets.isNotEmpty) selectedDataset = datasets.first;

    } catch (e) {
      print("Error loading JSON from assets: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  void selectDataset(Dataset dataset) {
    selectedDataset = dataset;
    isManualMode = false;
    notifyListeners();
  }

  void setManualGenes(String input) {
    if (input.trim().isEmpty) {
      isManualMode = false;
      manualGenes = [];
    } else {
      isManualMode = true;
      manualGenes = input.split(',').map((e) => e.trim().toUpperCase()).toList();
    }
    notifyListeners();
  }

  // الدالة دي بتجيب الأدوية من الداتا بيز
  Future<void> fetchRecommendationsFromDB() async {
    isLoading = true;
    notifyListeners();

    List<String> genesToSearch = [];

    if (isManualMode && manualGenes.isNotEmpty) {
      genesToSearch = manualGenes;
    } else if (selectedDataset != null) {
      // هنا بناخد الـ symbol بتاع كل جين من الملف
      genesToSearch = selectedDataset!.significantGenes.map((g) => g.symbol).toList();
    }

    print("🔍 Searching SQLite for genes: $genesToSearch");

    // بنبعت الجينات لملف الـ SQLite بتاعك
    aiRecommendations = await DatabaseService().getDrugsForGenes(genesToSearch);

    print("💊 Database returned ${aiRecommendations.length} drug recommendations.");

    isLoading = false;
    notifyListeners();
  }
}

// ==========================================
// 3. MAIN APP ENTRY
// ==========================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => DataProvider()..loadData())],
      child: const OncoApp(),
    ),
  );
}

class OncoApp extends StatelessWidget {
  const OncoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OncoRepurpose AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1), primary: const Color(0xFF1976D2)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.white, foregroundColor: Color(0xFF0D47A1), centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// 4. SCREENS
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OncoRepurpose AI', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Option A: Manual Gene Input', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'e.g. PIK3CA, TP53',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => provider.setManualGenes(value),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                ),

                const Text('Option B: Select TCGA Dataset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Dataset>(
                        isExpanded: true,
                        value: provider.selectedDataset,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1976D2)),
                        onChanged: provider.isManualMode ? null : (v) => v != null ? provider.selectDataset(v) : null,
                        items: provider.datasets.map((d) {
                          return DropdownMenuItem<Dataset>(value: d, child: Text(d.cancerName, style: const TextStyle(fontWeight: FontWeight.w500)));
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                if (!provider.isManualMode)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.biotech),
                    label: const Text('View Genomic Signatures'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenomicDataScreen())),
                  ),
                const SizedBox(height: 16),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Analyze with AI', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                    await provider.fetchRecommendationsFromDB();
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AIRecommendationScreen()));
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GenomicDataScreen extends StatelessWidget {
  const GenomicDataScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TCGA Genomic Profile')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          final dataset = provider.selectedDataset;
          if (dataset == null) return const Center(child: Text('Empty'));
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: dataset.significantGenes.length,
              itemBuilder: (context, index) {
                final gene = dataset.significantGenes[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: const Icon(Icons.science, color: Colors.blue)),
                    title: Text(gene.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${gene.type} | Log2FC: ${gene.log2fc}'),
                    trailing: Chip(label: Text('P-val: ${gene.pValue}', style: const TextStyle(fontSize: 12)), backgroundColor: Colors.amber.shade100),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AIRecommendationScreen extends StatelessWidget {
  const AIRecommendationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Results')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          final recommendations = provider.aiRecommendations;
          
          if (recommendations.isEmpty) {
            return const Center(child: Text('No results found for these genes.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final drug = recommendations[index];
              bool isNovel = drug.isNovel == 1; 
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DrugDetailsScreen(drug: drug))),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(drug.drug, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)), overflow: TextOverflow.ellipsis)),
                            if (isNovel) 
                              const Chip(label: Text('⭐ Novel Repurposing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)), backgroundColor: Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Target: ${drug.gene}'), backgroundColor: Colors.blue.shade50), 
                            Chip(label: Text('Score: ${drug.score}'), backgroundColor: Colors.teal.shade50),
                            Chip(
                              avatar: const Icon(Icons.science, size: 16, color: Colors.purple),
                              label: Text(drug.interaction.isNotEmpty ? drug.interaction : 'Unknown', style: const TextStyle(fontSize: 12)), 
                              backgroundColor: Colors.purple.shade50
                            ),
                            Chip(
                              avatar: const Icon(Icons.source, size: 16, color: Colors.deepOrange),
                              label: Text(drug.source.isNotEmpty ? drug.source : 'Database', style: const TextStyle(fontSize: 12)), 
                              backgroundColor: Colors.orange.shade50
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DrugDetailsScreen extends StatelessWidget {
  final DrugInteraction drug; 
  const DrugDetailsScreen({super.key, required this.drug});
  
  @override
  Widget build(BuildContext context) {
    // 1. Fetch the exact gene data (P-Value, Log2FC) from the dataset
    final provider = Provider.of<DataProvider>(context, listen: false);
    final dataset = provider.selectedDataset;
    SignificantGene? targetGene;
    if (dataset != null) {
      try {
        targetGene = dataset.significantGenes.firstWhere((g) => g.symbol == drug.gene);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Drug Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECOMMENDED DRUG', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(drug.drug, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Chip(label: Text('Target: ${drug.gene}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blue.shade800),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoCard('Evidence Score', drug.score.toStringAsFixed(2))), 
                const SizedBox(width: 16), 
                Expanded(child: _buildInfoCard('Novel Drug?', drug.isNovel == 1 ? 'Yes ⭐' : 'No'))
              ]
            ),
            const SizedBox(height: 24),
            const Text('Map & Evidence Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            
            // 2. TCGA Genomic Profile (P-Value / Log2FC)
            if (targetGene != null) ...[
              _buildDetailRow(
                Icons.science, 
                'Genomic Profile (TCGA Patient Data)', 
                'Status: ${targetGene.type}\nLog2 Fold Change: ${targetGene.log2fc}\nP-Value: ${targetGene.pValue}'
              ),
              const SizedBox(height: 12),
            ],

            // 3. Formatted Mechanism of Action (like PDF)
            _buildDetailRow(
              Icons.settings_suggest, 
              'Mechanism of Action', 
              drug.interaction.isNotEmpty 
                ? '${drug.drug} → ${drug.interaction}s → ${drug.gene} signaling'
                : 'Undetermined Mechanism'
            ),
            const SizedBox(height: 12),

            _buildDetailRow(Icons.biotech, 'Protein Class (Target Category)', drug.targetCategory.isNotEmpty ? drug.targetCategory : 'Unknown Classification'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.library_books, 'Research Source Database', drug.source.isNotEmpty ? drug.source : 'Literature Mining'),
            const SizedBox(height: 12),
            
            // 4. Molecular Docking Binding Affinity
            _buildDetailRow(
              Icons.join_inner, 
              'Molecular Docking (Binding Affinity)', 
              'ΔG = ${drug.dockingScore.toStringAsFixed(1)} kcal/mol\n${drug.dockingScore <= -7.0 ? '🟢 Strong Binding' : (drug.dockingScore <= -5.0 ? '🟡 Moderate Binding' : '🔴 Weak Binding')}'
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              Icons.verified, 
              'Evidence Level Indicator', 
              drug.score > 5.0 ? '🟢 Clinical / High Confidence' : (drug.score > 1.0 ? '🟡 In vitro / Moderate' : '🔵 Computational / Predictive')
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1976D2), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }
}