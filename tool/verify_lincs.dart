import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  stdout.writeln('=== NIH LINCS L1000FWD Live API Verification ===');
  stdout.writeln('Connecting to https://maayanlab.cloud/l1000fwd/ ...\n');

  final client = http.Client();
  final baseUrl = Uri.parse('https://maayanlab.cloud/l1000fwd/');

  var allPassed = true;

  // Step 1: Submit up and down gene sets to sig_search
  final upGenes = ['ESR1', 'GATA3', 'FOXA1', 'ERBB2'];
  final downGenes = ['TP53', 'CDKN2A', 'PTEN', 'RB1'];

  stdout.writeln('Submitting Breast Cancer signature:');
  stdout.writeln('  Up: ${upGenes.join(", ")}');
  stdout.writeln('  Down: ${downGenes.join(", ")}');

  final searchUrl = baseUrl.resolve('sig_search');
  final searchResponse = await client.post(
    searchUrl,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({
      'up_genes': upGenes,
      'down_genes': downGenes,
    }),
  );

  final searchPass = searchResponse.statusCode == 200;
  if (!searchPass) allPassed = false;

  final searchBody = searchPass
      ? jsonDecode(searchResponse.body) as Map<String, dynamic>
      : <String, dynamic>{};
  final resultId = searchBody['result_id'] as String?;
  final hasResultId = resultId != null && resultId.isNotEmpty;
  if (!hasResultId) allPassed = false;

  stdout.writeln('\n| Check | Expected | Actual | Status |');
  stdout.writeln('| --- | --- | --- | --- |');
  stdout.writeln(
      '| POST /sig_search | HTTP 200 + result_id | HTTP ${searchResponse.statusCode} (id: $resultId) | ${searchPass && hasResultId ? "PASS" : "FAIL"} |');

  if (!hasResultId) {
    stderr.writeln('Failed to obtain result_id. Exiting.');
    client.close();
    exit(1);
  }

  // Step 2: Retrieve topn opposing and similar perturbagen signatures
  final topnUrl = baseUrl.resolve('result/topn/$resultId');
  final topnResponse = await client.get(
    topnUrl,
    headers: {'Accept': 'application/json'},
  );

  final topnPass = topnResponse.statusCode == 200;
  if (!topnPass) allPassed = false;

  final topnBody = topnPass
      ? jsonDecode(topnResponse.body) as Map<String, dynamic>
      : <String, dynamic>{};
  final opposite = (topnBody['opposite'] as List<dynamic>?) ?? const [];
  final similar = (topnBody['similar'] as List<dynamic>?) ?? const [];

  final hasOpposite = opposite.isNotEmpty;
  if (!hasOpposite) allPassed = false;

  stdout.writeln(
      '| GET /result/topn | Opposing signatures >= 10 | ${opposite.length} opposing, ${similar.length} similar hits | ${hasOpposite ? "PASS" : "FAIL"} |');

  double? topScore;
  String? topSigId;
  if (opposite.isNotEmpty) {
    final first = opposite.first as Map<String, dynamic>;
    topScore = (first['scores'] as num?)?.toDouble();
    topSigId = first['sig_id'] as String?;
  }

  final scoreNegative = topScore != null && topScore < 0;
  if (!scoreNegative) allPassed = false;

  stdout.writeln(
      '| Top Reversal Score | Negative (< 0.0) | ${topScore?.toStringAsFixed(4) ?? "none"} | ${scoreNegative ? "PASS" : "FAIL"} |');

  // Step 3: Check signature metadata lookup
  String? resolvedDrug;
  if (topSigId != null) {
    final sigUrl = baseUrl.resolve('sig/$topSigId');
    final sigRes = await client.get(sigUrl, headers: {'Accept': 'application/json'});
    if (sigRes.statusCode == 200) {
      final sigData = jsonDecode(sigRes.body) as Map<String, dynamic>;
      resolvedDrug = sigData['pert_desc'] as String?;
    }
  }

  final drugResolved = resolvedDrug != null && resolvedDrug.isNotEmpty;
  stdout.writeln(
      '| Signature Drug Lookup | Resolved pert_desc | $resolvedDrug | ${drugResolved ? "PASS" : "FAIL"} |');

  stdout.writeln('\nTop 3 Opposing Perturbagens:');
  for (final hit in opposite.take(3)) {
    final sig = hit['sig_id'];
    final sc = hit['scores'];
    final qv = hit['qvals'];
    stdout.writeln('  - Sig: $sig | Score: $sc | FDR q: $qv');
  }

  stdout.writeln('\n================================================');
  client.close();

  if (allPassed) {
    stdout.writeln('All LINCS L1000 live verifications PASSED!');
    exit(0);
  } else {
    stderr.writeln('Some LINCS L1000 verifications FAILED.');
    exit(1);
  }
}
