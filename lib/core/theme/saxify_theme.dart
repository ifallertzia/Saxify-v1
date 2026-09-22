import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'saxify_accents.dart';

/// Saxify's fixed dark/neon surfaces. Only the accent rotates — the shell stays
/// the same deep-space dark as the web app.
class SaxifyColors {
  const SaxifyColors._();

  static const Color background = Color(0xFF08070D);
  static const Color surface = Color(0xFF100E18);
  static const Color surfaceAlt = Color(0xFF161322);
  static const Color card = Color(0xFF191527);
  static const Color cardHover = Color(0xFF211B33);
  static const Color border = Color(0xFF241F36);
  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFB7B1CC);
  static const Color textMuted = Color(0xFF8D87A6);
  static const Color textFaint = Color(0xFF655F7C);
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
}

/// Builds the whole [ThemeData] for a given accent.
class SaxifyTheme {
  const SaxifyTheme._();

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static ThemeData build(SaxifyAccent accent) {
    final TextTheme base = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    final TextTheme textTheme = base.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
          textStyle: base.displayLarge?.copyWith(fontWeight: FontWeight.w700)),
      displayMedium: GoogleFonts.spaceGrotesk(
          textStyle: base.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
      displaySmall: GoogleFonts.spaceGrotesk(
          textStyle: base.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
      headlineLarge: GoogleFonts.spaceGrotesk(
          textStyle: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
      headlineMedium: GoogleFonts.spaceGrotesk(
          textStyle: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      headlineSmall: GoogleFonts.spaceGrotesk(
          textStyle: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
      titleLarge: GoogleFonts.spaceGrotesk(
          textStyle: base.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
      titleMedium: GoogleFonts.spaceGrotesk(
          textStyle: base.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      titleSmall: GoogleFonts.spaceGrotesk(
          textStyle: base.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      labelLarge:
          base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: base.labelMedium?.copyWith(letterSpacing: 0.3),
    ).apply(
      bodyColor: SaxifyColors.textPrimary,
      displayColor: SaxifyColors.textPrimary,
    );

    final ColorScheme scheme = const ColorScheme.dark().copyWith(
      primary: accent.primary,
      onPrimary: Colors.black,
      primaryContainer: accent.secondary,
      onPrimaryContainer: Colors.white,
      secondary: accent.secondary,
      onSecondary: Colors.white,
      tertiary: accent.secondary,
      surface: SaxifyColors.surface,
      onSurface: SaxifyColors.textPrimary,
      surfaceContainerLowest: SaxifyColors.background,
      surfaceContainerLow: SaxifyColors.surface,
      surfaceContainer: SaxifyColors.surfaceAlt,
      surfaceContainerHigh: SaxifyColors.card,
      surfaceContainerHighest: SaxifyColors.cardHover,
      onSurfaceVariant: SaxifyColors.textSecondary,
      outline: SaxifyColors.border,
      outlineVariant: SaxifyColors.border,
      error: SaxifyColors.danger,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SaxifyColors.background,
      canvasColor: SaxifyColors.background,
      primaryColor: accent.primary,
      dividerColor: SaxifyColors.border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: SaxifyColors.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: SaxifyColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: SaxifyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SaxifyColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: SaxifyColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: SaxifyColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SaxifyColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: SaxifyColors.surfaceAlt,
        hintStyle: const TextStyle(color: SaxifyColors.textFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: SaxifyColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: BorderSide(color: accent.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SaxifyColors.surfaceAlt,
        selectedColor: accent.primary.withValues(alpha: 0.18),
        side: const BorderSide(color: SaxifyColors.border),
        labelStyle: const TextStyle(
          color: SaxifyColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent.primary,
        inactiveTrackColor: SaxifyColors.border,
        thumbColor: accent.primary,
        overlayColor: accent.primary.withValues(alpha: 0.18),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent.primary,
        linearTrackColor: SaxifyColors.border,
        circularTrackColor: SaxifyColors.border,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SaxifyColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SaxifyColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: SaxifyColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SaxifyColors.cardHover,
        contentTextStyle: const TextStyle(color: SaxifyColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? accent.primary
              : SaxifyColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? accent.primary.withValues(alpha: 0.30)
              : SaxifyColors.surfaceAlt,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          SaxifyColors.border,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SaxifyColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.primary.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        height: 66,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? accent.primary
                : SaxifyColors.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 11,
            fontWeight:
                states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? accent.primary
                : SaxifyColors.textMuted,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent.primary,
        unselectedLabelColor: SaxifyColors.textMuted,
        indicatorColor: accent.primary,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: SaxifyColors.textMuted,
        textColor: SaxifyColors.textPrimary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SaxifyColors.cardHover,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(color: SaxifyColors.textPrimary, fontSize: 12),
      ),
      // Lets any widget grab the live accent via Theme.of(context).
      extensions: <ThemeExtension<dynamic>>[SaxifyAccentExtension(accent)],
    );
  }
}
