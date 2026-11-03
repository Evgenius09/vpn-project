import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/settings_screen.dart';
import 'home_screen.dart';
import 'kitchen_sink.dart';
import 'placeholder_screen.dart';

/// Navigation as data (tech.md 8). A slice adds a route through a
/// contract-change, not by editing the router.
class AppRoute {
  const AppRoute({
    required this.path,
    required this.build,
    this.public = false,
    this.debugOnly = false,
  });

  final String path;
  final WidgetBuilder build;

  /// Reachable without a token.
  final bool public;

  /// Left out of release builds.
  final bool debugOnly;
}

abstract final class RoutePaths {
  static const login = '/login';
  static const home = '/';
  static const settings = '/settings';
  static const settingsSection = '/settings/:section';
  static const kitchenSink = '/dev/kitchen-sink';
}

final List<AppRoute> allRoutes = [
  AppRoute(
    path: RoutePaths.login,
    public: true,
    build: (_) => const LoginScreen(),
  ),
  AppRoute(path: RoutePaths.home, build: (_) => const HomeScreen()),
  AppRoute(path: RoutePaths.settings, build: (_) => const SettingsScreen()),
  AppRoute(
    path: RoutePaths.settingsSection,
    build: (_) => const SettingsPlaceholderScreen(),
  ),
  AppRoute(
    path: RoutePaths.kitchenSink,
    public: true,
    debugOnly: true,
    build: (_) => const KitchenSinkScreen(),
  ),
];

/// The routes of a build. [debug] is a parameter so tests can check release.
List<AppRoute> routesFor({bool debug = kDebugMode}) =>
    allRoutes.where((route) => debug || !route.debugOnly).toList();

/// The login guard: no token means /login, and a signed-in user skips it.
String? redirectFor(String path, {required bool signedIn}) {
  if (path == RoutePaths.login) {
    return signedIn ? RoutePaths.home : null;
  }
  if (signedIn || _isPublic(path)) {
    return null;
  }
  return RoutePaths.login;
}

bool _isPublic(String path) =>
    allRoutes.any((route) => route.public && route.path == path);
