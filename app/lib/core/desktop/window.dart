import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const _minimumWindowSize = Size(360, 640);

/// Applies the desktop window limits of tech.md 2.1. The default size lives in
/// the Windows runner, so the first frame is already right.
Future<void> configureDesktopWindow() async {
  if (!Platform.isWindows) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(_minimumWindowSize);
}
