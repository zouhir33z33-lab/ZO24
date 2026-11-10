import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'app_colors.dart';

enum AppThemeKind { light, dark, national }

class AppTheme {
  static ThemeData of(AppThemeKind kind) {
    switch (kind) {
      case AppThemeKind.dark:
        return _build(
          brightness: Brightness.dark,
          primary: const Color(0xFF1E5BBF),
          bg: AppColors.darkBackground,
          surface: AppColors.darkSurface,
          appBar: const Color(0xFF0B2F6B),
        );
      case AppThemeKind.national:
        return _build(
          brightness: Brightness.light,
          primary: AppColors.nationalGreen,
          bg: const Color(0xFFF4F8F5),
          surface: Colors.white,
          appBar: AppColors.nationalGreen,
        );
      case AppThemeKind.light:
        return _build(
          brightness: Brightness.light,
          primary: AppColors.primary,
          bg: AppColors.background,
          surface: AppColors.surface,
          appBar: AppColors.primary,
        );
    }
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color bg,
    required Color surface,
    required Color appBar,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(primary: primary, surface: surface);
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppConstants.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: AppConstants.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.12),
      ),
    );
  }
}
