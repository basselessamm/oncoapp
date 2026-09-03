import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../services/network/network_consent.dart';
import '../services/network/response_cache.dart';
import '../theme/theme_provider.dart';
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإعدادات والخصوصية' : 'Settings & Privacy'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeading(
                    isAr ? 'لغة التطبيق' : 'Language',
                    icon: Icons.language_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageCard(isAr),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'المظهر والثيم' : 'Appearance',
                    icon: Icons.palette_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildThemeCard(),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'الاتصال الخارجي والبيانات السحابية' : 'External lookups',
                    icon: Icons.cloud_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildConsentCard(),
                  const SizedBox(height: 32),
                  SectionHeading(
                    isAr ? 'البيانات المخزنة محلياً' : 'Stored data',
                    icon: Icons.storage_outlined,
                  ),
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

  Widget _buildLanguageCard(bool isAr) {
    final localeProvider = context.watch<LocaleProvider?>();
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    final selectedCode = localeProvider?.locale?.languageCode ?? 'system';

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr ? 'لغة واجهة المستخدم' : 'Interface Language',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'اختر اللغة العربية للتعريب الكامل ودعم الاتجاه من اليمين لليسار، أو الإنجليزية، أو مطابقة إعدادات الجهاز.'
                  : 'Select Arabic for full right-to-left localization, English, or match system preference.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'system',
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('النظام / System'),
                ),
                ButtonSegment<String>(
                  value: 'en',
                  label: Text('EN'),
                ),
                ButtonSegment<String>(
                  value: 'ar',
                  label: Text('عربي'),
                ),
              ],
              selected: {selectedCode},
              onSelectionChanged: (selection) {
                final code = selection.first;
                if (code == 'system') {
                  localeProvider?.setLocale(null);
                } else {
                  localeProvider?.setLocale(Locale(code));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard() {
    final themeProvider = context.watch<ThemeProvider?>();
    if (themeProvider == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr ? 'نمط الواجهة والمظهر' : 'Interface Theme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'اختر بين النمط الداكن الفاخر (Midnight Slate) أو النمط الطبي الناصع أو مظهر النظام.'
                  : 'Choose between OLED Midnight Slate, Crisp Biotech White, or automatic system appearance.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(isAr ? 'النظام' : 'System'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(isAr ? 'نهاري' : 'Light'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(isAr ? 'ليلي' : 'Dark'),
                ),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (newSelection) {
                themeProvider.setThemeMode(newSelection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard() {
    return Consumer<NetworkConsent>(
      builder: (context, consent, _) {
        final theme = Theme.of(context);
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
        final borderColor = theme.colorScheme.outline;

        return Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: Text(
                    isAr ? 'السماح بالاستعلامات السحابية الخارجية' : 'Allow external lookups',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    consent.allowExternalRequests
                        ? (isAr
                            ? 'يتم إرسال رموز الجينات للخدمات الخارجية (Open Targets & LINCS).'
                            : 'Gene symbols you query are sent to external services.')
                        : (isAr
                            ? 'متوقف. لا شيء يغادر هذا الجهاز مطلقاً.'
                            : 'Off. Nothing leaves this device.'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: consent.allowExternalRequests,
                  onChanged: consent.isLoaded
                      ? (value) => consent.setAllowed(value)
                      : null,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bullet(
                        isAr
                            ? 'البيانات المرسلة: رموز الجينات في استعلامك فقط (مثل "TP53"). لا شيء آخر - لا نسب تغير لوغاريتمي، لا قيم احتمالية، لا محتوى ملفات، ولا أي معرفات.'
                            : 'What is sent: the gene symbols in your query, for example "TP53". Nothing else - no fold changes, no p-values, no file contents, no identifiers.',
                      ),
                      _Bullet(
                        isAr
                            ? 'أهمية الخصوصية: قائمة الجينات من دراسة غير منشورة قد تكشف موضوع بحثك قبل نشره رسمياً.'
                            : 'Why it matters: a gene list from an unpublished study reveals what you are working on before you publish it.',
                      ),
                      _Bullet(
                        isAr
                            ? 'ما يعمل والتطبيق متوقف: كل ما يقدمه التطبيق اليوم! البحث عن الأدوية، فحص مجموعات الجينات، وتحليل دراستك الخاصة وفحص التوافق الاتجاهي كلها تعمل محلياً على قاعدة البيانات المدمجة.'
                            : 'What still works with this off: everything the app does today. Drug search, gene-set lookups, your own study analysis, and the directional check all run against the bundled database.',
                      ),
                      _Bullet(
                        isAr
                            ? 'الجهات المستقبلة: تُرسل الطلبات لمنصة Open Targets (opentargets.org) ومبادرة NIH LINCS L1000FWD. لا توجد أي بيانات مرضى أو ملفات تغادر جهازك.'
                            : 'Recipients: requests are sent to the Open Targets Platform (opentargets.org) and NIH LINCS L1000FWD (maayanlab.cloud/l1000fwd). No patient data, file contents, or identifiers leave this device.',
                      ),
                      _Bullet(
                        isAr
                            ? 'يتم تخزين الاستجابات مؤقتاً على هذا الجهاز لتعمل الاستعلامات المتكررة دون اتصال.'
                            : 'Responses are cached on this device so repeat lookups work offline.',
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
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stats == null
                      ? (isAr ? 'جاري فحص الاستجابات المخزنة...' : 'Checking cached responses...')
                      : stats.isEmpty
                          ? (isAr ? 'لا توجد استجابات مخزنة مؤقتاً' : 'No cached responses')
                          : (isAr
                              ? '${stats.entries} استجابة مخزنة  -  ${stats.sizeLabel}'
                              : '${stats.entries} cached response${stats.entries == 1 ? '' : 's'}  -  ${stats.sizeLabel}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'تُحفظ الاستجابات المخزنة لمدة تصل إلى 30 يوماً ويُعاد استخدامها عند انقطاع الاتصال بالإنترنت كنسخة محلية محفوظة.'
                : 'Cached responses are kept for up to 30 days and reused when the network is unavailable, labelled as an offline copy.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed:
                  _busy || (stats?.isEmpty ?? true) ? null : _clearCache,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(isAr ? 'مسح الاستجابات المخزنة' : 'Clear cached responses'),
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
