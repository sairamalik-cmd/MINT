import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const scaffold = Color(0xFFFAFCFB);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE6EEEC);
  static const primary = Color(0xFF12201F);
  static const secondary = Color(0xFF5F6F6C);
  static const teal = Color(0xFF0F5C58);
  static const mint = Color(0xFFD5F2E6);
  static const gold = Color(0xFFC8962E);
  static const goldTint = Color(0xFFFBF1D9);
  static const up = Color(0xFF22A861);
  static const upBackground = Color(0xFFE4F6EC);
  static const upText = Color(0xFF11743A);
  static const down = Color(0xFFE04F4F);
  static const downBackground = Color(0xFFFCE8E8);
  static const downText = Color(0xFFB82F2F);
  static const amber = Color(0xFFB7791F);
  static const amberBackground = Color(0xFFFFF5D9);
}

abstract final class AppTextStyles {
  static final hero = GoogleFonts.inter(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    color: AppColors.primary,
  );
  static final sectionTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
  static final rowTitle = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static final subtitle = GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.secondary,
  );
  static final caption = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.secondary,
  );
}

ThemeData buildAppTheme() {
  final base = GoogleFonts.interTextTheme();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.scaffold,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      surface: AppColors.surface,
      primary: AppColors.teal,
      secondary: AppColors.gold,
    ),
    textTheme: base.apply(
      bodyColor: AppColors.primary,
      displayColor: AppColors.primary,
    ),
    dividerColor: AppColors.divider,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.mint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
  );
}
