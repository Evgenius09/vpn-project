import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';
import 'controls.dart';
import 'status.dart';

class SelectOption<T> {
  const SelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A screen of the settings tree: a back arrow, a big title and a scrolling
/// body (tech.md 43).
class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.title,
    required this.children,
    this.onBack,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// Null pops the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: AppShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.text,
                        size: AppSizes.icon,
                      ),
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.screenTitle.copyWith(color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg + AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                title.toUpperCase(),
                style: AppText.overline.copyWith(
                  letterSpacing: 0,
                  color: colors.textMuted,
                ),
              ),
            ),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
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

  static const _height = 64.0;

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.bodyStrong.copyWith(
                        color: locked ? colors.textMuted : colors.text,
                      ),
                    ),
                    if (caption != null && caption.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        caption,
                        style: AppText.caption.copyWith(
                          color: colors.textMuted,
                        ),
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
      ),
    );
  }
}

/// The switch of the design: a 44 by 26 track with a 20 px knob.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  static const _width = 44.0;
  static const _height = 26.0;
  static const _knob = 20.0;

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          width: _width,
          height: _height,
          padding: const EdgeInsets.all((_height - _knob) / 2),
          decoration: BoxDecoration(
            color: value ? colors.primary : colors.idle,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            duration: AppDurations.normal,
            curve: AppCurves.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: AppDurations.normal,
              width: _knob,
              height: _knob,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.onPrimary : colors.textMuted,
              ),
            ),
          ),
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
      trailing: AppSwitch(value: value, onChanged: change),
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
    final current = options.where((option) => option.value == value);
    return _SettingsRow(
      title: title,
      subtitle: current.isEmpty ? null : current.first.label,
      locked: locked,
      onTap: onChanged == null ? null : () => _open(context),
      trailing: const _Chevron(),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Text(
    '›',
    style: AppText.headline.copyWith(color: context.colors.textMuted),
  );
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    required this.title,
    required this.onTap,
    this.value,
    this.trailing,
    super.key,
  });

  final String title;

  /// The current value, under the title as in the design.
  final String? value;
  final VoidCallback? onTap;

  /// Replaces the chevron, for a row with its own action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: title,
      subtitle: value,
      locked: false,
      onTap: onTap,
      trailing: trailing ?? const _Chevron(),
    );
  }
}

/// One answer of a single-choice list. The chosen one carries a check mark.
class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selected,
      child: _SettingsRow(
        title: title,
        subtitle: subtitle,
        locked: false,
        onTap: onTap,
        trailing: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: selected ? 1 : 0,
          child: Icon(
            Icons.check_rounded,
            size: AppSizes.iconSmall + 2,
            color: colors.primaryText,
          ),
        ),
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
      trailing: const _Chevron(),
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

/// One traffic meter of the account card.
class AccountMeter {
  const AccountMeter({
    required this.label,
    required this.value,
    required this.accent,
    this.progress,
  });

  final String label;
  final String value;
  final AppAccent accent;

  /// Null fills the bar, for a plan without a limit.
  final double? progress;
}

/// The account card at the top of settings: who is signed in, the plan, and
/// the traffic of each mode (tech.md 43).
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.title,
    this.subtitle,
    this.action,
    this.meters = const [],
    super.key,
  });

  static const _avatar = 48.0;
  static const _bar = 6.0;

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<AccountMeter> meters;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border, width: AppSizes.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _avatar,
                height: _avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '@',
                  style: AppText.title.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primaryText,
                  ),
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
                      style: AppText.bodyStrong.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.caption.copyWith(
                          fontSize: 13,
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
          if (meters.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < meters.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _Meter(meters[i], bar: _bar)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(this.meter, {required this.bar});

  final AccountMeter meter;
  final double bar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meter.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: colors.textMuted),
        ),
        Text(
          meter.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: meter.accent.text,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(bar / 2),
          child: SizedBox(
            height: bar,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.surfaceAlt),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: (meter.progress ?? 1).clamp(0.0, 1.0)),
                  duration: AppDurations.slow,
                  curve: AppCurves.standard,
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: ColoredBox(color: meter.accent.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
