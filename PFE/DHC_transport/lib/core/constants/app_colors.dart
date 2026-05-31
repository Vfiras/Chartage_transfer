import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF030303);
  static const Color secondary = Color(0xFFC8A96B);
  static const Color secondaryDark = Color(0xFF8E7745);
  static const Color secondaryLight = Color(0xFFE0C68A);
  static const Color lightAccent = Color(0xFFC8A96B);
  static const Color lightAccentText = Color(0xFF8E7745);
  static const Color tertiary = Color(0xFF9FACD7);
  static const Color neutral = Color(0xFF7B7670);

  static bool _isDark = true;

  static bool get isDark => _isDark;

  static void setDarkMode(bool value) => _isDark = value;

  static Color get background =>
      _isDark ? const Color(0xFF020202) : const Color(0xFFFAF7EF);
  static Color get surface =>
      _isDark ? const Color(0xFF101010) : const Color(0xFFFFFEFA);
  static Color get surfaceElevated =>
      _isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF3ECDE);
  static Color get surfaceSoft =>
      _isDark ? const Color(0xFF080808) : const Color(0xFFFBF5EA);
  static Color get lightCard =>
      _isDark ? const Color(0xFFF7F1E3) : const Color(0xFFFFFFFF);

  static Color get textPrimary =>
      _isDark ? const Color(0xFFFFFCF3) : const Color(0xFF15120D);
  static Color get textSecondary =>
      _isDark ? const Color(0xFFD8D1C4) : const Color(0xFF4E473D);
  static Color get textMuted =>
      _isDark ? const Color(0xFF918B80) : const Color(0xFF7E766B);
  static Color get textHint =>
      _isDark ? const Color(0xFF656057) : const Color(0xFFAAA297);

  static Color get border =>
      _isDark ? const Color(0x30C8A96B) : const Color(0x00000000);
  static Color get softBorder =>
      _isDark ? const Color(0x18C8A96B) : const Color(0x00000000);
  static Color get goldBorder =>
      _isDark ? const Color(0x99C8A96B) : const Color(0x44D99A12);
  static Color get accent => _isDark ? secondary : lightAccent;
  static Color get accentText => _isDark ? secondary : lightAccentText;
  static const Color danger = Color(0xFFB24B4B);

  static const Color blue = Color(0xFF4A90D9);
  static const Color green = Color(0xFF27AE60);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color pink = Color(0xFFD9534F);
  static const Color teal = Color(0xFF00A896);
  static const Color whatsapp = Color(0xFF25D366);

  static const Color chipBlueBg = Color(0x1A4A90D9);
  static const Color chipGoldBg = Color(0x24D4AF37);
  static const Color chipGreenBg = Color(0x1A27AE60);
  static const Color chipPurpleBg = Color(0x1A7B5EA7);
  static const Color chipPinkBg = Color(0x1AD9534F);
  static const Color chipTealBg = Color(0x1A00A896);
}
