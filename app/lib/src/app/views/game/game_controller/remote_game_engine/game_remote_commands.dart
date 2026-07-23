import 'dart:async';
import 'dart:io';

import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';
import '../../../../remote_connection/remote_error.dart';
import '../game_commands.dart';
import 'game_realtime.dart';
import 'game_remote_connection.dart';

const onlineGameRefreshInterval = Duration(seconds: 1);
const onlineGameRealtimeRefreshInterval = Duration(seconds: 15);

bool onlineActionResultIsSingleRevision(
  int beforeRevision,
  int resultRevision,
) => resultRevision == beforeRevision + 1;

bool isStaleOnlineActionError(Object error) =>
    error is RemoteRequestException &&
    error.statusCode == HttpStatus.conflict &&
    error.message == 'stale action';

class GameRemoteCommands extends GameCommandStream {
  GameRemoteCommands({
    required this.client,
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.seatToken,
    required OnlineSessionUpdate initialUpdate,
    required this.realtimeReconnectDelay,
    this.spectator = false,
  }) : _latestRevision = initialUpdate.actionLogCount {
    _realtime = GameRealtime(
      client: client,
      sessionID: sessionID,
      playerID: playerID,
      seatToken: seatToken,
      reconnectDelay: realtimeReconnectDelay,
      afterRevision: () => _latestRevision,
      onState: _publishState,
      onActions: _publishActions,
      onConnectionChanged: (connected) => _startPolling(
        interval: connected
            ? onlineGameRealtimeRefreshInterval
            : onlineGameRefreshInterval,
      ),
    );
  }

  final GameRemoteConnection client;
  final String sessionID;
  final String inviteCode;
  final int playerID;
  final String seatToken;
  final bool spectator;
  final Duration realtimeReconnectDelay;
  late final GameRealtime _realtime;

  Timer? _refreshTimer;
  int _latestRevision;
  bool _refreshInFlight = false;
  bool _commandInFlight = false;
  bool _disposed = false;

  bool get commandInFlight => _commandInFlight;

  void start() {
    _startPolling();
    if (!spectator) {
      _realtime.start();
    }
  }

  @override
  Future<void> send(GameCommand command) {
    if (_disposed) {
      return Future.value();
    }
    return switch (command) {
      SubmitGameAction() => _submitAction(command),
      RefreshGame() => _refresh(command),
      SendGameReaction() => _sendReaction(command),
      KickGamePlayer() => _kickPlayer(command),
      LeaveGame() => _leave(command),
      _ => _unsupported(command),
    };
  }

  Future<void> _unsupported(GameCommand command) async {
    publish(
      GameCommandFailed(
        command: command,
        error: UnsupportedError(
          '${command.runtimeType} is not an online game command',
        ),
      ),
    );
  }

  Future<void> _submitAction(SubmitGameAction command) async {
    if (_commandInFlight || spectator) {
      return;
    }
    _commandInFlight = true;
    try {
      final beforeRevision = command.expectedRevision ?? _latestRevision;
      final OnlineSessionUpdate update;
      try {
        update = await client.submitAction(
          sessionID: sessionID,
          playerID: playerID,
          seatToken: seatToken,
          actionLogCount: beforeRevision,
          action: command.action,
        );
      } catch (error) {
        if (!isStaleOnlineActionError(error)) {
          rethrow;
        }
        final refreshed = await client.fetchUpdate(
          sessionID: sessionID,
          playerID: playerID,
          seatToken: seatToken,
        );
        _publishState(refreshed);
        publish(GameCommandCompleted(command));
        return;
      }
      if (onlineActionResultIsSingleRevision(
        beforeRevision,
        update.actionLogCount,
      )) {
        _publishActions(
          OnlineActionUpdatesResponse(
            sessionID: sessionID,
            actionLogCount: update.actionLogCount,
            updates: [
              OnlineActionUpdate(
                revision: update.actionLogCount,
                action: OnlineEngineAction.fromEngineAction(command.action),
                update: update,
              ),
            ],
          ),
        );
        publish(GameCommandCompleted(command));
        return;
      }
      final response = await _fetchUpdates(afterRevision: beforeRevision);
      if (response == null || !_publishActions(response)) {
        _publishState(update);
      }
      publish(GameCommandCompleted(command));
    } catch (error) {
      publish(GameCommandFailed(command: command, error: error));
    } finally {
      _commandInFlight = false;
    }
  }

  Future<void> _refresh(RefreshGame command) async {
    if (command.minimumRevision != null &&
        _latestRevision >= command.minimumRevision!) {
      return;
    }
    try {
      final response = spectator ? null : await _fetchUpdates();
      if (response != null && _publishActions(response)) {
        return;
      }
      final update = spectator
          ? await client.fetchSpectatorUpdate(sessionID)
          : await client.fetchUpdate(
              sessionID: sessionID,
              playerID: playerID,
              seatToken: seatToken,
            );
      _publishState(update);
    } catch (error) {
      publish(GameCommandFailed(command: command, error: error));
    }
  }

  Future<OnlineActionUpdatesResponse?> _fetchUpdates({
    int? afterRevision,
  }) async {
    if (_refreshInFlight) {
      return null;
    }
    _refreshInFlight = true;
    try {
      return await client.fetchActionUpdates(
        sessionID: sessionID,
        playerID: playerID,
        seatToken: seatToken,
        afterRevision: afterRevision ?? _latestRevision,
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _sendReaction(SendGameReaction command) async {
    if (spectator) {
      return;
    }
    try {
      _publishState(
        await client.submitReaction(
          sessionID: sessionID,
          playerID: playerID,
          seatToken: seatToken,
          reactionID: command.reactionID,
        ),
      );
    } catch (error) {
      publish(GameCommandFailed(command: command, error: error));
    }
  }

  Future<void> _kickPlayer(KickGamePlayer command) async {
    try {
      _publishState(
        await client.kickSessionPlayer(
          sessionID: sessionID,
          hostPlayerID: playerID,
          targetPlayerID: command.playerID,
          seatToken: seatToken,
        ),
      );
    } catch (error) {
      publish(GameCommandFailed(command: command, error: error));
    }
  }

  Future<void> _leave(LeaveGame command) async {
    if (spectator) {
      return;
    }
    try {
      await client.leaveSession(
        sessionID: sessionID,
        playerID: playerID,
        seatToken: seatToken,
      );
    } catch (_) {
      // Local teardown must not wait for a failed best-effort leave request.
    }
  }

  bool _publishActions(OnlineActionUpdatesResponse response) {
    final resync = response.resyncUpdate;
    if (resync != null) {
      if (resync.actionLogCount < _latestRevision) {
        return false;
      }
      final committed = resync.actionLogCount > _latestRevision;
      _latestRevision = resync.actionLogCount;
      _deliverState(resync, committed: committed);
      return true;
    }
    final updates = response.updates
        .where((update) => update.revision > _latestRevision)
        .toList(growable: false);
    if (updates.isEmpty) {
      return false;
    }
    _latestRevision = updates.last.revision;
    for (final update in updates) {
      _deliverState(
        update.update,
        action: update.action.engineAction,
        committed: true,
      );
    }
    return true;
  }

  void _publishState(OnlineSessionUpdate update) {
    if (update.actionLogCount < _latestRevision) {
      return;
    }
    final committed = update.actionLogCount > _latestRevision;
    _latestRevision = update.actionLogCount;
    _deliverState(update, committed: committed);
  }

  void _deliverState(
    OnlineSessionUpdate update, {
    EngineAction? action,
    bool committed = false,
  }) {
    publish(
      OnlineGameStateReceived(update, action: action, committed: committed),
    );
  }

  void _startPolling({Duration interval = onlineGameRefreshInterval}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      interval,
      (_) => unawaited(send(const RefreshGame())),
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _realtime.dispose();
    super.dispose();
  }
}
