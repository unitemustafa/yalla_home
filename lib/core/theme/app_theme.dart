import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Cairo';

  static TextTheme get _lightTextTheme => const TextTheme(
    headlineLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      color: AppColors.lightTextPrimary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.lightTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(color: AppColors.lightTextPrimary, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
    bodySmall: TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
  ).apply(fontFamily: fontFamily);

  static TextTheme get _darkTextTheme => const TextTheme(
    headlineLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      color: AppColors.darkTextPrimary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: AppColors.darkTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
    bodySmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
  ).apply(fontFamily: fontFamily);

  static ThemeData get lightTheme => _baseTheme(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardColor: AppColors.lightCardColor,
    textTheme: _lightTextTheme,
    inputBorderColor: const Color(0xFFE4E7F0),
  );

  static ThemeData get darkTheme => _baseTheme(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardColor: AppColors.darkCardColor,
    textTheme: _darkTextTheme,
    inputBorderColor: Colors.white.withValues(alpha: 0.12),
  );

  static ThemeData _baseTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required TextTheme textTheme,
    required Color inputBorderColor,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        surface: scaffoldBackgroundColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.38),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF222326) : const Color(0xFFF5F6FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: TextStyle(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
