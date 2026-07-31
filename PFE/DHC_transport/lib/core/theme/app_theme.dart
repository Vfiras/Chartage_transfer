import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData darkTheme({TextTheme? baseTextTheme}) =>
      _theme(baseTextTheme: baseTextTheme, brightness: Brightness.dark);

  static ThemeData lightTheme({TextTheme? baseTextTheme}) =>
      _theme(baseTextTheme: baseTextTheme, brightness: Brightness.light);

  static ThemeData _theme({
    TextTheme? baseTextTheme,
    required Brightness brightness,
  }) {
    final textTheme = (baseTextTheme ?? const TextTheme()).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.secondary,
        primary: AppColors.secondary,
        onPrimary: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        brightness: brightness,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        headerBackgroundColor: AppColors.surface,
        headerForegroundColor: AppColors.textPrimary,
        subHeaderForegroundColor: AppColors.textSecondary,
        dividerColor: AppColors.softBorder,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        headerHelpStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        headerHeadlineStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
        weekdayStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
        dayStyle: TextStyle(fontWeight: FontWeight.w700),
        dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textHint.withValues(alpha: 0.45);
          }
          return AppColors.textSecondary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.secondaryLight;
        }),
        todayBorder: BorderSide(color: AppColors.secondary, width: 1.4),
        yearForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textHint.withValues(alpha: 0.45);
          }
          return AppColors.textSecondary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary;
          }
          return Colors.transparent;
        }),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        dialBackgroundColor: AppColors.surfaceElevated,
        dialHandColor: AppColors.secondary,
        dialTextColor: AppColors.textPrimary,
        hourMinuteColor: AppColors.surfaceElevated,
        hourMinuteTextColor: AppColors.textPrimary,
        dayPeriodColor: AppColors.surfaceElevated,
        dayPeriodTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.secondary,
        helpTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.secondary),
        ),
        labelStyle: TextStyle(color: AppColors.textMuted),
        hintStyle: TextStyle(color: AppColors.textHint),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
