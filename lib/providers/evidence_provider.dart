import 'package:flutter/foundation.dart';

import '../models/disease_option.dart';
import '../models/target_evidence.dart';
import '../services/network/api_result.dart';
import '../services/open_targets_service.dart';
import 'data_provider.dart' show LoadStatus;

/// Manages target evidence loaded from the Open Targets Platform.
///
/// Kept strictly separate from [DataProvider] to prevent network concerns
/// from polluting local SQLite database operations.
class EvidenceProvider with ChangeNotifier {
  EvidenceProvider({
    required OpenTargetsService service,
    DiseaseOption? initialDisease,
  })  : _service = service,
        selectedDisease =
            initialDisease ?? DiseaseOption.breastCancerDefaults.first;

  final OpenTargetsService _service;

  /// Target evidence indexed by uppercase gene symbol.
  Map<String, TargetEvidence> evidenceByGene = const {};

  /// Current loading state.
  LoadStatus status = LoadStatus.idle;

  /// Human-readable error message when [status] is [LoadStatus.failed].
  String? error;

  /// Specific failure reason to distinguish consent gates from network outages.
  NetworkFailureReason? failureReason;

  /// Provenance of the active evidence (Live network, fresh cache, or stale cache).
  DataFreshness? freshness;

  /// Timestamp when the underlying response was retrieved from Open Targets.
  DateTime? retrievedAt;

  /// Active disease context used for target-disease association scoring.
  DiseaseOption? selectedDisease;

  /// Last set of gene symbols passed to [loadEvidence], used when re-fetching
  /// after disease selection changes.
  List<String> lastQueriedGenes = const [];

  /// Whether evidence loading was blocked because external lookups are disabled
  /// in Settings.
  bool get isConsentBlocked =>
      failureReason == NetworkFailureReason.consentNotGranted;

  /// Looks up evidence for a single gene symbol, case-insensitively.
  TargetEvidence? evidenceFor(String gene) =>
      evidenceByGene[gene.trim().toUpperCase()];

  /// Loads target-disease evidence for [geneSymbols] against [selectedDisease].
  Future<void> loadEvidence(List<String> geneSymbols) async {
    final clean = geneSymbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    lastQueriedGenes = clean;

    if (clean.isEmpty) {
      evidenceByGene = const {};
      status = LoadStatus.ready;
      error = null;
      failureReason = null;
      freshness = null;
      retrievedAt = null;
      notifyListeners();
      return;
    }

    status = LoadStatus.loading;
    error = null;
    failureReason = null;
    notifyListeners();

    final diseaseId =
        selectedDisease?.id ?? DiseaseOption.breastCancerDefaults.first.id;

    final result = await _service.fetchEvidence(
      geneSymbols: clean,
      diseaseId: diseaseId,
    );

    switch (result) {
      case ApiSuccess(:final data, :final freshness, :final retrievedAt):
        evidenceByGene = data;
        this.freshness = freshness;
        this.retrievedAt = retrievedAt;
        status = LoadStatus.ready;
        error = null;
        failureReason = null;
        notifyListeners();

      case ApiFailure(:final reason, :final message):
        status = LoadStatus.failed;
        error = message;
        failureReason = reason;
        notifyListeners();
    }
  }

  /// Changes the disease context, clears previous evidence, and re-fetches
  /// if a gene query is currently active.
  void selectDisease(DiseaseOption disease) {
    if (selectedDisease == disease) return;

    selectedDisease = disease;
    evidenceByGene = const {};
    status = LoadStatus.idle;
    error = null;
    failureReason = null;
    freshness = null;
    retrievedAt = null;

    if (lastQueriedGenes.isNotEmpty) {
      loadEvidence(lastQueriedGenes);
    } else {
      notifyListeners();
    }
  }
}
