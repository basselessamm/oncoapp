import 'package:flutter/material.dart';

import '../models/connectivity_evidence.dart';
import '../models/drug_candidate.dart';
import '../models/drug_interaction.dart';
import '../models/pharmacology.dart';
import '../models/target_evidence.dart';
import '../services/network/api_result.dart';
import '../theme/app_theme.dart';

/// Palette used across the app. Extracted so the values stop being repeated as
/// raw hex literals at every call site.
abstract final class AppColors {
  static const Color primary = Color(0xFFE91E63);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color primaryLight = Color(0xFFF48FB1);
  static const Color surfaceTint = Color(0xFFF8BBD0);
  static const Color background = Color(0xFFFCE4EC);
}

/// States the app must be able to tell apart when reporting a scientific
/// result: corroborated, single-source, and not reported at all.
abstract final class EvidenceColors {
  static const Color corroborated = Color(0xFF2E7D32);
  static const Color single = Color(0xFFEF6C00);
  static const Color unknown = Color(0xFF616161);

  /// Drug acts against the observed expression change.
  static const Color opposes = Color(0xFF00695C);

  /// Drug acts along with the observed change - a counter-indication.
  static const Color reinforces = Color(0xFFC62828);

  /// Strong disease association in Open Targets (score >= 0.30).
  static const Color strongAssociation = Color(0xFF1B5E20);

  /// Weak disease association in Open Targets (score 0.01 - 0.09).
  static const Color weakAssociation = Color(0xFF9E9D24);

  /// Strong LINCS transcriptomic reversal (q <= 0.05, score <= -0.30).
  static const Color strongReversal = Color(0xFF4A148C);

  /// Moderate LINCS transcriptomic reversal (q <= 0.10, score < 0.0).
  static const Color moderateReversal = Color(0xFF1565C0);

  /// Nominal LINCS reversal (p <= 0.05 or score < 0.0).
  static const Color nominalReversal = Color(0xFF00838F);

  /// LINCS perturbagen mimics the disease expression signature (score > 0.0).
  static const Color mimicWarning = Color(0xFFD84315);
}

/// Chip stating how a drug's direction of action relates to a gene's observed
/// expression change.
///
/// The direction check is the app's only inferential step, so it carries an
/// icon and a word rather than colour alone, and its tooltip states the
/// limitation that mRNA level is not protein activity.
class DirectionChip extends StatelessWidget {
  const DirectionChip({super.key, required this.match, this.dense = false});

  final DirectionalMatch match;

  /// Shorter label, for dense per-gene rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final (icon, color, short, arLabel) = switch (match) {
      DirectionalMatch.opposes => (
          Icons.swap_vert,
          EvidenceColors.opposes,
          'Opposes',
          'يعاكس',
        ),
      DirectionalMatch.reinforces => (
          Icons.trending_flat,
          EvidenceColors.reinforces,
          'Reinforces',
          'يعزز',
        ),
      DirectionalMatch.conflicting => (
          Icons.compare_arrows,
          EvidenceColors.single,
          'Conflicting',
          'متعارض',
        ),
      DirectionalMatch.undetermined => (
          Icons.help_outline,
          EvidenceColors.unknown,
          'Unknown',
          'غير محدد',
        ),
    };

    final label = isAr ? arLabel : (dense ? short : match.label);

    return InfoChip(
      dense: dense,
      icon: icon,
      label: label,
      background: color.withValues(alpha: 0.10),
      foreground: color,
      tooltip: '${match.explanation}\n\n'
          'Direction is inferred from the reported interaction type. mRNA '
          'level is not protein activity, and a dysregulated gene may be a '
          'passenger rather than a driver.',
    );
  }
}

/// Chip summarising a candidate drug's overall relationship to the signature.
class CandidateDirectionChip extends StatelessWidget {
  const CandidateDirectionChip({
    super.key,
    required this.candidate,
    this.dense = false,
  });

  final DrugCandidate candidate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final direction = candidate.overallDirection;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final (icon, color) = switch (direction) {
      CandidateDirection.opposing => (Icons.swap_vert, EvidenceColors.opposes),
      CandidateDirection.mixed => (
          Icons.compare_arrows,
          EvidenceColors.single,
        ),
      CandidateDirection.reinforcing => (
          Icons.trending_flat,
          EvidenceColors.reinforces,
        ),
      CandidateDirection.undetermined => (
          Icons.help_outline,
          EvidenceColors.unknown,
        ),
    };

    final opposing = candidate.opposingCount;
    final label = switch (direction) {
      CandidateDirection.opposing => isAr
          ? 'يعاكس $opposing من أصل ${candidate.targetCount}'
          : 'Opposes $opposing of ${candidate.targetCount}',
      CandidateDirection.mixed => isAr
          ? 'يعاكس $opposing، يعزز ${candidate.reinforcingCount}'
          : 'Opposes $opposing, reinforces ${candidate.reinforcingCount}',
      CandidateDirection.reinforcing => isAr ? 'يعزز الورم' : direction.label,
      _ => isAr ? 'غير محدد' : direction.label,
    };

    return InfoChip(
      dense: dense,
      icon: icon,
      label: label,
      background: color.withValues(alpha: 0.10),
      foreground: color,
      tooltip: direction.explanation,
    );
  }
}

/// Warning shown for candidates that only reinforce the observed dysregulation.
///
/// Kept visible rather than filtered out: it is a real counter-indication
/// signal, and previously such drugs were listed identically to opposing ones.
class ReinforcementWarning extends StatelessWidget {
  const ReinforcementWarning({super.key, required this.candidate});

  final DrugCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EvidenceColors.reinforces.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: EvidenceColors.reinforces.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: EvidenceColors.reinforces),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              candidate.reinforcingCount == candidate.targetCount
                  ? 'This drug pushes every matched gene further in the '
                      'direction it already moved. That argues against it as a '
                      'reversal candidate.'
                  : 'This drug reinforces the observed change on '
                      '${candidate.reinforcingCount} of '
                      '${candidate.targetCount} matched genes.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Color(0xFF8A1F1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standing notice that the app reports database records, not clinical advice.
///
/// Shown on the home screen and on every results surface. The app previously
/// presented placeholder values as findings with no statement of scope.
class ResearchUseBanner extends StatelessWidget {
  const ResearchUseBanner({super.key, this.dense = false});

  /// Compact single-line form, for use above a results list.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final border = theme.colorScheme.outline.withValues(alpha: 0.35);
    final text = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final iconColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.biotech_outlined, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr
                  ? (dense
                      ? 'منصة بحثية متخصصة: تفاعلات جينية ودوائية موثقة بقواعد البيانات المرجعية (Research use only).'
                      : 'منصة بحثية متخصصة: يعرض التطبيق تفاعلات الجينات والأدوية وأدلة المعاكسة النسخية الموثقة بقواعد البيانات المرجعية (Research use only).')
                  : (dense
                      ? 'Research use only. Documented interactions from reference databases, not treatment recommendations.'
                      : 'Research use only. This app reports gene-drug interactions recorded in public databases. It does not predict efficacy and must not be used to guide patient care.'),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// States that displayed data came from an expired cache because the network
/// was unreachable.
///
/// Shown whenever an [ApiSuccess] carries [DataFreshness.staleCache]. Presenting
/// month-old evidence as current would be the same class of error as the
/// placeholder docking scores this app used to display.
class OfflineDataBanner extends StatelessWidget {
  const OfflineDataBanner({
    super.key,
    required this.retrievedAt,
    this.onRetry,
  });

  /// When the cached response was originally received.
  final DateTime? retrievedAt;

  final VoidCallback? onRetry;

  /// Coarse age description. Exact timestamps imply a precision that does not
  /// matter here.
  static String describeAge(DateTime? retrievedAt) {
    if (retrievedAt == null) return 'from an earlier session';
    final age = DateTime.now().difference(retrievedAt);
    if (age.inMinutes < 60) return 'from ${age.inMinutes} min ago';
    if (age.inHours < 24) return 'from ${age.inHours} h ago';
    if (age.inDays == 1) return 'from yesterday';
    return 'from ${age.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 18, color: Color(0xFF455A64)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline copy ${describeAge(retrievedAt)}. The service could not '
              'be reached, so this may be out of date.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF37474F),
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip stating where a piece of external data came from.
class FreshnessChip extends StatelessWidget {
  const FreshnessChip({super.key, required this.freshness, this.retrievedAt});

  final DataFreshness freshness;
  final DateTime? retrievedAt;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (freshness) {
      DataFreshness.network => (Icons.cloud_done_outlined, EvidenceColors.corroborated),
      DataFreshness.freshCache => (Icons.save_outlined, EvidenceColors.unknown),
      DataFreshness.staleCache => (Icons.cloud_off_outlined, EvidenceColors.single),
    };

    return InfoChip(
      icon: icon,
      label: freshness.label,
      background: color.withValues(alpha: 0.10),
      foreground: color,
      tooltip: switch (freshness) {
        DataFreshness.network => 'Fetched from the service just now.',
        DataFreshness.freshCache =>
          'Served from this device\'s cache, still within its freshness window.',
        DataFreshness.staleCache =>
          'Served from an expired cache ${OfflineDataBanner.describeAge(retrievedAt)} '
              'because the service could not be reached.',
      },
    );
  }
}

/// Small labelled pill.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.border,
    this.icon,
    this.tooltip,
    this.dense = false,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final Color? border;
  final IconData? icon;
  final String? tooltip;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = foreground ??
        (isDark ? theme.colorScheme.onSurface : Colors.black87);
    final bg = background ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest
            : AppColors.surfaceTint);

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dense ? 6 : 8),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            SizedBox(width: dense ? 3.5 : 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 12,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

/// Chip stating how many independent databases report an interaction.
///
/// This is the strongest corroboration signal in the bundled dataset and was
/// previously unused: 90.8% of gene-drug pairs come from a single database.
class CorroborationChip extends StatelessWidget {
  const CorroborationChip({
    super.key,
    required this.interaction,
    this.dense = false,
  });

  final DrugInteraction interaction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final corroboration = interaction.corroboration;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final color = switch (corroboration) {
      Corroboration.corroborated => EvidenceColors.corroborated,
      Corroboration.replicated => EvidenceColors.corroborated,
      Corroboration.single => EvidenceColors.single,
      Corroboration.none => EvidenceColors.unknown,
    };

    final count = interaction.sourceCount;
    final label = count == 0
        ? (isAr ? 'غير موثق' : corroboration.label)
        : (isAr ? '$count مصادر' : '$count source${count == 1 ? '' : 's'}');

    return InfoChip(
      dense: dense,
      icon: Icons.hub_outlined,
      label: label,
      background: color.withValues(alpha: 0.10),
      foreground: color,
      tooltip: '${corroboration.explanation}.\n'
          '${interaction.sources.isEmpty ? '' : interaction.sources.join(', ')}',
    );
  }
}

/// Chip describing the mechanism of action, or its absence.
///
/// 64% of rows in the bundled database have no reported mechanism. Earlier
/// versions printed the literal text "NULL" here.
class MechanismChip extends StatelessWidget {
  const MechanismChip({
    super.key,
    required this.interaction,
    this.dense = false,
  });

  final DrugInteraction interaction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (interaction.hasUnknownMechanism) {
      return InfoChip(
        dense: dense,
        icon: Icons.help_outline,
        label: isAr ? 'الآلية غير مسجلة' : 'Mechanism not reported',
        background: const Color(0xFFEEEEEE),
        foreground: EvidenceColors.unknown,
        tooltip: 'No source database recorded an interaction type for this '
            'gene-drug pair.',
      );
    }
    return InfoChip(
      dense: dense,
      icon: Icons.settings_outlined,
      label: interaction.mechanismLabel!,
      background: AppColors.primaryLight.withValues(alpha: 0.30),
      tooltip: 'Interaction type as reported by '
          '${interaction.sources.join(', ')}.',
    );
  }
}

/// Chip stating regulatory approval status.
///
/// Replaces the "⭐ Novel" badge, which was derived from the inverse of DGIdb's
/// `approved` column and so meant "not FDA-approved" rather than "novel
/// repurposing candidate".
class ApprovalChip extends StatelessWidget {
  const ApprovalChip({
    super.key,
    required this.interaction,
    this.dense = false,
  });

  final DrugInteraction interaction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final approved = interaction.isApproved;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return InfoChip(
      dense: dense,
      icon: approved ? Icons.verified_outlined : Icons.biotech_outlined,
      label: approved
          ? (isAr ? 'معتمد FDA' : 'FDA-approved')
          : (isAr ? 'غير معتمد' : 'Not FDA-approved'),
      background: approved
          ? EvidenceColors.corroborated.withValues(alpha: 0.10)
          : const Color(0xFFE3F2FD),
      foreground:
          approved ? EvidenceColors.corroborated : const Color(0xFF1565C0),
      tooltip: approved
          ? 'At least one source database marks this drug as approved.'
          : 'No source database marks this drug as approved. This includes '
              'investigational and discontinued compounds; it is not a '
              'novelty assessment.',
    );
  }
}

/// Chip showing where the DGIdb interaction score falls in the database's own
/// distribution.
class DocumentationChip extends StatelessWidget {
  const DocumentationChip({super.key, required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    final strength = interaction.evidenceStrength;
    return InfoChip(
      icon: Icons.description_outlined,
      label: '${strength.label} (${interaction.score.toStringAsFixed(2)})',
      background: const Color(0xFFF3E5F5),
      foreground: const Color(0xFF6A1B9A),
      tooltip: '${strength.explanation}.\n'
          'The DGIdb interaction score measures how well documented an '
          'interaction is, not how effective the drug is.',
    );
  }
}

/// Full-surface message for empty, failed, and loading states.
///
/// Failures were previously indistinguishable from empty results, because the
/// provider swallowed exceptions and left the list empty.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(isAr ? 'إعادة المحاولة' : 'Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Titled card used for detail rows on the drug profile.
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.footnote,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Optional smaller line clarifying what the value does and does not mean.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardTheme.color ??
        (isDark ? const Color(0xFF172033) : Colors.white);
    final borderColor =
        isDark ? const Color(0xFF2E3A52) : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                child,
                if (footnote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    footnote!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading, previously copy-pasted as an inline `TextStyle` in six
/// places.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip showing target-disease association strength from Open Targets.
class AssociationChip extends StatelessWidget {
  const AssociationChip({
    super.key,
    required this.evidence,
    this.dense = false,
  });

  final TargetEvidence evidence;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final strength = evidence.associationStrength;
    final score = evidence.associationScore;
    final color = switch (strength) {
      AssociationStrength.strong => EvidenceColors.strongAssociation,
      AssociationStrength.moderate => EvidenceColors.corroborated,
      AssociationStrength.weak => EvidenceColors.weakAssociation,
      AssociationStrength.negligible => EvidenceColors.single,
      AssociationStrength.notReported => EvidenceColors.unknown,
    };

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arStrengthLabel = switch (strength) {
      AssociationStrength.strong => 'ارتباط قوي',
      AssociationStrength.moderate => 'ارتباط متوسط',
      AssociationStrength.weak => 'ارتباط ضعيف',
      AssociationStrength.negligible => 'ارتباط ضئيل',
      AssociationStrength.notReported => 'غير مسجل',
    };

    final label = score != null
        ? '${isAr ? arStrengthLabel : strength.label} (${score.toStringAsFixed(2)})'
        : (isAr ? arStrengthLabel : strength.label);

    return InfoChip(
      dense: dense,
      icon: Icons.public,
      label: dense && score != null ? 'OT: ${score.toStringAsFixed(2)}' : label,
      background: color.withValues(alpha: 0.12),
      foreground: color,
      tooltip: '${strength.explanation}\n\n'
          'Open Targets target-disease association score (calibrated empirical scale). '
          'enableIndirect: true inherits evidence from child disease ontology terms.',
    );
  }
}

/// Chip displaying target tractability / druggability assessment.
class TractabilityChip extends StatelessWidget {
  const TractabilityChip({
    super.key,
    required this.evidence,
  });

  final TargetEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final tier = evidence.bestTractability;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arTier = switch (tier) {
      TractabilityTier.approvedDrug => 'دواء معتمد',
      TractabilityTier.advancedClinical => 'تجارب سريرية متقدمة',
      TractabilityTier.phase1Clinical => 'مرحلة أولى سريرية',
      TractabilityTier.preclinicalEvidence => 'أدلة ما قبل سريرية',
      TractabilityTier.noEvidence => 'لا توجد أدلة',
    };
    final color = switch (tier) {
      TractabilityTier.approvedDrug => EvidenceColors.corroborated,
      TractabilityTier.advancedClinical => EvidenceColors.corroborated,
      TractabilityTier.phase1Clinical => EvidenceColors.single,
      TractabilityTier.preclinicalEvidence => EvidenceColors.single,
      TractabilityTier.noEvidence => EvidenceColors.unknown,
    };

    return InfoChip(
      icon: Icons.biotech_outlined,
      label: isAr ? arTier : tier.label,
      background: color.withValues(alpha: 0.12),
      foreground: color,
      tooltip: tier.explanation,
    );
  }
}

/// Chip displaying the highest clinical development stage for a candidate.
class ClinicalStageChip extends StatelessWidget {
  const ClinicalStageChip({
    super.key,
    required this.candidate,
  });

  final ClinicalCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final stage = candidate.stage;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arStage = switch (stage) {
      ClinicalStage.approval => 'معتمد رسمياً',
      ClinicalStage.preApproval => 'ما قبل الاعتماد',
      ClinicalStage.phase3 => 'المرحلة السريرية 3',
      ClinicalStage.phase2 => 'المرحلة السريرية 2',
      ClinicalStage.phase1 => 'المرحلة السريرية 1',
      ClinicalStage.unknown => 'غير محدد',
    };
    final color = stage.rank >= ClinicalStage.approval.rank
        ? EvidenceColors.corroborated
        : (stage.rank >= ClinicalStage.phase1.rank
            ? const Color(0xFF1565C0)
            : EvidenceColors.unknown);

    return InfoChip(
      icon: Icons.local_hospital_outlined,
      label: isAr ? arStage : stage.label,
      background: color.withValues(alpha: 0.10),
      foreground: color,
      tooltip: 'Open Targets maximum clinical trial stage: ${stage.label}.',
    );
  }
}

/// Warning banner shown when evidence suggests a target may be a passenger rather than a driver.
class PassengerWarning extends StatelessWidget {
  const PassengerWarning({super.key, required this.evidence});

  final TargetEvidence evidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا يوجد دليل منشور يربط هذا الجين بالمرض المحدد. قد يكون تغيّر التعبير نتيجة للورم لا سبباً له.\n'
              'No published evidence links this gene to the selected disease. '
              'The observed expression change may be a consequence of tumourigenesis rather than a cause.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Color(0xFF7A3E00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notice explaining that external evidence is unavailable, with guidance or retry.
class EvidenceUnavailableNote extends StatelessWidget {
  const EvidenceUnavailableNote({
    super.key,
    required this.reason,
    this.onEnable,
  });

  final NetworkFailureReason reason;
  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context) {
    final isConsent = reason == NetworkFailureReason.consentNotGranted;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConsent ? const Color(0xFFE3F2FD) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConsent ? const Color(0xFF90CAF9) : const Color(0xFFFFCDD2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConsent ? Icons.lock_outline : Icons.cloud_off_outlined,
            size: 16,
            color: isConsent ? const Color(0xFF1565C0) : const Color(0xFFC62828),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConsent
                  ? (isAr
                      ? 'الأدلة الخارجية للأهداف متوقفة. فعّل الاستعلامات في الإعدادات للاتصال بـ Open Targets.'
                      : 'External target evidence is disabled. Enable lookups in Settings to connect to Open Targets.')
                  : (isAr
                      ? 'تعذر جلب أدلة Open Targets الخارجية. يتم عرض السجلات المحلية المخزنة.'
                      : 'Unable to retrieve Open Targets evidence. Showing local records.'),
              style: TextStyle(
                fontSize: 12,
                color: isConsent ? const Color(0xFF0D47A1) : const Color(0xFF8A1F1F),
              ),
            ),
          ),
          if (onEnable != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onEnable,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(isConsent ? (isAr ? 'الإعدادات' : 'Settings') : (isAr ? 'إعادة المحاولة' : 'Retry')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip displaying LINCS L1000 whole-transcriptome signature reversal score and tier.
class ConnectivityScoreChip extends StatelessWidget {
  const ConnectivityScoreChip({
    super.key,
    required this.evidence,
    this.dense = false,
  });

  final LincsEvidence evidence;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<EvidenceThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? EvidenceThemeColors.dark
            : EvidenceThemeColors.light);

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final (label, icon, color, bg, border) = switch (evidence.tier) {
      ReversalTier.strongReversal => (
          dense
              ? (isAr ? 'معاكسة ${evidence.formattedScore}' : 'Reversal ${evidence.formattedScore}')
              : (isAr ? 'معاكسة قوية ${evidence.formattedScore}' : 'Strong Reversal ${evidence.formattedScore}'),
          Icons.published_with_changes_rounded,
          ext.strongReversalInk,
          ext.strongReversalSurface,
          ext.strongReversalBorder,
        ),
      ReversalTier.moderateReversal => (
          dense
              ? (isAr ? 'معاكسة ${evidence.formattedScore}' : 'Reversal ${evidence.formattedScore}')
              : (isAr ? 'معاكسة متوسطة ${evidence.formattedScore}' : 'Moderate Reversal ${evidence.formattedScore}'),
          Icons.swap_vert_circle_outlined,
          ext.moderateReversalInk,
          ext.moderateReversalSurface,
          ext.moderateReversalBorder,
        ),
      ReversalTier.nominalReversal => (
          dense
              ? (isAr ? 'اسمية ${evidence.formattedScore}' : 'Nominal ${evidence.formattedScore}')
              : (isAr ? 'معاكسة اسمية ${evidence.formattedScore}' : 'Nominal Reversal ${evidence.formattedScore}'),
          Icons.tune_rounded,
          ext.nominalReversalInk,
          ext.nominalReversalSurface,
          ext.nominalReversalBorder,
        ),
      ReversalTier.mimic => (
          dense
              ? (isAr ? 'محاكاة +${(evidence.score * 100).toStringAsFixed(0)}%' : 'Mimic +${(evidence.score * 100).toStringAsFixed(0)}%')
              : (isAr ? 'محاكاة للورم (+${(evidence.score * 100).toStringAsFixed(0)}%)' : 'Signature Mimic (+${(evidence.score * 100).toStringAsFixed(0)}%)'),
          Icons.warning_amber_rounded,
          ext.mimicInk,
          ext.mimicSurface,
          ext.mimicBorder,
        ),
      ReversalTier.untested => (
          isAr ? 'غير مجرب' : 'Untested',
          Icons.help_outline_rounded,
          ext.neutralInk,
          ext.neutralSurface,
          ext.neutralBorder,
        ),
    };

    final tooltipParts = <String>[
      'LINCS L1000 transcriptomic connectivity score: ${evidence.score.toStringAsFixed(3)}',
    ];
    if (evidence.qval != null) {
      tooltipParts.add('FDR q-value: ${evidence.qval!.toStringAsExponential(2)}');
    } else if (evidence.pval != null) {
      tooltipParts.add('p-value: ${evidence.pval!.toStringAsExponential(2)}');
    }
    if (evidence.cellLine != null) {
      tooltipParts.add('Cell line: ${evidence.cellLine}');
    }
    if (evidence.isReversal) {
      tooltipParts.add('Opposes whole disease signature in cell assay.');
    } else {
      tooltipParts.add('Caution: Mimics disease expression profile.');
    }

    return Tooltip(
      message: tooltipParts.join('\n'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : 9,
          vertical: dense ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed card displaying LINCS L1000 connectivity metrics on the drug profile screen.
class LincsDetailsCard extends StatelessWidget {
  const LincsDetailsCard({super.key, required this.evidence});

  final LincsEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<EvidenceThemeColors>() ??
        (isDark ? EvidenceThemeColors.dark : EvidenceThemeColors.light);

    final cardBg = theme.cardTheme.color ??
        (isDark ? const Color(0xFF172033) : Colors.white);
    final borderColor =
        isDark ? const Color(0xFF2E3A52) : Colors.grey.shade200;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final normalizedProgress = ((evidence.score + 1.0) / 2.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.biotech_outlined,
                    size: 18,
                    color: ext.strongReversalInk,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'المعاكسة النسخية (LINCS L1000)' : 'Transcriptomic Reversal (LINCS L1000)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              ConnectivityScoreChip(evidence: evidence),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'يقيس التشابه النسخي بين تأثير الدواء وبصمة الورم عبر مكتبة NIH LINCS L1000. الدرجات السالبة تعاكس تعبير الورم.'
                : 'Measures transcriptomic concordance with the tumor signature from the NIH LINCS L1000 library. Negative scores indicate therapeutic reversal.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'درجة الاتصال النسخي: ${evidence.score.toStringAsFixed(3)} (${evidence.formattedScore})'
                : 'Connectivity Score: ${evidence.score.toStringAsFixed(3)} (${evidence.formattedScore})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalizedProgress,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFEDE7F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                evidence.isReversal
                    ? ext.strongReversalInk
                    : ext.mimicInk,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? '-1.0 (معاكسة كاملة)' : '-1.0 (Full Reversal)',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '0.0',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                isAr ? '+1.0 (تعزيز كامل)' : '+1.0 (Full Mimic)',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (evidence.qval != null)
                _buildStatPill(
                  theme,
                  isAr ? 'قيمة FDR' : 'FDR q-value',
                  evidence.qval!.toStringAsExponential(2),
                ),
              if (evidence.pval != null)
                _buildStatPill(
                  theme,
                  isAr ? 'القيمة الاحتمالية p' : 'p-value',
                  evidence.pval!.toStringAsExponential(2),
                ),
              if (evidence.zscore != null)
                _buildStatPill(
                  theme,
                  isAr ? 'درجة z المعيارية' : 'z-score',
                  evidence.zscore!.toStringAsFixed(2),
                ),
              if (evidence.cellLine != null)
                _buildStatPill(theme, isAr ? 'خط الخلايا' : 'Cell line', evidence.cellLine!),
              if (evidence.durationHours != null)
                _buildStatPill(theme, isAr ? 'المدة' : 'Duration', '${evidence.durationHours}${isAr ? ' س' : 'h'}'),
              if (evidence.dose != null)
                _buildStatPill(theme, isAr ? 'التركيز' : 'Concentration', '${evidence.dose} μM'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            evidence.isReversal
                ? 'Drug perturbation induces transcriptomic changes that oppose the overall tumor signature in vitro, indicating therapeutic reversal potential.'
                : 'Caution: In vitro drug exposure produces gene expression changes correlated with the tumor phenotype.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: evidence.isReversal ? ext.strongReversalInk : ext.mimicInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Ultra-compact, high-density HUD strip designed specifically for candidate drug cards.
/// Displays key quantitative signals in one streamlined row:
/// [Overall Direction] • [Targets] • [Open Targets OT Score] • [LINCS Reversal %] • [Approval]
class CandidateMiniHud extends StatelessWidget {
  const CandidateMiniHud({
    super.key,
    required this.candidate,
    required this.isManualQuery,
    this.primaryEvidence,
    this.lincsEvidence,
  });

  final DrugCandidate candidate;
  final bool isManualQuery;
  final TargetEvidence? primaryEvidence;
  final LincsEvidence? lincsEvidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<EvidenceThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? EvidenceThemeColors.dark
            : EvidenceThemeColors.light);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!isManualQuery)
          CandidateDirectionChip(candidate: candidate, dense: true),
        InfoChip(
          dense: true,
          icon: Icons.my_location,
          label: isAr
              ? '${candidate.targetCount} أهداف'
              : '${candidate.targetCount} targets',
          background: theme.colorScheme.surfaceContainerHighest,
        ),
        if (primaryEvidence?.associationScore != null)
          InfoChip(
            dense: true,
            icon: Icons.public,
            label: 'OT ${primaryEvidence!.associationScore!.toStringAsFixed(2)}',
            background: ext.strongAssociationSurface,
            foreground: ext.strongAssociationInk,
            border: ext.strongAssociationBorder,
          ),
        if (lincsEvidence != null)
          ConnectivityScoreChip(evidence: lincsEvidence!, dense: true),
        ApprovalChip(
          interaction: candidate.primaryTarget.interaction,
          dense: true,
        ),
      ],
    );
  }
}

