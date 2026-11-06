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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: AppText.overline.copyWith(color: colors.textMuted),
            ),
          ),
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.border, width: AppSizes.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                  children[i],
                ],
              ],
            ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyStrong.copyWith(
                      color: locked ? colors.textMuted : colors.text,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: AppText.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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

/// The account card at the top of settings: who is signed in, the plan, and
/// how much traffic is left (tech.md 43). [progress] null draws a full bar for
/// an unlimited plan.
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.title,
    this.subtitle,
    this.action,
    this.meterLabel,
    this.meterValue,
    this.progress,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final String? meterLabel;
  final String? meterValue;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border, width: AppSizes.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primarySoft, colors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.topBarButton,
                height: AppSizes.topBarButton,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '@',
                  style: AppText.title.copyWith(color: colors.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(color: colors.text),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ],
          ),
          if (meterLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    meterLabel!,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ),
                if (meterValue != null)
                  Text(
                    meterValue!,
                    style: AppText.label.copyWith(color: colors.primaryText),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: AppSizes.pingDot - 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: colors.surfaceAlt),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: (progress ?? 1).clamp(0.0, 1.0)),
                      duration: AppDurations.slow,
                      curve: AppCurves.standard,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.primaryText],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
