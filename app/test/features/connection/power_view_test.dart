import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/connection/domain/connection_state.dart';
import 'package:vpnclient/features/connection/application/power_view.dart';
import 'package:vpnclient/features/connection/domain/elapsed.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

const _regular = TunnelMode.regular;
const _whitelist = TunnelMode.whitelist;

TunnelSnapshot _tunnel(
  TunnelStatus status, {
  TunnelMode userMode = _regular,
  TunnelMode? effectiveMode,
}) => TunnelSnapshot(
  status: status,
  userMode: userMode,
  effectiveMode: effectiveMode ?? userMode,
);

TunnelMode _other(TunnelMode mode) => mode == _regular ? _whitelist : _regular;

extension on Any {
  Generator<TunnelSnapshot> get snapshot => combine3(
    choose(TunnelStatus.values),
    choose(TunnelMode.values),
    choose(TunnelMode.values),
    (TunnelStatus status, TunnelMode user, TunnelMode effective) =>
        _tunnel(status, userMode: user, effectiveMode: effective),
  );

  Generator<TunnelMode> get mode => choose(TunnelMode.values);
}

void main() {
  // One test per row of the PowerButton table in tech.md 2.1.
  group('the table of tech.md 2.1', () {
    for (final screen in TunnelMode.values) {
      test('disconnected: idle, a tap starts ${screen.json}', () {
        final view = powerViewFor(screen, _tunnel(TunnelStatus.disconnected));

        expect(view.state, PowerState.idle);
        expect(view.action, StartTunnel(screen));
        expect(view.activeElsewhere, isNull);
      });

      test('connected in ${screen.json} on its screen: a tap stops', () {
        final tunnel = _tunnel(
          TunnelStatus.connected,
          userMode: _other(screen),
          effectiveMode: screen,
        );
        final view = powerViewFor(screen, tunnel);

        expect(view.state, PowerState.connected);
        expect(view.action, const StopTunnel());
        expect(view.activeElsewhere, isNull);
      });

      test('connected in the other mode: idle, a tap switches the mode', () {
        final tunnel = _tunnel(
          TunnelStatus.connected,
          effectiveMode: _other(screen),
        );
        final view = powerViewFor(screen, tunnel);

        expect(view.state, PowerState.idle);
        expect(view.action, SwitchUserMode(screen));
        expect(view.activeElsewhere, _other(screen));
      });

      test('connecting and disconnecting ignore taps on ${screen.json}', () {
        final connecting = powerViewFor(
          screen,
          _tunnel(TunnelStatus.connecting, userMode: _other(screen)),
        );
        final disconnecting = powerViewFor(
          screen,
          _tunnel(TunnelStatus.disconnecting, userMode: _other(screen)),
        );

        expect(connecting.state, PowerState.connecting);
        expect(connecting.action, isNull);
        expect(disconnecting.state, PowerState.disconnecting);
        expect(disconnecting.action, isNull);
      });
    }
  });

  test('an error shows on the screen of the failed mode and starts again', () {
    final tunnel = _tunnel(TunnelStatus.error, userMode: _whitelist);

    final failed = powerViewFor(_whitelist, tunnel);
    final other = powerViewFor(_regular, tunnel);

    expect(failed.state, PowerState.error);
    expect(failed.action, const StartTunnel(_whitelist));
    expect(other.state, PowerState.idle);
    expect(other.action, const StartTunnel(_regular));
  });

  test('a start needs a loaded profile, a stop does not', () {
    expect(
      powerViewFor(
        _regular,
        _tunnel(TunnelStatus.disconnected),
        canStart: false,
      ).action,
      isNull,
    );
    expect(
      powerViewFor(
        _regular,
        _tunnel(TunnelStatus.connected),
        canStart: false,
      ).action,
      const StopTunnel(),
    );
  });

  Glados2<TunnelSnapshot, TunnelMode>(any.snapshot, any.mode).test(
    'a pending call ignores every tap',
    (tunnel, screen) {
      expect(powerViewFor(screen, tunnel, busy: true).action, isNull);
    },
  );

  Glados<TunnelSnapshot>(any.snapshot).test(
    'connecting and disconnecting look the same on both screens',
    (tunnel) {
      final busy =
          tunnel.status == TunnelStatus.connecting ||
          tunnel.status == TunnelStatus.disconnecting;
      if (busy) {
        expect(
          powerViewFor(_regular, tunnel).state,
          powerViewFor(_whitelist, tunnel).state,
        );
      }
    },
  );

  Glados<TunnelSnapshot>(any.snapshot).test(
    'connected: exactly the effective mode screen shows connected',
    (tunnel) {
      if (tunnel.status != TunnelStatus.connected) {
        return;
      }
      final connected = [
        for (final screen in TunnelMode.values)
          if (powerViewFor(screen, tunnel).state == PowerState.connected)
            screen,
      ];
      expect(connected, [tunnel.effectiveMode]);
    },
  );

  Glados2<TunnelSnapshot, TunnelMode>(any.snapshot, any.mode).test(
    'a tap acts only on the mode of its own screen',
    (tunnel, screen) {
      switch (powerViewFor(screen, tunnel).action) {
        case StartTunnel(:final mode) || SwitchUserMode(:final mode):
          expect(mode, screen);
        case StopTunnel():
          expect(tunnel.effectiveMode, screen);
        case null:
          break;
      }
    },
  );

  group('formatElapsed', () {
    test('writes hours, minutes, and seconds', () {
      expect(formatElapsed(Duration.zero), '00:00:00');
      expect(
        formatElapsed(const Duration(minutes: 12, seconds: 31)),
        '00:12:31',
      );
      expect(formatElapsed(const Duration(hours: 26, seconds: 5)), '26:00:05');
    });

    test('a clock behind connectedSince shows zero', () {
      expect(formatElapsed(const Duration(seconds: -3)), '00:00:00');
    });

    Glados<int>(any.intInRange(0, 400000))
        .test('the text reads back as the same number of seconds', (seconds) {
          final parts = formatElapsed(Duration(seconds: seconds))
              .split(':')
              .map(int.parse)
              .toList();
          expect(parts, hasLength(3));
          expect(parts[1], lessThan(60));
          expect(parts[2], lessThan(60));
          expect(parts[0] * 3600 + parts[1] * 60 + parts[2], seconds);
        });
  });
}
