import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Mint colourway (from the Mint style sheet and watcher mock).
/// Glazed porcelain dusted with green powder: tone is only how densely the
/// powder lies. Gold is the one accent and marks only what is chosen.
abstract final class MintColors {
  // Porcelain and glaze.
  static const stock = Color(0xFFF4F8F5);
  static const page = Color(0xFFE9EFEB);
  static const porcMid = Color(0xFFEDF3EF);
  static const glaze = Color(0xFFDCE6E0);
  static const glazeDeep = Color(0xFFB9C9C1);
  static const well = Color(0xFFE6EEE9);

  // Powder, from loose to struck.
  static const powder = Color(0xFF86CCA8);
  static const tamped = Color(0xFF76BE99);
  static const hover = Color(0xFF95D4B4);
  static const hiRow = Color(0xFFCDEBDB);
  static const grainDark = Color(0xFF4E9C76);
  static const deep = Color(0xFF1D6650);

  // Specks laid over powder and slab.
  static const speckDust = Color(0xFF5FAF88);
  static const speckDark = Color(0xFF2F7A5A);
  static const speckSlab = Color(0xFF0F3D2E);
  static const speckLight = Color(0xFFF2FAF5);

  // On the deep slab.
  static const slabTint = Color(0xFFBFE3D0);
  static const slabUp = Color(0xFFA6E6C4);
  static const slabDown = Color(0xFFF4BBA2);

  // Line and voice.
  static const ink = Color(0xFF2A2421);
  static const mute = Color(0xFF5E6B66);
  static const hoji = Color(0xFFB04E2A);
  static const hojiTint = Color(0xFFF6EEE8);

  // Gold: marks and fills only. Never text below 24px; gold text uses goldLo.
  static const gold = Color(0xFFA9832F);
  static const goldHi = Color(0xFFE2C982);
  static const goldLo = Color(0xFF7A5A17);

  /// The shade every shadow is cast in (rgb 29,60,50).
  static Color shade(double opacity) => Color.fromRGBO(29, 60, 50, opacity);

  static Color move(bool isUp, {bool onSlab = false}) =>
      onSlab ? (isUp ? slabUp : slabDown) : (isUp ? deep : hoji);
}

/// Fraunces for names and reading, IBM Plex Mono for every figure and label.
abstract final class MintText {
  /// The wordmark and display words: italic 300.
  static TextStyle display({double size = 46, Color color = MintColors.deep}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w300,
        height: .95,
        letterSpacing: -.02 * size,
        color: color,
      );

  /// Struck figures: roman 500, tabular.
  static TextStyle figure({double size = 68, Color color = MintColors.stock}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: .9,
        letterSpacing: -.045 * size,
        color: color,
        fontFeatures: const [
          FontFeature.liningFigures(),
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle serif({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = MintColors.ink,
    bool italic = false,
    double height = 1.4,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    height: height,
  );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = MintColors.ink,
    double letterSpacing = 0,
    double height = 1.35,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// The small uppercase label (`.lab`).
  static TextStyle label({Color color = MintColors.mute, double size = 10.5}) =>
      mono(
        size: size,
        weight: FontWeight.w500,
        color: color,
        letterSpacing: .08 * size,
      );

  /// The quiet caption (`.cap`).
  static TextStyle caption({Color color = MintColors.mute}) =>
      mono(size: 10.5, color: color, letterSpacing: .4, height: 1.45);

  /// Reading text (`.body`).
  static TextStyle body({Color color = MintColors.ink}) =>
      serif(size: 13.5, color: color, height: 1.45);

  /// A row or card head: Fraunces 600.
  static TextStyle head({double size = 15.5, Color color = MintColors.ink}) =>
      serif(size: size, weight: FontWeight.w600, color: color, height: 1.15);
}

ThemeData buildAppTheme() {
  final base = GoogleFonts.frauncesTextTheme().apply(
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
      textStyle: MintText.serif(size: 15),
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
