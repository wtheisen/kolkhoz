import 'dart:async';
import 'dart:io';

import 'online_game_client.dart';
import 'online_game_models.dart';

class OnlineGameRealtime {
  OnlineGameRealtime({
    required this.client,
    required this.sessionID,
    required this.playerID,
    required this.seatToken,
    required this.reconnectDelay,
    required this.afterRevision,
    required this.onState,
    required this.onActions,
    required this.onConnectionChanged,
  });

  final KolkhozOnlineClient client;
  final String sessionID;
  final int playerID;
  final String seatToken;
  final Duration reconnectDelay;
  final int Function() afterRevision;
  final void Function(OnlineSessionUpdate update) onState;
  final void Function(OnlineActionUpdatesResponse updates) onActions;
  final void Function(bool connected) onConnectionChanged;

  WebSocket? _socket;
  Timer? _reconnectTimer;
  int _generation = 0;
  bool _disposed = false;

  void start() {
    _clearConnection();
    _generation += 1;
    final generation = _generation;
    unawaited(_connect(generation));
  }

  Future<void> _connect(int generation) async {
    try {
      final socket = await client.connectRealtime(
        sessionID: sessionID,
        playerID: playerID,
        seatToken: seatToken,
        afterRevision: afterRevision(),
      );
      if (_disposed || _generation != generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      onConnectionChanged(true);
      socket.listen(
        _handleFrame,
        onError: (_) => _scheduleReconnect(generation),
        onDone: () => _scheduleReconnect(generation),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(generation);
    }
  }

  void _handleFrame(Object? data) {
    if (_disposed) {
      return;
    }
    try {
      final frame = OnlineRealtimeFrame.decode(data);
      if (frame.update case final update?) {
        onState(update);
      } else if (frame.updates case final updates?) {
        onActions(updates);
      }
    } catch (_) {
      // Durable polling and reconnect isolate malformed realtime frames.
    }
  }

  void _scheduleReconnect(int generation) {
    if (_disposed || _generation != generation || _reconnectTimer != null) {
      return;
    }
    final wasConnected = _socket != null;
    _socket = null;
    if (wasConnected) {
      onConnectionChanged(false);
    }
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      if (!_disposed && _generation == generation) {
        unawaited(_connect(generation));
      }
    });
  }

  void _clearConnection() {
    _generation += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _clearConnection();
  }
}
