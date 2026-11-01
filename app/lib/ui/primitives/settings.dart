import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';
import 'controls.dart';

class SelectOption<T> {
  const SelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    this.footer,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              title,
              style: AppText.label.copyWith(color: colors.textMuted),
            ),
          ),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                footer!,
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// The shared row of every settings tile. A locked tile ignores input and says
/// why (tech.md 8).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.locked,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool locked;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = locked
        ? AppLocalizations.of(context).lockedByProvider
        : subtitle;
    return InkWell(
      onTap: locked ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(
                      color: locked ? colors.textMuted : colors.text,
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption,
                      style: AppText.caption.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ),
            if (locked)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.lock_outline,
                  size: AppSizes.iconSmall,
                  color: colors.textMuted,
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.locked = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final change = locked ? null : onChanged;
    return _SettingsRow(
      title: title,
      subtitle: subtitle,
      locked: locked,
      onTap: change == null ? null : () => change(!value),
      trailing: Switch(value: value, onChanged: change),
    );
  }
}

class SettingsSelectTile<T> extends StatelessWidget {
  const SettingsSelectTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.locked = false,
    super.key,
  });

  final String title;
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool locked;

  Future<void> _open(BuildContext context) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title, style: AppText.title),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option.value),
              child: Text(option.label, style: AppText.body),
            ),
        ],
      ),
    );
    if (selected != null) {
      onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = options.where((option) => option.value == value);
    return _SettingsRow(
      title: title,
      locked: locked,
      onTap: onChanged == null ? null : () => _open(context),
      trailing: Text(
        current.isEmpty ? '' : current.first.label,
        style: AppText.label.copyWith(color: colors.textMuted),
      ),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    required this.title,
    required this.onTap,
    this.value,
    super.key,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsRow(
      title: title,
      locked: false,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: AppText.label.copyWith(color: colors.textMuted),
            ),
          Icon(
            Icons.chevron_right,
            size: AppSizes.icon,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}

class SettingsInputTile extends StatelessWidget {
  const SettingsInputTile({
    required this.title,
    required this.value,
    this.validator,
    this.keyboardType,
    this.onSubmitted,
    this.locked = false,
    super.key,
  });

  final String title;
  final String value;
  final String? Function(String)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final bool locked;

  Future<void> _open(BuildContext context) async {
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => _InputDialog(
        title: title,
        value: value,
        validator: validator,
        keyboardType: keyboardType,
      ),
    );
    if (submitted != null) {
      onSubmitted?.call(submitted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: title,
      subtitle: value,
      locked: locked,
      onTap: onSubmitted == null ? null : () => _open(context),
    );
  }
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.value,
    required this.validator,
    required this.keyboardType,
  });

  final String title;
  final String value;
  final String? Function(String)? validator;
  final TextInputType? keyboardType;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _controller = TextEditingController(text: widget.value);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = widget.validator?.call(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title, style: AppText.title),
      content: AppTextField(
        controller: _controller,
        errorText: _error,
        keyboardType: widget.keyboardType,
      ),
      actions: [
        AppButton(
          label: strings.cancel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: strings.save, onPressed: _submit),
      ],
    );
  }
}
