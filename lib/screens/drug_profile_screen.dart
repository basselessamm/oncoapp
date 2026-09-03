import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../models/drug_interaction.dart';
import '../models/pharmacology.dart';
import '../providers/connectivity_provider.dart';
import '../providers/data_provider.dart';
import '../providers/evidence_provider.dart';
import '../services/network/api_result.dart';
import '../services/network/response_cache.dart';
import '../widgets/evidence_widgets.dart';
import 'settings_screen.dart';

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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withValues(alpha: 0.65);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تفاصيل التفاعل الدوائي' : 'Interaction Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(interaction: interaction),
            const SizedBox(height: 20),
            const ResearchUseBanner(),
            const SizedBox(height: 24),
            SectionHeading(
              isAr ? 'بيانات التفاعل المسجلة' : 'What the databases report',
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: 16),
            DetailCard(
              icon: Icons.settings_outlined,
              title: isAr ? 'آلية العمل الحيوية' : 'Mechanism of action',
              footnote: interaction.hasUnknownMechanism
                  ? (isAr
                      ? 'لم يسجل أي مصدر نوع التفاعل. ينطبق هذا على 64% من السجلات في قاعدة البيانات.'
                      : 'No source recorded an interaction type. This is the case for 64% of records in the bundled database.')
                  : (isAr
                      ? 'كما ورد في قواعد البيانات المرجعية المذكورة أدناه.'
                      : 'As reported by the source databases listed below.'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interaction.mechanismLabel ?? (isAr ? 'غير مسجلة' : 'Not reported'),
                    style: TextStyle(fontSize: 14, color: onSurface),
                  ),
                  if (interaction.direction !=
                      PharmacologicDirection.unspecified) ...[
                    const SizedBox(height: 6),
                    Text(
                      isAr
                          ? (switch (interaction.direction) {
                              PharmacologicDirection.suppresses => 'تثبيط الهدف',
                              PharmacologicDirection.activates => 'تنشيط الهدف',
                              PharmacologicDirection.conflicting => 'تقارير متضاربة',
                              PharmacologicDirection.unspecified => 'الآلية غير مسجلة',
                            })
                          : interaction.direction.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DetailCard(
              icon: Icons.hub_outlined,
              title: isAr ? 'توثيق وتكرار المصادر' : 'Corroboration',
              footnote: '${interaction.corroboration.explanation}. '
                  '${isAr ? "9.2% فقط من أزواج الجينات والأدوية موثقة في أكثر من مصدر." : "Only 9.2% of gene-drug pairs in this database are reported by more than one source."}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr
                        ? (interaction.sourceCount == 0 ? 'غير موثق' : '${interaction.sourceCount} مصادر موثقة')
                        : interaction.corroboration.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  if (interaction.sources.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      interaction.sources.join(', '),
                      style: TextStyle(fontSize: 13, color: onSurfaceMuted),
                    ),
                  ],
                ],
              ),
            ),
            DetailCard(
              icon: Icons.description_outlined,
              title: isAr ? 'درجة توثيق DGIdb' : 'DGIdb interaction score',
              footnote: isAr
                  ? 'تقيس مدى توثيق التفاعل ووزنه بالنسبة لعدد الشركاء، وليست مقياساً للفعالية أو الفعالية السريرية.'
                  : 'Measures how well documented the interaction is, weighted against how many partners the gene and drug have. It is not a measure of efficacy, potency, or clinical confidence. ${interaction.evidenceStrength.explanation}.',
              child: Text(
                '${interaction.score.toStringAsFixed(3)}  -  '
                '${interaction.evidenceStrength.label}',
                style: TextStyle(fontSize: 14, color: onSurface),
              ),
            ),
            DetailCard(
              icon: Icons.gavel_outlined,
              title: isAr ? 'الحالة التنظيمية والاعتماد' : 'Regulatory status',
              footnote: interaction.isApproved
                  ? (isAr
                      ? 'قاعدة بيانات واحدة على الأقل تدرج الدواء كمعتمد لدواعيه الخاصة (وليس بالضرورة لنوع السرطان قيد الدراسة).'
                      : 'At least one source database marks this drug as approved. Approval is for its own indication, not for the cancer type under study.')
                  : (isAr
                      ? 'لم يُسجل كمعتمد في المصادر. يشمل المركبات قيد البحث وتلك المتوقفة.'
                      : 'No source database marks this drug as approved. This includes investigational and discontinued compounds and is not an assessment of repurposing novelty.'),
              child: Text(
                isAr
                    ? (interaction.isApproved ? 'معتمد رسمياً' : 'مركب بحثي / غير معتمد')
                    : interaction.approvalLabel,
                style: TextStyle(fontSize: 14, color: onSurface),
              ),
            ),
            if (interaction.targetCount != null)
              DetailCard(
                icon: Icons.scatter_plot_outlined,
                title: isAr ? 'نطاق الأهداف الجينية' : 'Target breadth',
                footnote: interaction.targetCount! >= 20
                    ? (isAr
                        ? 'الدواء ذو الأهداف المتعددة قد يكون مدروساً بعمق أو غير انتقائي.'
                        : 'A drug with many recorded targets is either well studied or non-selective. Treat a single-gene match as weak evidence of a specific effect.')
                    : (isAr
                        ? 'عدد الجينات المتميزة المسجلة لهذا الدواء عبر قاعدة البيانات كاملة.'
                        : 'Number of distinct genes this drug is recorded against across the whole database.'),
                child: Text(
                  isAr
                      ? '${interaction.targetCount} جينات مسجلة'
                      : '${interaction.targetCount} gene${interaction.targetCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: onSurface),
                ),
              ),
            const SizedBox(height: 8),
            SectionHeading(
              isAr ? 'السياق مع مجموعتك الجينية' : 'Your gene set',
              icon: Icons.biotech_outlined,
            ),
            const SizedBox(height: 16),
            _GenomicContext(interaction: interaction),
            const SizedBox(height: 16),
            SectionHeading(
              isAr ? 'الأدلة الخارجية (Open Targets & LINCS)' : 'External evidence',
              icon: Icons.public,
            ),
            const SizedBox(height: 16),
            _ExternalEvidenceSection(interaction: interaction),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradColors = isDark
        ? [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ]
        : [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ];

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'تفاعل جيني دوائي مسجل' : 'REPORTED INTERACTION',
            style: TextStyle(
              color: isDark ? theme.colorScheme.primary : Colors.white70,
              letterSpacing: 1.2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
              color: isDark ? theme.colorScheme.surface : Colors.transparent,
              border: Border.all(
                  color: isDark ? theme.colorScheme.outline : Colors.white70),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAr ? 'الهدف الجيني: ${interaction.gene}' : 'Target: ${interaction.gene}',
              style: TextStyle(
                color: isDark ? theme.colorScheme.onSurface : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withValues(alpha: 0.65);

    return Consumer<DataProvider>(
      builder: (context, provider, _) {
        final dataset = provider.queriedSignature ??
            (provider.isManualMode ? null : provider.selectedDataset);

        if (dataset == null) {
          return DetailCard(
            icon: Icons.edit_outlined,
            title: isAr ? 'سياق التعبير الجيني' : 'Expression context',
            footnote: isAr
                ? 'أُدخلت الجينات يدوياً، لذلك لا يتوفر معامل التغير اللوغاريتمي لمقارنة اتجاه الدواء.'
                : 'Genes were entered manually, so there is no fold change to compare the drug\'s direction against.',
            child: Text(
              isAr ? 'غير متوفر' : 'Not available',
              style: TextStyle(fontSize: 14, color: onSurface),
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
            title: isAr ? 'سياق التعبير الجيني' : 'Expression context',
            footnote: isAr
                ? 'هذا الهدف ليس من ضمن الجينات في "${dataset.cancerName}".'
                : 'This target is not among the genes in "${dataset.cancerName}".',
            child: Text(
              isAr ? 'ليس في البصمة المحددة' : 'Not in the selected signature',
              style: TextStyle(fontSize: 14, color: onSurface),
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
              title: isAr ? 'فحص التوافق الاتجاهي' : 'Directional check',
              footnote: isAr
                  ? '${verdict.explanation}\n\nيقارن هذا الفحص اتجاه عمل الدواء باتجاه تغير الجين في الورم. إنه فحص توافق جزيئي وليس تنبؤاً سريرياً حتمياً.'
                  : "${verdict.explanation}\n\nThis compares the drug's reported direction of action against the direction this gene moved. It is a consistency check, not a prediction.",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DirectionChip(match: verdict),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isAr
                        ? '${switch (interaction.direction) {
                            PharmacologicDirection.suppresses => "مثبط للهدف",
                            PharmacologicDirection.activates => "منشط للهدف",
                            PharmacologicDirection.conflicting => "تأثير متضارب",
                            PharmacologicDirection.unspecified => "آلية غير مسجلة",
                          }}  مقابل  ${regulation == GeneRegulation.up ? "تعبير جيني مرتفع" : "تعبير جيني منخفض"} في هذه البصمة'
                        : '${interaction.direction.label}  vs  ${regulation.label.toLowerCase()} in this study',
                    style: TextStyle(fontSize: 13, color: onSurfaceMuted),
                  ),
                ],
              ),
            ),
            DetailCard(
              icon: Icons.show_chart,
              title: isAr ? 'مستويات التعبير في ${dataset.cancerName}' : 'Expression in ${dataset.cancerName}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(isAr ? 'الاتجاه' : 'Direction', match.type, onSurface),
                  _row(isAr ? 'تغير الطي (Log2FC)' : 'Log2 fold change', match.log2fc.toStringAsFixed(3), onSurface),
                  if (pValue != null)
                    _row(
                      match.adjustedPValue != null
                          ? (isAr ? 'القيمة الاحتمالية المصححة (FDR)' : 'Adjusted p-value')
                          : (isAr ? 'القيمة الاحتمالية (p-value)' : 'Raw p-value'),
                      pValue.toStringAsExponential(2),
                      onSurface,
                    ),
                  if (match.higherExpressionIn.isNotEmpty)
                    _row(isAr ? 'أعلى في' : 'Higher in', match.higherExpressionIn, onSurface),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 13.5, color: color),
      ),
    );
  }
}

class _ExternalEvidenceSection extends StatelessWidget {
  const _ExternalEvidenceSection({required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withValues(alpha: 0.65);

    return Consumer<EvidenceProvider>(
      builder: (context, provider, _) {
        if (provider.isConsentBlocked) {
          return EvidenceUnavailableNote(
            reason: NetworkFailureReason.consentNotGranted,
            onEnable: () {
              final cache = context.read<ResponseCache>();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(cache: cache)),
              );
            },
          );
        }

        final evidence = provider.evidenceFor(interaction.gene);
        final disease = provider.selectedDisease?.name ?? (isAr ? 'المرض المحدد' : 'selected disease');

        final connectivityProvider = context.watch<ConnectivityProvider>();
        final lincsEvidence = connectivityProvider.getEvidenceForDrug(interaction.drug);

        if (evidence == null && lincsEvidence == null) {
          return DetailCard(
            icon: Icons.info_outline,
            title: isAr ? 'أدلة Open Targets' : 'Open Targets evidence',
            footnote: isAr
                ? 'لا توجد سجلات خارجية محملة للجين ${interaction.gene} ضد $disease.'
                : 'No external evidence record loaded for ${interaction.gene} against $disease.',
            child: Text(
              isAr ? 'لا يوجد سجل خارجي' : 'No external record',
              style: TextStyle(fontSize: 14, color: onSurface),
            ),
          );
        }

        final dtScores = evidence?.datatypeScores ?? const {};
        final candidate = evidence?.mostAdvancedCandidate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (evidence != null) ...[
              DetailCard(
                icon: Icons.hub_outlined,
                title: isAr ? 'ارتباط الهدف بالمرض ($disease)' : 'Target-disease association ($disease)',
                footnote:
                    '${isAr ? "درجة الارتباط المعيارية في Open Targets:" : "Open Targets calibrated association score with enableIndirect: true."} '
                    '${evidence.associationStrength.explanation}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AssociationChip(evidence: evidence),
                        if (provider.freshness != null) ...[
                          const SizedBox(width: 8),
                          FreshnessChip(
                            freshness: provider.freshness!,
                            retrievedAt: provider.retrievedAt,
                          ),
                        ],
                      ],
                    ),
                    if (dtScores.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        isAr ? 'تفصيل الأدلة حسب نوع البيانات:' : 'Evidence breakdown by data type:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final entry in dtScores.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurfaceMuted,
                                ),
                              ),
                              Text(
                                entry.value.toStringAsFixed(3),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            DetailCard(
              icon: Icons.biotech_outlined,
              title: isAr ? 'قابلية استهداف الهدف (Tractability)' : 'Target tractability',
              footnote: evidence.bestTractability.explanation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TractabilityChip(evidence: evidence),
                  if (evidence.tractability.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final bucket in evidence.tractability)
                          if (bucket.value)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFC8E6C9),
                                ),
                              ),
                              child: Text(
                                '${bucket.modality}: ${bucket.label}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            DetailCard(
              icon: Icons.local_hospital_outlined,
              title: isAr ? 'المرشحات في التجارب السريرية' : 'Clinical pipeline candidate',
              footnote: candidate != null
                  ? (isAr
                      ? 'المرشح الأكثر تقدماً في التجارب السريرية المسجل لهذا الهدف في Open Targets.'
                      : 'Most advanced clinical trial candidate recorded for this target in Open Targets.')
                  : (isAr
                      ? 'لا توجد أدوية سريرية نشطة مسجلة لهذا الهدف في Open Targets.'
                      : 'No active clinical pipeline drug recorded in Open Targets.'),
              child: candidate != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              candidate.drugName ??
                                  candidate.drugId ??
                                  (isAr ? 'مرشح غير معروف' : 'Unknown candidate'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ClinicalStageChip(candidate: candidate),
                          ],
                        ),
                        if (candidate.drugType != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${isAr ? "النوع الجزيئي: " : "Modality: "}${candidate.drugType}',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceMuted,
                            ),
                          ),
                        ],
                        if (candidate.indications.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${isAr ? "دواعي الاستعمال: " : "Indications: "}${candidate.indications.take(3).join(", ")}'
                            '${candidate.indications.length > 3 ? "..." : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceMuted,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      isAr ? 'لا توجد مرشحات سريرية مسجلة' : 'No clinical candidates recorded',
                      style: TextStyle(fontSize: 14, color: onSurface),
                    ),
            ),
            ],
            if (lincsEvidence != null) ...[
              const SizedBox(height: 12),
              LincsDetailsCard(evidence: lincsEvidence),
            ],
          ],
        );
      },
    );
  }
}
