import 'dart:io';

import 'package:flutter/material.dart';

import '../services/study_analysis_service.dart';
import '../widgets/evidence_widgets.dart';
import 'analysis_result_screen.dart';

/// Filter configuration for a user-uploaded differential-expression table.
class FilterConfigScreen extends StatefulWidget {
  const FilterConfigScreen({
    super.key,
    required this.file,
    required this.studyName,
    required this.pmid,
    required this.sampleSize,
  });

  final File file;
  final String studyName;
  final String pmid;
  final int sampleSize;

  @override
  State<FilterConfigScreen> createState() => _FilterConfigScreenState();
}

class _FilterConfigScreenState extends State<FilterConfigScreen> {
  // Defaults come from AnalysisConfig so the two cannot drift apart.
  static const AnalysisConfig _defaults = AnalysisConfig();

  int _upCount = _defaults.upCount;
  int _downCount = _defaults.downCount;
  double _pValue = _defaults.pValueThreshold;
  double _log2fc = _defaults.minLog2FC;
  MultipleTestingCorrection _correction = _defaults.correction;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFileCard(),
              const SizedBox(height: 28),
              const SectionHeading('Significance', icon: Icons.analytics),
              const SizedBox(height: 16),
              _buildCorrectionSelector(),
              const SizedBox(height: 20),
              _buildPValueSelector(),
              const SizedBox(height: 20),
              _buildFoldChangeSlider(),
              const SizedBox(height: 32),
              const SectionHeading('Genes to keep', icon: Icons.tune),
              const SizedBox(height: 8),
              const Text(
                'Genes are ranked by absolute fold change within each '
                'direction, then truncated.',
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _buildCounter(
                'Upregulated',
                _upCount,
                (value) => setState(() => _upCount = value),
              ),
              _buildCounter(
                'Downregulated',
                _downCount,
                (value) => setState(() => _downCount = value),
              ),
              if (_upCount != _downCount) ...[
                const SizedBox(height: 4),
                const Text(
                  'Asymmetric limits bias the signature toward one direction. '
                  'Keep them equal unless the study design justifies '
                  'otherwise.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7A3E00)),
                ),
              ],
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: _running ? null : _analyze,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                icon: _running
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_running ? 'Analysing...' : 'Run analysis',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard() {
    final theme = Theme.of(context);
    final fileName = widget.file.uri.pathSegments.isEmpty
        ? widget.file.path
        : widget.file.uri.pathSegments.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.studyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(fileName,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Multiple-testing correction',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...MultipleTestingCorrection.values.map(
          (correction) => RadioListTile<MultipleTestingCorrection>(
            contentPadding: EdgeInsets.zero,
            value: correction,
            // ignore: deprecated_member_use
            groupValue: _correction,
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) setState(() => _correction = value);
            },
            title: Text(correction.label,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(correction.explanation,
                style: const TextStyle(fontSize: 11, height: 1.35)),
          ),
        ),
      ],
    );
  }

  Widget _buildPValueSelector() {
    final isAdjusted = _correction != MultipleTestingCorrection.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isAdjusted ? 'Adjusted p-value cutoff' : 'Raw p-value cutoff',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [0.05, 0.01, 0.001].map((threshold) {
            return ChoiceChip(
              label: Text('p <= $threshold'),
              selected: _pValue == threshold,
              onSelected: (_) => setState(() => _pValue = threshold),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFoldChangeSlider() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Minimum |log2FC|',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text(_log2fc.toStringAsFixed(1),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
          ],
        ),
        Slider(
          value: _log2fc,
          max: 5.0,
          divisions: 50,
          label: _log2fc.toStringAsFixed(1),
          onChanged: (value) => setState(() => _log2fc = value),
        ),
        Text(
          _log2fc == 0
              ? 'No effect-size filter.'
              : 'Keeps genes changing at least '
                  '${_foldChangeLabel(_log2fc)}-fold in either direction.',
          style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
        ),
      ],
    );
  }

  static String _foldChangeLabel(double log2fc) {
    final fold = 1 << log2fc.floor();
    return log2fc == log2fc.floorToDouble()
        ? '$fold'
        : '~${(fold * (1 + (log2fc - log2fc.floorToDouble()))).toStringAsFixed(1)}';
  }

  Widget _buildCounter(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            tooltip: 'Decrease $label',
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 56,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'Increase $label',
            onPressed: value < 500 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final signature = await StudyAnalysisService.analyzeStudy(
        file: widget.file,
        studyName: widget.studyName,
        pmid: widget.pmid,
        sampleSize: widget.sampleSize,
        config: AnalysisConfig(
          upCount: _upCount,
          downCount: _downCount,
          pValueThreshold: _pValue,
          minLog2FC: _log2fc,
          correction: _correction,
        ),
      );

      if (!mounted) return;
      setState(() => _running = false);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(signature: signature),
        ),
      );
    } on StudyAnalysisException catch (error) {
      if (!mounted) return;
      setState(() => _running = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _running = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $error'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }
}
