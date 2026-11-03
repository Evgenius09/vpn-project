import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../gen/api/export.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../data/selection_store.dart';
import '../domain/server_selection.dart';

final selectionStoreProvider = Provider<SelectionStore>(
  (ref) => FileSelectionStore(getApplicationSupportDirectory),
);

/// The stored choice of each group, as the user made it. It may name a server
/// the profile no longer holds; [chosenServerProvider] resolves that.
class SelectionController extends AsyncNotifier<SelectedServers> {
  @override
  Future<SelectedServers> build() => ref.read(selectionStoreProvider).read();

  Future<void> remember(TunnelMode group, String serverId) async {
    final current = await future;
    final next = withChoice(current, group, serverId);
    state = AsyncData(next);
    await ref.read(selectionStoreProvider).write(next);
  }
}

final selectionControllerProvider =
    AsyncNotifierProvider<SelectionController, SelectedServers>(
      SelectionController.new,
    );

/// The server of [group] the list highlights and the next start sends. Null
/// until the profile and the stored choice are loaded, and for an empty group.
final chosenServerProvider = Provider.family<String?, TunnelMode>((ref, group) {
  final profile = ref.watch(profileControllerProvider);
  final stored = ref.watch(selectionControllerProvider).value;
  if (profile is! ProfileReady || stored == null) {
    return null;
  }
  return choiceIn(profile.profile.servers, group, storedFor(stored, group));
});
