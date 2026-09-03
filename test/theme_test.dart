import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/theme/app_theme.dart';
import 'package:onco_repurpose_ai/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('light theme has correct brightness and extensions', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      final ext = theme.extension<EvidenceThemeColors>();
      expect(ext, isNotNull);
      expect(ext!.opposesInk, EvidenceThemeColors.light.opposesInk);
      expect(ext.strongReversalInk, EvidenceThemeColors.light.strongReversalInk);
    });

    test('dark theme has correct brightness and extensions', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      final ext = theme.extension<EvidenceThemeColors>();
      expect(ext, isNotNull);
      expect(ext!.opposesInk, EvidenceThemeColors.dark.opposesInk);
      expect(ext.strongReversalInk, EvidenceThemeColors.dark.strongReversalInk);
    });
  });

  group('ThemeProvider', () {
    late Directory tempDir;
    late File tempFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('theme_test');
      tempFile = File('${tempDir.path}/theme.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('starts with system mode and switches cleanly', () async {
      final provider = ThemeProvider(storageFile: tempFile);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isSystem, isTrue);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDark, isTrue);
      expect(await tempFile.exists(), isTrue);

      // Verify reloaded state
      final fresh = ThemeProvider(storageFile: tempFile);
      await fresh.load();
      expect(fresh.themeMode, ThemeMode.dark);
      expect(fresh.isDark, isTrue);
    });
  });
}
