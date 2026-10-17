import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Spacing (8-point grid) and radii from docs/SPEC.md.
abstract final class AppSpacing {
  static const screen = 20.0;
  static const s1 = 8.0;
  static const s2 = 16.0;
  static const s3 = 24.0;
  static const s4 = 32.0;
}

abstract final class AppRadii {
  static const card = 24.0;
  static const sheet = 28.0;
}

abstract final class AppTheme {
  static const _pill = StadiumBorder();

  static TextTheme _textTheme() {
    const base = TextTheme(
      // Display 28/34 semibold
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w600,
      ),
      // Title 20/28 semibold
      titleLarge: TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      // Body 16/24 regular
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      // Label 14/20 medium
      labelLarge: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
      // Caption 12/16
      bodySmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
      ),
    );
    return GoogleFonts.interTextTheme(
      base,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.ink);
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: AppColors.brand,
      secondary: AppColors.brand,
      onSecondary: AppColors.ink,
      tertiary: AppColors.brandStrong,
      onTertiary: AppColors.surface,
      error: AppColors.danger,
      onError: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerHighest: AppColors.surface2,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: _textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // No drop shadows on mobile: white cards on the off-white background.
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      // Primary button: full-width black pill, 56 px, teal label.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.brand,
          minimumSize: const Size.fromHeight(56),
          shape: _pill,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      // Secondary button: white pill with ink text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide.none,
          shape: _pill,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface2,
        shape: StadiumBorder(),
        side: BorderSide.none,
      ),
    );
  }
}
