import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenSortTheme {
  // Colors
  static const Color scaffoldBackground = Color(0xFFFAFAFA); // Clean off-white
  static const Color darkText = Color(0xFF4A5568); // From "Zen" in logo
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF424242); // Dark Grey
  static const Color accentColor = Color(0xFFBDBDBD); // Medium Grey
  static const Color purple = Color(0xFF9800A6);

  // Gradient Colors for Buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF9D00), Color(0xFFF75830), Color(0xFFF11E5A), Color(0xFF9800A6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [
      Color(0xFF9800A6), // Purple
      Color(0xFFF11E5A), // Pink
      Color(0xFFF75830), // Orange-Red
      Color(0xFFFF9D00), // Orange
      Color(0xFFF75830), // Orange-Red
      Color(0xFFF11E5A), // Pink
      Color(0xFF9800A6), // Purple
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient orangePurpleGradient = LinearGradient(
    colors: [Color(0xFFF75830), Color(0xFF9800A6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    tileMode: TileMode.mirror,
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
    fontFamily: GoogleFonts.nunito().fontFamily,
  );
}
