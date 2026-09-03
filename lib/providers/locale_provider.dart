import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages application Locale (Arabic, English, System) with disk persistence.
class LocaleProvider with ChangeNotifier {
  LocaleProvider({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  Locale? _locale = const Locale('ar');

  /// Returns explicit user locale, or null if following system default.
  Locale? get locale => _locale;

  bool get isSystem => _locale == null;
  bool get isExplicitArabic => _locale?.languageCode == 'ar';
  bool get isExplicitEnglish => _locale?.languageCode == 'en';

  bool isArabicActive(BuildContext context) {
    if (_locale != null) {
      return _locale!.languageCode == 'ar';
    }
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  Future<void> load() async {
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final lang = json['language_code'] as String?;
        if (lang == 'ar' || lang == 'en') {
          _locale = Locale(lang!);
          notifyListeners();
        }
      }
    } catch (_) {
      // Fail safely to system default
    }
  }

  Future<void> setLocale(Locale? newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    await _save();
  }

  Future<void> toggleLocale(BuildContext context) async {
    final isArabic = isArabicActive(context);
    await setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }

  Future<void> _save() async {
    try {
      final file = await _resolveStorageFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'language_code': _locale?.languageCode,
      }));
    } catch (_) {
      // Storage errors shouldn't crash the UI
    }
  }

  Future<File> _resolveStorageFile() async {
    if (_storageOverride != null) return _storageOverride;
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'oncoapp_locale.json'));
  }
}
