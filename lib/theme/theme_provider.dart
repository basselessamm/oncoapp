import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages application ThemeMode with disk persistence and system sync.
class ThemeProvider with ChangeNotifier {
  ThemeProvider({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isSystem => _themeMode == ThemeMode.system;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isDark => _themeMode == ThemeMode.dark;

  bool isDarkModeActive(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> load() async {
    try {
      final file = await _resolveStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final modeString = json['theme_mode'] as String?;
        if (modeString != null) {
          _themeMode = ThemeMode.values.firstWhere(
            (m) => m.name == modeString,
            orElse: () => ThemeMode.system,
          );
          notifyListeners();
        }
      }
    } catch (_) {
      // Fail safely to system default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentlyDark = isDarkModeActive(context);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _save() async {
    try {
      final file = await _resolveStorageFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'theme_mode': _themeMode.name}));
    } catch (_) {
      // Storage errors shouldn't crash the UI
    }
  }

  Future<File> _resolveStorageFile() async {
    if (_storageOverride != null) return _storageOverride;
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'oncoapp_theme_mode.json'));
  }
}
