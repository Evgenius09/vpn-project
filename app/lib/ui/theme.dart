import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light({AccentKind accent = AccentKind.regular}) =>
      fromColors(
        AppColors.light.withAccent(AppColors.light.accentOf(accent)),
        Brightness.light,
      );

  static ThemeData dark({AccentKind accent = AccentKind.regular}) => fromColors(
    AppColors.dark.withAccent(AppColors.dark.accentOf(accent)),
    Brightness.dark,
  );

  static ThemeData fromColors(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.primaryText,
      onSecondary: colors.onPrimary,
      error: colors.danger,
      onError: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.text,
      surfaceContainerHighest: colors.surfaceAlt,
      outline: colors.border,
      outlineVariant: colors.border,
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    const buttonSize = Size.fromHeight(AppSizes.buttonHeight);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      splashFactory: InkSparkle.splashFactory,
      extensions: [colors],
      textTheme: const TextTheme(
        displaySmall: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.headline,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        labelLarge: AppText.label,
        bodySmall: AppText.caption,
      ).apply(bodyColor: colors.text, displayColor: colors.text),
      iconTheme: IconThemeData(color: colors.text, size: AppSizes.icon),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        surfaceTintColor: colors.bg,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.display.copyWith(color: colors.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceAlt,
          disabledForegroundColor: colors.textMuted,
          minimumSize: buttonSize,
          shape: pill,
          textStyle: AppText.bodyStrong,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.text,
          disabledForegroundColor: colors.textMuted,
          minimumSize: buttonSize,
          shape: pill,
          side: BorderSide(color: colors.border, width: AppSizes.border),
          textStyle: AppText.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primaryText,
          disabledForegroundColor: colors.textMuted,
          shape: pill,
          textStyle: AppText.label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppText.body.copyWith(color: colors.textMuted),
        prefixStyle: AppText.body.copyWith(color: colors.textMuted),
        labelStyle: AppText.label.copyWith(color: colors.textMuted),
        floatingLabelStyle: AppText.label.copyWith(color: colors.primaryText),
        errorStyle: AppText.caption.copyWith(color: colors.danger),
        border: _field(colors.border),
        enabledBorder: _field(colors.border),
        focusedBorder: _field(colors.primary, width: AppSizes.borderStrong),
        errorBorder: _field(colors.danger),
        focusedErrorBorder: _field(colors.danger, width: AppSizes.borderStrong),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        circularTrackColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: colors.border, width: AppSizes.border),
        ),
        titleTextStyle: AppText.title.copyWith(color: colors.text),
        contentTextStyle: AppText.body.copyWith(color: colors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.border, width: AppSizes.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: AppSizes.border,
        space: AppSizes.border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colors.border, width: AppSizes.border),
        ),
        textStyle: AppText.caption.copyWith(color: colors.text),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _field(
    Color color, {
    double width = AppSizes.border,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Rebuilds the theme around [accent], so primitives below pick the hue of
/// one mode. [accent] may be a blend while the user swipes between modes.
class AccentTheme extends StatelessWidget {
  const AccentTheme({required this.accent, required this.child, super.key});

  final AppAccent accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors.withAccent(accent);
    return Theme(
      data: AppTheme.fromColors(colors, theme.brightness),
      child: child,
    );
  }
}
