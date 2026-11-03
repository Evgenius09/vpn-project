#!/usr/bin/env bash
# Prints what a failed or hung emulator test leaves behind. The test step kills
# flutter with SIGKILL, so the app is still alive to dump its threads. Every adb
# call has a timeout: a wedged emulator must not hold the job until its limit,
# which also loses the log.
set -uo pipefail

run() { timeout -s KILL 60 adb "$@"; }

run root >/dev/null
sleep 3
run wait-for-device || echo "--- the emulator did not come back"

pid="$(run shell pidof com.vpnclient.app | tr -d '\r')"
if [[ -n "$pid" ]]; then
  echo "--- threads of $pid"
  run shell debuggerd -j "$pid" | grep -vE '^\s*$' | head -n 400
else
  echo "--- the app is not running"
fi

echo "--- logcat"
run logcat -d -v time 'flutter:I' 'AndroidRuntime:E' 'GoLog:I' 'ActivityManager:W' '*:S' | tail -n 200
