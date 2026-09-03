import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/models/cancer_signature.dart';
import 'package:onco_repurpose_ai/models/drug_candidate.dart';
import 'package:onco_repurpose_ai/models/drug_interaction.dart';
import 'package:onco_repurpose_ai/providers/data_provider.dart';
import 'package:onco_repurpose_ai/screens/interaction_results_screen.dart';
import 'package:onco_repurpose_ai/widgets/evidence_widgets.dart';
import 'package:provider/provider.dart';

void main() {
  DrugInteraction interaction({
    required String gene,
    required String drug,
    List<String> types = const ['inhibitor'],
    List<String> sources = const ['ChEMBL'],
    double score = 1.0,
    bool approved = false,
  }) {
    return DrugInteraction(
      gene: gene,
      drug: drug,
      interactionTypes: types,
      sources: sources,
      score: score,
      isApproved: approved,
    );
  }

  CancerSignature signature() => const CancerSignature(
        id: 'sig',
        cancerName: 'Test Carcinoma',
        pmid: '1',
        sampleSize: 50,
        significantGenes: [
          SignificantGene(
              symbol: 'UP_GENE', type: 'Upregulated', log2fc: 3.0, pValue: 0.001),
          SignificantGene(
              symbol: 'DOWN_GENE',
              type: 'Downregulated',
              log2fc: -3.0,
              pValue: 0.001),
        ],
      );

  /// Builds a provider already in the `ready` state with grouped candidates.
  DataProvider resultsProvider(
    List<DrugInteraction> interactions, {
    bool manual = false,
    InteractionFilters filters = const InteractionFilters(),
  }) {
    final provider = DataProvider();
    final sig = manual ? null : signature();
    provider.queriedSignature = sig;
    provider.queriedGenes = manual
        ? ['UP_GENE', 'DOWN_GENE']
        : sig!.significantGenes.map((g) => g.symbol).toList();
    provider.interactionResults = interactions;
    provider.candidates = DrugCandidate.group(interactions, signature: sig);
    provider.lastFilters = filters;
    provider.interactionStatus = LoadStatus.ready;
    return provider;
  }

  Future<void> pump(WidgetTester tester, DataProvider provider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DataProvider>.value(
        value: provider,
        child: const MaterialApp(home: InteractionResultsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('titles the screen as candidates, not AI results',
      (tester) async {
    await pump(
      tester,
      resultsProvider([interaction(gene: 'UP_GENE', drug: 'DRUG_A')]),
    );

    expect(find.text('Candidate Drugs'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
  });

  testWidgets('shows one card per drug, not per gene-drug pair',
      (tester) async {
    await pump(
      tester,
      resultsProvider([
        interaction(gene: 'UP_GENE', drug: 'DRUG_A'),
        interaction(gene: 'DOWN_GENE', drug: 'DRUG_A'),
      ]),
    );

    expect(find.text('DRUG_A'), findsOneWidget);
    expect(find.text('2 of your genes'), findsOneWidget);
  });

  testWidgets('states how many genes a candidate opposes', (tester) async {
    await pump(
      tester,
      resultsProvider([
        interaction(gene: 'UP_GENE', drug: 'DRUG_A', types: ['inhibitor']),
      ]),
    );

    expect(find.text('Opposes 1 of 1'), findsOneWidget);
  });

  testWidgets('warns when a candidate only reinforces the dysregulation',
      (tester) async {
    // An inhibitor of an under-expressed gene: a genuine counter-indication
    // that the old screen displayed identically to a favourable hit.
    await pump(
      tester,
      resultsProvider([
        interaction(gene: 'DOWN_GENE', drug: 'DRUG_B', types: ['inhibitor']),
      ]),
    );

    expect(find.byType(ReinforcementWarning), findsOneWidget);
    expect(
      find.textContaining('further in the direction it already moved'),
      findsOneWidget,
    );
  });

  testWidgets('does not warn for an opposing candidate', (tester) async {
    await pump(
      tester,
      resultsProvider([
        interaction(gene: 'UP_GENE', drug: 'DRUG_A', types: ['inhibitor']),
      ]),
    );

    expect(find.byType(ReinforcementWarning), findsNothing);
  });

  testWidgets('ranks an opposing candidate above a higher-scoring one',
      (tester) async {
    await pump(
      tester,
      resultsProvider([
        interaction(
            gene: 'DOWN_GENE', drug: 'HIGH_SCORE', types: ['inhibitor'], score: 90),
        interaction(
            gene: 'UP_GENE', drug: 'OPPOSES', types: ['inhibitor'], score: 1),
      ]),
    );

    final opposesY = tester.getTopLeft(find.text('OPPOSES')).dy;
    final highScoreY = tester.getTopLeft(find.text('HIGH_SCORE')).dy;
    expect(opposesY, lessThan(highScoreY));
  });

  testWidgets('omits directional claims for a manual gene list',
      (tester) async {
    await pump(
      tester,
      resultsProvider(
        [interaction(gene: 'UP_GENE', drug: 'DRUG_A', types: ['inhibitor'])],
        manual: true,
      ),
    );

    expect(find.byType(CandidateDirectionChip), findsNothing);
    expect(
      find.textContaining('no expression direction is available'),
      findsOneWidget,
    );
  });

  testWidgets('states research-use scope above the results', (tester) async {
    await pump(
      tester,
      resultsProvider([interaction(gene: 'UP_GENE', drug: 'DRUG_A')]),
    );

    expect(find.byType(ResearchUseBanner), findsOneWidget);
  });

  testWidgets('expands to a per-gene breakdown with directions',
      (tester) async {
    await pump(
      tester,
      resultsProvider([
        interaction(gene: 'UP_GENE', drug: 'DRUG_A', types: ['inhibitor']),
        interaction(gene: 'DOWN_GENE', drug: 'DRUG_A', types: ['inhibitor']),
      ]),
    );

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('UP_GENE'), findsOneWidget);
    expect(find.text('DOWN_GENE'), findsOneWidget);
    expect(find.text('Opposes'), findsOneWidget);
    expect(find.text('Reinforces'), findsOneWidget);
  });

  testWidgets('explains an empty result by the coverage gap', (tester) async {
    await pump(tester, resultsProvider(const []));

    expect(find.text('No candidates found'), findsOneWidget);
    expect(
      find.textContaining('frequently not druggable targets'),
      findsOneWidget,
    );
  });

  testWidgets('explains an empty result caused by the opposing filter',
      (tester) async {
    await pump(
      tester,
      resultsProvider(
        const [],
        filters: const InteractionFilters(onlyOpposing: true),
      ),
    );

    expect(
      find.textContaining('acts against the direction of change'),
      findsOneWidget,
    );
  });

  testWidgets('distinguishes a failed lookup from an empty one',
      (tester) async {
    final provider = DataProvider();
    provider.interactionStatus = LoadStatus.failed;
    provider.interactionError = 'Simulated database failure';
    await pump(tester, provider);

    expect(find.text('Lookup failed'), findsOneWidget);
    expect(find.text('Simulated database failure'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('shows a spinner while the lookup runs', (tester) async {
    final provider = DataProvider();
    provider.interactionStatus = LoadStatus.loading;
    await tester.pumpWidget(
      ChangeNotifierProvider<DataProvider>.value(
        value: provider,
        child: const MaterialApp(home: InteractionResultsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
