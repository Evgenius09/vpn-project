import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ping/data/user_settings_store.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../domain/auto_switch_setting.dart';

/// The user's own `whitelist.autoOnCellular`, null until they touch the toggle.
class AutoSwitchChoiceController extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() async =>
      (await ref.read(userSettingsStoreProvider).read())
          .whitelist
          ?.autoOnCellular;

  Future<void> choose(bool value) async {
    state = AsyncData(value);
    final store = ref.read(userSettingsStoreProvider);
    await store.write(withAutoOnCellular(await store.read(), value));
  }
}

final autoSwitchChoiceProvider =
    AsyncNotifierProvider<AutoSwitchChoiceController, bool?>(
      AutoSwitchChoiceController.new,
    );

/// What the toggle shows.
class AutoSwitchToggleView {
  const AutoSwitchToggleView({required this.value, required this.locked});

  final bool value;
  final bool locked;
}

/// The toggle, or null while it stays hidden: no profile yet, or the provider
/// turned the feature off (tech.md 34.1).
final autoSwitchToggleProvider = Provider<AutoSwitchToggleView?>((ref) {
  final profile = ref.watch(profileControllerProvider);
  if (profile is! ProfileReady || !profile.profile.policy.flags.autoWhitelist) {
    return null;
  }
  final policy = profile.profile.policy;
  return AutoSwitchToggleView(
    value: autoOnCellularFrom(
      policy,
      ref.watch(autoSwitchChoiceProvider).value,
    ),
    locked: autoOnCellularLocked(policy),
  );
});

/// `autoSwitch.enabled` of the next request, or null until the profile and the
/// stored choice are both read, so loading never looks like a change.
final autoSwitchEnabledProvider = Provider<bool?>((ref) {
  final profile = ref.watch(profileControllerProvider);
  final choice = ref.watch(autoSwitchChoiceProvider);
  if (profile is! ProfileReady || !choice.hasValue) {
    return null;
  }
  return autoSwitchEnabled(profile.profile.policy, choice.value);
});
