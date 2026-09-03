import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/evidence_widgets.dart';

/// About page: scope of the app, where its data comes from, and credits.
///
/// The data-provenance and limitations sections are the substance here. A
/// research tool has to state what its numbers are and are not, and this
/// information previously existed nowhere in the app.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const String _dgidbUrl = 'https://www.dgidb.org';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIdentity(),
                  const SizedBox(height: 28),
                  const ResearchUseBanner(),
                  const SizedBox(height: 32),
                  const SectionHeading('Where the data comes from',
                      icon: Icons.storage_outlined),
                  const SizedBox(height: 16),
                  _buildDataSources(context),
                  const SizedBox(height: 32),
                  const SectionHeading('What this app does not do',
                      icon: Icons.report_outlined),
                  const SizedBox(height: 16),
                  _buildLimitations(),
                  const SizedBox(height: 32),
                  const SectionHeading('Credits',
                      icon: Icons.people_outline),
                  const SizedBox(height: 16),
                  _buildCredits(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/icon.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'OncoRepurpose',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'A gene-drug interaction browser for cancer research',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildDataSources(BuildContext context) {
    return Column(
      children: [
        DetailCard(
          icon: Icons.medication_outlined,
          title: 'Gene-drug interactions',
          footnote: 'DGIdb aggregates ChEMBL, DTC, Guide to Pharmacology, TTD, '
              'NCI, PharmGKB and others. Interaction scores measure how well '
              'documented a claim is, not how effective a drug is.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DGIdb (Drug Gene Interaction Database)\n'
                '98,239 records covering 5,012 genes and 18,854 drugs.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _open(context, _dgidbUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('dgidb.org'),
              ),
            ],
          ),
        ),
        const DetailCard(
          icon: Icons.biotech_outlined,
          title: 'Reference gene signatures',
          footnote: 'Bundled signatures are fixed top-N gene lists published '
              'with each study. They are provided as examples; your own study '
              'files are the intended input.',
          child: Text(
            'TCGA Breast Invasive Carcinoma (PanCancer Atlas) and three '
            'triple-negative breast cancer subtype comparisons.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  /// Explicit statement of the app's limits.
  ///
  /// Each entry corresponds to a capability the interface previously implied
  /// but did not have. The directional check added in Phase 1 is described in
  /// terms of what it can and cannot establish.
  Widget _buildLimitations() {
    const limitations = [
      (
        Icons.psychology_outlined,
        'No machine learning',
        'Results come from SQL queries over a fixed database, plus a '
            'directional consistency check. There is no model, no training, '
            'and no prediction.',
      ),
      (
        Icons.swap_vert,
        'Direction is a check, not a prediction',
        'The app compares a drug\'s reported direction of action against the '
            'direction each gene moved in the study. But mRNA level is not '
            'protein activity, and a dysregulated gene may be a passenger '
            'rather than a driver of the tumour. Reversing a passenger achieves '
            'nothing.',
      ),
      (
        Icons.help_outline,
        'Most mechanisms are unreported',
        '64% of records in the bundled database name no interaction type, so '
            'no direction can be inferred for them. Those candidates are '
            'labelled undetermined rather than assumed favourable.',
      ),
      (
        Icons.hub_outlined,
        'No pathway or network analysis',
        'Genes are queried individually. Pathway enrichment, protein '
            'interaction neighbours, feedback loops, and a drug\'s targets '
            'outside your gene set are not considered.',
      ),
      (
        Icons.science_outlined,
        'No docking or binding predictions',
        'Earlier versions displayed a binding affinity figure. That value was '
            'a placeholder constant and has been removed.',
      ),
    ];

    return Column(
      children: [
        for (final (icon, title, body) in limitations)
          DetailCard(
            icon: icon,
            title: title,
            child: Text(body,
                style: const TextStyle(fontSize: 13, height: 1.45)),
          ),
      ],
    );
  }

  Widget _buildCredits() {
    const founders = [
      'Dr. Salma Kamal Ahmed',
      'Dr. Laila Ahmed Mohamed',
      'Dr. Rawan Ashraf Elkhelaly',
      'Dr. Yasmin Reda Mohamed',
      'Dr. Naira Mohamed Ismail',
      'Dr. Mariam Nabil Abdalla',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Project idea and research',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),
          for (final name in founders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle,
                      size: 6, color: AppColors.primaryLight),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(name,
                          style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          const Divider(height: 28),
          const Text('Development',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Eng. Bassel Essam', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}
