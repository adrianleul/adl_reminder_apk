import 'package:flutter/material.dart';

/// The "Next up" design: near-black ink on white with one orange accent.
/// Text on the accent is always ink, never white (white on orange fails
/// contrast).
abstract final class AppColors {
  static const ink = Color(0xFF111318);
  static const accent = Color(0xFFFF6A2B);
  static const background = Color(0xFFFFFFFF);

  /// Quiet fills: cards, chips, inactive buttons.
  static const surface = Color(0xFFF4F5F7);
  static const line = Color(0xFFE4E5EA);

  /// Secondary text (4.6:1 on white) and tertiary text (on ink).
  static const muted = Color(0xFF5F6370);
  static const mutedOnInk = Color(0xFFB5B8C2);
  static const navIdle = Color(0xFF8D919C);

  /// Missed/overdue: dark enough for text on white and on [missedFill].
  static const missed = Color(0xFFA33A0B);
  static const missedFill = Color(0xFFFFF0E9);
}

/// Headings and big numbers.
const String displayFont = 'SpaceGrotesk';

/// Body text. Amharic falls back to the system's Ethiopic font.
const String bodyFont = 'DMSans';

TextStyle displayStyle(double size, {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: weight ?? FontWeight.w700,
      letterSpacing: -size * 0.03,
      height: 1.1,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.surface,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    error: AppColors.missed,
    errorContainer: AppColors.missedFill,
    onErrorContainer: AppColors.missed,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: bodyFont,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 56),
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 56),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.background,
      selectedColor: AppColors.ink,
      secondarySelectedColor: AppColors.ink,
      checkmarkColor: Colors.white,
      side: const BorderSide(color: AppColors.line, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.navIdle, width: 2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFD4D6DC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      actionTextColor: AppColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.ink
            : AppColors.line,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
