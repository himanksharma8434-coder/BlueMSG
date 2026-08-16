import 'package:flutter/material.dart';

/// Cyberpunk / Modern Dark Mesh design system for bitmsg.
class AppTheme {
  static const Color background = Color(0xFF070B12);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceLight = Color(0xFF1E293B);
  static const Color cardBorder = Color(0xFF334155);

  static const Color primaryCyan = Color(0xFF00F2FE);
  static const Color primaryPurple = Color(0xFF9D50BB);
  static const Color accentMint = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);

  // Disaster Crisis & Relief Colors
  static const Color sosRed = Color(0xFFFF334B);
  static const Color sosOrange = Color(0xFFFF8800);
  static const Color medicalCyan = Color(0xFF00E5FF);
  static const Color foodAmber = Color(0xFFFFB300);
  static const Color waterBlue = Color(0xFF00B0FF);
  static const Color shelterEmerald = Color(0xFF00E676);
  static const Color powerPurple = Color(0xFFE040FB);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sosGradient = LinearGradient(
    colors: [sosRed, sosOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient medicalGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> cyanGlow({double blur = 12, double opacity = 0.3}) => [
        BoxShadow(
          color: primaryCyan.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> purpleGlow({double blur = 12, double opacity = 0.3}) => [
        BoxShadow(
          color: primaryPurple.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> sosGlow({double blur = 14, double opacity = 0.4}) => [
        BoxShadow(
          color: sosRed.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];

  static BoxDecoration glassDecoration({
    Color? color,
    Color borderColor = cardBorder,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: color ?? surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ],
    );
  }

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
        elevation: 4,
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
