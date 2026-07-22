import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import '../../remote_connection/remote_connection.dart';

class ProfileRemoteConnection {
  const ProfileRemoteConnection(this._remote);

  final RemoteConnection _remote;

  Future<void> deleteAccount() async {
    await _remote.request(method: 'DELETE', path: 'account');
  }

  Future<bool> fetchFullGameEntitlement() async {
    final json = await _remote.requestJson(
      method: 'GET',
      path: 'commerce/entitlements',
    );
    return json['fullGame'] as bool? ?? false;
  }

  Future<bool> claimFullGamePurchase({
    required String provider,
    required String verificationData,
  }) async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'commerce/purchases/claim',
      body: {'provider': provider, 'verificationData': verificationData},
    );
    return json['fullGame'] as bool? ?? false;
  }

  Future<OnlineComradesResponse> fetchComrades() async {
    final decoded = await _remote.request(method: 'GET', path: 'comrades');
    return OnlineComradesResponse.fromJson(jsonObject(decoded));
  }

  Future<List<OnlineComradeProfile>> fetchLeaderboard() async {
    final json = await _remote.requestJson(method: 'GET', path: 'leaderboard');
    return [
      for (final value in jsonList(json['players'] ?? const []))
        OnlineComradeProfile.fromJson(jsonObject(value)),
    ];
  }

  Future<List<OnlineRecentGame>> fetchRecentGames() async {
    final json = await _remote.requestJson(
      method: 'GET',
      path: 'results/recent',
    );
    return [
      for (final value in jsonList(json['games'] ?? const []))
        OnlineRecentGame.fromJson(jsonObject(value)),
    ];
  }

  Future<OnlineGameReplay> fetchReplay(String sessionID) async {
    final json = await _remote.requestJson(
      method: 'GET',
      path: 'results/$sessionID/replay',
    );
    return OnlineGameReplay.fromJson(json);
  }

  Future<OnlineComradeProfile> fetchPublicProfile(String userID) async {
    final decoded = await _remote.request(
      method: 'GET',
      path: 'profiles/$userID',
    );
    return OnlineComradeProfile.fromJson(jsonObject(decoded));
  }

  Future<OnlineComradeProfile> fetchCurrentProfile() async {
    final decoded = await _remote.request(method: 'GET', path: 'profile');
    return OnlineComradeProfile.fromJson(jsonObject(decoded));
  }

  Future<OnlineComradeProfile> updateCurrentProfile({
    required String displayName,
    required String portraitAsset,
  }) async {
    final decoded = await _remote.request(
      method: 'PATCH',
      path: 'profile',
      body: {'displayName': displayName, 'portraitAsset': portraitAsset},
    );
    return OnlineComradeProfile.fromJson(jsonObject(decoded));
  }

  Future<OnlineComradeProfile> sendComradeRequest(String comradeCode) async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'comrades',
      body: {'comradeCode': comradeCode},
    );
    return OnlineComradeProfile.fromJson(
      jsonObject(json['request'] ?? json['comrade']),
    );
  }

  Future<OnlineComradeProfile> sendComradeRequestToUser(String userID) async {
    final json = await _remote.requestJson(
      method: 'POST',
      path: 'comrades',
      body: {'userID': userID},
    );
    return OnlineComradeProfile.fromJson(
      jsonObject(json['request'] ?? json['comrade']),
    );
  }

  Future<void> respondToComradeRequest({
    required String userID,
    required bool accept,
  }) async {
    await _remote.requestJson(
      method: 'POST',
      path: 'comrades/respond',
      body: {'userID': userID, 'accept': accept},
    );
  }

  Future<void> removeComrade(String userID) async {
    await _remote.requestJson(
      method: 'POST',
      path: 'comrades/remove',
      body: {'userID': userID},
    );
  }
}
