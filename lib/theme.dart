import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const scaffold = Color(0xFFEEF4F1);
  static const surface = Color(0xFFF9FCFA);
  static const divider = Color(0xFFDCE7E1);
  static const primary = Color(0xFF18332E);
  static const secondary = Color(0xFF6F817B);
  static const teal = Color(0xFF0F5C58);
  static const tealSoft = Color(0xFF1E6C61);
  static const mint = Color(0xFFDCEADF);
  static const mintPanel = Color(0xFFE7F0EA);
  static const gold = Color(0xFFC8962E);
  static const goldTint = Color(0xFFFBF1D9);
  static const up = Color(0xFF22A861);
  static const upBackground = Color(0xFFE4F6EC);
  static const upText = Color.fromARGB(255, 28, 117, 65);
  static const down = Color(0xFFE04F4F);
  static const downBackground = Color(0xFFFCE8E8);
  static const downText = Color(0xFFB82F2F);
  static const amber = Color(0xFFB7791F);
  static const amberBackground = Color(0xFFFFF5D9);
}

abstract final class ChartColors {
  static const gold = AppColors.gold;
  static const usd = AppColors.teal;
  static const sar = Color(0xFF3978C5);
  static const aed = Color(0xFF8A5FBF);
  static const cny = Color(0xFFD67B35);
  static const eur = Color(0xFF5A67C8);
  static const gbp = Color(0xFFC45B78);
  static const krw = Color(0xFF2B8C9C);
  static const jpy = Color(0xFF8B63A8);
  static const cad = Color(0xFFD16654);
  static const aud = Color(0xFF2E9A73);

  static Color forRate(String id) => switch (id) {
    'gold' => gold,
    'usd' => usd,
    'sar' => sar,
    'aed' => aed,
    'cny' => cny,
    'eur' => eur,
    'gbp' => gbp,
    'krw' => krw,
    'jpy' => jpy,
    'cad' => cad,
    'aud' => aud,
    _ => usd,
  };
}

abstract final class AppTextStyles {
  static final hero = GoogleFonts.inter(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    color: AppColors.primary,
  );
  static final sectionTitle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
  static final rowTitle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static final subtitle = GoogleFonts.inter(
    fontSize: 13,
    color: AppColors.secondary,
  );
  static final caption = GoogleFonts.inter(
    fontSize: 11,
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
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.mint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
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
