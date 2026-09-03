import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/network/network_consent.dart';
import '../services/network/response_cache.dart';
import '../widgets/evidence_widgets.dart';

/// Controls whether the app may contact external services, and what it has
/// stored locally.
///
/// External lookups are off by default and every existing feature works with
/// them off, since they all run against the bundled database. This screen states
/// exactly what would be transmitted rather than asking for a blanket
/// permission.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.cache});

  final ResponseCache cache;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CacheStats? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final stats = await widget.cache.stats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading('External lookups',
                      icon: Icons.cloud_outlined),
                  const SizedBox(height: 16),
                  _buildConsentCard(),
                  const SizedBox(height: 32),
                  const SectionHeading('Stored data',
                      icon: Icons.storage_outlined),
                  const SizedBox(height: 16),
                  _buildCacheCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsentCard() {
    return Consumer<NetworkConsent>(
      builder: (context, consent, _) {
        // Material rather than a decorated Container: a ListTile paints its
        // background and ink splashes on the nearest Material ancestor, so a
        // coloured Container between the two hides them, which Flutter asserts
        // on in debug builds.
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('Allow external lookups',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    consent.allowExternalRequests
                        ? 'Gene symbols you query are sent to external '
                            'services.'
                        : 'Off. Nothing leaves this device.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: consent.allowExternalRequests,
                  onChanged: consent.isLoaded
                      ? (value) => consent.setAllowed(value)
                      : null,
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bullet(
                        'What is sent: the gene symbols in your query, for '
                        'example "TP53". Nothing else - no fold changes, no '
                        'p-values, no file contents, no identifiers.',
                      ),
                      _Bullet(
                        'Why it matters: a gene list from an unpublished study '
                        'reveals what you are working on before you publish it.',
                      ),
                      _Bullet(
                        'What still works with this off: everything the app '
                        'does today. Drug search, gene-set lookups, your own '
                        'study analysis, and the directional check all run '
                        'against the bundled database.',
                      ),
                      _Bullet(
                        'Responses are cached on this device so repeat lookups '
                        'work offline.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCacheCard() {
    final stats = _stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stats == null
                      ? 'Checking cached responses...'
                      : stats.isEmpty
                          ? 'No cached responses'
                          : '${stats.entries} cached response'
                              '${stats.entries == 1 ? '' : 's'}  -  '
                              '${stats.sizeLabel}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Cached responses are kept for up to 30 days and reused when the '
            'network is unavailable, labelled as an offline copy.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed:
                  _busy || (stats?.isEmpty ?? true) ? null : _clearCache,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear cached responses'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    await widget.cache.clear();
    await _refreshStats();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Cached responses cleared')),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
