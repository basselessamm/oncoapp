import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';

/// Review screen for a freshly analysed study file, before saving it.
class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key, required this.signature});

  final CancerSignature signature;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final signature = widget.signature;
    final genes = signature.significantGenes;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: Column(
        children: [
          _buildSummary(signature),
          Expanded(
            child: genes.isEmpty
                ? const StatusMessage(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No genes passed the filters',
                    detail: 'Loosen the p-value or fold-change threshold, or '
                        'switch off FDR correction if the file already '
                        'contains adjusted p-values.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: genes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final gene = genes[index];
                      final isUp = gene.isUpregulated;
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isUp
                                ? EvidenceColors.corroborated
                                : const Color(0xFFC62828),
                          ),
                          title: Text(gene.symbol,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'log2FC ${gene.log2fc.toStringAsFixed(2)}'
                            '${gene.effectivePValue == null ? '' : '  -  p ${gene.effectivePValue!.toStringAsExponential(1)}'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            gene.type,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSummary(CancerSignature signature) {
    final provenance = signature.provenance;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('Kept', '${signature.significantGenes.length}'),
              _stat('Up', '${signature.upregulatedCount}'),
              _stat('Down', '${signature.downregulatedCount}'),
              if (provenance != null)
                _stat('Passed filters', '${provenance.genesPassingFilters}'),
            ],
          ),
          if (provenance != null) ...[
            const SizedBox(height: 16),
            Text(
              '${provenance.genesInFile} genes parsed from '
              '${provenance.sourceFileName}. '
              '${provenance.usedFdrCorrection ? 'Benjamini-Hochberg FDR correction applied' : 'No multiple-testing correction applied'}; '
              'threshold p <= ${provenance.pValueThreshold}, '
              '|log2FC| >= ${provenance.minLog2FC}.',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Colors.black54),
            ),
            if (provenance.rowsSkipped > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${provenance.rowsSkipped} row(s) skipped: missing gene '
                'symbol, fold change, or p-value.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF7A3E00)),
              ),
            ],
            if (!provenance.usedFdrCorrection) ...[
              const SizedBox(height: 8),
              const Text(
                'Raw p-values were used. On a whole-transcriptome table this '
                'admits roughly 5% of genes by chance.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A3E00)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _saving || widget.signature.significantGenes.isEmpty
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save study',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<DataProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await provider.addLabStudy(widget.signature);
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Study saved')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the study: $error'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }
}
