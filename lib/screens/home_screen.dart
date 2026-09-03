import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../models/drug_interaction.dart';
import '../providers/data_provider.dart';
import '../providers/locale_provider.dart';
import '../services/network/response_cache.dart';
import '../theme/theme_provider.dart';
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
    final themeProvider = context.watch<ThemeProvider?>();
    final isDark = themeProvider?.isDarkModeActive(context) ??
        Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          isAr ? 'أونكو-ريبوربوز' : 'OncoRepurpose',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Quick Language Toggle
          InkWell(
            onTap: () {
              context.read<LocaleProvider>().toggleLocale(context);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    isAr ? 'EN' : 'عربي',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: isAr
                ? (isDark ? 'التبديل إلى الوضع النهاري' : 'التبديل إلى الوضع الليلي')
                : (isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'),
            onPressed: () {
              themeProvider?.toggleTheme(context);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: isAr ? 'الإعدادات والخصوصية' : 'Settings and privacy',
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
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: isAr ? 'المصادر والاعتمادات' : 'About and sources',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreditsScreen()),
            ),
          ),
          const SizedBox(width: 4),
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
              title: isAr ? 'تعذر تحميل البيانات المرجعية' : 'Could not load reference data',
              detail: provider.datasetError,
              onRetry: provider.loadData,
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Wide desktop workstation dashboard (>= 960px)
                if (constraints.maxWidth >= 960.0) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ResearchUseBanner(dense: true),
                            if (provider.datasetError != null) ...[
                              const SizedBox(height: 12),
                              _WarningLine(message: provider.datasetError!),
                            ],
                            const SizedBox(height: 28),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Drug search & Study upload
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SectionHeading(
                                        isAr ? 'البحث عن دواء' : 'Look up a drug',
                                        icon: Icons.medication_outlined,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSearchField(provider, isAr),
                                      const SizedBox(height: 32),
                                      const Divider(),
                                      const SizedBox(height: 24),
                                      SectionHeading(
                                        isAr ? 'تحليل دراستي الخاصة' : 'Analyse my study file',
                                        icon: Icons.upload_file,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildLabEntry(isAr),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 44),
                                // Right Column: Signatures & Gene set query
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SectionHeading(
                                        isAr ? 'استكشاف الأدوية لمجموعة جينات' : 'Find drugs for a gene set',
                                        icon: Icons.biotech_outlined,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isAr
                                            ? 'استعلام بقواعد بيانات DGIdb و Open Targets و LINCS L1000 لفحص التوافق الاتجاهي بين الدواء والتغيرات الملاحظة في الورم.'
                                            : 'Queries DGIdb for every drug recorded against your genes, then checks whether each drug acts against the direction your genes moved.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildManualInput(provider, isAr),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Center(
                                          child: Text(
                                            isAr ? 'أو' : 'OR',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      _buildDatasetPicker(provider, isAr),
                                      const SizedBox(height: 20),
                                      if (!provider.isManualMode)
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.list_alt),
                                          label: Text(isAr ? 'استعراض جينات هذه البصمة' : 'View genes in this signature'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const GenomicDataScreen()),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      _buildLookupButton(provider, isAr),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Mobile & tablet compact high-density layout (< 960px)
                final theme = Theme.of(context);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ResearchUseBanner(dense: true),
                          if (provider.datasetError != null) ...[
                            const SizedBox(height: 8),
                            _WarningLine(message: provider.datasetError!),
                          ],
                          const SizedBox(height: 14),

                          // Card 1: Find drugs for gene set
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.colorScheme.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeading(
                                    isAr ? 'استكشاف الأدوية لمجموعة جينات' : 'Find drugs for a gene set',
                                    icon: Icons.biotech_outlined,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isAr
                                        ? 'استعلام بقواعد بيانات DGIdb و Open Targets و LINCS L1000 لفحص التوافق الاتجاهي بين الدواء والتغيرات الملاحظة في الورم.'
                                        : 'Queries DGIdb for every drug recorded against your genes, then checks whether each drug acts against the direction your genes moved.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildManualInput(provider, isAr),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Center(
                                      child: Text(
                                        isAr ? 'أو' : 'OR',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  _buildDatasetPicker(provider, isAr),
                                  const SizedBox(height: 14),
                                  if (!provider.isManualMode) ...[
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.list_alt, size: 18),
                                      label: Text(isAr ? 'استعراض جينات هذه البصمة' : 'View genes in this signature'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const GenomicDataScreen()),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  _buildLookupButton(provider, isAr),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Card 2: Direct Drug Search
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.colorScheme.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeading(
                                    isAr ? 'البحث المباشر عن دواء' : 'Look up a drug',
                                    icon: Icons.medication_outlined,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSearchField(provider, isAr),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Card 3: Lab Studies
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.colorScheme.outline),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeading(
                                    isAr ? 'تحليل دراستي الخاصة' : 'Analyse my study file',
                                    icon: Icons.upload_file,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildLabEntry(isAr),
                                ],
                              ),
                            ),
                          ),
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

  // --- Shared Reusable Input Widgets ---

  Widget _buildSearchField(DataProvider provider, bool isAr) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: isAr ? 'اسم الدواء، مثلاً: Tamoxifen' : 'Drug name, e.g. Tamoxifen',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          tooltip: isAr ? 'بحث' : 'Search',
          onPressed: () => _handleSearch(provider),
        ),
      ),
      onSubmitted: (_) => _handleSearch(provider),
    );
  }

  Widget _buildManualInput(DataProvider provider, bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr ? 'رموز الجينات المستهدفة:' : 'Gene Symbols:',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _manualGeneController,
          decoration: InputDecoration(
            hintText: 'PIK3CA, TP53, ERBB2',
            helperText: provider.isManualMode
                ? (isAr
                    ? 'تم التعرف على ${provider.manualGenes.length} جين'
                    : '${provider.manualGenes.length} gene(s) recognised')
                : (isAr
                    ? 'افصل بين الرموز بفواصل أو مسافات'
                    : 'Separate symbols with commas or spaces'),
            prefixIcon: const Icon(Icons.science_outlined),
            suffixIcon: provider.isManualMode
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: isAr ? 'مسح الجينات' : 'Clear gene list',
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

  Widget _buildDatasetPicker(DataProvider provider, bool isAr) {
    final theme = Theme.of(context);
    final signature = provider.selectedDataset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CancerSignature>(
                isExpanded: true,
                value: signature,
                onChanged: (value) {
                  if (value != null) {
                    _manualGeneController.clear();
                    provider.selectDataset(value);
                  }
                },
                items: [
                  for (final dataset in provider.datasets)
                    DropdownMenuItem(
                      value: dataset,
                      child: Text(
                        _localizedCancerName(dataset.cancerName, isAr),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  for (final study in provider.labStudies)
                    DropdownMenuItem(
                      value: study,
                      child: Text(
                        '${isAr ? "دراستي: " : "My study: "}${study.cancerName}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (signature != null) ...[
          const SizedBox(height: 6),
          Text(
            isAr
                ? '${signature.significantGenes.length} جين (${signature.upregulatedCount} up, ${signature.downregulatedCount} down)${signature.sampleSize > 0 ? ' - n=${signature.sampleSize}' : ''}'
                : '${signature.significantGenes.length} genes (${signature.upregulatedCount} up, ${signature.downregulatedCount} down)'
                    '${signature.sampleSize > 0 ? ' - n=${signature.sampleSize}' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ],
    );
  }

  String _localizedCancerName(String name, bool isAr) {
    if (!isAr) return name;
    if (name.contains('PanCancer Atlas')) return 'سرطان الثدي الارتشاحي (TCGA PanCancer)';
    if (name.contains('Basal vs Normal')) return 'سرطان الثدي (القاعدي مقابل الطبيعي)';
    if (name.contains('Mesenchymal vs Immunomodulatory')) return 'سرطان الثدي TNBC: لحمي متوسطي مقابل مناعي';
    if (name.contains('Immunomodulatory vs Luminal Androgen')) return 'سرطان الثدي TNBC: مناعي مقابل مستقبلات الأندروجين';
    if (name.contains('Basal-Like 1 vs Mesenchymal')) return 'سرطان الثدي TNBC: شبيه قاعدي 1 مقابل لحمي متوسطي';
    return name;
  }

  Widget _buildLookupButton(DataProvider provider, bool isAr) {
    final geneCount = provider.activeGenes.length;
    final theme = Theme.of(context);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.search, size: 18),
      label: Text(
        geneCount == 0
            ? (isAr ? 'اختر جينات للبحث' : 'Select genes to search')
            : (isAr
                ? 'استكشاف الأدوية لـ $geneCount جين'
                : 'Search interactions for $geneCount gene${geneCount == 1 ? '' : 's'}'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      onPressed: geneCount == 0 ? null : () => _showFilterSheet(provider, isAr),
    );
  }

  Widget _buildLabEntry(bool isAr) {
    final theme = Theme.of(context);
    return Column(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text(
            isAr ? 'تحليل ملف دراستي الخاصة' : 'Analyse my own study file',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: theme.colorScheme.primary,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LabScreen()),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isAr
              ? 'ارفع جدول التعبير الجيني التفريقي (CSV/TSV) ليتم تطبيق تصحيح FDR تلقائياً.'
              : 'Upload a differential-expression table (CSV/TSV). FDR correction is applied by default.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
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

  Future<void> _showFilterSheet(DataProvider provider, bool isAr) async {
    final hasDirection = !provider.isManualMode;
    final filters = await showModalBottomSheet<InteractionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initial: provider.lastFilters,
        hasExpressionDirection: hasDirection,
        isAr: isAr,
      ),
    );
    if (filters == null || !mounted) return;

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
        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF6C00)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A3E00)),
          ),
        ),
      ],
    );
  }
}

/// Filter sheet for an interaction lookup.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.hasExpressionDirection,
    required this.isAr,
  });

  final InteractionFilters initial;
  final bool hasExpressionDirection;
  final bool isAr;

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
    final isAr = widget.isAr;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeading(isAr ? 'فلاتر البحث' : 'Filters', icon: Icons.tune),
            const SizedBox(height: 16),
            if (widget.hasExpressionDirection)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isAr ? 'الأدوية المعاكسة للتعبير فقط' : 'Opposing drugs only',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: Text(
                  isAr
                      ? 'يقتصر على الأدوية التي تعاكس اتجاه تغير جين واحد على الأقل في الورم.'
                      : 'Keeps drugs that act against the direction at least one of your genes moved.',
                  style: const TextStyle(fontSize: 11, height: 1.35),
                ),
                value: _onlyOpposing,
                onChanged: (value) => setState(() => _onlyOpposing = value),
              )
            else
              _FilterNote(
                isAr
                    ? 'أُدخلت الجينات يدوياً، لذلك لا يتوفر اتجاه تعبير وفلتر المعاكسة غير نشط.'
                    : 'Genes were entered manually, so no expression direction is available.',
              ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isAr ? 'استبعاد الأدوية المعتمدة FDA' : 'Exclude approved drugs',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              subtitle: Text(
                isAr
                    ? 'التركيز على المركبات البحثية. علماً بأن "غير معتمد" في DGIdb يعني "not FDA-approved" ويشمل المركبات الاستقصائية والتجريبية.'
                    : 'Focus on novel or investigational compounds. Note that "not approved" in DGIdb means "not FDA-approved", which includes investigational and abandoned drugs, not guaranteed novelty.',
                style: const TextStyle(fontSize: 11, height: 1.35),
              ),
              value: _onlyUnapproved,
              onChanged: (value) => setState(() => _onlyUnapproved = value),
            ),
            const SizedBox(height: 14),
            Text(
              isAr ? 'الحد الأدنى لتوثيق المصادر' : 'Minimum corroboration',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text(isAr ? 'أي مصدر' : 'Any', style: const TextStyle(fontSize: 11.5))),
                ButtonSegment(value: 2, label: Text(isAr ? 'مصدران +' : '2+ sources', style: const TextStyle(fontSize: 11.5))),
                ButtonSegment(value: 3, label: Text(isAr ? '3 مصادر +' : '3+ sources', style: const TextStyle(fontSize: 11.5))),
              ],
              selected: {_minSourceCount},
              onSelectionChanged: (selection) =>
                  setState(() => _minSourceCount = selection.first),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? (switch (_minSourceCount) {
                      >= 3 => 'الأكثر صرامة: 3.8% فقط من سجلات البيانات تطابق هذا الحد.',
                      2 => 'موصى به: 9.2% من السجلات تطابق هذا الحد.',
                      _ => '90.8% من السجلات مسجلة في قاعدة بيانات واحدة.',
                    })
                  : (switch (_minSourceCount) {
                      >= 3 => 'Strictest: 3.8% of records in the database qualify.',
                      2 => 'Recommended: 9.2% of records qualify.',
                      _ => '90.8% of records come from a single database.',
                    }),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAr ? 'الحد الأدنى لدرجة التوثيق' : 'Minimum documentation score',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  _minScore.toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
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
              _scoreHint(_minScore, isAr),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isAr ? 'إلغاء' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark),
                    onPressed: () => Navigator.pop(
                      context,
                      InteractionFilters(
                        onlyUnapproved: _onlyUnapproved,
                        minScore: _minScore,
                        minSourceCount: _minSourceCount,
                        onlyOpposing: widget.hasExpressionDirection && _onlyOpposing,
                      ),
                    ),
                    child: Text(isAr ? 'تطبيق والبحث' : 'Search'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _scoreHint(double value, bool isAr) {
    if (value <= 0) {
      return isAr ? 'لا يوجد فلتر للدرجة - جميع السجلات مشمولة.' : 'No score filter - all records included.';
    }
    if (value < EvidenceStrength.moderatelyDocumentedThreshold) {
      return isAr ? 'أقل من المئين 75 من السجلات.' : 'Below the 75th percentile of records.';
    }
    if (value < 2.63) {
      return isAr ? 'أعلى 25% من السجلات تقريباً.' : 'Roughly the top 25% of records.';
    }
    if (value < EvidenceStrength.wellDocumentedThreshold) {
      return isAr ? 'أعلى 10% من السجلات تقريباً.' : 'Roughly the top 10% of records.';
    }
    return isAr ? 'أعلى 5% من السجلات - نتائج قليلة جداً متوقعة.' : 'Top 5% of records - expect few results.';
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
            style: const TextStyle(fontSize: 11.5, height: 1.4, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
