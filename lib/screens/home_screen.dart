import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../models/drug_interaction.dart';
import '../providers/data_provider.dart';
import '../services/network/response_cache.dart';
import '../widgets/evidence_widgets.dart';
import 'credits_screen.dart';
import 'drug_search_screen.dart';
import 'genomic_data_screen.dart';
import 'interaction_results_screen.dart';
import 'lab_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualGeneController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _manualGeneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OncoRepurpose',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings and privacy',
            onPressed: () {
              final cache = context.read<ResponseCache>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(cache: cache),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About, data sources and credits',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreditsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingDatasets) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.datasetStatus == LoadStatus.failed) {
            return StatusMessage(
              icon: Icons.error_outline,
              title: 'Could not load reference data',
              detail: provider.datasetError,
              onRetry: provider.loadData,
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Single narrow column on a 1280px desktop window reads as a
                // ribbon; cap the content width instead.
                final maxWidth = constraints.maxWidth > 700.0 ? 640.0 : double.infinity;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ResearchUseBanner(),
                          if (provider.datasetError != null) ...[
                            const SizedBox(height: 12),
                            _WarningLine(message: provider.datasetError!),
                          ],
                          const SizedBox(height: 28),
                          const SectionHeading('Look up a drug',
                              icon: Icons.medication_outlined),
                          const SizedBox(height: 12),
                          _buildSearchField(provider),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 24),
                          const SectionHeading('Find drugs for a gene set',
                              icon: Icons.biotech_outlined),
                          const SizedBox(height: 8),
                          const Text(
                            'Queries DGIdb for every drug recorded against '
                            'your genes, then checks whether each drug acts '
                            'against the direction your genes moved.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          _buildManualInput(provider),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('OR',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                            ),
                          ),
                          _buildDatasetPicker(provider),
                          const SizedBox(height: 24),
                          if (!provider.isManualMode)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.list_alt),
                              label: const Text('View genes in this signature'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const GenomicDataScreen()),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _buildLookupButton(provider),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 24),
                          _buildLabEntry(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(DataProvider provider) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Drug name, e.g. Tamoxifen',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Search',
          onPressed: () => _handleSearch(provider),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (_) => _handleSearch(provider),
    );
  }

  Widget _buildManualInput(DataProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Option A: enter gene symbols',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _manualGeneController,
          decoration: InputDecoration(
            hintText: 'PIK3CA, TP53, ERBB2',
            helperText: provider.isManualMode
                ? '${provider.manualGenes.length} gene(s) recognised'
                : 'Separate symbols with commas or spaces',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.science_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: provider.isManualMode
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear gene list',
                    onPressed: () {
                      _manualGeneController.clear();
                      provider.setManualGenes('');
                    },
                  )
                : null,
          ),
          onChanged: provider.setManualGenes,
        ),
      ],
    );
  }

  Widget _buildDatasetPicker(DataProvider provider) {
    final signature = provider.selectedDataset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Option B: use a signature',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CancerSignature>(
                isExpanded: true,
                value: signature,
                onChanged: provider.isManualMode
                    ? null
                    : (value) {
                        if (value != null) provider.selectDataset(value);
                      },
                items: [
                  for (final dataset in provider.datasets)
                    DropdownMenuItem(
                      value: dataset,
                      child: Text(dataset.cancerName,
                          overflow: TextOverflow.ellipsis),
                    ),
                  for (final study in provider.labStudies)
                    DropdownMenuItem(
                      value: study,
                      child: Text('My study: ${study.cancerName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.primaryDark)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (signature != null && !provider.isManualMode) ...[
          const SizedBox(height: 8),
          Text(
            '${signature.significantGenes.length} genes  -  '
            '${signature.upregulatedCount} up, '
            '${signature.downregulatedCount} down'
            '${signature.sampleSize > 0 ? '  -  n=${signature.sampleSize}' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }

  Widget _buildLookupButton(DataProvider provider) {
    final geneCount = provider.activeGenes.length;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      icon: const Icon(Icons.search),
      label: Text(
        geneCount == 0
            ? 'Select genes to search'
            : 'Search interactions for $geneCount gene'
                '${geneCount == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onPressed:
          geneCount == 0 ? null : () => _showFilterSheet(provider),
    );
  }

  Widget _buildLabEntry() {
    return Column(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Analyse my own study file',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
            foregroundColor: AppColors.primaryDark,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LabScreen()),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Upload a differential-expression table (CSV/TSV). '
          'FDR correction is applied by default.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  void _handleSearch(DataProvider provider) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    provider.searchDrugs(query);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrugSearchScreen(searchQuery: query)),
    );
  }

  Future<void> _showFilterSheet(DataProvider provider) async {
    final hasDirection = !provider.isManualMode;
    final filters = await showModalBottomSheet<InteractionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initial: provider.lastFilters,
        hasExpressionDirection: hasDirection,
      ),
    );
    if (filters == null || !mounted) return;

    // Navigate first; the results screen renders the provider's loading and
    // error states itself. This removes the blocking progress dialog, which had
    // no timeout and could lock the app, and the `silent` flag that existed to
    // stop a global loading toggle from unmounting this screen.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InteractionResultsScreen()),
    );
    provider.findInteractionsForGenes(filters: filters);
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.warning_amber_rounded,
            size: 16, color: Color(0xFFEF6C00)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A3E00))),
        ),
      ],
    );
  }
}

/// Filter sheet for an interaction lookup.
///
/// The score slider now spans the range the data actually occupies. The old
/// 0-10 slider paired with a `score > 5.0` "high confidence" label described
/// only 5% of records, so most of its travel had no effect.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.hasExpressionDirection,
  });

  final InteractionFilters initial;

  /// Whether the query carries fold changes, i.e. came from a signature rather
  /// than a typed gene list. The directional filter is meaningless without it.
  final bool hasExpressionDirection;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _onlyUnapproved = widget.initial.onlyUnapproved;
  late double _minScore = widget.initial.minScore;
  late int _minSourceCount = widget.initial.minSourceCount;
  late bool _onlyOpposing = widget.initial.onlyOpposing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeading('Filters', icon: Icons.tune),
            const SizedBox(height: 20),
            if (widget.hasExpressionDirection)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opposing drugs only',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Keeps drugs that act against the direction at least one of '
                  'your genes moved. Drugs that reinforce the change are '
                  'otherwise shown with a warning rather than hidden.',
                  style: TextStyle(fontSize: 11, height: 1.35),
                ),
                value: _onlyOpposing,
                onChanged: (value) => setState(() => _onlyOpposing = value),
              )
            else
              const _FilterNote(
                'Genes were entered manually, so no expression direction is '
                'available and the directional filter is unavailable.',
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude approved drugs',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Keeps only drugs no source database marks as approved. This '
                'means "not FDA-approved" - it includes investigational and '
                'discontinued compounds.',
                style: TextStyle(fontSize: 11, height: 1.35),
              ),
              value: _onlyUnapproved,
              onChanged: (value) => setState(() => _onlyUnapproved = value),
            ),
            const SizedBox(height: 16),
            const Text('Minimum corroboration',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Any')),
                ButtonSegment(value: 2, label: Text('2+ sources')),
                ButtonSegment(value: 3, label: Text('3+ sources')),
              ],
              selected: {_minSourceCount},
              onSelectionChanged: (selection) =>
                  setState(() => _minSourceCount = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_minSourceCount) {
                >= 3 => 'Strictest: 3.8% of records in the database qualify.',
                2 => 'Recommended: 9.2% of records qualify.',
                _ => '90.8% of records come from a single database.',
              },
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Minimum documentation score',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_minScore.toStringAsFixed(2),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
              ],
            ),
            Slider(
              value: _minScore,
              max: EvidenceStrength.wellDocumentedThreshold,
              divisions: 21,
              label: _minScore.toStringAsFixed(2),
              onChanged: (value) => setState(() => _minScore = value),
            ),
            Text(
              _scoreHint(_minScore),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark),
                    onPressed: () => Navigator.pop(
                      context,
                      InteractionFilters(
                        onlyUnapproved: _onlyUnapproved,
                        minScore: _minScore,
                        minSourceCount: _minSourceCount,
                        onlyOpposing:
                            widget.hasExpressionDirection && _onlyOpposing,
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Percentile guidance measured on the 69,018 aggregated gene-drug pairs in
  /// the bundled database.
  static String _scoreHint(double value) {
    if (value <= 0) return 'No score filter - all records included.';
    if (value < EvidenceStrength.moderatelyDocumentedThreshold) {
      return 'Below the 75th percentile of records.';
    }
    if (value < 2.63) return 'Roughly the top 25% of records.';
    if (value < EvidenceStrength.wellDocumentedThreshold) {
      return 'Roughly the top 10% of records.';
    }
    return 'Top 5% of records - expect few results.';
  }
}

/// Explanatory line shown in place of a filter that does not apply.
class _FilterNote extends StatelessWidget {
  const _FilterNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.black45),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 11.5, height: 1.4, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
