import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../widgets/animated_entrance.dart';
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
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'نتائج البحث: $searchQuery' : 'Results: $searchQuery'),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          switch (provider.searchStatus) {
            case LoadStatus.loading:
            case LoadStatus.idle:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.failed:
              return StatusMessage(
                icon: Icons.error_outline,
                title: isAr ? 'فشل البحث' : 'Search failed',
                detail: provider.searchError,
                onRetry: () => provider.searchDrugs(searchQuery),
              );
            case LoadStatus.ready:
              break;
          }

          final results = provider.searchResults;
          if (results.isEmpty) {
            return StatusMessage(
              icon: Icons.search_off,
              title: isAr ? 'لم يطابق أي دواء هذا الاسم' : 'No drug matched that name',
              detail: isAr
                  ? 'الأسماء مأخوذة من قواعد بيانات DGIdb وغالباً ما تكون بالاسم العلمي الجنيس (مثلاً: "Doxorubicin" وليس الاسم التجاري).'
                  : 'Names come from DGIdb source databases and are usually the generic form, e.g. "Doxorubicin" rather than a brand name.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  children: [
                    const ResearchUseBanner(dense: true),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        isAr
                            ? 'تم العثور على ${results.length} دواء مطابق'
                            : '${results.length} drug${results.length == 1 ? '' : 's'} matched',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final interaction = results[index];
                    return InteractiveHoverCard(
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DrugProfileScreen(interaction: interaction),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        interaction.isUnnamedCompound
                                            ? interaction.drug
                                                .replaceFirst('CHEMBL:', '')
                                            : interaction.drug,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ApprovalChip(interaction: interaction, dense: true),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (interaction.targetCount != null)
                                      InfoChip(
                                        dense: true,
                                        icon: Icons.scatter_plot_outlined,
                                        label: isAr
                                            ? '${interaction.targetCount} أهداف'
                                            : '${interaction.targetCount} target${interaction.targetCount == 1 ? '' : 's'}',
                                        background: theme.colorScheme
                                            .surfaceContainerHighest,
                                        tooltip: isAr
                                            ? 'الجينات المتميزة المسجلة لهذا الدواء.'
                                            : 'Distinct genes this drug is recorded against.',
                                      ),
                                    MechanismChip(interaction: interaction, dense: true),
                                    CorroborationChip(interaction: interaction, dense: true),
                                  ],
                                ),
                              ],
                            ),
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
