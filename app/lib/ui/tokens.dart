import 'package:flutter/material.dart';

/// The accent of one mode screen. Each mode has its own hue, so the user tells
/// the regular VPN from the whitelists at a glance (tech.md 43).
@immutable
class AppAccent {
  const AppAccent({
    required this.primary,
    required this.deep,
    required this.text,
    required this.soft,
  });

  /// Fills: the connected PowerButton, the ModeSwitch thumb, primary buttons.
  final Color primary;

  /// The far stop of gradients on primary fills.
  final Color deep;

  /// Accent text and icons on the background.
  final Color text;

  /// Tinted fills: the halo, the selected server, chips.
  final Color soft;

  static const regularDark = AppAccent(
    primary: Color(0xFF7C6CFF),
    deep: Color(0xFF4F46E5),
    text: Color(0xFFB4A8FF),
    soft: Color(0xFF221F45),
  );

  static const whitelistDark = AppAccent(
    primary: Color(0xFFFF6B3D),
    deep: Color(0xFFE5383B),
    text: Color(0xFFFFB38A),
    soft: Color(0xFF3A1F19),
  );

  static const regularLight = AppAccent(
    primary: Color(0xFF6C5CF5),
    deep: Color(0xFF4F46E5),
    text: Color(0xFF5242D8),
    soft: Color(0xFFECE9FF),
  );

  static const whitelistLight = AppAccent(
    primary: Color(0xFFF2602F),
    deep: Color(0xFFE5383B),
    text: Color(0xFFC94A1C),
    soft: Color(0xFFFFEAE1),
  );

  static AppAccent lerp(AppAccent a, AppAccent b, double t) => AppAccent(
    primary: Color.lerp(a.primary, b.primary, t)!,
    deep: Color.lerp(a.deep, b.deep, t)!,
    text: Color.lerp(a.text, b.text, t)!,
    soft: Color.lerp(a.soft, b.soft, t)!,
  );
}

/// Which accent a screen wears. The ui layer does not know `TunnelMode`, so
/// screens map their mode onto this.
enum AccentKind { regular, whitelist }

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryDeep,
    required this.primaryText,
    required this.primarySoft,
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
    required this.telegram,
    required this.regular,
    required this.whitelist,
  });

  static const _darkBase = AppColors(
    bg: Color(0xFF0B0D14),
    surface: Color(0xFF151823),
    surfaceAlt: Color(0xFF1E2230),
    primary: Color(0xFF7C6CFF),
    primaryDeep: Color(0xFF4F46E5),
    primaryText: Color(0xFFB4A8FF),
    primarySoft: Color(0xFF221F45),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFFF2F4F8),
    textMuted: Color(0xFF8A91A6),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF5B83D),
    danger: Color(0xFFF04452),
    connected: Color(0xFF22C55E),
    connecting: Color(0xFFF5B83D),
    idle: Color(0xFF3A4054),
    border: Color(0xFF2A2F3F),
    telegram: Color(0xFF2AABEE),
    regular: AppAccent.regularDark,
    whitelist: AppAccent.whitelistDark,
  );

  static const _lightBase = AppColors(
    bg: Color(0xFFF4F5FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECEEF5),
    primary: Color(0xFF6C5CF5),
    primaryDeep: Color(0xFF4F46E5),
    primaryText: Color(0xFF5242D8),
    primarySoft: Color(0xFFECE9FF),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFF12141C),
    textMuted: Color(0xFF636B80),
    success: Color(0xFF16A34A),
    warning: Color(0xFFC98A0B),
    danger: Color(0xFFDC2F3F),
    connected: Color(0xFF16A34A),
    connecting: Color(0xFFC98A0B),
    idle: Color(0xFFDDE1EB),
    border: Color(0xFFDDE1EC),
    telegram: Color(0xFF2AABEE),
    regular: AppAccent.regularLight,
    whitelist: AppAccent.whitelistLight,
  );

  static const dark = _darkBase;
  static const light = _lightBase;

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primaryDeep;
  final Color primaryText;
  final Color primarySoft;
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
  final Color telegram;

  /// The accents of the two modes in this brightness.
  final AppAccent regular;
  final AppAccent whitelist;

  AppAccent accentOf(AccentKind kind) => switch (kind) {
    AccentKind.regular => regular,
    AccentKind.whitelist => whitelist,
  };

  /// The same palette wearing [accent] in its primary slots.
  AppColors withAccent(AppAccent accent) => copyWith(
    primary: accent.primary,
    primaryDeep: accent.deep,
    primaryText: accent.text,
    primarySoft: accent.soft,
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryDeep,
    Color? primaryText,
    Color? primarySoft,
  }) => AppColors(
    bg: bg,
    surface: surface,
    surfaceAlt: surfaceAlt,
    primary: primary ?? this.primary,
    primaryDeep: primaryDeep ?? this.primaryDeep,
    primaryText: primaryText ?? this.primaryText,
    primarySoft: primarySoft ?? this.primarySoft,
    onPrimary: onPrimary,
    text: text,
    textMuted: textMuted,
    success: success,
    warning: warning,
    danger: danger,
    connected: connected,
    connecting: connecting,
    idle: idle,
    border: border,
    telegram: telegram,
    regular: regular,
    whitelist: whitelist,
  );

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
      primaryDeep: mix(primaryDeep, other.primaryDeep),
      primaryText: mix(primaryText, other.primaryText),
      primarySoft: mix(primarySoft, other.primarySoft),
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
      telegram: mix(telegram, other.telegram),
      regular: AppAccent.lerp(regular, other.regular, t),
      whitelist: AppAccent.lerp(whitelist, other.whitelist, t),
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
  static const double tile = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppText {
  static const wordmark = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w800);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  /// The mode switch: long enough to read as one gesture, short enough to feel
  /// immediate.
  static const page = Duration(milliseconds: 460);

  /// The wave that rolls out of the PowerButton when the tunnel connects.
  static const wave = Duration(milliseconds: 1400);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const spring = Curves.easeOutBack;
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
  static const double borderStrong = 1.5;
  static const double dot = 8;
  static const double dotActive = 22;
  static const double spinner = 20;
  static const double spinnerStroke = 2;
  static const double codeCell = 48;
  static const double codeCellHeight = 60;
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;
  static const double powerButton = 240;
  static const double powerButtonCompact = 160;
  static const double modeSwitchHeight = 64;
  static const double modeSwitchInset = 6;
  static const double serverTileHeight = 56;
  static const double flag = 32;
  static const double chip = 30;
  static const double pingDot = 8;
  static const double topBarButton = 44;
  static const double topBarIcon = 28;
  static const double buttonHeight = 54;
  static const double fieldHeight = 54;
  static const double logoTile = 72;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
