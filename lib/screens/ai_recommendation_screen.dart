import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/drug_interaction.dart';

class AIRecommendationScreen extends StatelessWidget {
  const AIRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Repurposing Results'),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isAnalyzing) {
             return const Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   CircularProgressIndicator(),
                   SizedBox(height: 16),
                   Text("Querying interaction database...", style: TextStyle(fontSize: 16))
                 ]
               )
             );
          }

          final recommendations = provider.recommendedDrugs;

          return Column(
            children: [
              // CRUCIAL DISCLAIMER
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade600, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.shade100, blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Disclaimer: Recommendations are evidence-based hypotheses for research & decision support, not direct clinical prescriptions.",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Found ${recommendations.length} Potential Repurposed Drugs',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: recommendations.isEmpty
                    ? const Center(child: Text("No recommendations found for this profile."))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: recommendations.length,
                        itemBuilder: (context, index) {
                          final DrugInteraction interaction = recommendations[index];
                          final isNovel = interaction.isNovel == 1;

                          return Card(
                            elevation: isNovel ? 6 : 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isNovel 
                                  ? BorderSide(color: Colors.amber.shade400, width: 2) 
                                  : BorderSide.none,
                            ),
                            color: isNovel ? Colors.amber.shade50 : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              interaction.drug,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isNovel ? Colors.amber.shade900 : const Color(0xFF0D47A1),
                                              ),
                                            ),
                                            if (isNovel) 
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade700,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('⭐ Novel Repurposing', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildChip('Gene: ${interaction.gene}', Colors.blue.shade100, Colors.blue.shade800),
                                      const SizedBox(width: 8),
                                      _buildChip(interaction.interaction, Colors.teal.shade100, Colors.teal.shade800),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Target Category: ${interaction.targetCategory}",
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                      ),
                                      Text(
                                        "Score: ${interaction.score}",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Source: ${interaction.source}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
