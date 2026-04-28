import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drug_interaction.dart';
import '../services/database_service.dart';
import '../models/cancer_signature.dart';

class DataProvider with ChangeNotifier {
  List<CancerSignature> datasets = [];
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
          print("Error loading JSON $path: $e");
        }
      }

      if (datasets.isNotEmpty) selectedDataset = datasets.first;
    } catch (e) {
      print("Error loading datasets: $e");
    }

    isLoading = false;
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

  Future<void> fetchRecommendationsFromDB() async {
    isLoading = true;
    notifyListeners();

    List<String> genesToSearch = [];

    if (isManualMode && manualGenes.isNotEmpty) {
      genesToSearch = manualGenes;
    } else if (selectedDataset != null) {
      genesToSearch = selectedDataset!.significantGenes.map((g) => g.symbol).toList();
    }

    aiRecommendations = await DatabaseService().getDrugsForGenes(genesToSearch);

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
