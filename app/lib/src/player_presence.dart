class PlayerPresence {
  const PlayerPresence({
    required this.seatID,
    required this.connected,
    this.lastSeenAt,
    this.timeouts = 0,
    this.autopilot = false,
    this.abandoned = false,
  });

  final int seatID;
  final bool connected;
  final double? lastSeenAt;
  final int timeouts;
  final bool autopilot;
  final bool abandoned;
}
