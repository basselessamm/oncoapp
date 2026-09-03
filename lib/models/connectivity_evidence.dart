/// Models for LINCS L1000 transcriptomic perturbation evidence and connectivity scores.
library;

/// Tiers describing the therapeutic potential of a drug's signature reversal.
enum ReversalTier {
  /// Statistically significant opposing signature (q <= 0.05, score <= -0.30).
  strongReversal,

  /// Corroborated opposing signature (q <= 0.10, score < 0.0).
  moderateReversal,

  /// Nominal or uncorrected opposing signature (p <= 0.05 or score < 0.0).
  nominalReversal,

  /// Drug mimics the disease expression profile (score > 0.0). Warning: may exacerbate disease.
  mimic,

  /// Drug has not been profiled in the LINCS L1000 library.
  untested,
}

/// Transcriptomic connectivity evidence connecting a drug candidate to a cancer signature.
class LincsEvidence {
  const LincsEvidence({
    required this.drugName,
    required this.score,
    this.pval,
    this.qval,
    this.zscore,
    this.combinedScore,
    this.sigId,
    this.cellLine,
    this.durationHours,
    this.dose,
  });

  /// Canonical drug name (e.g. "TAMOXIFEN").
  final String drugName;

  /// Connectivity score from LINCS / L1000FWD.
  ///
  /// Negative scores indicate an opposing (reversal) profile (therapeutic potential).
  /// Positive scores indicate a mimicking profile (may exacerbate the disease phenotype).
  final double score;

  /// P-value of the signature concordance/discordance.
  final double? pval;

  /// False Discovery Rate (FDR) adjusted q-value.
  final double? qval;

  /// Standardized z-score.
  final double? zscore;

  /// Combined score balancing effect size and statistical significance.
  final double? combinedScore;

  /// Internal L1000FWD signature identifier (e.g. "CPC008_MCF7_24H:BRD-K...").
  final String? sigId;

  /// Cell line assayed (e.g. "MCF7", "MDAMB231", "PC3").
  final String? cellLine;

  /// Treatment duration in hours (e.g. 6 or 24).
  final int? durationHours;

  /// Drug concentration in micromolar (e.g. 10.0).
  final double? dose;

  /// Classifies the therapeutic reversal tier.
  ReversalTier get tier {
    if (score > 0) return ReversalTier.mimic;

    final q = qval;
    final p = pval;

    if (q != null && q <= 0.05 && score <= -0.30) {
      return ReversalTier.strongReversal;
    }
    if (q != null && q <= 0.10 && score < 0.0) {
      return ReversalTier.moderateReversal;
    }
    if ((p != null && p <= 0.05) || score < 0.0) {
      return ReversalTier.nominalReversal;
    }
    return ReversalTier.untested;
  }

  /// True if the drug statistically significantly reverses the cancer signature.
  bool get isSignificantReversal =>
      tier == ReversalTier.strongReversal || tier == ReversalTier.moderateReversal;

  /// True if the drug is an opposing (reversal) perturbagen.
  bool get isReversal => score < 0;

  /// Formatted percentage string of the reversal strength (e.g. "-75.4%").
  String get formattedScore => '${(score * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
        'drugName': drugName,
        'score': score,
        'pval': pval,
        'qval': qval,
        'zscore': zscore,
        'combinedScore': combinedScore,
        'sigId': sigId,
        'cellLine': cellLine,
        'durationHours': durationHours,
        'dose': dose,
      };

  factory LincsEvidence.fromJson(Map<String, dynamic> json) {
    return LincsEvidence(
      drugName: json['drugName'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      pval: (json['pval'] as num?)?.toDouble(),
      qval: (json['qval'] as num?)?.toDouble(),
      zscore: (json['zscore'] as num?)?.toDouble(),
      combinedScore: (json['combinedScore'] as num?)?.toDouble(),
      sigId: json['sigId'] as String?,
      cellLine: json['cellLine'] as String?,
      durationHours: (json['durationHours'] as num?)?.toInt(),
      dose: (json['dose'] as num?)?.toDouble(),
    );
  }

  /// Parses cell line, duration, and dose from standard L1000 `sig_id` if available.
  ///
  /// Format: `[batch]_[cellLine]_[duration]H:[pert_id]:[dose]`
  /// Example: `CPC008_MCF7_24H:BRD-K93754473-001-01-4:10`
  static ({String? cellLine, int? durationHours, double? dose}) parseSigIdMetadata(
      String sigId) {
    try {
      final parts = sigId.split(':');
      String? cell;
      int? dur;
      double? d;

      if (parts.isNotEmpty) {
        final prefix = parts[0].split('_');
        if (prefix.length >= 3) {
          cell = prefix[1];
          final timeStr = prefix[2].replaceAll(RegExp(r'[^0-9]'), '');
          dur = int.tryParse(timeStr);
        }
      }

      if (parts.length >= 3) {
        d = double.tryParse(parts.last);
      }

      return (cellLine: cell, durationHours: dur, dose: d);
    } catch (_) {
      return (cellLine: null, durationHours: null, dose: null);
    }
  }

  @override
  String toString() =>
      'LincsEvidence(drug: $drugName, score: $score, tier: $tier, cell: $cellLine)';
}
