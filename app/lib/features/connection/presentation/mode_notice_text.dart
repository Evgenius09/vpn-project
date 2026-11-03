import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';

String _modeName(AppLocalizations strings, TunnelMode mode) => switch (mode) {
  TunnelMode.regular => strings.modeRegular,
  TunnelMode.whitelist => strings.modeWhitelist,
};

/// The banner text of a mode change the auto switch made (tech.md 34.2).
String modeNoticeText(AppLocalizations strings, ModePayload change) =>
    switch (change.reason) {
      ModeSwitchReason.networkCellular => strings.modeNoticeCellular(
        _modeName(strings, change.to),
      ),
      ModeSwitchReason.networkWifi => strings.modeNoticeWifi(
        _modeName(strings, change.to),
      ),
      ModeSwitchReason.overrideCleared => strings.modeNoticeOverrideCleared(
        _modeName(strings, change.to),
      ),
      ModeSwitchReason.noWhitelistServers => strings.modeNoticeNoWhitelist(
        _modeName(strings, change.to),
      ),
      // The controller drops user changes before they reach a banner.
      ModeSwitchReason.user => _modeName(strings, change.to),
    };
