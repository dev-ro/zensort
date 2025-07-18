import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenSortTheme {
  // Colors
  static const Color scaffoldBackground = Color(0xFFF5F5F5);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF6A8A82);
  static const Color accentColor = Color(0xFFC2DCD3);

  // Gradient Colors for Buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFFF9D00),
      Color(0xFFF75830),
      Color(0xFFF11E5A),
      Color(0xFF9800A6),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Text Styles
  static final TextStyle headline = GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: darkText,
  );

  static final TextStyle body = GoogleFonts.nunito(
    fontSize: 16,
    color: darkText,
  );

  static final TextStyle bodyLight = GoogleFonts.nunito(
    fontSize: 16,
    color: lightText,
  );

  static final TextStyle button = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: lightText,
  );
}

ThemeData getLightTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ZenSortTheme.scaffoldBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: ZenSortTheme.primaryColor,
      onPrimary: ZenSortTheme.lightText,
      secondary: ZenSortTheme.accentColor,
      onSecondary: ZenSortTheme.darkText,
      error: Colors.red,
      onError: ZenSortTheme.lightText,
      background: ZenSortTheme.scaffoldBackground,
      onBackground: ZenSortTheme.darkText,
      surface: Color(0xFFFFFFFF),
      onSurface: ZenSortTheme.darkText,
    ),
    textTheme:
        TextTheme(
          headlineLarge: ZenSortTheme.headline,
          headlineMedium: ZenSortTheme.headline.copyWith(fontSize: 24),
          headlineSmall: ZenSortTheme.headline.copyWith(fontSize: 20),
          titleLarge: ZenSortTheme.headline.copyWith(fontSize: 18),
          titleMedium: ZenSortTheme.body.copyWith(fontWeight: FontWeight.bold),
          titleSmall: ZenSortTheme.body.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          bodyLarge: ZenSortTheme.body,
          bodyMedium: ZenSortTheme.body.copyWith(fontSize: 14),
          bodySmall: ZenSortTheme.body.copyWith(fontSize: 12),
          labelLarge: ZenSortTheme.button,
          labelMedium: ZenSortTheme.button.copyWith(fontSize: 16),
          labelSmall: ZenSortTheme.button.copyWith(fontSize: 14),
        ).apply(
          bodyColor: ZenSortTheme.darkText,
          displayColor: ZenSortTheme.darkText,
        ),
  );
}
