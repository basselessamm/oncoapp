import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/cancer_signature.dart';
import 'drug_search_screen.dart';
import 'ai_recommendation_screen.dart';
import 'genomic_data_screen.dart';
import 'credits_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualGeneController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _manualGeneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OncoRepurpose AI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFFC2185B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditsScreen())),
            tooltip: 'About & Credits',
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // DRUG SEARCH SECTION (The New Feature)
                // ==========================================
                const Text(
                  '💊 Quick Drug Lookup (Novel Only)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search novel drugs (e.g. Aspirin)...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFE91E63)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Color(0xFFE91E63)),
                        onPressed: () => _handleSearch(provider),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: (_) => _handleSearch(provider),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // ==========================================
                // OPTION A: MANUAL GENE INPUT
                // ==========================================
                const Text(
                  '🧬 Option A: Manual Gene Input',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualGeneController,
                  decoration: InputDecoration(
                    hintText: 'e.g. PIK3CA, TP53',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.science),
                    suffixIcon: provider.isManualMode 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _manualGeneController.clear();
                              provider.setManualGenes('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => provider.setManualGenes(value),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                ),

                // ==========================================
                // OPTION B: SELECT DATASET
                // ==========================================
                const Text(
                  '🔬 Option B: Select Dataset',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CancerSignature>(
                        isExpanded: true,
                        value: provider.selectedDataset,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE91E63)),
                        onChanged: provider.isManualMode ? null : (v) => v != null ? provider.selectDataset(v) : null,
                        items: provider.datasets.map((d) {
                          return DropdownMenuItem<CancerSignature>(
                            value: d, 
                            child: Text(d.cancerName, style: const TextStyle(fontWeight: FontWeight.w500))
                          );
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenomicDataScreen())),
                  ),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text('🎯 Analyze with AI', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                    showDialog(
                      context: context, 
                      barrierDismissible: false, 
                      builder: (context) => const Center(child: CircularProgressIndicator())
                    );
                    try {
                      await provider.fetchRecommendationsFromDB();
                      if (mounted) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AIRecommendationScreen()));
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSearch(DataProvider provider) {
    if (_searchController.text.isNotEmpty) {
      provider.searchNovelDrugs(_searchController.text);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DrugSearchScreen(searchQuery: _searchController.text),
        ),
      );
    }
  }
}
