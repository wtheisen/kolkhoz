import 'c_engine_bridge.dart';
import 'player.dart';

class GameSeat {
  const GameSeat({
    required this.seatID,
    required this.player,
    this.ready = true,
  });

  final int seatID;
  final GamePlayer player;
  final bool ready;
}

class GameSpectator {
  const GameSpectator({required this.id, this.displayName});

  final String id;
  final String? displayName;
}

class GameLobby {
  GameLobby({
    required this.variants,
    required List<GameSeat> seats,
    List<GameSpectator> spectators = const [],
  }) : seats = List.unmodifiable(seats),
       spectators = List.unmodifiable(spectators) {
    if (seats.length != 4 ||
        seats.indexed.any((entry) => entry.$1 != entry.$2.seatID)) {
      throw ArgumentError.value(
        seats,
        'seats',
        'must contain seats 0 through 3',
      );
    }
  }

  final KolkhozGameVariants variants;
  final List<GameSeat> seats;
  final List<GameSpectator> spectators;

  List<GamePlayer> get players =>
      List.unmodifiable(seats.map((seat) => seat.player));

  bool get readyToStart => seats.every((seat) => seat.ready);

  GameLobby copyWith({
    KolkhozGameVariants? variants,
    List<GameSeat>? seats,
    List<GameSpectator>? spectators,
  }) => GameLobby(
    variants: variants ?? this.variants,
    seats: seats ?? this.seats,
    spectators: spectators ?? this.spectators,
  );
}
