import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/cancer_signature.dart';
import 'drug_profile_screen.dart'; // Using the premium profile screen

class AIRecommendationScreen extends StatelessWidget {
  const AIRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Repurposing Results')),
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
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => DrugProfileScreen(drug: drug))
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                drug.drug, 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)), 
                                overflow: TextOverflow.ellipsis
                              )
                            ),
                            if (isNovel) 
                              const Chip(
                                label: Text('⭐ Novel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), 
                                backgroundColor: Colors.amber
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip('Target: ${drug.gene}', Colors.pink.shade50), 
                            _buildInfoChip('Score: ${drug.score.toStringAsFixed(2)}', const Color(0xFFF8BBD0)),
                            _buildInfoChip((drug.interaction == null || drug.interaction!.trim().isEmpty) ? 'Unknown Interaction' : drug.interaction!, const Color(0xFFF48FB1)),
                            
                            // Lookup the gene to show higher expression
                            if (provider.selectedDataset != null && !provider.isManualMode)
                              ...[
                                () {
                                  final geneInfo = provider.selectedDataset!.significantGenes.firstWhere(
                                    (g) => g.symbol == drug.gene, 
                                    orElse: () => SignificantGene(symbol: '', frequency: '', type: '')
                                  );
                                    return _buildInfoChip('Higher in: ${geneInfo.higherExpressionIn}', const Color(0xFFFCE4EC));
                                  return const SizedBox.shrink();
                                }()
                              ]
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

  Widget _buildInfoChip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
