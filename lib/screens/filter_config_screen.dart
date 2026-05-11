import 'dart:io';
import 'package:flutter/material.dart';
import '../services/study_analysis_service.dart';
import 'analysis_result_screen.dart';

class FilterConfigScreen extends StatefulWidget {
  final File file;
  final String studyName;
  final String pmid;
  final int sampleSize;

  const FilterConfigScreen({
    super.key,
    required this.file,
    required this.studyName,
    required this.pmid,
    required this.sampleSize,
  });

  @override
  State<FilterConfigScreen> createState() => _FilterConfigScreenState();
}

class _FilterConfigScreenState extends State<FilterConfigScreen> {
  int _upCount = 25;
  int _downCount = 5;
  double _pValue = 0.05;
  double _log2fc = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Smart Filter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('🎯 GENE SELECTION', Icons.tune),
            _buildCounter('Upregulated Genes', _upCount, (v) => setState(() => _upCount = v), 25),
            _buildCounter('Downregulated Genes', _downCount, (v) => setState(() => _downCount = v), 5),
            
            const SizedBox(height: 32),
            _buildSectionHeader('🔬 STATISTICAL FILTERS', Icons.analytics),
            _buildPValueSelector(),
            _buildFCSelector(),
            
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => _analyze(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('🚀 Run Analysis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Analyzing: ${widget.studyName}\nFile: ${widget.file.path.split(Platform.pathSeparator).last}',
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC2185B)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged, int recommended) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              if (value == recommended)
                const Text('⭐ Recommended', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              IconButton(onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text(value.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPValueSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('P-Value Threshold'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [0.05, 0.01, 0.001].map((v) {
            bool selected = _pValue == v;
            return ChoiceChip(
              label: Text('p < $v ${v == 0.05 ? "⭐" : ""}'),
              selected: selected,
              onSelected: (s) => setState(() => _pValue = v),
              selectedColor: const Color(0xFFF48FB1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFCSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Min |Log2FC|'),
            Text(_log2fc.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: _log2fc,
          min: 0.0,
          max: 5.0,
          divisions: 50,
          activeColor: const Color(0xFFE91E63),
          onChanged: (v) => setState(() => _log2fc = v),
        ),
      ],
    );
  }

  void _analyze() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final config = AnalysisConfig(
        upCount: _upCount,
        downCount: _downCount,
        pValueThreshold: _pValue,
        minLog2FC: _log2fc,
      );

      final signature = await StudyAnalysisService.analyzeStudy(
        file: widget.file,
        studyName: widget.studyName,
        pmid: widget.pmid,
        sampleSize: widget.sampleSize,
        config: config,
      );

      if (mounted) {
        Navigator.pop(context); // Close loader
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnalysisResultScreen(signature: signature)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
