import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final evidenceColors = theme.extension<EvidenceThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? EvidenceThemeColors.dark
            : EvidenceThemeColors.light);

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
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isUp
                                ? evidenceColors.opposesInk
                                : evidenceColors.reinforcesInk,
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
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.65),
                            ),
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
    final theme = Theme.of(context);
    final provenance = signature.provenance;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
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
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
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
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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
