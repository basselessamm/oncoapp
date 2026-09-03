import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  stdout.writeln('=== Open Targets Live API Verification ===');
  stdout.writeln('Connecting to https://api.platform.opentargets.org/api/v4/graphql ...\n');

  final client = http.Client();
  final endpoint = Uri.parse('https://api.platform.opentargets.org/api/v4/graphql');

  Future<Map<String, dynamic>> postGraphQL(String query, Map<String, dynamic> variables) async {
    final response = await client.post(
      endpoint,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('errors') && body['errors'] != null) {
      throw Exception('GraphQL errors: ${body['errors']}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  var allPassed = true;

  // Step 1: Map symbols to Ensembl IDs
  const genes = ['ESR1', 'TP53', 'ACTB', 'OR4F5'];
  const diseaseId = 'MONDO_0004989';

  stdout.writeln('Mapping symbols: ${genes.join(", ")}...');
  const mapIdsQuery = r'''
    query MapGeneSymbols($symbols: [String!]!) {
      mapIds(queryTerms: $symbols) {
        mappings {
          term
          hits {
            id
            name
          }
        }
      }
    }
  ''';

  final mapData = await postGraphQL(mapIdsQuery, {'symbols': genes});
  final mappings = (mapData['mapIds']?['mappings'] as List<dynamic>?) ?? [];
  final symbolToEnsembl = <String, String>{};
  final ensemblToSymbol = <String, String>{};

  for (final m in mappings) {
    final term = m['term'] as String;
    final hits = m['hits'] as List<dynamic>?;
    if (hits != null && hits.isNotEmpty) {
      final ensemblId = hits.first['id'] as String;
      symbolToEnsembl[term] = ensemblId;
      ensemblToSymbol[ensemblId] = term;
    }
  }

  stdout.writeln('Resolved symbols: $symbolToEnsembl');

  // Step 2: Query reverse disease associations with enableIndirect: true
  // Guard check: query MUST NOT contain associatedDiseases
  assert(!mapIdsQuery.contains('associatedDiseases('));
  const assocQuery = r'''
    query DiseaseTargetAssocs($diseaseId: String!, $ensemblIds: [String!]!) {
      disease(efoId: $diseaseId) {
        id
        name
        associatedTargets(Bs: $ensemblIds, enableIndirect: true) {
          count
          rows {
            score
            datatypeScores {
              id
              score
            }
            target {
              id
              approvedSymbol
              approvedName
            }
          }
        }
      }
    }
  ''';

  final resolvedEnsemblIds = symbolToEnsembl.values.toList();
  final assocData = await postGraphQL(assocQuery, {
    'diseaseId': diseaseId,
    'ensemblIds': resolvedEnsemblIds,
  });

  final diseaseNode = assocData['disease'] as Map<String, dynamic>?;
  if (diseaseNode == null) {
    stderr.writeln('FAIL: disease $diseaseId not found in Open Targets');
    exit(1);
  }

  final rows = (diseaseNode['associatedTargets']?['rows'] as List<dynamic>?) ?? [];
  final scoreBySymbol = <String, double?>{};

  for (final g in genes) {
    scoreBySymbol[g] = null;
  }

  for (final r in rows) {
    final target = r['target'] as Map<String, dynamic>;
    final symbol = target['approvedSymbol'] as String;
    final score = (r['score'] as num?)?.toDouble();
    scoreBySymbol[symbol] = score;
  }

  // Print results table
  stdout.writeln('\n| Query / Target | Expected | Actual | Status |');
  stdout.writeln('| --- | --- | --- | --- |');

  // Check ESR1 (~0.8179)
  final esr1Score = scoreBySymbol['ESR1'];
  final esr1Pass = esr1Score != null && (esr1Score - 0.8179).abs() < 0.05;
  if (!esr1Pass) allPassed = false;
  stdout.writeln('| ESR1 (breast carcinoma) | ~0.8179 | ${esr1Score?.toStringAsFixed(4) ?? "null"} | ${esr1Pass ? "PASS" : "FAIL"} |');

  // Check TP53 (~0.8606)
  final tp53Score = scoreBySymbol['TP53'];
  final tp53Pass = tp53Score != null && (tp53Score - 0.8606).abs() < 0.05;
  if (!tp53Pass) allPassed = false;
  stdout.writeln('| TP53 (breast carcinoma) | ~0.8606 | ${tp53Score?.toStringAsFixed(4) ?? "null"} | ${tp53Pass ? "PASS" : "FAIL"} |');

  // Check ACTB (~0.0413)
  final actbScore = scoreBySymbol['ACTB'];
  final actbPass = actbScore != null && (actbScore - 0.0413).abs() < 0.05;
  if (!actbPass) allPassed = false;
  stdout.writeln('| ACTB (housekeeping negative control) | ~0.0413 | ${actbScore?.toStringAsFixed(4) ?? "null"} | ${actbPass ? "PASS" : "FAIL"} |');

  // Check OR4F5 (none / null)
  final or4f5Score = scoreBySymbol['OR4F5'];
  final or4f5Pass = or4f5Score == null;
  if (!or4f5Pass) allPassed = false;
  stdout.writeln('| OR4F5 (olfactory negative control) | none (null) | ${or4f5Score?.toStringAsFixed(4) ?? "none"} | ${or4f5Pass ? "PASS" : "FAIL"} |');

  // Step 3: Disease search for "breast"
  stdout.writeln('\nSearching diseases for "breast"...');
  const diseaseSearchQuery = r'''
    query SearchDiseases($query: String!) {
      search(queryString: $query, entityNames: ["disease"], page: { index: 0, size: 10 }) {
        total
        hits {
          id
          name
          description
        }
      }
    }
  ''';

  final searchData = await postGraphQL(diseaseSearchQuery, {'query': 'breast'});
  final hits = (searchData['search']?['hits'] as List<dynamic>?) ?? [];
  final searchPass = hits.isNotEmpty;
  if (!searchPass) allPassed = false;
  stdout.writeln('| Search "breast" | >= 1 result | ${hits.length} results | ${searchPass ? "PASS" : "FAIL"} |');

  if (hits.isNotEmpty) {
    stdout.writeln('\nFirst 3 search hits:');
    for (final h in hits.take(3)) {
      stdout.writeln('  - ${h['id']}: ${h['name']}');
    }
  }

  stdout.writeln('\n========================================');
  client.close();

  if (allPassed) {
    stdout.writeln('All Open Targets live verifications PASSED!');
    exit(0);
  } else {
    stderr.writeln('Some Open Targets verifications FAILED.');
    exit(1);
  }
}
