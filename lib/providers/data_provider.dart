import 'package:flutter/material.dart';
import '../models/cancer_signature.dart';
import '../models/drug_interaction.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';

class DataProvider with ChangeNotifier {
  final DataService _dataService = DataService();
  final DatabaseService _databaseService = DatabaseService();

  List<CancerSignature> _signatures = [];
  CancerSignature? _selectedSignature;
  
  List<DrugInteraction> _recommendedDrugs = [];
  
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _errorMessage;

  List<CancerSignature> get signatures => _signatures;
  CancerSignature? get selectedSignature => _selectedSignature;
  List<DrugInteraction> get recommendedDrugs => _recommendedDrugs;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _signatures = await _dataService.loadCancerSignatures();
      if (_signatures.isNotEmpty) {
        _selectedSignature = _signatures.first;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSignature(CancerSignature signature) {
    _selectedSignature = signature;
    notifyListeners();
  }

  Future<void> fetchRecommendations(CancerSignature selectedCancer) async {
    try {
      _isAnalyzing = true;
      notifyListeners();

      // Extract gene symbols
      final List<String> geneSymbols = selectedCancer.significantGenes.map((e) => e.symbol).toList();
      
      _recommendedDrugs = await _databaseService.getDrugsForGenes(geneSymbols);

      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isAnalyzing = false;
      notifyListeners();
    }
  }
}
