import 'package:flutter/material.dart';
import 'screens/form_screen.dart';

void main() {
  runApp(const SimularCDIApp());
}

class SimularCDIApp extends StatelessWidget {
  const SimularCDIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simulador CDI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald 500
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        // We use standard Material TextTheme but we'll style locally
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A), // Slate 900
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const FormScreen(),
    );
  }
}
