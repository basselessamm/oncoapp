import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';

class AnalysisResultScreen extends StatelessWidget {
  final CancerSignature signature;

  const AnalysisResultScreen({super.key, required this.signature});

  @override
  Widget build(BuildContext context) {
    int upCount = signature.significantGenes.where((g) => g.type == 'Upregulated').length;
    int downCount = signature.significantGenes.where((g) => g.type == 'Downregulated').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: Column(
        children: [
          _buildSummaryHeader(upCount, downCount),
          Expanded(child: _buildGeneList()),
          _buildActionFooter(context),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(int up, int down) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          const Text('ANALYSIS SUMMARY', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total Genes', (up + down).toString(), Colors.blue),
              _buildStat('Upregulated', up.toString(), Colors.green),
              _buildStat('Downregulated', down.toString(), Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildGeneList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: signature.significantGenes.length,
      itemBuilder: (context, index) {
        final gene = signature.significantGenes[index];
        bool isUp = gene.type == 'Upregulated';
        return Card(
          child: ListTile(
            leading: Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? Colors.green : Colors.red),
            title: Text(gene.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Log2FC: ${gene.log2fc}'),
            trailing: Chip(label: Text(gene.type, style: const TextStyle(fontSize: 10))),
          ),
        );
      },
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Discard'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _save(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('💾 Save Study', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.addLabStudy(signature);
    if (context.mounted) {
      // Pop back to Lab Screen then Home
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study saved successfully!'), backgroundColor: Colors.green),
      );
    }
  }
}
