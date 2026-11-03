import '../../../gen/api/export.dart';

/// Values for keys the policy leaves out. They match
/// backend/config/policy.yaml, like the tunnel settings of tech.md 27.2.
const builtInPingType = PingType.tcp;
const builtInPingOnOpen = true;
const builtInSortByPing = true;

/// How the app pings until S3-05 lets the user change it (tech.md 31.2).
class PingSettings {
  const PingSettings({
    required this.type,
    required this.timeout,
    required this.onOpen,
  });

  final PingType type;
  final Duration timeout;
  final bool onOpen;
}

PingSettings pingSettingsFrom(ClientPolicy policy) {
  final ping = policy.defaults.ping;
  return PingSettings(
    type: ping?.type ?? builtInPingType,
    timeout: Duration(milliseconds: ping?.timeoutMs ?? policy.ping.timeoutMs),
    onOpen: ping?.onOpen ?? builtInPingOnOpen,
  );
}

/// Whether the provider fixed `ui.sortByPing`, so the toggle is locked.
bool sortByPingLocked(ClientPolicy policy) =>
    policy.locked.contains(SettingsKey.uiSortByPing);

/// The sort toggle: the user's choice, unless the provider locked the key,
/// then the policy default, then the built-in value.
bool sortByPingFrom(ClientPolicy policy, bool? userChoice) {
  final fallback = policy.defaults.ui?.sortByPing ?? builtInSortByPing;
  if (sortByPingLocked(policy)) {
    return fallback;
  }
  return userChoice ?? fallback;
}
