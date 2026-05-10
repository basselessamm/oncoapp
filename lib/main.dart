import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import unified providers and screens
import 'providers/data_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProvider()..loadData())
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
      title: 'OncoRepurpose AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC2185B), 
          primary: const Color(0xFFE91E63),
          secondary: const Color(0xFFF48FB1),
        ),
        scaffoldBackgroundColor: const Color(0xFFFCE4EC), // Light pink background
        appBarTheme: const AppBarTheme(
          elevation: 0, 
          backgroundColor: Colors.transparent, 
          foregroundColor: Color(0xFFC2185B), 
          centerTitle: true
        ),
      ),
      home: const HomeScreen(),
    );
  }
}