import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/data_provider.dart';
import 'screens/home_screen.dart';
import 'services/network/api_client.dart';
import 'services/network/network_consent.dart';
import 'services/network/response_cache.dart';
import 'widgets/evidence_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // `dart:io` Platform throws on web. This app cannot run on web anyway - it
  // depends on a local SQLite file and path_provider - so the guard documents
  // the constraint rather than pretending to support it.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Consent is loaded before any feature can request the network. It defaults to
  // denied, and the client refuses to send anything until it reports otherwise.
  final consent = NetworkConsent()..load();
  final cache = ResponseCache();
  final apiClient = ApiClient(
    hasConsent: () => consent.allowExternalRequests,
    cache: cache,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: consent),
        Provider<ResponseCache>.value(value: cache),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => DataProvider()..loadData()),
      ],
      child: const OncoApp(),
    ),
  );
}

class OncoApp extends StatelessWidget {
  const OncoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OncoRepurpose',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  /// Single source of truth for component styling.
  ///
  /// Styles were previously written inline at every call site, so 64 raw hex
  /// literals coexisted with a `ColorScheme` that no screen ever read.
  static ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryDark,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
        ),
        iconTheme: IconThemeData(color: AppColors.primaryDark),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(horizontal: 4),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primaryDark,
        thumbColor: AppColors.primaryDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1),
    );
  }
}
