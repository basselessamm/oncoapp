import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class GenomicDataScreen extends StatelessWidget {
  const GenomicDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genomic Profile')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          final dataset = provider.selectedDataset;
          if (dataset == null) return const Center(child: Text('No dataset selected'));

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: dataset.significantGenes.length,
              itemBuilder: (context, index) {
                final gene = dataset.significantGenes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink.shade50, 
                      child: const Icon(Icons.science, color: Color(0xFFE91E63))
                    ),
                    title: Text(gene.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${gene.type} | Log2FC: ${gene.log2fc}'),
                        if (gene.higherExpressionIn.isNotEmpty)
                          Text('Higher expression in: ${gene.higherExpressionIn}', style: const TextStyle(color: Color(0xFFC2185B))),
                      ],
                    ),
                    trailing: Chip(
                      label: Text('P-val: ${gene.pValue}', style: const TextStyle(fontSize: 12)), 
                      backgroundColor: Colors.amber.shade100
                    ),
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
