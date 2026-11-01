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
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox.square(
            dimension: AppSizes.spinner,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.spinnerStroke,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: AppSizes.iconSmall),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, style: AppText.label)),
      ],
    );
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: action, child: child),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: action,
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: action, child: child),
      AppButtonVariant.danger => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colors.danger,
          foregroundColor: colors.onPrimary,
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppText.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
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
  final _focusNode = FocusNode();

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
                    Container(
                      width: AppSizes.codeCell,
                      height: AppSizes.codeCellHeight,
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? colors.surface
                            : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: hasError ? colors.danger : colors.border,
                          width: AppSizes.border,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: AppText.title.copyWith(color: colors.text),
                      ),
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: AppText.caption.copyWith(color: colors.danger),
          ),
        ],
      ],
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
