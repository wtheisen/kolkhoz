enum RemoteAvailability { unknown, reachable, unreachable }

class RemoteActiveGame {
  const RemoteActiveGame({
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.started,
    required this.requiresSync,
  });

  final String sessionID;
  final String inviteCode;
  final int playerID;
  final bool started;
  final bool requiresSync;

  factory RemoteActiveGame.fromJson(Map<String, Object?> json) {
    return RemoteActiveGame(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      playerID: json['playerID'] as int,
      started: json['started'] as bool? ?? false,
      requiresSync: json['requiresSync'] as bool? ?? true,
    );
  }
}

class RemoteStatus {
  const RemoteStatus({
    this.availability = RemoteAvailability.unknown,
    this.citizensOnline = 0,
    this.activeGame,
    this.lastHeartbeatAt,
  });

  final RemoteAvailability availability;
  final int citizensOnline;
  final RemoteActiveGame? activeGame;
  final DateTime? lastHeartbeatAt;

  factory RemoteStatus.fromHeartbeatJson(Map<String, Object?> json) {
    final service = _object(json['service']);
    final active = json['activeSession'];
    return RemoteStatus(
      availability: RemoteAvailability.reachable,
      citizensOnline: _nonNegativeInt(
        service['citizensOnline'] ?? service['activeSeats'],
      ),
      activeGame: active is Map
          ? RemoteActiveGame.fromJson(active.cast<String, Object?>())
          : null,
      lastHeartbeatAt: DateTime.now().toUtc(),
    );
  }
}

Map<String, Object?> _object(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

int _nonNegativeInt(Object? value) => value is int && value >= 0 ? value : 0;
