import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drug_interaction.dart';
import '../services/database_service.dart';
import '../models/cancer_signature.dart';
import '../services/lab_storage_service.dart';

class DataProvider with ChangeNotifier {
  List<CancerSignature> datasets = [];
  List<CancerSignature> labStudies = [];
  CancerSignature? selectedDataset;
  bool isLoading = true;
  List<String> manualGenes = [];
  bool isManualMode = false;
  
  List<DrugInteraction> aiRecommendations = []; 
  List<DrugInteraction> searchResults = [];
  bool isSearching = false;

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      List<String> filePaths = [
        'assets/data/Breast_Invasive_Carcinoma_TCGA/tcga_signatures.json',
        'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/basal_like1_vs_mesenchymal.json',
        'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/immunomodulatory_vs_luminal_androgen.json',
        'assets/data/Triple_Negative_Breast_Cancer_DLDCCC/mesenchymal_vs_immunomodulatory.json'
      ];
      
      datasets = [];
      for (String path in filePaths) {
        try {
          String jsonString = await rootBundle.loadString(path);
          final List<dynamic> jsonData = json.decode(jsonString);
          datasets.addAll(jsonData.map((i) => CancerSignature.fromJson(i)).toList());
        } catch (e) {
          debugPrint("Error loading JSON $path: $e");
        }
      }

      if (datasets.isNotEmpty) selectedDataset = datasets.first;
      
      await loadLabStudies();
    } catch (e) {
      debugPrint("Error loading datasets: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadLabStudies() async {
    try {
      labStudies = await LabStorageService.loadAllStudies();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading lab studies: $e");
    }
  }

  Future<void> addLabStudy(CancerSignature study) async {
    await LabStorageService.saveStudy(study);
    labStudies.add(study);
    selectedDataset = study;
    isManualMode = false;
    notifyListeners();
  }

  Future<void> deleteLabStudy(CancerSignature study) async {
    await LabStorageService.deleteStudy(study.cancerName);
    labStudies.removeWhere((s) => s.cancerName == study.cancerName);
    if (selectedDataset?.cancerName == study.cancerName) {
      selectedDataset = datasets.isNotEmpty ? datasets.first : (labStudies.isNotEmpty ? labStudies.first : null);
    }
    notifyListeners();
  }

  void selectDataset(CancerSignature dataset) {
    selectedDataset = dataset;
    isManualMode = false;
    notifyListeners();
  }

  void setManualGenes(String input) {
    if (input.trim().isEmpty) {
      isManualMode = false;
      manualGenes = [];
    } else {
      isManualMode = true;
      manualGenes = input.split(',').map((e) => e.trim().toUpperCase()).toList();
    }
    notifyListeners();
  }

  Future<void> fetchRecommendationsFromDB({bool onlyNovel = false, double minScore = 0.0}) async {
    isLoading = true;
    notifyListeners();

    List<String> genesToSearch = [];

    if (isManualMode && manualGenes.isNotEmpty) {
      genesToSearch = manualGenes;
    } else if (selectedDataset != null) {
      genesToSearch = selectedDataset!.significantGenes.map((g) => g.symbol.toUpperCase()).toList();
    }

    aiRecommendations = await DatabaseService().getDrugsForGenes(
      genesToSearch, 
      onlyNovel: onlyNovel, 
      minScore: minScore
    );

    isLoading = false;
    notifyListeners();
  }

  Future<void> searchNovelDrugs(String query) async {
    try {
      isSearching = true;
      searchResults = [];
      notifyListeners();

      searchResults = await DatabaseService().searchNovelDrugs(query);

      isSearching = false;
      notifyListeners();
    } catch (e) {
      isSearching = false;
      notifyListeners();
    }
  }
}
