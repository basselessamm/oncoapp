import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';
import 'drug_profile_screen.dart';

/// Results of a drug-name search.
///
/// The query now covers approved drugs too. It was previously restricted to
/// `is_novel = 1`, so searching for Cisplatin returned nothing and searching
/// for Aspirin returned only unrelated derivatives.
class DrugSearchScreen extends StatelessWidget {
  const DrugSearchScreen({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results: $searchQuery')),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          switch (provider.searchStatus) {
            case LoadStatus.loading:
            case LoadStatus.idle:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.failed:
              return StatusMessage(
                icon: Icons.error_outline,
                title: 'Search failed',
                detail: provider.searchError,
                onRetry: () => provider.searchDrugs(searchQuery),
              );
            case LoadStatus.ready:
              break;
          }

          final results = provider.searchResults;
          if (results.isEmpty) {
            return const StatusMessage(
              icon: Icons.search_off,
              title: 'No drug matched that name',
              detail: 'Names come from DGIdb source databases and are usually '
                  'the generic form, e.g. "Doxorubicin" rather than a brand '
                  'name.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const ResearchUseBanner(dense: true),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${results.length} drug'
                        '${results.length == 1 ? '' : 's'} matched',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final interaction = results[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DrugProfileScreen(interaction: interaction),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                interaction.isUnnamedCompound
                                    ? interaction.drug
                                        .replaceFirst('CHEMBL:', '')
                                    : interaction.drug,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ApprovalChip(interaction: interaction),
                                  if (interaction.targetCount != null)
                                    InfoChip(
                                      icon: Icons.scatter_plot_outlined,
                                      label:
                                          '${interaction.targetCount} target'
                                          '${interaction.targetCount == 1 ? '' : 's'}',
                                      background: AppColors.background,
                                      tooltip: 'Distinct genes this drug is '
                                          'recorded against. A high count '
                                          'indicates a non-selective or '
                                          'heavily studied compound.',
                                    ),
                                  MechanismChip(interaction: interaction),
                                  CorroborationChip(interaction: interaction),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
