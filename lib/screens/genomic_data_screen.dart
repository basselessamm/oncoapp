import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'ai_recommendation_screen.dart';

class GenomicDataScreen extends StatelessWidget {
  const GenomicDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genomic Profile'),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          final dataset = provider.selectedDataset;
          if (dataset == null) return const Center(child: Text('No dataset selected'));

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(dataset.cancerType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Gene Expression Data (${dataset.geneExpression.length} markers)', style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: dataset.geneExpression.length,
                    itemBuilder: (context, index) {
                      String gene = dataset.geneExpression.keys.elementAt(index);
                      String expression = dataset.geneExpression.values.elementAt(index);
                      bool isUpregulated = expression == 'Upregulated';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isUpregulated ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isUpregulated ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isUpregulated ? Colors.red.shade700 : Colors.blue.shade700,
                            ),
                          ),
                          title: Text(gene, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isUpregulated ? Colors.red.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isUpregulated ? Colors.red.shade200 : Colors.blue.shade200),
                            ),
                            child: Text(
                              expression,
                              style: TextStyle(
                                color: isUpregulated ? Colors.red.shade700 : Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Analyze with AI', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Replace to avoid pushing multiple instances if coming from HomeScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AIRecommendationScreen()),
                    );
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
