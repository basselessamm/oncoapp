import 'package:flutter/material.dart';
import '../models/oncology_data.dart';

class DrugDetailsScreen extends StatelessWidget {
  final Rule rule;

  const DrugDetailsScreen({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drug Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECOMMENDED DRUG', style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    rule.recommendedDrug,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildWhiteChip('Target: ${rule.targetGene}'),
                      const SizedBox(width: 8),
                      _buildWhiteChip(rule.condition),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Specs
            Row(
              children: [
                Expanded(child: _buildInfoCard('Docking Score', rule.dockingScore, Icons.science)),
                const SizedBox(width: 16),
                Expanded(child: _buildInfoCard('Evidence', rule.evidenceLevel, Icons.book)),
              ],
            ),
            const SizedBox(height: 24),

            // Mechanism
            _buildSectionTitle('Mechanism of Action'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                rule.mechanism,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 24),

            // Target Protein & Pathways
            _buildSectionTitle('Protein Target'),
            const SizedBox(height: 8),
            Text(rule.proteinTarget, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),

            _buildSectionTitle('Impacted Pathways'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rule.pathways.map((pathway) {
                return Chip(
                  label: Text(pathway, style: const TextStyle(color: Colors.white)),
                  backgroundColor: const Color(0xFF00B0FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
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
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1976D2)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
    );
  }
}
