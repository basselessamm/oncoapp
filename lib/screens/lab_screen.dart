import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cancer_signature.dart';
import '../providers/data_provider.dart';
import '../widgets/evidence_widgets.dart';
import 'filter_config_screen.dart';
import 'genomic_data_screen.dart';

/// Upload and manage user-supplied differential-expression studies.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final _nameController = TextEditingController();
  final _pmidController = TextEditingController();
  final _sizeController = TextEditingController();
  File? _selectedFile;

  @override
  void dispose() {
    _nameController.dispose();
    _pmidController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Studies')),
      body: SafeArea(
        child: Consumer<DataProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUploadSection(),
                      if (provider.labStudies.isNotEmpty)
                        _buildStudiesSection(provider),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Upload a study',
            icon: Icons.upload_file_outlined),
        const SizedBox(height: 8),
        const Text(
          'A CSV or TSV table with a gene symbol column, a log2 fold change '
          'column, and a p-value column.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primaryLight, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    size: 36, color: AppColors.primary),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _selectedFile == null
                        ? 'Tap to select a CSV or TSV file'
                        : _fileName(_selectedFile!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: _inputDecoration('Study name', Icons.title),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pmidController,
                decoration:
                    _inputDecoration('PMID (optional)', Icons.link),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sizeController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                    'Sample size (optional)', Icons.groups_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _selectedFile == null ? null : _proceedToConfig,
          icon: const Icon(Icons.tune),
          label: const Text('Configure analysis',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStudiesSection(DataProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 44),
        const SectionHeading('Saved studies',
            icon: Icons.folder_open_outlined),
        const SizedBox(height: 16),
        ...provider.labStudies.map(
          (study) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              title: Text(study.cancerName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${study.significantGenes.length} genes  -  '
                '${study.upregulatedCount} up, ${study.downregulatedCount} down'
                '${study.sampleSize > 0 ? '  -  n=${study.sampleSize}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    tooltip: 'View genes in ${study.cancerName}',
                    onPressed: () {
                      provider.selectDataset(study);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GenomicDataScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete ${study.cancerName}',
                    onPressed: () => _confirmDelete(provider, study),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  static String _fileName(File file) =>
      file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;

  Future<void> _pickFile() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['tsv', 'csv', 'txt'],
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file picker: $error')),
      );
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That file could not be read from storage. '
              'Copy it to local storage and try again.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedFile = File(path);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = result!.files.single.name.split('.').first;
      }
    });
  }

  void _proceedToConfig() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a study name first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterConfigScreen(
          file: _selectedFile!,
          studyName: name,
          pmid: _pmidController.text.trim(),
          sampleSize: int.tryParse(_sizeController.text.trim()) ?? 0,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      DataProvider provider, CancerSignature study) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this study?'),
        content: Text('"${study.cancerName}" will be removed from this '
            'device. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.deleteLabStudy(study);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete the study: $error')),
      );
    }
  }
}
