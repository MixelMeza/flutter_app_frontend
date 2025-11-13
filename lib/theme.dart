import 'package:flutter/material.dart';

class AppColors {
  // Base palette
  static const Color tan = Color(0xFFD8BA98);
  static const Color maroon = Color(0xFF7F0303);
  static const Color alabaster = Color(0xFFEFE8DF);
  static const Color lightBlue = Color(0xFF96C0CE);
  static const Color midnightBlue = Color(0xFF0F414A);

  // Derived / semantic colors will be provided by AppTheme
}

class AppTheme {
  // Light ThemeData
  static ThemeData lightTheme({Color? primaryOverride}) {
    final primary = primaryOverride ?? AppColors.midnightBlue;

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        background: AppColors.alabaster,
        onPrimary: AppColors.alabaster,
        onBackground: AppColors.midnightBlue,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.midnightBlue),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.midnightBlue),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.midnightBlue),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.midnightBlue),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.alabaster,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.midnightBlue,
          foregroundColor: AppColors.alabaster,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Dark ThemeData
  static ThemeData darkTheme({Color? primaryOverride}) {
    final primary = primaryOverride ?? AppColors.maroon;
    // base dark surface from midnightBlue; we will derive muted variants from existing palette
    final midnight = AppColors.midnightBlue;

    // Create a slightly desaturated/softer version of primary for surfaces and buttons
    final hPrimary = HSLColor.fromColor(primary);
    final mutedPrimary = hPrimary
        .withSaturation((hPrimary.saturation * 0.72).clamp(0.0, 1.0))
        .withLightness((hPrimary.lightness * 0.9).clamp(0.0, 1.0))
        .toColor();

    // Surface color: blend a little of primary over midnight to warm the surfaces without adding new constants
    final surface = Color.alphaBlend(mutedPrimary.withOpacity(0.06), midnight);

    // Input fill: subtle translucent version of midnight for contrast
    final inputFill = midnight.withOpacity(0.14);

    // Card color a touch lighter than scaffold so the card stands out with BackdropFilter
    final cardColor = Color.alphaBlend(Colors.black.withOpacity(0.28), midnight).withOpacity(0.78);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      // keep scaffold transparent so widgets that render gradients (like LoginVersion7) still show them
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        background: midnight,
        onPrimary: AppColors.alabaster,
        onBackground: AppColors.alabaster,
      ).copyWith(surface: surface, onSurface: AppColors.alabaster),
      // Text styles tuned for dark background (use alabaster for contrast, slightly muted for body)
      textTheme: TextTheme(
        headlineLarge: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.alabaster),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.alabaster),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.alabaster.withOpacity(0.94)),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.alabaster.withOpacity(0.88)),
      ),
      // Use derived surfaces for cards and canvas
      cardColor: cardColor,
      canvasColor: surface,
      dialogBackgroundColor: cardColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        hintStyle: const TextStyle(color: AppColors.alabaster),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mutedPrimary,
          foregroundColor: AppColors.alabaster,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Helper to pick ThemeData by bool
  static ThemeData themeFor({required bool isDark, Color? primaryOverride}) {
    return isDark ? darkTheme(primaryOverride: primaryOverride) : lightTheme(primaryOverride: primaryOverride);
  }
}
