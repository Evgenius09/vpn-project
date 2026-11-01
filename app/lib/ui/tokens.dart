import 'package:flutter/material.dart';

/// Colors. The palette is a placeholder: a redesign replaces these values and
/// the screens stay untouched (tech.md 2.1).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.connected,
    required this.connecting,
    required this.idle,
    required this.border,
  });

  static const light = AppColors(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECEEF2),
    primary: Color(0xFF2F5BEA),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFF14171F),
    textMuted: Color(0xFF5C6370),
    success: Color(0xFF17803D),
    warning: Color(0xFFB25E00),
    danger: Color(0xFFC62828),
    connected: Color(0xFF17803D),
    connecting: Color(0xFFB25E00),
    idle: Color(0xFF5C6370),
    border: Color(0xFFD9DCE3),
  );

  static const dark = AppColors(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surfaceAlt: Color(0xFF22262E),
    primary: Color(0xFF7C9BFF),
    onPrimary: Color(0xFF0F1115),
    text: Color(0xFFECEFF4),
    textMuted: Color(0xFF9AA2B1),
    success: Color(0xFF4CC38A),
    warning: Color(0xFFF2B35B),
    danger: Color(0xFFFF8A80),
    connected: Color(0xFF4CC38A),
    connecting: Color(0xFFF2B35B),
    idle: Color(0xFF9AA2B1),
    border: Color(0xFF2E333D),
  );

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color connected;
  final Color connecting;
  final Color idle;
  final Color border;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      connected: mix(connected, other.connected),
      connecting: mix(connecting, other.connecting),
      idle: mix(idle, other.idle),
      border: mix(border, other.border),
    );
  }
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class AppText {
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppLayout {
  static const double maxContentWidth = 480;
}

/// Sizes that belong to a single primitive but still must not be literals in
/// its build method.
abstract final class AppSizes {
  static const double icon = 24;
  static const double iconSmall = 16;
  static const double iconLarge = 48;
  static const double border = 1;
  static const double dot = 8;
  static const double spinner = 20;
  static const double spinnerStroke = 2;
  static const double codeCell = 44;
  static const double codeCellHeight = 52;
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
