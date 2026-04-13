import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/oncology_data.dart';
import '../providers/data_provider.dart';
import 'genomic_data_screen.dart';
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
          if (provider.oncologyData == null || provider.oncologyData!.datasets.isEmpty) {
            return const Center(child: Text('No datasets available'));
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select Cancer Dataset',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
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
                        onChanged: (Dataset? newValue) {
                          if (newValue != null) {
                            provider.selectDataset(newValue);
                          }
                        },
                        items: provider.oncologyData!.datasets
                            .map<DropdownMenuItem<Dataset>>((Dataset dataset) {
                          return DropdownMenuItem<Dataset>(
                            value: dataset,
                            child: Text(
                              dataset.cancerType,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (provider.selectedDataset != null)
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
                        Text('Source ID: ${provider.selectedDataset!.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('Data Source: ${provider.selectedDataset!.source}', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.biotech),
                        label: const Text('View Genomic Data'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: null,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GenomicDataScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Analyze with AI', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AIRecommendationScreen()),
                    );
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
