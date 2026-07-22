import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import '../../../remote_connection/remote_connection.dart';

class MenuRemoteConnection {
  const MenuRemoteConnection(this._remote);

  final RemoteConnection _remote;

  Future<List<OnlineSessionListing>> fetchSessions() async {
    final decoded = await _remote.request(method: 'GET', path: 'sessions');
    return [
      for (final value in jsonList(decoded))
        OnlineSessionListing.fromJson(jsonObject(value)),
    ];
  }

  Future<List<OnlineSessionListing>> fetchWatchableSessions() async {
    final decoded = await _remote.request(
      method: 'GET',
      path: 'sessions/watchable',
    );
    return [
      for (final value in jsonList(decoded))
        OnlineSessionListing.fromJson(jsonObject(value)),
    ];
  }

  Future<OnlineSessionListing> fetchSession(String sessionID) async {
    final decoded = await _remote.request(
      method: 'GET',
      path: 'sessions/$sessionID',
    );
    return OnlineSessionListing.fromJson(jsonObject(decoded));
  }

  Future<List<OnlineSessionInvite>> fetchSessionInvites() async {
    final decoded = await _remote.request(
      method: 'GET',
      path: 'sessions/invites',
    );
    return [
      for (final value in jsonList(decoded))
        OnlineSessionInvite.fromJson(jsonObject(value)),
    ];
  }

  Future<OnlineServerStatus> fetchServerStatus() async {
    final decoded = await _remote.request(method: 'GET', path: 'metrics');
    return OnlineServerStatus.fromJson(jsonObject(decoded));
  }

  Future<Map<String, Object?>> fetchAdminOperations() =>
      _remote.requestJson(method: 'GET', path: 'admin/operations');

  Future<void> restartProductionServer() async {
    await _remote.requestJson(
      method: 'POST',
      path: 'admin/control/restart',
      headers: {'X-Kolkhoz-Restart-Confirm': 'restart'},
    );
  }

  Future<OnlineSessionResponse> syncActiveSession() async {
    final decoded = await _remote.request(
      method: 'POST',
      path: 'active-session/sync',
    );
    return OnlineSessionResponse.fromJson(jsonObject(decoded));
  }

  Future<OnlineSessionResponse> createSession({
    int? seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    bool ranked = false,
    bool browserJoinable = true,
    int bestOf = 1,
  }) async {
    final body = <String, Object?>{
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
      'ranked': ranked,
      'browserJoinable': browserJoinable,
      'bestOf': bestOf,
      'seed': ?seed,
    };
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'sessions',
      body: body,
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<void> inviteSessionComrades({
    required String sessionID,
    required List<String> userIDs,
  }) async {
    await _remote.requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/invites',
      body: {'userIDs': userIDs},
    );
  }

  Future<void> declineSessionInvite(String sessionID) async {
    await _remote.requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/invites/decline',
      body: {'sessionID': sessionID},
    );
  }

  Future<OnlineSessionResponse> joinSession({
    required String sessionID,
    int? preferredPlayerID,
  }) async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/join',
      body: {'sessionID': sessionID, 'preferredPlayerID': ?preferredPlayerID},
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> matchmakeSession({
    bool rankedOnly = false,
    bool comradesOnly = false,
  }) async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'sessions/matchmake',
      body: {'rankedOnly': rankedOnly, 'comradesOnly': comradesOnly},
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineDailyChallenge> fetchDailyChallenge() async {
    final json = await _remote.requestJson(
      method: 'GET',
      path: 'challenges/daily',
    );
    return OnlineDailyChallenge.fromJson(json);
  }

  Future<OnlineSessionResponse> startDailyChallenge() async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'challenges/daily/start',
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineWeeklyTournament> fetchWeeklyTournament() async {
    final json = await _remote.requestJson(
      method: 'GET',
      path: 'tournaments/weekly',
    );
    return OnlineWeeklyTournament.fromJson(json);
  }

  Future<OnlineWeeklyTournament> joinWeeklyTournament() async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'tournaments/weekly/join',
    );
    return OnlineWeeklyTournament.fromJson(json);
  }

  Future<OnlineWeeklyTournament> leaveWeeklyTournament() async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'tournaments/weekly/leave',
    );
    return OnlineWeeklyTournament.fromJson(json);
  }
}
