import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'l10n/app_localizations.dart';
import 'providers/connectivity_provider.dart';
import 'providers/data_provider.dart';
import 'providers/evidence_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/home_screen.dart';
import 'services/lincs_service.dart';
import 'services/network/api_client.dart';
import 'services/network/network_consent.dart';
import 'services/network/response_cache.dart';
import 'services/open_targets_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

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
  final themeProvider = ThemeProvider()..load();
  final localeProvider = LocaleProvider()..load();
  final apiClient = ApiClient(
    hasConsent: () => consent.allowExternalRequests,
    cache: cache,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: consent),
        Provider<ResponseCache>.value(value: cache),
        Provider<ApiClient>.value(value: apiClient),
        Provider<OpenTargetsService>(
          create: (ctx) => OpenTargetsService(client: ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<EvidenceProvider>(
          create: (ctx) =>
              EvidenceProvider(service: ctx.read<OpenTargetsService>()),
        ),
        Provider<LincsService>(
          create: (ctx) => LincsService(client: ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (ctx) =>
              ConnectivityProvider(lincsService: ctx.read<LincsService>()),
        ),
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
    final themeProvider = context.watch<ThemeProvider?>();
    final localeProvider = context.watch<LocaleProvider?>();
    final mode = themeProvider?.themeMode ?? ThemeMode.system;

    return MaterialApp(
      title: 'OncoRepurpose',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      locale: localeProvider?.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}

