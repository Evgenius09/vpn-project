import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile_state.dart';

final profileCacheProvider = Provider<ProfileCache>(
  (ref) => FileProfileCache(getApplicationSupportDirectory),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(profileCacheProvider),
    ref.watch(apiEndpointsProvider),
  ),
);

class ProfileController extends Notifier<ProfileState> {
  Timer? _retry;

  @override
  ProfileState build() {
    ref.onDispose(() => _retry?.cancel());
    unawaited(Future.microtask(load));
    return const ProfileLoading();
  }

  Future<void> load() async {
    _retry?.cancel();
    try {
      final loaded = await ref.read(profileRepositoryProvider).load();
      if (!ref.mounted) {
        return;
      }
      state = ProfileReady(loaded.profile, fromCache: loaded.fromCache);
      final retryAfter = loaded.retryAfterSec;
      if (retryAfter != null) {
        _retry = Timer(Duration(seconds: retryAfter), load);
      }
    } on ApiProblem catch (problem) {
      if (!ref.mounted) {
        return;
      }
      if (problem.isUnauthorized) {
        // Dropping the session moves the router to /login (tech.md 5.2).
        await ref.read(sessionProvider.notifier).signOut();
        return;
      }
      state = const ProfileFailed();
    } on ApiUnavailable {
      if (ref.mounted) {
        state = const ProfileFailed();
      }
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
