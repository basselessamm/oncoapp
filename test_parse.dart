import 'dart:convert';
import 'package:onco_repurpose_ai/main.dart';
import 'dart:io';

void main() async {
  try {
    String jsonString = File('assets/data/tcga_signatures.json').readAsStringSync();
    final List<dynamic> jsonData = json.decode(jsonString);
    var datasets = jsonData.map((i) => Dataset.fromJson(i)).toList();
    print("Parsed Dataset successfully.");
  } catch (e, stacktrace) {
    print("Error parsing dataset: $e\n$stacktrace");
  }
}
