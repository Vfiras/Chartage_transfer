import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get h1 => GoogleFonts.comfortaa(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.1,
        letterSpacing: -0.2,
      );

  static TextStyle get h2 => GoogleFonts.comfortaa(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get h3 => GoogleFonts.comfortaa(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  static TextStyle get title => GoogleFonts.comfortaa(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.comfortaa(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.comfortaa(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      );

  static TextStyle get overline => GoogleFonts.comfortaa(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: AppColors.secondary,
      );

  static TextStyle get button => GoogleFonts.comfortaa(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      );
}
