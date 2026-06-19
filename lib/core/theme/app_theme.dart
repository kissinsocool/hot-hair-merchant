import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPink = Color(0xFFE8A2B0);
  static const Color bgCream = Color(0xFFFDFBF9);
  static const Color textDark = Color(0xFF5A5A5A);
  static const Color accentBeige = Color(0xFFE8DCD0);
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        primary: primaryPink,
        surface: white,
      ),
      primaryColor: primaryPink,
      scaffoldBackgroundColor: bgCream,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyLarge: TextStyle(color: textDark, fontSize: 16),
        bodyMedium: TextStyle(color: textDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
