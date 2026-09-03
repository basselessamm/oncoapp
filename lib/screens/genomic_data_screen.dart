import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';

/// Lists the genes in the selected signature.
class GenomicDataScreen extends StatelessWidget {
  const GenomicDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gene Signature')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          final dataset = provider.selectedDataset;
          if (dataset == null) {
            return const StatusMessage(
              icon: Icons.inbox_outlined,
              title: 'No signature selected',
            );
          }

          final genes = dataset.significantGenes;
          return Column(
            children: [
              _SignatureHeader(signature: dataset),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: genes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _GeneTile(gene: genes[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignatureHeader extends StatelessWidget {
  const _SignatureHeader({required this.signature});

  final CancerSignature signature;

  @override
  Widget build(BuildContext context) {
    final provenance = signature.provenance;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            signature.cancerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(
                icon: Icons.arrow_upward,
                label: '${signature.upregulatedCount} up',
                background:
                    EvidenceColors.corroborated.withValues(alpha: 0.10),
                foreground: EvidenceColors.corroborated,
              ),
              InfoChip(
                icon: Icons.arrow_downward,
                label: '${signature.downregulatedCount} down',
                background: const Color(0xFFFFEBEE),
                foreground: const Color(0xFFC62828),
              ),
              if (signature.sampleSize > 0)
                InfoChip(
                  icon: Icons.groups_outlined,
                  label: 'n = ${signature.sampleSize}',
                  background: AppColors.background,
                ),
              if (signature.pmid.isNotEmpty)
                InfoChip(
                  icon: Icons.article_outlined,
                  label: 'PMID ${signature.pmid}',
                  background: AppColors.background,
                ),
            ],
          ),
          if (provenance != null) ...[
            const SizedBox(height: 10),
            Text(
              'From ${provenance.sourceFileName}: '
              '${provenance.genesInFile} genes parsed, '
              '${provenance.genesPassingFilters} passed '
              '${provenance.usedFdrCorrection ? 'FDR-adjusted' : 'raw'} '
              'p <= ${provenance.pValueThreshold} and '
              '|log2FC| >= ${provenance.minLog2FC}'
              '${provenance.rowsSkipped > 0 ? ', ${provenance.rowsSkipped} rows skipped as unreadable' : ''}.',
              style: const TextStyle(
                  fontSize: 11, height: 1.35, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _GeneTile extends StatelessWidget {
  const _GeneTile({required this.gene});

  final SignificantGene gene;

  @override
  Widget build(BuildContext context) {
    final isUp = gene.isUpregulated;
    final color =
        isUp ? EvidenceColors.corroborated : const Color(0xFFC62828);
    final pValue = gene.effectivePValue;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Direction is conveyed by icon and text, not by colour alone.
            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gene.symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${gene.type}  -  log2FC ${gene.log2fc.toStringAsFixed(2)}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (gene.higherExpressionIn.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Higher in ${gene.higherExpressionIn}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primaryDark),
                    ),
                  ],
                ],
              ),
            ),
            if (pValue != null)
              InfoChip(
                label: pValue.toStringAsExponential(1),
                background: const Color(0xFFFFF8E1),
                tooltip: gene.adjustedPValue != null
                    ? 'FDR-adjusted p-value'
                    : 'Raw p-value, not corrected for multiple testing',
              ),
          ],
        ),
      ),
    );
  }
}
