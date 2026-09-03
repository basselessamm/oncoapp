import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import '../providers/evidence_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/evidence_widgets.dart';

/// Lists the genes in the selected signature with their expression metrics
/// and Open Targets disease-association scores.
class GenomicDataScreen extends StatefulWidget {
  const GenomicDataScreen({super.key});

  @override
  State<GenomicDataScreen> createState() => _GenomicDataScreenState();
}

class _GenomicDataScreenState extends State<GenomicDataScreen> {
  String? _lastDatasetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataProvider = context.read<DataProvider>();
    final evidenceProvider = context.read<EvidenceProvider>();
    final dataset = dataProvider.selectedDataset;
    if (dataset != null && dataset.id != _lastDatasetId) {
      _lastDatasetId = dataset.id;
      final symbols = dataset.significantGenes.map((g) => g.symbol).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          evidenceProvider.loadEvidence(symbols);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'البصمة الجينية' : 'Gene Signature'),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          final dataset = provider.selectedDataset;
          if (dataset == null) {
            return StatusMessage(
              icon: Icons.inbox_outlined,
              title: isAr ? 'لم يتم تحديد أي بصمة جينية' : 'No signature selected',
            );
          }

          final genes = dataset.significantGenes;
          return Column(
            children: [
              _SignatureHeader(signature: dataset),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  itemCount: genes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
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
    final theme = Theme.of(context);
    final evidenceColors = theme.extension<EvidenceThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? EvidenceThemeColors.dark
            : EvidenceThemeColors.light);

    final provenance = signature.provenance;
    final evidenceProvider = context.watch<EvidenceProvider>();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  signature.cancerName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (evidenceProvider.freshness != null)
                FreshnessChip(
                  freshness: evidenceProvider.freshness!,
                  retrievedAt: evidenceProvider.retrievedAt,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoChip(
                dense: true,
                icon: Icons.arrow_upward,
                label: isAr ? '${signature.upregulatedCount} مرتفع' : '${signature.upregulatedCount} up',
                background: evidenceColors.opposesSurface,
                foreground: evidenceColors.opposesInk,
              ),
              InfoChip(
                dense: true,
                icon: Icons.arrow_downward,
                label: isAr ? '${signature.downregulatedCount} منخفض' : '${signature.downregulatedCount} down',
                background: evidenceColors.reinforcesSurface,
                foreground: evidenceColors.reinforcesInk,
              ),
              if (signature.sampleSize > 0)
                InfoChip(
                  dense: true,
                  icon: Icons.groups_outlined,
                  label: isAr ? 'العينات: ${signature.sampleSize}' : 'n = ${signature.sampleSize}',
                  background: theme.colorScheme.surfaceContainerHighest,
                ),
              if (signature.pmid.isNotEmpty)
                InfoChip(
                  dense: true,
                  icon: Icons.article_outlined,
                  label: 'PMID ${signature.pmid}',
                  background: theme.colorScheme.surfaceContainerHighest,
                ),
            ],
          ),
          if (provenance != null) ...[
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'من ${provenance.sourceFileName}: تم تحليل ${provenance.genesInFile} جين، واجتاز ${provenance.genesPassingFilters} مرشحات الدلالة.'
                  : 'From ${provenance.sourceFileName}: ${provenance.genesInFile} genes parsed, ${provenance.genesPassingFilters} passed ${provenance.usedFdrCorrection ? 'FDR-adjusted' : 'raw'} p <= ${provenance.pValueThreshold} and |log2FC| >= ${provenance.minLog2FC}.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
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
    final theme = Theme.of(context);
    final evidenceColors = theme.extension<EvidenceThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? EvidenceThemeColors.dark
            : EvidenceThemeColors.light);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final isUp = gene.isUpregulated;
    final color =
        isUp ? evidenceColors.opposesInk : evidenceColors.reinforcesInk;
    final pValue = gene.effectivePValue;

    final evidenceProvider = context.watch<EvidenceProvider>();
    final evidence = evidenceProvider.evidenceFor(gene.symbol);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gene.symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${gene.type}  -  log2FC ${gene.log2fc.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  if (gene.higherExpressionIn.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      isAr
                          ? 'أعلى في ${gene.higherExpressionIn}'
                          : 'Higher in ${gene.higherExpressionIn}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (evidence != null) ...[
              AssociationChip(evidence: evidence, dense: true),
              const SizedBox(width: 6),
            ],
            if (pValue != null)
              InfoChip(
                dense: true,
                label: pValue.toStringAsExponential(1),
                background: theme.colorScheme.surfaceContainerHighest,
                tooltip: gene.adjustedPValue != null
                    ? (isAr ? 'القيمة الاحتمالية المصححة (FDR)' : 'FDR-adjusted p-value')
                    : (isAr ? 'القيمة الاحتمالية غير المصححة' : 'Raw p-value, not corrected for multiple testing'),
              ),
          ],
        ),
      ),
    );
  }
}
