import 'package:flutter/material.dart';
import '../models/oncology_data.dart';
import '../services/data_service.dart';

class DataProvider with ChangeNotifier {
  final DataService _dataService = DataService();

  OncologyData? _oncologyData;
  Dataset? _selectedDataset;
  bool _isLoading = true;
  String? _errorMessage;

  OncologyData? get oncologyData => _oncologyData;
  Dataset? get selectedDataset => _selectedDataset;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _oncologyData = await _dataService.loadOncologyData();
      if (_oncologyData!.datasets.isNotEmpty) {
        _selectedDataset = _oncologyData!.datasets.first;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDataset(Dataset dataset) {
    _selectedDataset = dataset;
    notifyListeners();
  }

  List<Rule> getRecommendations() {
    if (_oncologyData == null || _selectedDataset == null) return [];

    List<Rule> matchingRules = [];

    _selectedDataset!.geneExpression.forEach((gene, expression) {
      final matching = _oncologyData!.rules.where(
        (rule) => rule.targetGene == gene && rule.condition == expression,
      );
      matchingRules.addAll(matching);
    });

    return matchingRules;
  }
}
