import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/drug_candidate.dart';
import '../models/pharmacology.dart';
import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';
import 'drug_profile_screen.dart';

/// Candidate drugs for the queried gene set, one card per drug.
///
/// Two things changed here versus the former "AI Repurposing Results" screen:
/// results are grouped per drug rather than per (gene, drug) pair, and each
/// target carries a directional verdict. A drug hitting eight signature genes
/// used to appear as eight unrelated rows with no combined view.
class InteractionResultsScreen extends StatelessWidget {
  const InteractionResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Drugs')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          switch (provider.interactionStatus) {
            case LoadStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.failed:
              return StatusMessage(
                icon: Icons.error_outline,
                title: 'Lookup failed',
                detail: provider.interactionError,
                onRetry: () => provider.findInteractionsForGenes(
                  filters: provider.lastFilters,
                ),
              );
            case LoadStatus.idle:
            case LoadStatus.ready:
              break;
          }

          final candidates = provider.candidates;
          if (candidates.isEmpty) {
            return StatusMessage(
              icon: Icons.search_off,
              title: 'No candidates found',
              detail: _emptyDetail(provider),
            );
          }

          return Column(
            children: [
              _ResultsSummary(provider: provider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: candidates.length,
                  itemBuilder: (context, index) => _CandidateCard(
                    candidate: candidates[index],
                    isManualQuery: provider.queriedSignature == null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Explains an empty result in terms of the real cause.
  ///
  /// Differential-expression outliers and druggable targets are largely
  /// disjoint sets: only 13 of the 30 genes in the bundled TCGA signature have
  /// any interaction record at all.
  String _emptyDetail(DataProvider provider) {
    final geneCount = provider.queriedGenes.length;
    final filters = provider.lastFilters;
    if (filters.onlyOpposing) {
      return 'No drug was found that acts against the direction of change on '
          'any of the $geneCount gene(s) queried. Turn off the '
          '"opposing only" filter to see the remaining interactions.';
    }
    if (!filters.isDefault) {
      return 'None of the $geneCount gene(s) queried has an interaction '
          'matching the current filters. Try lowering the score or source '
          'requirement.';
    }
    return 'None of the $geneCount gene(s) queried appears in the interaction '
        'database. Differentially expressed genes are frequently not druggable '
        'targets, so this is a common outcome.';
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.provider});

  final DataProvider provider;

  @override
  Widget build(BuildContext context) {
    final candidates = provider.candidates;
    final geneCount = provider.queriedGenes.length;
    final matchedGenes = <String>{};
    for (final candidate in candidates) {
      for (final hit in candidate.targets) {
        matchedGenes.add(hit.gene);
      }
    }
    final opposing =
        candidates.where((candidate) => candidate.opposingCount > 0).length;
    final multiTarget =
        candidates.where((candidate) => candidate.targetCount > 1).length;
    final isManual = provider.queriedSignature == null;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResearchUseBanner(dense: true),
          const SizedBox(height: 12),
          Text(
            '${candidates.length} drug${candidates.length == 1 ? '' : 's'} '
            'across ${matchedGenes.length} of $geneCount queried '
            'gene${geneCount == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          if (isManual)
            const Text(
              'Genes were entered manually, so no expression direction is '
              'available and no directional check was performed.',
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
            )
          else
            Text(
              '$opposing oppose the observed change on at least one gene'
              '${multiTarget == 0 ? '.' : '; $multiTarget hit more than one gene.'}',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.isManualQuery});

  final DrugCandidate candidate;
  final bool isManualQuery;

  @override
  Widget build(BuildContext context) {
    final showsReinforcementWarning =
        candidate.reinforcingCount > 0 && candidate.opposingCount == 0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.displayName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            if (candidate.isUnnamedCompound) ...[
              const SizedBox(height: 2),
              const Text(
                'ChEMBL accession only - no common name recorded',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(
                  icon: Icons.my_location,
                  label: '${candidate.targetCount} of your gene'
                      '${candidate.targetCount == 1 ? '' : 's'}',
                  background: AppColors.background,
                  tooltip: 'Genes from your query that this drug is recorded '
                      'against: ${candidate.targets.map((h) => h.gene).join(', ')}',
                ),
                if (!isManualQuery)
                  CandidateDirectionChip(candidate: candidate),
                CorroborationChip(interaction: candidate.primaryTarget.interaction),
                ApprovalChip(interaction: candidate.primaryTarget.interaction),
              ],
            ),
            if (showsReinforcementWarning) ...[
              const SizedBox(height: 12),
              ReinforcementWarning(candidate: candidate),
            ],
            const SizedBox(height: 4),
            _TargetBreakdown(
              candidate: candidate,
              isManualQuery: isManualQuery,
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable per-gene breakdown.
///
/// Collapsed by default so a promiscuous drug does not dominate the list, but
/// present inline because the per-gene direction is the substance of the result.
class _TargetBreakdown extends StatelessWidget {
  const _TargetBreakdown({
    required this.candidate,
    required this.isManualQuery,
  });

  final DrugCandidate candidate;
  final bool isManualQuery;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Strips the default ExpansionTile divider lines inside a card.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          candidate.targetCount == 1
              ? 'Target: ${candidate.primaryTarget.gene}'
              : 'Targets: ${candidate.targets.map((h) => h.gene).join(', ')}',
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          for (final hit in candidate.targets)
            _TargetRow(hit: hit, isManualQuery: isManualQuery),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrugProfileScreen(
                    interaction: candidate.primaryTarget.interaction,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Interaction detail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.hit, required this.isManualQuery});

  final TargetHit hit;
  final bool isManualQuery;

  @override
  Widget build(BuildContext context) {
    final interaction = hit.interaction;
    final direction = interaction.direction;

    return Padding
      (padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hit.gene,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              if (!isManualQuery) DirectionChip(match: hit.match, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (direction != PharmacologicDirection.unspecified)
                direction.label
              else
                'Mechanism not reported',
              if (hit.regulation != null) hit.regulation!.label,
              '${interaction.sourceCount} source'
                  '${interaction.sourceCount == 1 ? '' : 's'}',
            ].join('  -  '),
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
