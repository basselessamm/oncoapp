import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
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
      title: 'OncoRepurpose AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Modern deep medical blue
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF00B0FF),
          surface: Colors.white,
          background: const Color(0xFFF5F7FA), // Clean, slightly grayish white
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0D47A1),
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
