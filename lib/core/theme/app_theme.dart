import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  /// Cyber Mint — hsl(155, 100%, 40%)
  static const primary = Color(0xFF00CC7A);
  static const primaryDark = Color(0xFF00A864);
  static const primaryDeep = Color(0xFF008F55);
  /// Tournament attention accent (FIFA-style)
  static const lime = Color(0xFF46ED13);
  static const gold = Color(0xFFE8B923);
  static const goldDark = Color(0xFFB45309);
  static const bg = Color(0xFF041510);
  static const surface = Color(0xFF0B221A);
  static const surface2 = Color(0xFF103028);
  static const edge = Color(0xFF1E4A3A);
  static const ink = Color(0xFFF2FFF8);
  static const muted = Color(0xFF8FB8A6);
  static const faint = Color(0xFF5E8A76);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Light
  static const lightBg = Color(0xFFF2FBF7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE8F7F0);
  static const lightEdge = Color(0xFFC5E6D6);
  static const lightInk = Color(0xFF06281C);
  static const lightMuted = Color(0xFF4A7A66);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primaryDark,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Color(0xFF003D26),
      onSurface: AppColors.ink,
    ),
  );

  final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return _finish(base, textTheme, dark: true);
}

ThemeData buildLightAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryDark,
      surface: AppColors.lightSurface,
      error: AppColors.danger,
      onPrimary: Color(0xFF003D26),
      onSurface: AppColors.lightInk,
    ),
  );

  final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
    bodyColor: AppColors.lightInk,
    displayColor: AppColors.lightInk,
  );

  return _finish(base, textTheme, dark: false);
}

ThemeData _finish(ThemeData base, TextTheme textTheme, {required bool dark}) {
  final bg = dark ? AppColors.bg : AppColors.lightBg;
  final surface = dark ? AppColors.surface : AppColors.lightSurface;
  final surface2 = dark ? AppColors.surface2 : AppColors.lightSurface2;
  final edge = dark ? AppColors.edge : AppColors.lightEdge;
  final ink = dark ? AppColors.ink : AppColors.lightInk;
  final muted = dark ? AppColors.muted : AppColors.lightMuted;
  final faint = dark ? AppColors.faint : AppColors.lightMuted;

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg.withValues(alpha: 0.92),
      elevation: 0,
      centerTitle: false,
      foregroundColor: ink,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      iconTheme: IconThemeData(color: ink),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: edge),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: TextStyle(color: faint),
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: edge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: edge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF052E12),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: edge),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: 0.96),
      indicatorColor: AppColors.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : faint,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: ink),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: edge,
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.primary,
      textColor: ink,
    ),
  );
}
