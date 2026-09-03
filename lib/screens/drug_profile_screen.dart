import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../models/drug_interaction.dart';
import '../models/pharmacology.dart';
import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';

/// Detail view for one gene-drug interaction.
///
/// Three cards were removed from this screen because the columns behind them
/// were constants in the bundled database, not measurements:
///
/// * "Molecular Docking (Binding Affinity)" displayed `ΔG = -5.0 kcal/mol` for
///   every row, alongside a hardcoded green "Strong Binding" indicator. No
///   docking was performed.
/// * "Protein Class (Target Category)" displayed the string `TARGET` for every
///   row.
/// * "Evidence Level Indicator" labelled `score > 5.0` as
///   "Clinical / High Confidence", asserting a clinical meaning the DGIdb
///   interaction score does not carry.
class DrugProfileScreen extends StatelessWidget {
  const DrugProfileScreen({super.key, required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interaction Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(interaction: interaction),
            const SizedBox(height: 20),
            const ResearchUseBanner(),
            const SizedBox(height: 24),
            const SectionHeading('What the databases report',
                icon: Icons.fact_check_outlined),
            const SizedBox(height: 16),
            DetailCard(
              icon: Icons.settings_outlined,
              title: 'Mechanism of action',
              footnote: interaction.hasUnknownMechanism
                  ? 'No source recorded an interaction type. This is the case '
                      'for 64% of records in the bundled database.'
                  : 'As reported by the source databases listed below.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interaction.mechanismLabel ?? 'Not reported',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  if (interaction.direction !=
                      PharmacologicDirection.unspecified) ...[
                    const SizedBox(height: 6),
                    Text(
                      interaction.direction.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DetailCard(
              icon: Icons.hub_outlined,
              title: 'Corroboration',
              footnote: '${interaction.corroboration.explanation}. Only 9.2% of '
                  'gene-drug pairs in this database are reported by more than '
                  'one source.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interaction.corroboration.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (interaction.sources.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      interaction.sources.join(', '),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
            DetailCard(
              icon: Icons.description_outlined,
              title: 'DGIdb interaction score',
              footnote: 'Measures how well documented the interaction is, '
                  'weighted against how many partners the gene and drug have. '
                  'It is not a measure of efficacy, potency, or clinical '
                  'confidence. ${interaction.evidenceStrength.explanation}.',
              child: Text(
                '${interaction.score.toStringAsFixed(3)}  -  '
                '${interaction.evidenceStrength.label}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            DetailCard(
              icon: Icons.gavel_outlined,
              title: 'Regulatory status',
              footnote: interaction.isApproved
                  ? 'At least one source database marks this drug as approved. '
                      'Approval is for its own indication, not for the cancer '
                      'type under study.'
                  : 'No source database marks this drug as approved. This '
                      'includes investigational and discontinued compounds and '
                      'is not an assessment of repurposing novelty.',
              child: Text(
                interaction.approvalLabel,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            if (interaction.targetCount != null)
              DetailCard(
                icon: Icons.scatter_plot_outlined,
                title: 'Target breadth',
                footnote: interaction.targetCount! >= 20
                    ? 'A drug with many recorded targets is either well studied '
                        'or non-selective. Treat a single-gene match as weak '
                        'evidence of a specific effect.'
                    : 'Number of distinct genes this drug is recorded against '
                        'across the whole database.',
                child: Text(
                  '${interaction.targetCount} gene'
                  '${interaction.targetCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            const SizedBox(height: 8),
            const SectionHeading('Your gene set', icon: Icons.biotech_outlined),
            const SizedBox(height: 16),
            _GenomicContext(interaction: interaction),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORTED INTERACTION',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.2,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            interaction.isUnnamedCompound
                ? interaction.drug.replaceFirst('CHEMBL:', '')
                : interaction.drug,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Target: ${interaction.gene}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the queried gene's expression change and the directional verdict.
class _GenomicContext extends StatelessWidget {
  const _GenomicContext({required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, _) {
        // The signature that produced the result, not whatever is selected now.
        final dataset = provider.queriedSignature ??
            (provider.isManualMode ? null : provider.selectedDataset);

        if (dataset == null) {
          return const DetailCard(
            icon: Icons.edit_outlined,
            title: 'Expression context',
            footnote: 'Genes were entered manually, so there is no fold change '
                'to compare the drug\'s direction against.',
            child: Text(
              'Not available',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          );
        }

        SignificantGene? match;
        for (final candidate in dataset.significantGenes) {
          if (candidate.symbol == interaction.gene) {
            match = candidate;
            break;
          }
        }

        if (match == null) {
          return DetailCard(
            icon: Icons.help_outline,
            title: 'Expression context',
            footnote: 'This target is not among the genes in '
                '"${dataset.cancerName}".',
            child: const Text(
              'Not in the selected signature',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          );
        }

        final regulation = GeneRegulation.fromLog2FoldChange(match.log2fc);
        final verdict =
            DirectionalMatch.resolve(interaction.direction, regulation);
        final pValue = match.effectivePValue;

        return Column(
          children: [
            DetailCard(
              icon: Icons.swap_vert,
              title: 'Directional check',
              footnote: '${verdict.explanation}\n\n'
                  'This compares the drug\'s reported direction of action '
                  'against the direction this gene moved. It is a consistency '
                  'check, not a prediction: mRNA level is not protein '
                  'activity, and a dysregulated gene may be a passenger rather '
                  'than a driver of the tumour.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DirectionChip(match: verdict),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${interaction.direction.label}  vs  '
                    '${regulation.label.toLowerCase()} in this study',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            DetailCard(
              icon: Icons.show_chart,
              title: 'Expression in ${dataset.cancerName}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Direction', match.type),
                  _row('Log2 fold change', match.log2fc.toStringAsFixed(3)),
                  if (pValue != null)
                    _row(
                      match.adjustedPValue != null
                          ? 'Adjusted p-value'
                          : 'Raw p-value',
                      pValue.toStringAsExponential(2),
                    ),
                  if (match.higherExpressionIn.isNotEmpty)
                    _row('Higher in', match.higherExpressionIn),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}
