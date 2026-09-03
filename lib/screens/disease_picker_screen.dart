import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/disease_option.dart';
import '../providers/evidence_provider.dart';
import '../services/open_targets_service.dart';
import '../widgets/evidence_widgets.dart';

/// Screen allowing the user to select the disease context for Open Targets
/// target-disease association scoring.
class DiseasePickerScreen extends StatefulWidget {
  const DiseasePickerScreen({super.key});

  @override
  State<DiseasePickerScreen> createState() => _DiseasePickerScreenState();
}

class _DiseasePickerScreenState extends State<DiseasePickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<DiseaseOption> _searchResults = const [];
  bool _isSearching = false;
  String? _searchError;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchError = null;
        _searchResults = const [];
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
      _hasSearched = true;
    });

    final service = context.read<OpenTargetsService>();
    final result = await service.searchDiseases(query);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (result.isSuccess) {
        _searchResults = result.dataOrNull ?? const [];
      } else {
        _searchError = 'Search failed. Check your network connection.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final evidenceProvider = context.watch<EvidenceProvider>();
    final currentDisease = evidenceProvider.selectedDisease;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تحديد سياق المرض' : 'Select Disease Context'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr
                            ? 'تعتمد درجات أدلة ربط الهدف بالمرض في Open Targets بدقة على الكيان المرضي المختار. غيّر هذا السياق لاستكشاف أدلة الأنماط الفرعية.'
                            : 'Target-disease evidence scores in Open Targets depend strictly on the chosen disease entity. Change this context to explore subtype-specific evidence.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: isAr
                              ? 'ابحث في أنطولوجيا الأمراض (مثال: breast carcinoma)...'
                              : 'Search disease ontology (e.g., breast carcinoma)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBody(currentDisease, evidenceProvider, isAr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    DiseaseOption? currentDisease,
    EvidenceProvider evidenceProvider,
    bool isAr,
  ) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError != null) {
      return StatusMessage(
        icon: Icons.cloud_off_outlined,
        title: isAr ? 'البحث غير متوفر' : 'Search unavailable',
        detail: _searchError,
        onRetry: () => _performSearch(_searchController.text),
      );
    }

    if (_hasSearched) {
      if (_searchResults.isEmpty) {
        return StatusMessage(
          icon: Icons.search_off,
          title: isAr ? 'لم يتم العثور على أمراض' : 'No diseases found',
          detail: isAr ? 'جرب البحث بمصطلح أورام أوسع.' : 'Try searching with a broader oncology term.',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final option = _searchResults[index];
          final isSelected = currentDisease?.id == option.id;
          return _DiseaseTile(
            option: option,
            isSelected: isSelected,
            onSelect: () => _selectDisease(evidenceProvider, option),
          );
        },
      );
    }

    // Default view: Curated breast cancer options
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeading(
          isAr ? 'الخيارات المرجعية الموصى بها لأورام الثدي' : 'Curated Breast Oncology Defaults',
          icon: Icons.recommend_outlined,
        ),
        const SizedBox(height: 12),
        for (final option in DiseaseOption.breastCancerDefaults) ...[
          _DiseaseTile(
            option: option,
            isSelected: currentDisease?.id == option.id,
            onSelect: () => _selectDisease(evidenceProvider, option),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _selectDisease(EvidenceProvider provider, DiseaseOption option) {
    provider.selectDisease(option);
    Navigator.pop(context);
  }
}

class _DiseaseTile extends StatelessWidget {
  const _DiseaseTile({
    required this.option,
    required this.isSelected,
    required this.onSelect,
  });

  final DiseaseOption option;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : const Color(0xFFFFF0F5);
    final unselectedColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      color: isSelected ? selectedColor : unselectedColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle,
                        color: theme.colorScheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                option.id,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              if (option.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  option.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
