import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/disease_option.dart';
import '../models/drug_candidate.dart';
import '../models/pharmacology.dart';
import '../models/target_evidence.dart';
import '../providers/connectivity_provider.dart';
import '../providers/data_provider.dart';
import '../providers/evidence_provider.dart';
import '../services/network/api_result.dart';
import '../services/network/response_cache.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/evidence_widgets.dart';
import 'disease_picker_screen.dart';
import 'drug_profile_screen.dart';
import 'settings_screen.dart';

/// Candidate drugs for the queried gene set, one card per drug.
class InteractionResultsScreen extends StatefulWidget {
  const InteractionResultsScreen({super.key});

  @override
  State<InteractionResultsScreen> createState() =>
      _InteractionResultsScreenState();
}

class _InteractionResultsScreenState extends State<InteractionResultsScreen> {
  List<String>? _lastQueried;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataProvider = context.read<DataProvider>();
    final evidenceProvider = context.read<EvidenceProvider>();
    final connectivityProvider = context.read<ConnectivityProvider>();
    final genes = dataProvider.queriedGenes;
    if (genes.isNotEmpty && !listEquals(genes, _lastQueried)) {
      _lastQueried = List.from(genes);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          evidenceProvider.loadEvidence(genes);
          final sig = dataProvider.queriedSignature;
          if (sig != null &&
              (sig.upregulatedGenes.isNotEmpty ||
                  sig.downregulatedGenes.isNotEmpty)) {
            connectivityProvider.fetchForSignature(
              signatureKey: sig.id,
              upGenes: sig.upregulatedGenes,
              downGenes: sig.downregulatedGenes,
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المرشحات الدوائية' : 'Candidate Drugs'),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          switch (provider.interactionStatus) {
            case LoadStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.failed:
              return StatusMessage(
                icon: Icons.error_outline,
                title: isAr ? 'فشل استرجاع التفاعلات' : 'Lookup failed',
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
              title: isAr ? 'لا توجد أدوية متفاعلة' : 'No candidates found',
              detail: _emptyDetail(provider, isAr),
            );
          }

          return Column(
            children: [
              _ResultsSummary(provider: provider),
              Expanded(
                child: AdaptiveCardGrid(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  itemCount: candidates.length,
                  itemBuilder: (context, index) => AnimatedEntrance(
                    index: index,
                    child: _CandidateCard(
                      candidate: candidates[index],
                      isManualQuery: provider.queriedSignature == null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _emptyDetail(DataProvider provider, bool isAr) {
    final geneCount = provider.queriedGenes.length;
    final filters = provider.lastFilters;
    if (filters.onlyOpposing) {
      return isAr
          ? 'لم يتم العثور على أدوية تعاكس اتجاه التغير لأي من الجينات الـ $geneCount المستعلم عنها. قم بإلغاء تفعيل فلتر "المعاكسة فقط" للاطلاع على سائر التفاعلات.'
          : 'No drug was found that acts against the direction of change on '
              'any of the $geneCount gene(s) queried. Turn off the '
              '"opposing only" filter to see the remaining interactions.';
    }
    if (!filters.isDefault) {
      return isAr
          ? 'لا يوجد تفاعل لأي من الجينات الـ $geneCount يطابق الفلاتر الحالية. جرب خفض حد الدرجة أو عدد المصادر.'
          : 'None of the $geneCount gene(s) queried has an interaction '
              'matching the current filters. Try lowering the score or source '
              'requirement.';
    }
    return isAr
        ? 'لا يظهر أي من الجينات الـ $geneCount في قاعدة بيانات التفاعلات. جينات التعبير التفريقي الشديد غالباً ما تكون غير قابلة للاستهداف الدوائي.'
        : 'None of the $geneCount gene(s) queried appears in the interaction '
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

    final evidenceProvider = context.watch<EvidenceProvider>();
    final disease = evidenceProvider.selectedDisease ??
        DiseaseOption.breastCancerDefaults.first;

    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final summaryBg = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: summaryBg,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResearchUseBanner(dense: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.hub_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAr ? 'السياق المرضي: ${disease.name}' : 'Disease: ${disease.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DiseasePickerScreen(),
                  ),
                ),
                icon: const Icon(Icons.edit, size: 13),
                label: Text(isAr ? 'تغيير' : 'Change'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              if (evidenceProvider.freshness != null) ...[
                const SizedBox(width: 4),
                FreshnessChip(
                  freshness: evidenceProvider.freshness!,
                  retrievedAt: evidenceProvider.retrievedAt,
                ),
              ],
            ],
          ),
          if (evidenceProvider.freshness == DataFreshness.staleCache) ...[
            const SizedBox(height: 6),
            OfflineDataBanner(
              retrievedAt: evidenceProvider.retrievedAt,
              onRetry: () =>
                  evidenceProvider.loadEvidence(provider.queriedGenes),
            ),
          ],
          if (evidenceProvider.isConsentBlocked) ...[
            const SizedBox(height: 6),
            EvidenceUnavailableNote(
              reason: NetworkFailureReason.consentNotGranted,
              onEnable: () {
                final cache = context.read<ResponseCache>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(cache: cache),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            isAr
                ? '${candidates.length} دواء مرشح عبر ${matchedGenes.length} من أصل $geneCount جين مستعلم عنه'
                : '${candidates.length} drug${candidates.length == 1 ? '' : 's'} across ${matchedGenes.length} of $geneCount queried gene${geneCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          if (isManual)
            Text(
              isAr
                  ? 'أُدخلت الجينات يدوياً، لذلك لا يتوفر اتجاه تعبير ولم يتم فحص التوافق الاتجاهي.'
                  : 'Genes were entered manually, so no expression direction is available and no directional check was performed.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            )
          else
            Text(
              isAr
                  ? '$opposing أدوية تعاكس التغير الملاحظ في جين واحد على الأقل${multiTarget == 0 ? '.' : '؛ $multiTarget أدوية تستهدف أكثر من جين.'}'
                  : '$opposing oppose the observed change on at least one gene${multiTarget == 0 ? '.' : '; $multiTarget hit more than one gene.'}',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
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

    final evidenceProvider = context.watch<EvidenceProvider>();
    final primaryEvidence =
        evidenceProvider.evidenceFor(candidate.primaryTarget.gene);

    final connectivityProvider = context.watch<ConnectivityProvider>();
    final lincsEvidence =
        connectivityProvider.getEvidenceForDrug(candidate.drug);

    final allTargetsPassenger = candidate.targets.isNotEmpty &&
        candidate.targets.every((hit) {
          final ev = evidenceProvider.evidenceFor(hit.gene);
          return ev != null && ev.isLikelyPassenger;
        });

    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return InteractiveHoverCard(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Drug Name + Approval Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      candidate.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ApprovalChip(
                    interaction: candidate.primaryTarget.interaction,
                    dense: true,
                  ),
                ],
              ),
              if (candidate.isUnnamedCompound) ...[
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? 'رمز ChEMBL فقط - لا يوجد اسم شائع مسجل'
                      : 'ChEMBL accession only - no common name recorded',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Row 2: Dense Metrics Badges
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoChip(
                    dense: true,
                    icon: Icons.my_location,
                    label: isAr
                        ? '${candidate.targetCount} من جيناتك'
                        : '${candidate.targetCount} of your gene${candidate.targetCount == 1 ? '' : 's'}',
                    background: theme.colorScheme.surfaceContainerHighest,
                    tooltip: isAr
                        ? 'جينات استعلامك المسجلة لهذا الدواء: ${candidate.targets.map((h) => h.gene).join(', ')}'
                        : 'Genes from your query that this drug is recorded against: ${candidate.targets.map((h) => h.gene).join(', ')}',
                  ),
                  if (!isManualQuery)
                    CandidateDirectionChip(candidate: candidate, dense: true),
                  ApprovalChip(
                    interaction: candidate.primaryTarget.interaction,
                    dense: true,
                  ),
                  if (primaryEvidence != null)
                    AssociationChip(evidence: primaryEvidence),
                  if (lincsEvidence != null)
                    ConnectivityScoreChip(evidence: lincsEvidence, dense: true),
                ],
              ),

              if (showsReinforcementWarning) ...[
                const SizedBox(height: 8),
                ReinforcementWarning(candidate: candidate),
              ],
              if (allTargetsPassenger) ...[
                const SizedBox(height: 8),
                PassengerWarning(
                  evidence: primaryEvidence ??
                      TargetEvidence(
                        geneSymbol: candidate.primaryTarget.gene,
                        associationScore: null,
                        clinicalCandidateCount: 0,
                      ),
                ),
              ],

              const SizedBox(height: 6),

              // Row 3: Target Breakdown & Action
              _TargetBreakdown(
                candidate: candidate,
                isManualQuery: isManualQuery,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetBreakdown extends StatelessWidget {
  const _TargetBreakdown({
    required this.candidate,
    required this.isManualQuery,
  });

  final DrugCandidate candidate;
  final bool isManualQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final targetsTitle = candidate.targetCount == 1
        ? (isAr
            ? 'الهدف: ${candidate.primaryTarget.gene}'
            : 'Target: ${candidate.primaryTarget.gene}')
        : (isAr
            ? 'الأهداف: ${candidate.targets.map((h) => h.gene).join(', ')}'
            : 'Targets: ${candidate.targets.map((h) => h.gene).join(', ')}');

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 6),
        title: Text(
          targetsTitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.unfold_more_rounded,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        children: [
          for (final hit in candidate.targets)
            _TargetRow(hit: hit, isManualQuery: isManualQuery),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrugProfileScreen(
                    interaction: candidate.primaryTarget.interaction,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 13),
              label: Text(
                isAr ? 'عرض الملف الدوائي الكامل' : 'Full Drug Profile',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
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
    final theme = Theme.of(context);
    final interaction = hit.interaction;
    final direction = interaction.direction;

    final evidenceProvider = context.watch<EvidenceProvider>();
    final geneEvidence = evidenceProvider.evidenceFor(hit.gene);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              if (geneEvidence != null) ...[
                AssociationChip(evidence: geneEvidence, dense: true),
                const SizedBox(width: 6),
              ],
              if (!isManualQuery) DirectionChip(match: hit.match, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            () {
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              final mechText = switch (direction) {
                PharmacologicDirection.suppresses => isAr ? 'تثبيط الهدف' : direction.label,
                PharmacologicDirection.activates => isAr ? 'تنشيط الهدف' : direction.label,
                PharmacologicDirection.conflicting => isAr ? 'تقارير متضاربة' : direction.label,
                PharmacologicDirection.unspecified => isAr ? 'الآلية غير مسجلة' : 'Mechanism not reported',
              };
              final regText = hit.regulation == null
                  ? null
                  : (isAr
                      ? (hit.regulation == GeneRegulation.up
                          ? 'مفرط التعبير'
                          : 'منخفض التعبير')
                      : hit.regulation!.label);
              final sourceText = isAr
                  ? '${interaction.sourceCount} مصادر'
                  : '${interaction.sourceCount} source${interaction.sourceCount == 1 ? '' : 's'}';

              return [
                mechText,
                if (regText != null) regText,
                sourceText,
              ].join('  •  ');
            }(),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
