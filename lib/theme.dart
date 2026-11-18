import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mint colour system: glazed porcelain, spearmint powder and gold.
abstract final class MintColors {
  // Porcelain and glaze.
  static const stock = Color(0xFFF4F8F5);
  static const page = Color(0xFFE9EFEB);
  static const porcMid = Color(0xFFEDF3EF);
  static const glaze = Color(0xFFDCE6E0);
  static const glazeDeep = Color(0xFFB9C9C1);
  static const well = Color(0xFFE6EEE9);

  // Powder.
  static const powder = Color(0xFF86CCA8);
  static const tamped = Color(0xFF76BE99);
  static const hover = Color(0xFF95D4B4);
  static const hiRow = Color(0xFFCDEBDB);
  static const grainDark = Color(0xFF4E9C76);
  static const deep = Color(0xFF1D6650);

  // Specks.
  static const speckDust = Color(0xFF5FAF88);
  static const speckDark = Color(0xFF2F7A5A);
  static const speckSlab = Color(0xFF0F3D2E);
  static const speckLight = Color(0xFFF2FAF5);

  // Deep slab.
  static const slabTint = Color(0xFFBFE3D0);
  static const slabUp = Color(0xFFA6E6C4);
  static const slabDown = Color(0xFFF4BBA2);

  // Text and status.
  static const ink = Color(0xFF2A2421);
  static const mute = Color(0xFF5E6B66);
  static const hoji = Color(0xFFB04E2A);
  static const hojiTint = Color(0xFFF6EEE8);

  // Gold accent.
  static const gold = Color(0xFFA9832F);
  static const goldHi = Color(0xFFE2C982);
  static const goldLo = Color(0xFF7A5A17);

  // Currency chart colors: one distinct hue per currency.
  static const goldGraph = Color(0xFFA9832F); // gold
  static const usdGraph = Color(0xFF277DA1); // blue
  static const sarGraph = Color(0xFF2E9C6A); // green
  static const aedGraph = Color(0xFFE07A3F); // orange
  static const cnyGraph = Color(0xFFD64550); // red
  static const eurGraph = Color(0xFF7656A5); // purple
  static const gbpGraph = Color(0xFFC2477F); // magenta
  static const krwGraph = Color(0xFF3F4FA8); // indigo
  static const jpyGraph = Color(0xFF6B7A8F); // slate
  static const cadGraph = Color(0xFF1AA3B8); // cyan
  static const audGraph = Color(0xFF8DAA2B); // olive-lime
  static const pkrGraph = Color(0xFF1D6650);
  static const defaultGraph = Color(0xFF668F7B);

  static const _graphColors = <String, Color>{
    'GOLD': goldGraph,
    'XAU': goldGraph,
    'USD': usdGraph,
    'SAR': sarGraph,
    'AED': aedGraph,
    'CNY': cnyGraph,
    'EUR': eurGraph,
    'GBP': gbpGraph,
    'KRW': krwGraph,
    'JPY': jpyGraph,
    'CAD': cadGraph,
    'AUD': audGraph,
    'PKR': pkrGraph,
  };

  /// Returns a consistent graph color for each currency.
  /// Accepts a currency code or a rate id ('usd', 'gold', ...).
  static Color currencyGraph(String code) =>
      _graphColors[code.toUpperCase()] ?? defaultGraph;

  static Color shade(double opacity) => Color.fromRGBO(29, 60, 50, opacity);

  static Color move(bool isUp, {bool onSlab = false}) =>
      onSlab ? (isUp ? slabUp : slabDown) : (isUp ? deep : hoji);
}

/// Typography:
/// DM Serif Display for the logo, greeting and prominent figures.
/// DM Sans for headings, labels, buttons, navigation and chart text.
abstract final class MintText {
  /// MINT logo and large italic display text: DM Serif Display Italic.
  static TextStyle display({double size = 46, Color color = MintColors.deep}) =>
      GoogleFonts.dmSerifDisplay(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        height: .98,
        letterSpacing: -.02 * size,
        color: color,
      );

  /// MINT logo: DM Serif Display Italic.
  static TextStyle logo({double size = 28, Color color = MintColors.deep}) =>
      display(size: size, color: color);

  /// Gold price and other big numbers: DM Serif Display.
  static TextStyle figure({double size = 68, Color color = MintColors.stock}) =>
      GoogleFonts.dmSerifDisplay(
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: .95,
        letterSpacing: -.035 * size,
        color: color,
        fontFeatures: const [
          FontFeature.liningFigures(),
          FontFeature.tabularFigures(),
        ],
      );

  /// Greeting ("Good evening"): DM Serif Display.
  static TextStyle serif({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = MintColors.ink,
    bool italic = false,
    double height = 1.4,
  }) => GoogleFonts.dmSerifDisplay(
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    height: height,
  );

  /// DM Sans with tabular figures, for numerical values.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = MintColors.ink,
    double letterSpacing = 0,
    double height = 1.35,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Small uppercase labels: DM Sans Medium.
  static TextStyle label({Color color = MintColors.mute, double size = 10.5}) =>
      mono(
        size: size,
        weight: FontWeight.w500,
        color: color,
        letterSpacing: .08 * size,
      );

  /// Chart labels and captions: DM Sans.
  static TextStyle caption({Color color = MintColors.mute}) =>
      mono(size: 10.5, color: color, letterSpacing: .4, height: 1.45);

  static TextStyle body({Color color = MintColors.ink}) =>
      GoogleFonts.dmSans(fontSize: 13.5, color: color, height: 1.5);

  /// Section headings: DM Sans Semibold.
  static TextStyle head({double size = 15.5, Color color = MintColors.ink}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.2,
      );

  /// Buttons and navigation: DM Sans Medium.
  static TextStyle button({double size = 14, Color color = MintColors.stock}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

ThemeData buildAppTheme() {
  final base = GoogleFonts.dmSansTextTheme().apply(
    bodyColor: MintColors.ink,
    displayColor: MintColors.ink,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: MintColors.stock,
    colorScheme: const ColorScheme.light(
      primary: MintColors.deep,
      onPrimary: MintColors.stock,
      secondary: MintColors.gold,
      onSecondary: MintColors.ink,
      surface: MintColors.stock,
      onSurface: MintColors.ink,
      error: MintColors.hoji,
      outline: MintColors.glazeDeep,
      outlineVariant: MintColors.glaze,
    ),
    textTheme: base,
    dividerColor: MintColors.glaze,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: MintColors.deep,
      selectionColor: MintColors.powder.withAlpha(110),
      selectionHandleColor: MintColors.deep,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MintColors.stock,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: MintColors.glazeDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: MintColors.ink,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: MintText.mono(size: 11.5, color: MintColors.stock),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MintColors.well,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: MintColors.deep, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: MintColors.hoji, width: 1.5),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: MintColors.hoji, width: 1.5),
      ),
      labelStyle: MintText.label(),
      floatingLabelStyle: MintText.label(color: MintColors.ink),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixStyle: MintText.mono(size: 13, color: MintColors.mute),
      suffixStyle: MintText.mono(size: 13, color: MintColors.mute),
      errorStyle: MintText.caption(color: MintColors.hoji),
      helperStyle: MintText.caption(),
    ),

    sliderTheme: SliderThemeData(
      trackHeight: 9,
      activeTrackColor: MintColors.powder,
      inactiveTrackColor: MintColors.well,
      thumbColor: Colors.white,
      overlayColor: MintColors.powder.withAlpha(60),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 13,
        elevation: 2,
        pressedElevation: 3,
      ),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      valueIndicatorColor: MintColors.ink,
      valueIndicatorTextStyle: MintText.mono(
        size: 12,
        weight: FontWeight.w600,
        color: MintColors.stock,
      ),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MintColors.powder
            : MintColors.well,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MintColors.tamped
            : MintColors.glazeDeep,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MintColors.deep,
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: MintText.mono(size: 14),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: MintColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: MintText.mono(size: 11, color: MintColors.stock),
    ),
  );
}
