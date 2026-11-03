import '../../../gen/api/export.dart';

/// The value when neither the user nor the policy sets
/// `whitelist.autoOnCellular`. It matches backend/config/policy.yaml.
const builtInAutoOnCellular = true;

/// Whether the provider fixed `whitelist.autoOnCellular`, so the toggle is
/// locked.
bool autoOnCellularLocked(ClientPolicy policy) =>
    policy.locked.contains(SettingsKey.whitelistAutoOnCellular);

/// The toggle: the user's choice, unless the provider locked the key, then the
/// policy default, then the built-in value (tech.md 34.1).
bool autoOnCellularFrom(ClientPolicy policy, bool? userChoice) {
  final fallback =
      policy.defaults.whitelist?.autoOnCellular ?? builtInAutoOnCellular;
  if (autoOnCellularLocked(policy)) {
    return fallback;
  }
  return userChoice ?? fallback;
}

/// `TunnelRequest.autoSwitch.enabled` (tech.md 34.1).
bool autoSwitchEnabled(ClientPolicy policy, bool? userChoice) =>
    policy.flags.autoWhitelist && autoOnCellularFrom(policy, userChoice);

/// [settings] with `whitelist.autoOnCellular` set and every other key kept.
SettingsPatch withAutoOnCellular(SettingsPatch settings, bool value) =>
    SettingsPatch(
      routing: settings.routing,
      dns: settings.dns,
      net: settings.net,
      perApp: settings.perApp,
      ping: settings.ping,
      connect: settings.connect,
      ui: settings.ui,
      whitelist: WhitelistPatch(autoOnCellular: value),
    );
