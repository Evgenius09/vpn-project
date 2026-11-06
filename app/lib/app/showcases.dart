import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// One primitive in all its states. The kitchen sink and the golden tests
/// render this same list, so they cannot drift apart (tech.md 8).
class Showcase {
  const Showcase(this.name, this.build);

  final String name;
  final WidgetBuilder build;
}

const _gap = SizedBox(height: AppSpacing.sm);

void _noop() {}

void _ignore<T>(T _) {}

final List<Showcase> showcases = [
  Showcase(
    'power_button',
    (_) => const Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        PowerButton(
          state: PowerState.idle,
          onPressed: _noop,
          size: 96,
          caption: 'idle',
        ),
        PowerButton(
          state: PowerState.connecting,
          onPressed: null,
          size: 96,
          caption: 'connecting',
        ),
        PowerButton(
          state: PowerState.connected,
          onPressed: _noop,
          size: 96,
          caption: 'connected',
        ),
        PowerButton(
          state: PowerState.disconnecting,
          onPressed: null,
          size: 96,
          caption: 'disconnecting',
        ),
        PowerButton(
          state: PowerState.error,
          onPressed: _noop,
          size: 96,
          caption: 'error',
        ),
      ],
    ),
  ),
  Showcase(
    'mode_pager',
    (_) => SizedBox(
      height: 96,
      child: ModePager(
        index: 0,
        onChanged: _ignore,
        pages: const [
          ModePage(
            title: 'one',
            child: Center(child: Text('Page one')),
          ),
          ModePage(
            title: 'two',
            child: Center(child: Text('Page two')),
          ),
        ],
      ),
    ),
  ),
  Showcase(
    'mode_switch',
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ModeSwitch(
          labels: ['Regular VPN', 'Whitelists'],
          index: 0,
          onChanged: _ignore,
        ),
        _gap,
        AccentTheme(
          accent: context.colors.whitelist,
          child: const ModeSwitch(
            labels: ['Regular VPN', 'Whitelists'],
            index: 1,
            onChanged: _ignore,
          ),
        ),
      ],
    ),
  ),
  Showcase(
    'sheet_chip',
    (_) => const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        SheetChip(icon: Icons.refresh_rounded, onPressed: _noop),
        SheetChip(icon: Icons.refresh_rounded, loading: true, onPressed: _noop),
        SheetChip(
          icon: Icons.south_rounded,
          label: 'By ping',
          onPressed: _noop,
        ),
        SheetChip(
          icon: Icons.sort_rounded,
          label: 'Default order',
          active: false,
          onPressed: _noop,
        ),
        SheetChip(
          icon: Icons.lock_outline_rounded,
          label: 'Locked',
          onPressed: null,
        ),
      ],
    ),
  ),
  Showcase(
    'account_card',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccountCard(
          title: '@seed_user',
          subtitle: 'Trial · until November 12',
          action: SheetChip(label: 'Renew', onPressed: _noop),
          meterLabel: 'Traffic',
          meterValue: '3.2 of 10 GB',
          progress: 0.32,
        ),
        _gap,
        AccountCard(
          title: '@seed_user',
          meterLabel: 'Traffic',
          meterValue: 'Unlimited',
        ),
      ],
    ),
  ),
  Showcase(
    'page_dots',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PageDots(count: 2, index: 0, onTap: _ignore),
        PageDots(count: 2, index: 1),
        PageDots(count: 4, index: 2, onTap: _ignore),
      ],
    ),
  ),
  Showcase(
    'server_sheet',
    (_) => const SizedBox(
      height: 240,
      child: ServerSheet(
        minExtent: 0.6,
        header: Text('Servers'),
        body: ServerTile(
          title: 'Frankfurt',
          countryCode: 'DE',
          ping: PingValue.ms(42),
          selected: true,
        ),
      ),
    ),
  ),
  Showcase(
    'server_tile',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ServerTile(
          title: 'Frankfurt',
          subtitle: 'VLESS',
          countryCode: 'DE',
          ping: PingValue.ms(42),
          selected: true,
          onTap: _noop,
        ),
        _gap,
        ServerTile(
          title: 'Amsterdam',
          countryCode: 'NL',
          ping: PingValue.ms(180),
          selected: false,
          onTap: _noop,
        ),
        _gap,
        ServerTile(
          title: 'No country',
          ping: PingValue.unknown(),
          selected: false,
        ),
        _gap,
        ServerTile(
          title: 'Offline',
          ping: PingValue.unreachable(),
          selected: false,
          trailing: Icon(Icons.star),
        ),
      ],
    ),
  ),
  Showcase(
    'ping_badge',
    (_) => const Wrap(
      spacing: AppSpacing.md,
      children: [
        PingBadge(value: PingValue.unknown()),
        PingBadge(value: PingValue.measuring()),
        PingBadge(value: PingValue.ms(42)),
        PingBadge(value: PingValue.ms(180)),
        PingBadge(value: PingValue.ms(900)),
        PingBadge(value: PingValue.unreachable()),
      ],
    ),
  ),
  Showcase(
    'flag_icon',
    (_) => const Wrap(
      spacing: AppSpacing.md,
      children: [
        FlagIcon(countryCode: 'DE'),
        FlagIcon(countryCode: 'NL', size: 32),
        FlagIcon(countryCode: '??'),
      ],
    ),
  ),
  Showcase(
    'status_banner',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusBanner(kind: BannerKind.info, text: 'Info'),
        _gap,
        StatusBanner(
          kind: BannerKind.warning,
          text: 'Warning',
          actionLabel: 'Open',
          onAction: _noop,
        ),
        _gap,
        StatusBanner(kind: BannerKind.error, text: 'Error'),
        _gap,
        StatusBanner(kind: BannerKind.success, text: 'Success'),
      ],
    ),
  ),
  Showcase(
    'traffic_counter',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrafficCounter(upBps: 512, downBps: 2048),
        _gap,
        TrafficCounter(upBps: 1536000, downBps: 10485760),
      ],
    ),
  ),
  Showcase(
    'code_input',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CodeInput(onCompleted: _ignore),
        _gap,
        CodeInput(onCompleted: _ignore, errorText: 'Wrong code'),
        _gap,
        CodeInput(onCompleted: _ignore, enabled: false),
      ],
    ),
  ),
  Showcase(
    'settings_section',
    (_) => const SettingsSection(
      title: 'Section',
      footer: 'Footer text',
      children: [SettingsNavTile(title: 'Item', onTap: _noop)],
    ),
  ),
  Showcase(
    'settings_toggle_tile',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsToggleTile(title: 'On', value: true, onChanged: _ignore),
        SettingsToggleTile(
          title: 'Off',
          subtitle: 'Subtitle',
          value: false,
          onChanged: _ignore,
        ),
        SettingsToggleTile(
          title: 'Locked',
          value: true,
          onChanged: _ignore,
          locked: true,
        ),
      ],
    ),
  ),
  Showcase(
    'settings_select_tile',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsSelectTile<int>(
          title: 'Select',
          value: 1,
          options: [SelectOption(value: 1, label: 'One')],
          onChanged: _ignore,
        ),
        SettingsSelectTile<int>(
          title: 'Locked',
          value: 1,
          options: [SelectOption(value: 1, label: 'One')],
          onChanged: _ignore,
          locked: true,
        ),
      ],
    ),
  ),
  Showcase(
    'settings_nav_tile',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsNavTile(title: 'Plain', onTap: _noop),
        SettingsNavTile(title: 'With value', value: 'Value', onTap: _noop),
      ],
    ),
  ),
  Showcase(
    'settings_input_tile',
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsInputTile(title: 'Input', value: '1500', onSubmitted: _ignore),
        SettingsInputTile(
          title: 'Locked',
          value: '1500',
          onSubmitted: _ignore,
          locked: true,
        ),
      ],
    ),
  ),
  Showcase(
    'app_button',
    (_) => const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(label: 'Primary', onPressed: _noop),
        AppButton(
          label: 'Secondary',
          onPressed: _noop,
          variant: AppButtonVariant.secondary,
        ),
        AppButton(
          label: 'Text',
          onPressed: _noop,
          variant: AppButtonVariant.text,
        ),
        AppButton(
          label: 'Danger',
          onPressed: _noop,
          variant: AppButtonVariant.danger,
        ),
        AppButton(label: 'Icon', onPressed: _noop, icon: Icons.send),
        AppButton(label: 'Loading', onPressed: _noop, loading: true),
        AppButton(label: 'Disabled', onPressed: null),
      ],
    ),
  ),
  Showcase(
    'app_text_field',
    (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: TextEditingController(),
          label: 'Label',
          hint: 'Hint',
        ),
        _gap,
        AppTextField(
          controller: TextEditingController(text: 'nickname'),
          prefixText: '@',
        ),
        _gap,
        AppTextField(
          controller: TextEditingController(),
          errorText: 'Error text',
        ),
      ],
    ),
  ),
  Showcase(
    'empty_state',
    (_) => const EmptyState(
      icon: Icons.dns,
      title: 'Title',
      message: 'Message',
      action: AppButton(label: 'Action', onPressed: _noop),
    ),
  ),
  Showcase(
    'loading_view',
    (_) => const SizedBox(height: 64, child: LoadingView()),
  ),
  Showcase(
    'error_view',
    (_) => const ErrorView(error: 'Something failed', onRetry: _noop),
  ),
];
