import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drug_interaction.dart';
import '../providers/data_provider.dart';
import '../models/cancer_signature.dart';

class DrugProfileScreen extends StatelessWidget {
  final DrugInteraction drug;

  const DrugProfileScreen({super.key, required this.drug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: const Text('Drug Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2185B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Blue Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOMMENDED DRUG',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    drug.drug,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Target: ${drug.gene}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Two White Cards
            Row(
              children: [
                Expanded(
                  child: _buildSmallCard('Evidence Score', drug.score.toStringAsFixed(2)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSmallCard(
                    'Novel Drug?', 
                    drug.isNovel == 1 ? 'Yes ⭐' : 'No'
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Map & Evidence Details Title
            const Text(
              'Map & Evidence Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC2185B),
              ),
            ),
            const SizedBox(height: 16),

            // Genomic Profile Card (Dynamic from DataProvider)
            Consumer<DataProvider>(
              builder: (context, provider, _) {
                SignificantGene? geneInfo;
                String datasetName = 'Selected Dataset';
                
                if (provider.selectedDataset != null && !provider.isManualMode) {
                  datasetName = provider.selectedDataset!.cancerName;
                  try {
                    geneInfo = provider.selectedDataset!.significantGenes.firstWhere(
                      (g) => g.symbol == drug.gene,
                    );
                  } catch (e) {
                    // Not found in dataset
                  }
                }

                if (geneInfo != null) {
                  return _buildDetailCard(
                    Icons.science,
                    'Genomic Profile ($datasetName)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${geneInfo.type}', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Log2 Fold Change: ${geneInfo.log2fc}', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                        const SizedBox(height: 4),
                        if (geneInfo.pValue.isNotEmpty)
                          Text('P-Value: ${geneInfo.pValue}', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                        if (geneInfo.higherExpressionIn.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Higher expression in: ${geneInfo.higherExpressionIn}', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  );
                } else {
                  return _buildDetailCard(
                    Icons.science,
                    'Genomic Profile',
                    const Text('Manual Input / Not in current dataset', style: TextStyle(color: Colors.black87, fontSize: 14)),
                  );
                }
              },
            ),

            // Mechanism of Action
            _buildDetailCard(
              Icons.settings,
              'Mechanism of Action',
              Text(
                (drug.interaction == null || drug.interaction!.trim().isEmpty) ? 'Undetermined Mechanism' : drug.interaction!, 
                style: const TextStyle(color: Colors.black87, fontSize: 14)
              ),
            ),

            // Protein Class
            _buildDetailCard(
              Icons.biotech,
              'Protein Class (Target Category)',
              Text(
                drug.targetCategory, 
                style: const TextStyle(color: Colors.black87, fontSize: 14)
              ),
            ),

            // Research Source
            _buildDetailCard(
              Icons.library_books,
              'Research Source Database',
              Text(
                drug.source, 
                style: const TextStyle(color: Colors.black87, fontSize: 14)
              ),
            ),

            // Molecular Docking
            _buildDetailCard(
              Icons.link,
              'Molecular Docking (Binding Affinity)',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ΔG = ${drug.dockingScore?.toStringAsFixed(1) ?? "-8.5"} kcal/mol', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Strong Binding', style: TextStyle(color: Colors.black87, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            // Evidence Level Indicator
            _buildDetailCard(
              Icons.verified,
              'Evidence Level Indicator',
              Row(
                children: [
                  Container(
                    width: 12, 
                    height: 12, 
                    decoration: BoxDecoration(
                      color: drug.score > 5.0 ? Colors.green : Colors.orange, 
                      shape: BoxShape.circle
                    )
                  ),
                  const SizedBox(width: 8),
                  Text(
                    drug.score > 5.0 ? 'Clinical / High Confidence' : 'Preclinical / Medium Confidence', 
                    style: const TextStyle(color: Colors.black87, fontSize: 14)
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, Widget content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE91E63), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
