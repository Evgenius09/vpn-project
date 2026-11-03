import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../application/auto_switch_controller.dart';

/// The `whitelist.autoOnCellular` toggle of the whitelist screen and the
/// settings (tech.md 34.1). It stays hidden while the provider keeps the
/// feature off.
class AutoSwitchToggle extends ConsumerWidget {
  const AutoSwitchToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(autoSwitchToggleProvider);
    if (view == null) {
      return const SizedBox.shrink();
    }
    final strings = AppLocalizations.of(context);
    return SettingsToggleTile(
      title: strings.autoSwitchTitle,
      subtitle: strings.autoSwitchSubtitle,
      value: view.value,
      locked: view.locked,
      onChanged: ref.read(autoSwitchChoiceProvider.notifier).choose,
    );
  }
}
