import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';

enum AppButtonVariant { primary, secondary, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final action = loading ? null : onPressed;
    final foreground = switch (variant) {
      AppButtonVariant.primary => colors.onPrimary,
      AppButtonVariant.danger => colors.danger,
      AppButtonVariant.secondary => colors.text,
      AppButtonVariant.text => colors.primaryText,
    };
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: AppSizes.spinner,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.spinnerStroke,
              strokeCap: StrokeCap.round,
              color: variant == AppButtonVariant.text
                  ? colors.primaryText
                  : colors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: AppSizes.iconSmall + 2),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 2)),
      ],
    );
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        style: FilledButton.styleFrom(foregroundColor: foreground),
        onPressed: action,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: action,
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: action, child: child),
      AppButtonVariant.danger => FilledButton(
        // A tinted fill keeps a destructive action visible without shouting.
        style: FilledButton.styleFrom(
          backgroundColor: colors.danger.withValues(alpha: 0.14),
          foregroundColor: foreground,
        ),
        onPressed: action,
        child: child,
      ),
    };
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.prefixText,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppText.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppText.bodyStrong.copyWith(color: colors.text),
          cursorColor: colors.primary,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixText: prefixText,
            prefixStyle: AppText.bodyStrong.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A row of digit cells over one hidden text field, so that typing, deleting,
/// and pasting behave like a normal input on touch and on a keyboard.
class CodeInput extends StatefulWidget {
  const CodeInput({
    required this.onCompleted,
    this.length = 6,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final String? errorText;
  final bool enabled;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _controller = TextEditingController();
  late final _focusNode = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    if (value.length == widget.length) {
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = _controller.text;
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          child: Stack(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    _cell(
                      colors,
                      digit: i < text.length ? text[i] : '',
                      active: focused && i == text.length,
                      error: hasError,
                      last: i == widget.length - 1,
                    ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      _DigitsOnly(),
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            style: AppText.caption.copyWith(color: colors.danger),
          ),
        ],
      ],
    );
  }

  Widget _cell(
    AppColors colors, {
    required String digit,
    required bool active,
    required bool error,
    required bool last,
  }) {
    final filled = digit.isNotEmpty;
    final edge = error
        ? colors.danger
        : active
        ? colors.primary
        : filled
        ? colors.primary.withValues(alpha: 0.4)
        : colors.border;
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      width: AppSizes.codeCell,
      height: AppSizes.codeCellHeight,
      margin: EdgeInsets.only(right: last ? 0 : AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !widget.enabled
            ? colors.surfaceAlt
            : active
            ? colors.primarySoft
            : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: edge,
          width: active ? AppSizes.borderStrong : AppSizes.border,
        ),
      ),
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text(
          digit,
          key: ValueKey(digit),
          style: AppText.title.copyWith(
            color: error ? colors.danger : colors.text,
          ),
        ),
      ),
    );
  }
}

/// Strips separators from a pasted code such as "12 34 56".
class _DigitsOnly extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

abstract final class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final strings = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppText.title),
        content: Text(message, style: AppText.body),
        actions: [
          AppButton(
            label: strings.cancel,
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            variant: danger
                ? AppButtonVariant.danger
                : AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
