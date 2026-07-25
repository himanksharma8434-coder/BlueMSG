import 'package:flutter/material.dart';

/// Cyberpunk / Modern Dark Mesh design system for bitmsg.
class AppTheme {
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFF1F2937);
  static const Color cardBorder = Color(0xFF374151);

  static const Color primaryCyan = Color(0xFF00F2FE);
  static const Color primaryPurple = Color(0xFF9D50BB);
  static const Color accentMint = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFBF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: primaryPurple,
        surface: surface,
        background: background,
        error: accentRose,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryCyan,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryCyan, width: 1.5),
        ),
      ),
    );
  }
}
