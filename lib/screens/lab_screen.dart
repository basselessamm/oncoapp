import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'filter_config_screen.dart';
import 'genomic_data_screen.dart';

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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tsv', 'csv'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        if (_nameController.text.isEmpty) {
          _nameController.text = result.files.single.name.split('.').first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Research Lab', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUploadSection(),
                const SizedBox(height: 32),
                _buildStudiesSection(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📁 Upload New Study', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF48FB1), width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFFE91E63)),
                const SizedBox(height: 8),
                Text(
                  _selectedFile == null ? 'Tap to select TSV/CSV file' : _selectedFile!.path.split(Platform.pathSeparator).last,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: _buildInputDecoration('Study Name', Icons.title),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pmidController,
                decoration: _buildInputDecoration('PMID (Optional)', Icons.link),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sizeController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Sample Size', Icons.groups),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _selectedFile == null ? null : () => _proceedToConfig(),
          icon: const Icon(Icons.biotech, color: Colors.white),
          label: const Text('Configure & Analyze', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStudiesSection(DataProvider provider) {
    if (provider.labStudies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        const Text('📚 My Lab Studies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
        const SizedBox(height: 16),
        ...provider.labStudies.map((study) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFCE4EC), child: Icon(Icons.analytics, color: Color(0xFFC2185B))),
            title: Text(study.cancerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Genes: ${study.significantGenes.length} | Sample: ${study.sampleSize}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                  onPressed: () {
                    provider.selectDataset(study);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GenomicDataScreen()));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(provider, study),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  void _proceedToConfig() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a study name')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterConfigScreen(
          file: _selectedFile!,
          studyName: _nameController.text,
          pmid: _pmidController.text,
          sampleSize: int.tryParse(_sizeController.text) ?? 0,
        ),
      ),
    );
  }

  void _confirmDelete(DataProvider provider, dynamic study) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Study?'),
        content: Text('Are you sure you want to delete "${study.cancerName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteLabStudy(study);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
