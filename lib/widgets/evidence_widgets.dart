import 'package:flutter/material.dart';

import '../models/drug_candidate.dart';
import '../models/drug_interaction.dart';
import '../models/pharmacology.dart';
import '../services/network/api_result.dart';

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
    final (icon, color, short) = switch (match) {
      DirectionalMatch.opposes => (
          Icons.swap_vert,
          EvidenceColors.opposes,
          'Opposes',
        ),
      DirectionalMatch.reinforces => (
          Icons.trending_flat,
          EvidenceColors.reinforces,
          'Reinforces',
        ),
      DirectionalMatch.conflicting => (
          Icons.compare_arrows,
          EvidenceColors.single,
          'Conflicting',
        ),
      DirectionalMatch.undetermined => (
          Icons.help_outline,
          EvidenceColors.unknown,
          'Unknown',
        ),
    };

    return InfoChip(
      icon: icon,
      label: dense ? short : match.label,
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
  const CandidateDirectionChip({super.key, required this.candidate});

  final DrugCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final direction = candidate.overallDirection;
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
      CandidateDirection.opposing =>
        'Opposes $opposing of ${candidate.targetCount}',
      CandidateDirection.mixed =>
        'Opposes $opposing, reinforces ${candidate.reinforcingCount}',
      _ => direction.label,
    };

    return InfoChip(
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: dense ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined,
              size: 18, color: Color(0xFFE65100)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dense
                  ? 'Research use only. Reported interactions, not treatment '
                      'recommendations.'
                  : 'Research use only. This app reports gene-drug interactions '
                      'recorded in public databases. It does not predict '
                      'efficacy and must not be used to guide patient care.',
              style: const TextStyle(
                fontSize: 12,
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
    this.background = AppColors.surfaceTint,
    this.foreground = Colors.black87,
    this.icon,
    this.tooltip,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
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
  const CorroborationChip({super.key, required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    final corroboration = interaction.corroboration;
    final color = switch (corroboration) {
      Corroboration.corroborated => EvidenceColors.corroborated,
      Corroboration.replicated => EvidenceColors.corroborated,
      Corroboration.single => EvidenceColors.single,
      Corroboration.none => EvidenceColors.unknown,
    };

    final count = interaction.sourceCount;
    return InfoChip(
      icon: Icons.hub_outlined,
      label: count == 0
          ? corroboration.label
          : '$count source${count == 1 ? '' : 's'}',
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
  const MechanismChip({super.key, required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    if (interaction.hasUnknownMechanism) {
      return const InfoChip(
        icon: Icons.help_outline,
        label: 'Mechanism not reported',
        background: Color(0xFFEEEEEE),
        foreground: EvidenceColors.unknown,
        tooltip: 'No source database recorded an interaction type for this '
            'gene-drug pair.',
      );
    }
    return InfoChip(
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
  const ApprovalChip({super.key, required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    final approved = interaction.isApproved;
    return InfoChip(
      icon: approved ? Icons.verified_outlined : Icons.biotech_outlined,
      label: interaction.approvalLabel,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                child,
                if (footnote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    footnote!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Colors.black54,
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
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}
