// The Flutter to Android bridge, VpnApi v1 (tech.md 5.6). Run pigeon from app/.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/gen/pigeon/vpn_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/vpnclient/app/gen/VpnApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.vpnclient.app.gen'),
  ),
)
enum TunnelModeMsg { regular, whitelist }

enum PrepareResult { granted, denied }

@HostApi()
abstract class VpnHostApi {
  @async
  PrepareResult prepare();

  @async
  void start(String tunnelRequestJson);

  @async
  void update(String tunnelRequestJson);

  @async
  void stop();

  @async
  void setUserMode(TunnelModeMsg mode);

  @async
  void selectServer(TunnelModeMsg group, String serverId);

  /// Returns a JSON CoreEvent of type url_test. Works only while connected.
  @async
  String urlTest(List<String> serverIds);

  /// Returns a JSON CoreEvent of type state.
  @async
  String getState();

  /// Returns JSON objects with package and label.
  @async
  List<String> listApps();

  /// Deletes the stored last request, so always-on cannot reconnect after a
  /// logout (tech.md 26.3).
  @async
  void forgetLastRequest();
}

@EventChannelApi()
abstract class VpnEventApi {
  /// A stream of JSON CoreEvent values.
  String events();
}
