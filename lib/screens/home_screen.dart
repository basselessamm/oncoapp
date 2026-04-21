import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import 'ai_recommendation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OncoRepurpose AI', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }
          if (provider.signatures.isEmpty) {
            return const Center(child: Text('No datasets available'));
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select Cancer Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
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
                        value: provider.selectedSignature,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1976D2)),
                        onChanged: (CancerSignature? newValue) {
                          if (newValue != null) {
                            provider.selectSignature(newValue);
                          }
                        },
                        items: provider.signatures
                            .map<DropdownMenuItem<CancerSignature>>((CancerSignature sig) {
                          return DropdownMenuItem<CancerSignature>(
                            value: sig,
                            child: Text(
                              sig.cancerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (provider.selectedSignature != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PMID: ${provider.selectedSignature!.pmid}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('Sample Size: ${provider.selectedSignature!.sampleSize}', style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Significant Genes: ${provider.selectedSignature!.significantGenes.length}', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Analyze for Repurposing', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: () async {
                    if (provider.selectedSignature != null) {
                      provider.fetchRecommendations(provider.selectedSignature!);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AIRecommendationScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
