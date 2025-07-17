import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenSortTheme {
  // Colors
  static const Color scaffoldBackground = Color(0xFFF5F5F5);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF6A8A82);
  static const Color accentColor = Color(0xFFC2DCD3);

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
