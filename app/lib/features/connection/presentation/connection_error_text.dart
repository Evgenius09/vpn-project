import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';

/// The banner text for each CoreErrorCode (tech.md 5.5).
String connectionErrorText(
  AppLocalizations strings,
  CoreErrorCode code,
) => switch (code) {
  CoreErrorCode.configInvalid => strings.connectionErrorConfigInvalid,
  CoreErrorCode.startFailed => strings.connectionErrorStartFailed,
  CoreErrorCode.noServersInGroup => strings.connectionErrorNoServers,
  CoreErrorCode.permissionDenied => strings.connectionErrorPermissionDenied,
  CoreErrorCode.tunFailed => strings.connectionErrorTunFailed,
  CoreErrorCode.revoked => strings.connectionErrorRevoked,
  CoreErrorCode.serviceUnavailable => strings.connectionErrorServiceUnavailable,
  CoreErrorCode.ipcVersionMismatch => strings.connectionErrorVersionMismatch,
  CoreErrorCode.internal => strings.connectionErrorInternal,
};
