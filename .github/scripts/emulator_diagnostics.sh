#!/usr/bin/env bash
# Prints what a failed or hung emulator test leaves behind. The test step kills
# flutter with SIGKILL, so the app is still alive to dump its threads.
set -uo pipefail

adb root >/dev/null
sleep 3
adb wait-for-device

pid="$(adb shell pidof com.vpnclient.app | tr -d '\r')"
if [[ -n "$pid" ]]; then
  echo "--- threads of $pid"
  adb shell debuggerd -j "$pid" | grep -vE '^\s*$' | head -n 400
else
  echo "--- the app is not running"
fi

echo "--- logcat"
adb logcat -d -v time 'flutter:I' 'AndroidRuntime:E' 'GoLog:I' 'ActivityManager:W' '*:S' | tail -n 200
