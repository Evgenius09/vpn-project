/// The last ping of one server (tech.md 31.2). Presentation maps it to the
/// PingValue of PingBadge.
sealed class ServerPing {
  const ServerPing();

  const factory ServerPing.unknown() = UnknownPing;
  const factory ServerPing.measuring() = MeasuringPing;
  const factory ServerPing.delay(int ms) = DelayPing;
  const factory ServerPing.unreachable() = UnreachablePing;
}

final class UnknownPing extends ServerPing {
  const UnknownPing();

  @override
  bool operator ==(Object other) => other is UnknownPing;

  @override
  int get hashCode => 0;
}

final class MeasuringPing extends ServerPing {
  const MeasuringPing();

  @override
  bool operator ==(Object other) => other is MeasuringPing;

  @override
  int get hashCode => 1;
}

final class DelayPing extends ServerPing {
  const DelayPing(this.ms);

  final int ms;

  @override
  bool operator ==(Object other) => other is DelayPing && other.ms == ms;

  @override
  int get hashCode => Object.hash(DelayPing, ms);

  @override
  String toString() => 'DelayPing($ms)';
}

final class UnreachablePing extends ServerPing {
  const UnreachablePing();

  @override
  bool operator ==(Object other) => other is UnreachablePing;

  @override
  int get hashCode => 2;
}
