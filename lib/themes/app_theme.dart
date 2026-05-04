import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryText = Color(0xFF0F1723);
  static const Color subtleGray = Color(0xFFF5F5F5);
  static const Color cardBorder = Color(0xFFE6E6E6);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color overlayDark = Color(0x73000000);

  static const double radius = 12;
  static const BoxShadow cardShadow = BoxShadow(
    blurRadius: 12,
    offset: Offset(0, 6),
    color: Color(0x0F0C0C0C),
  );

  static ThemeData light() {
    final textTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentGold,
        primary: primaryText,
        secondary: accentGold,
        surface: Colors.white,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 36,
          height: 48 / 36,
          fontWeight: FontWeight.w700,
          color: primaryText,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w600,
          color: primaryText,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryText,
          letterSpacing: 0,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 16,
          height: 24 / 16,
          color: primaryText,
          letterSpacing: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentGold, width: 1.2),
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFBBBBBB),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryText,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
