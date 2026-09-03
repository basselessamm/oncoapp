import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/cancer_signature.dart';
import '../models/drug_candidate.dart';
import '../models/drug_interaction.dart';
import '../services/database_service.dart';
import '../services/lab_storage_service.dart';

/// Outcome of an asynchronous load, so the UI can tell "still working" and
/// "failed" apart from "succeeded with nothing to show".
///
/// The previous implementation used bare `bool` flags, which made every failure
/// indistinguishable from an empty result - a query that threw rendered as
/// "No results found for these genes."
enum LoadStatus { idle, loading, ready, failed }

class DataProvider with ChangeNotifier {
  /// Signatures bundled with the app.
  List<CancerSignature> datasets = const [];

  /// Signatures the user derived from their own uploaded study files.
  List<CancerSignature> labStudies = const [];

  CancerSignature? selectedDataset;

  List<String> manualGenes = const [];
  bool isManualMode = false;

  LoadStatus datasetStatus = LoadStatus.idle;
  String? datasetError;

  /// Gene-drug interactions for the active gene set, one row per (gene, drug).
  ///
  /// Named for what it is: a database lookup result. It was previously called
  /// `aiRecommendations`, but nothing recommends anything and no model is
  /// involved - see [findInteractionsForGenes].
  List<DrugInteraction> interactionResults = const [];

  /// [interactionResults] grouped one entry per drug, with a directional
  /// verdict per target. This is what the results screen renders.
  List<DrugCandidate> candidates = const [];

  /// Gene symbols sent to the last lookup.
  List<String> queriedGenes = const [];

  /// Signature backing the last lookup, or `null` when genes were typed in.
  ///
  /// Held separately from [selectedDataset] so the results screen keeps
  /// describing the query that produced it after the user changes selection.
  CancerSignature? queriedSignature;

  LoadStatus interactionStatus = LoadStatus.idle;
  String? interactionError;

  List<DrugInteraction> searchResults = const [];
  LoadStatus searchStatus = LoadStatus.idle;
  String? searchError;

  /// Filters used for the most recent interaction lookup, for display on the
  /// results screen.
  InteractionFilters lastFilters = const InteractionFilters();

  final DatabaseService _database;

  DataProvider({DatabaseService? database})
      : _database = database ?? DatabaseService();

  /// Signature files shipped in `assets/data/`.
  ///
  /// `basal_vs_normal_unfiltered.json` is deliberately absent: it holds 19,499
  /// unfiltered genes with no direction column, is 4.1 MB, and was never
  /// loaded. It is no longer bundled either.
  static const List<String> signatureAssets = [
    'assets/data/Breast_Invasive_Carcinoma_TCGA/tcga_signatures.json',
    'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/basal_like1_vs_mesenchymal.json',
    'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/immunomodulatory_vs_luminal_androgen.json',
    'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/mesenchymal_vs_immunomodulatory.json',
  ];

  bool get isLoadingDatasets => datasetStatus == LoadStatus.loading;

  /// Gene symbols the next lookup will use.
  List<String> get activeGenes {
    if (isManualMode) return manualGenes;
    final dataset = selectedDataset;
    if (dataset == null) return const [];
    return dataset.significantGenes
        .map((gene) => gene.symbol.toUpperCase())
        .toList();
  }

  Future<void> loadData() async {
    datasetStatus = LoadStatus.loading;
    datasetError = null;
    notifyListeners();

    final loaded = <CancerSignature>[];
    final failures = <String>[];

    for (final path in signatureAssets) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = json.decode(raw) as List<dynamic>;
        loaded.addAll(decoded
            .cast<Map<String, dynamic>>()
            .map(CancerSignature.fromJson));
      } catch (error) {
        failures.add(path.split('/').last);
        debugPrint('Failed to load signature asset $path: $error');
      }
    }

    datasets = loaded;
    if (loaded.isNotEmpty) selectedDataset = loaded.first;

    try {
      labStudies = await LabStorageService.loadAllStudies();
    } catch (error) {
      failures.add('saved lab studies');
      debugPrint('Failed to load lab studies: $error');
    }

    if (loaded.isEmpty) {
      datasetStatus = LoadStatus.failed;
      datasetError = 'No reference signatures could be loaded. '
          'The app data may be damaged; reinstalling will restore it.';
    } else {
      datasetStatus = LoadStatus.ready;
      datasetError = failures.isEmpty
          ? null
          : 'Could not load: ${failures.join(', ')}.';
    }
    notifyListeners();
  }

  Future<void> addLabStudy(CancerSignature study) async {
    await LabStorageService.saveStudy(study);
    labStudies = [...labStudies, study];
    selectedDataset = study;
    isManualMode = false;
    notifyListeners();
  }

  Future<void> deleteLabStudy(CancerSignature study) async {
    await LabStorageService.deleteStudy(study.id);
    labStudies = labStudies.where((s) => s.id != study.id).toList();
    if (selectedDataset?.id == study.id) {
      selectedDataset =
          datasets.isNotEmpty ? datasets.first : labStudies.firstOrNull;
    }
    notifyListeners();
  }

  void selectDataset(CancerSignature dataset) {
    selectedDataset = dataset;
    isManualMode = false;
    notifyListeners();
  }

  /// Parses a comma-separated gene list.
  ///
  /// Returns `true` when the parsed set changed, so callers bound to a text
  /// field can skip notifying on keystrokes that do not alter the gene set.
  bool setManualGenes(String input) {
    final parsed = input
        .split(RegExp(r'[,\s;]+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();

    final changed = !listEquals(parsed, manualGenes) ||
        isManualMode != parsed.isNotEmpty;
    if (!changed) return false;

    manualGenes = parsed;
    isManualMode = parsed.isNotEmpty;
    notifyListeners();
    return true;
  }

  /// Looks up every drug reported to interact with the active gene set, grouped
  /// one row per drug with a directional verdict per target.
  ///
  /// This is a database query plus a directional consistency check, not a
  /// prediction. It reports what DGIdb's source databases have recorded, then
  /// compares each drug's direction of action against the direction each gene
  /// moved in the study. It does not model pathways, protein activity, or the
  /// drug's targets outside the queried set.
  Future<void> findInteractionsForGenes({
    InteractionFilters filters = const InteractionFilters(),
  }) async {
    interactionStatus = LoadStatus.loading;
    interactionError = null;
    lastFilters = filters;
    // Captured now so the results screen describes the query that produced
    // them, even if the user changes the selection afterwards.
    queriedGenes = activeGenes;
    queriedSignature = isManualMode ? null : selectedDataset;
    notifyListeners();

    try {
      interactionResults = await _database.getDrugsForGenes(
        queriedGenes,
        onlyUnapproved: filters.onlyUnapproved,
        minScore: filters.minScore,
        minSourceCount: filters.minSourceCount,
      );
      candidates = DrugCandidate.group(
        interactionResults,
        signature: queriedSignature,
      );
      if (filters.onlyOpposing) {
        candidates = candidates
            .where((candidate) => candidate.opposingCount > 0)
            .toList();
      }
      interactionStatus = LoadStatus.ready;
    } on DrugDatabaseException catch (error) {
      interactionResults = const [];
      candidates = const [];
      interactionStatus = LoadStatus.failed;
      interactionError = error.message;
    } catch (error) {
      interactionResults = const [];
      candidates = const [];
      interactionStatus = LoadStatus.failed;
      interactionError = 'Unexpected error during lookup: $error';
    }
    notifyListeners();
  }

  Future<void> searchDrugs(String query) async {
    searchStatus = LoadStatus.loading;
    searchError = null;
    searchResults = const [];
    notifyListeners();

    try {
      searchResults = await _database.searchDrugsByName(query);
      searchStatus = LoadStatus.ready;
    } on DrugDatabaseException catch (error) {
      searchStatus = LoadStatus.failed;
      searchError = error.message;
    } catch (error) {
      searchStatus = LoadStatus.failed;
      searchError = 'Unexpected error during search: $error';
    }
    notifyListeners();
  }
}

/// User-selected filters for an interaction lookup.
class InteractionFilters {
  const InteractionFilters({
    this.onlyUnapproved = false,
    this.minScore = 0.0,
    this.minSourceCount = 1,
    this.onlyOpposing = false,
  });

  /// Exclude drugs that any source database marks as approved.
  final bool onlyUnapproved;

  /// Minimum DGIdb interaction score.
  final double minScore;

  /// Minimum number of independent source databases reporting the pair.
  final int minSourceCount;

  /// Keep only drugs that act against the observed change on at least one gene.
  ///
  /// Applied after grouping, since the verdict depends on the gene's fold
  /// change rather than on anything stored in the database.
  final bool onlyOpposing;

  bool get isDefault =>
      !onlyUnapproved &&
      minScore == 0.0 &&
      minSourceCount == 1 &&
      !onlyOpposing;

  InteractionFilters copyWith({
    bool? onlyUnapproved,
    double? minScore,
    int? minSourceCount,
    bool? onlyOpposing,
  }) {
    return InteractionFilters(
      onlyUnapproved: onlyUnapproved ?? this.onlyUnapproved,
      minScore: minScore ?? this.minScore,
      minSourceCount: minSourceCount ?? this.minSourceCount,
      onlyOpposing: onlyOpposing ?? this.onlyOpposing,
    );
  }
}
