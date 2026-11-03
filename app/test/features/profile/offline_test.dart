import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import '../connection/connection_harness.dart';

// Acceptance of S2-06 (tech.md 16): with every API address down, a signed-in
// device connects from the cached profile.

void main() {
  testWidgets('connects from the cached profile with the API down', (
    tester,
  ) async {
    final app = ConnectionHarness();
    app.api.failure = const ApiUnavailable();
    app.cache.value = CachedProfile(
      ProfileV1.fromJson(jsonDecode(seedProfileJson()) as Map<String, Object?>),
      '"old"',
    );
    await app.pump(tester);

    await tapPower(tester);

    expect(app.taps, ['prepare', 'start']);
    final request =
        jsonDecode(app.bridge.requests.single) as Map<String, Object?>;
    expect(request['servers'], hasLength(5));
    expect(powerButton(tester).state, PowerState.connected);
  });
}
