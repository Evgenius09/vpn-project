import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/device/device_identity.dart';
import '../../../core/providers.dart';
import '../../profile/application/profile_controller.dart';
import '../data/auth_repository.dart';
import '../domain/login_state.dart';
import '../domain/username.dart';

typedef UrlOpener = Future<bool> Function(Uri url);

/// Opens the bot in Telegram or the browser. Tests replace it.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    () => ref.read(deviceIdentityProvider.future),
    appVersion: appVersion,
  ),
);

class LoginController extends Notifier<LoginState> {
  Timer? _ticker;

  static const _tick = Duration(seconds: 1);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  LoginState build() {
    ref.onDispose(_stopTicker);
    return const LoginUsername();
  }

  Future<void> submitUsername(String raw) async {
    final current = state;
    if (current.busy || current is! LoginUsername) {
      return;
    }
    final username = normalizeUsername(raw);
    if (username == null) {
      state = LoginUsername(
        username: raw,
        error: const LoginError(LoginFailure.invalidUsername),
      );
      return;
    }
    state = LoginUsername(username: raw, busy: true);
    await _requestCode(username);
  }

  /// "I pressed Start, send the code".
  Future<void> retryAfterStart() async {
    final current = state;
    if (current is LoginBotNotStarted && !current.busy) {
      state = LoginBotNotStarted(
        username: current.username,
        botUrl: current.botUrl,
        busy: true,
      );
      await _requestCode(current.username);
    }
  }

  Future<void> resend() async {
    final current = state;
    if (current is LoginCode && !current.busy && current.resendIn == 0) {
      state = current.copyWith(busy: true, clearError: true);
      await _requestCode(current.username);
    }
  }

  Future<void> _requestCode(String username) async {
    try {
      final challenge = await _repository.start(username);
      state = LoginCode(
        username: username,
        loginId: challenge.loginId,
        botUrl: challenge.botUrl,
        resendIn: challenge.resendAfterSec,
      );
      _startTicker();
    } on LoginException catch (exception) {
      _onStartFailed(username, exception.error);
    }
  }

  void _onStartFailed(String username, LoginError error) {
    final current = state;
    if (error.failure == LoginFailure.telegramUserNotFound) {
      _stopTicker();
      state = LoginBotNotStarted(username: username, botUrl: error.botUrl);
      return;
    }
    switch (current) {
      case LoginCode():
        final wait = error.failure == LoginFailure.rateLimited
            ? error.retryAfterSec
            : null;
        state = current.copyWith(busy: false, error: error, resendIn: wait);
        if (wait != null) {
          _startTicker();
        }
      case LoginBotNotStarted(:final botUrl):
        state = LoginBotNotStarted(
          username: username,
          botUrl: botUrl,
          error: error,
        );
      case LoginUsername(username: final typed):
        state = LoginUsername(username: typed, error: error);
    }
  }

  Future<void> submitCode(String code) async {
    final current = state;
    if (current is! LoginCode || current.busy) {
      return;
    }
    state = current.copyWith(busy: true, clearError: true);
    try {
      final token = await _repository.verify(current.loginId, code);
      // The profile of a previous session must not survive into this one.
      ref.invalidate(profileControllerProvider);
      await ref.read(sessionProvider.notifier).signIn(token);
      _stopTicker();
      state = const LoginUsername();
    } on LoginException catch (exception) {
      final latest = state;
      if (latest is LoginCode) {
        state = latest.copyWith(
          busy: false,
          error: exception.error,
          attempt: latest.attempt + 1,
        );
      }
    }
  }

  void changeUsername() {
    final username = switch (state) {
      LoginCode(:final username) => username,
      LoginBotNotStarted(:final username) => username,
      LoginUsername(:final username) => username,
    };
    _stopTicker();
    state = LoginUsername(username: username);
  }

  Future<void> openBot() async {
    final current = state;
    final url = switch (current) {
      LoginCode(:final botUrl) => botUrl,
      LoginBotNotStarted(:final botUrl) => botUrl,
      LoginUsername() => null,
    };
    if (url == null) {
      return;
    }
    final uri = Uri.tryParse(url);
    final opened = uri != null && await ref.read(urlOpenerProvider)(uri);
    if (!opened) {
      _showError(const LoginError(LoginFailure.botLinkFailed));
    }
  }

  void _showError(LoginError error) {
    state = switch (state) {
      final LoginCode code => code.copyWith(error: error),
      LoginBotNotStarted(:final username, :final botUrl) => LoginBotNotStarted(
        username: username,
        botUrl: botUrl,
        error: error,
      ),
      LoginUsername(:final username) => LoginUsername(
        username: username,
        error: error,
      ),
    };
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(_tick, (_) {
      final current = state;
      if (current is! LoginCode || current.resendIn <= 0) {
        _stopTicker();
        return;
      }
      state = current.copyWith(resendIn: current.resendIn - 1);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
