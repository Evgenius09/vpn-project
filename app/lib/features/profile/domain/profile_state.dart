import '../../../gen/api/export.dart';

sealed class ProfileState {
  const ProfileState();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileReady extends ProfileState {
  const ProfileReady(this.profile, {this.fromCache = false});

  final ProfileV1 profile;

  /// The API failed and this is the last saved profile.
  final bool fromCache;
}

/// No profile at all: the API failed and the cache is empty.
final class ProfileFailed extends ProfileState {
  const ProfileFailed();
}
