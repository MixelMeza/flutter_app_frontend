import 'package:flutter/material.dart';
// Use bundled 'Poppins' font declared in `pubspec.yaml` via ThemeData.fontFamily.
// Avoid using `google_fonts` at runtime to prevent AssetManifest lookups before
// the asset bundle is available.
TextTheme _safePoppinsTextTheme(TextTheme base) {
  return base.apply(fontFamily: 'Poppins');
}

class AppColors {
  // Base palette
  static const Color tan = Color(0xFFD8BA98);
  static const Color maroon = Color(0xFF7F0303);
  static const Color alabaster = Color(0xFFEFE8DF);
  static const Color mediumGray = Color(0xFF6E6E6E);
  static const Color lightBlue = Color(0xFF96C0CE);
  static const Color midnightBlue = Color(0xFF0F414A);
  static const Color iconOnDark = Color(0xFFEAECED);

  // Derived / semantic colors will be provided by AppTheme
}

class AppTheme {
  // Standard border radius used across cards, buttons and input fields
  static const double kBorderRadius = 14.0;
  // Light ThemeData
  static ThemeData lightTheme({Color? primaryOverride}) {
    final primary = primaryOverride ?? AppColors.midnightBlue;

    return ThemeData(
      brightness: Brightness.light,
      // Prefer the bundled font family name so assets/fonts/Poppins-*.ttf
      // (declared in pubspec.yaml) are used when present.
      fontFamily: 'Poppins',
      primaryColor: primary,
      // Light scaffold/background should use the requested alabaster color (#EFE8DF)
      scaffoldBackgroundColor: AppColors.alabaster,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: AppColors.alabaster,
      ).copyWith(surface: AppColors.alabaster, onSurface: AppColors.midnightBlue),
      textTheme: _safePoppinsTextTheme(
        TextTheme(
          headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.midnightBlue),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.midnightBlue),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.midnightBlue),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.midnightBlue),
        ),
      ),
      // Cards and list tiles styling for light theme: soft shadows and consistent radius
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.midnightBlue,
        textColor: AppColors.midnightBlue,
        tileColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      primaryIconTheme: const IconThemeData(color: AppColors.midnightBlue),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.alabaster,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.midnightBlue,
          foregroundColor: AppColors.alabaster,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
        ),
      ),
      // Bottom navigation bar: white background, medium-gray icons when inactive,
      // and maroon when active (as requested).
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.maroon,
        unselectedItemColor: AppColors.mediumGray,
        selectedIconTheme: IconThemeData(color: AppColors.maroon),
        unselectedIconTheme: IconThemeData(color: AppColors.mediumGray),
        showUnselectedLabels: true,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.alabaster,
        iconTheme: const IconThemeData(color: AppColors.midnightBlue),
        titleTextStyle: const TextStyle(color: AppColors.midnightBlue, fontSize: 18, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
      // subtle UI timing and feedback
      splashFactory: InkRipple.splashFactory,
      hoverColor: const Color.fromRGBO(15, 65, 74, 0.04),
      highlightColor: const Color.fromRGBO(15, 65, 74, 0.02),
      iconTheme: const IconThemeData(color: AppColors.midnightBlue),
      // Global shadow color used by Material elevations
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.12),
      // Ensure cards are white in light mode
      cardColor: Colors.white,
    );
  }

  // Dark ThemeData
  static ThemeData darkTheme({Color? primaryOverride}) {
    final primary = primaryOverride ?? AppColors.maroon;
    // Refined dark palette for better contrast and harmony
    // Refined neutral dark palette for better contrast and legibility
    final scaffoldBg = const Color(0xFF06080A); // very dark neutral base
    final surfaceNeutral = const Color(0xFF0E1314); // subtle surface tone

    // Create a slightly desaturated/softer version of primary for surfaces and buttons
    final hPrimary = HSLColor.fromColor(primary);
    final mutedPrimary = hPrimary
      .withSaturation((hPrimary.saturation * 0.78).clamp(0.0, 1.0))
      .withLightness((hPrimary.lightness * 1.05).clamp(0.0, 1.0))
      .toColor();

    // Surface color: blend a little of primary over midnight to warm the surfaces without adding new constants
    // Use explicit surface/card tones for more consistent visuals
    final surface = surfaceNeutral;

    // Input fill: subtle translucent version of surface for contrast
    final inputFill = const Color.fromRGBO(14, 19, 20, 0.10);

    // Card color a touch lighter than surface so the card stands out
    // Use a mid-dark card to improve separations in dark mode (user requested #2A2A2A)
    final cardColor = const Color(0xFF2A2A2A);

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
      primaryColor: primary,
      // Use a solid scaffold background for dark mode so individual pages
      // don't unexpectedly inherit transparency. Specific screens that need
      // gradients (e.g. login) should paint their own background.
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        background: scaffoldBg,
        onPrimary: AppColors.alabaster,
        onBackground: AppColors.alabaster,
      ).copyWith(surface: surface, onSurface: AppColors.alabaster),
      // Text styles tuned for dark background (use alabaster for contrast)
      textTheme: _safePoppinsTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.alabaster),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.alabaster),
          bodyLarge: TextStyle(fontSize: 16, color: Color.fromRGBO(239, 232, 223, 0.94)),
          bodyMedium: TextStyle(fontSize: 14, color: Color.fromRGBO(239, 232, 223, 0.88)),
        ),
      ),
      // Cards and list tiles on dark: stronger but soft shadow so cards read from background
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.iconOnDark,
        textColor: const Color.fromRGBO(239, 232, 223, 0.92),
        // use actual card color so tiles appear as solid cards in dark mode
        tileColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      // Use derived surfaces for cards and canvas
      cardColor: cardColor,
      canvasColor: surface,
      dialogTheme: DialogThemeData(backgroundColor: cardColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius), borderSide: BorderSide.none),
        hintStyle: const TextStyle(color: AppColors.alabaster),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mutedPrimary,
          foregroundColor: AppColors.alabaster,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
        ),
      ),
      // Default dark bottom bar (if used) — keep surface-based background and contrast icons
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.tan, // switch to warm tan accent for dark mode
        unselectedItemColor: const Color.fromRGBO(239, 232, 223, 0.72),
        selectedIconTheme: const IconThemeData(color: AppColors.tan),
        unselectedIconTheme: const IconThemeData(color: Color.fromRGBO(239, 232, 223, 0.72)),
        elevation: 8,
        showUnselectedLabels: true,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        iconTheme: const IconThemeData(color: AppColors.iconOnDark),
        titleTextStyle: const TextStyle(color: AppColors.alabaster, fontSize: 18, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
      // Ensure icons across the app are visible in dark mode
      iconTheme: const IconThemeData(color: AppColors.iconOnDark),
      // Global shadow color for dark theme (slightly stronger for contrast)
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.32),
      // Divider color to subtly separate sections in dark mode
      dividerColor: const Color.fromRGBO(239, 232, 223, 0.06),
    );
  }

  /// Dark theme variant for the Profile page: similar to the login dark theme
  /// but with a solid background (no gradient / transparent scaffold).
  static ThemeData profileDarkTheme({Color? primaryOverride}) {
    final base = darkTheme(primaryOverride: primaryOverride);
    // Build a copy with a solid scaffold background using midnightBlue
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.midnightBlue,
      colorScheme: base.colorScheme.copyWith(background: AppColors.midnightBlue),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: AppColors.midnightBlue),
    );
  }

  // Helper to pick ThemeData by bool
  static ThemeData themeFor({required bool isDark, Color? primaryOverride}) {
    return isDark ? darkTheme(primaryOverride: primaryOverride) : lightTheme(primaryOverride: primaryOverride);
  }
}
