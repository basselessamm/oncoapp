import 'package:flutter/foundation.dart';
import 'package:onco_repurpose_ai/models/connectivity_evidence.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart' show LoadStatus;
import 'package:onco_repurpose_ai/services/lincs_service.dart';
import 'package:onco_repurpose_ai/services/network/api_result.dart';

/// Manages transcriptomic connectivity evidence (LINCS L1000) for active disease signatures.
class ConnectivityProvider with ChangeNotifier {
  ConnectivityProvider({
    required LincsService lincsService,
  }) : _lincsService = lincsService;

  final LincsService _lincsService;

  LoadStatus status = LoadStatus.idle;

  String? errorMessage;
  NetworkFailureReason? failureReason;

  DataFreshness? freshness;
  DateTime? retrievedAt;

  Map<String, LincsEvidence> evidenceByDrug = const {};

  String? _lastLoadedSignatureKey;

  /// True if connectivity lookup was blocked because user consent was not granted.
  bool get isConsentBlocked =>
      failureReason == NetworkFailureReason.consentNotGranted;

  /// Fetches LINCS connectivity scores for the specified signature up/down genes.
  Future<void> fetchForSignature({
    required String signatureKey,
    required List<String> upGenes,
    required List<String> downGenes,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _lastLoadedSignatureKey == signatureKey &&
        status == LoadStatus.ready) {
      return;
    }

    status = LoadStatus.loading;
    errorMessage = null;
    failureReason = null;
    notifyListeners();

    final result = await _lincsService.fetchConnectivity(
      upGenes: upGenes,
      downGenes: downGenes,
    );

    switch (result) {
      case ApiSuccess(:final data, :final freshness, :final retrievedAt):
        evidenceByDrug = data;
        this.freshness = freshness;
        this.retrievedAt = retrievedAt;
        _lastLoadedSignatureKey = signatureKey;
        status = LoadStatus.ready;
        errorMessage = null;
        failureReason = null;
        notifyListeners();

      case ApiFailure(:final message, :final reason):
        status = LoadStatus.failed;
        errorMessage = message;
        failureReason = reason;
        notifyListeners();
    }
  }

  /// Looks up connectivity evidence for a specific drug name (case-insensitive).
  LincsEvidence? getEvidenceForDrug(String drugName) {
    final clean = drugName.trim().toUpperCase();
    return evidenceByDrug[clean];
  }

  /// Clears stored connectivity evidence.
  void clear() {
    status = LoadStatus.idle;
    evidenceByDrug = const {};
    errorMessage = null;
    failureReason = null;
    freshness = null;
    retrievedAt = null;
    _lastLoadedSignatureKey = null;
    notifyListeners();
  }
}
