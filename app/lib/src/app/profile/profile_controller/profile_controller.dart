import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/player_identity.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_remote_connection.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/supabase_config.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required RemoteConnection connection,
    KolkhozIdentityRuntime? identityRuntime,
    ProfileRemoteConnection? remoteConnection,
  }) : _remoteConnection =
           remoteConnection ?? ProfileRemoteConnection(connection),
       _connection = connection,
       _identity = identityRuntime ?? KolkhozIdentityRuntime.instance {
    _identity.addListener(_handleIdentityChanged);
  }

  final ProfileRemoteConnection _remoteConnection;
  final RemoteConnection _connection;
  final KolkhozIdentityRuntime _identity;

  bool busy = false;
  String? message;
  bool messageIsError = false;
  Timer? _profileSaveTimer;
  bool _comradesBusy = false;
  OnlineComradesResponse _comrades = const OnlineComradesResponse();
  List<OnlineRecentGame> _recentGames = const [];
  bool _recentGamesBusy = false;
  Object? _recentGamesError;
  int _recentGamesGeneration = 0;

  KolkhozPlayerIdentity? get player => _identity.player;
  String? get userID => player?.id;
  String? get accessToken => _identity.accessToken;
  bool get signedIn => userID != null;
  OnlineComradesResponse get comrades => _comrades;
  bool get comradesBusy => _comradesBusy;
  List<OnlineRecentGame> get recentGames => List.unmodifiable(_recentGames);
  bool get recentGamesBusy => _recentGamesBusy;
  Object? get recentGamesError => _recentGamesError;

  Future<void> start({
    required String installationID,
    required String displayName,
  }) async {
    final legacy = KolkhozSupabaseRuntime.instance;
    await legacy.start();
    if (legacy.isConfigured && !legacy.isReady) {
      message =
          'Could not check for an existing account. No guest account was created.';
      messageIsError = true;
      notifyListeners();
      return;
    }
    await _identity.start(
      remoteConnection: _connection,
      installationID: installationID,
      displayName: displayName,
      legacyAccessToken: legacy.client?.auth.currentSession?.accessToken,
    );
  }

  Future<OnlineComradeProfile?> loadCurrentProfile({
    required String successMessage,
    required String errorMessage,
  }) async {
    if (player == null || busy) return null;
    busy = true;
    notifyListeners();
    try {
      final profile = await _remoteConnection.fetchCurrentProfile();
      message = successMessage;
      messageIsError = false;
      return profile;
    } catch (_) {
      message = errorMessage;
      messageIsError = true;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveCurrentProfile({
    required String displayName,
    required String portraitAsset,
    required String loadingMessage,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (player?.portable != true || busy) return false;
    busy = true;
    message = loadingMessage;
    messageIsError = false;
    notifyListeners();
    try {
      await _remoteConnection.updateCurrentProfile(
        displayName: displayName,
        portraitAsset: portraitAsset,
      );
      _identity.updateDisplayName(displayName);
      message = successMessage;
      return true;
    } catch (_) {
      message = errorMessage;
      messageIsError = true;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void scheduleCurrentProfileSave({
    required String displayName,
    required String portraitAsset,
    required String loadingMessage,
    required String successMessage,
    required String errorMessage,
    Duration delay = const Duration(milliseconds: 700),
  }) {
    _profileSaveTimer?.cancel();
    _profileSaveTimer = Timer(delay, () {
      _profileSaveTimer = null;
      unawaited(
        saveCurrentProfile(
          displayName: displayName,
          portraitAsset: portraitAsset,
          loadingMessage: loadingMessage,
          successMessage: successMessage,
          errorMessage: errorMessage,
        ),
      );
    });
  }

  Future<void> refreshComrades() async {
    if (_comradesBusy) return;
    _comradesBusy = true;
    notifyListeners();
    try {
      replaceComrades(await _remoteConnection.fetchComrades());
    } catch (_) {
      replaceComrades(const OnlineComradesResponse());
    } finally {
      _comradesBusy = false;
      notifyListeners();
    }
  }

  void replaceComrades(OnlineComradesResponse response) {
    if (_comrades == response) return;
    _comrades = response;
    notifyListeners();
  }

  void clearSocialState() {
    _profileSaveTimer?.cancel();
    _profileSaveTimer = null;
    replaceComrades(const OnlineComradesResponse());
    _recentGames = const [];
    _recentGamesError = null;
    notifyListeners();
  }

  Future<void> loadRecentGames() async {
    final generation = ++_recentGamesGeneration;
    _recentGamesBusy = true;
    _recentGamesError = null;
    notifyListeners();
    try {
      final games = await _remoteConnection.fetchRecentGames();
      if (generation != _recentGamesGeneration) return;
      _recentGames = games;
    } catch (error) {
      if (generation == _recentGamesGeneration) {
        _recentGamesError = error;
      }
    } finally {
      if (generation == _recentGamesGeneration) {
        _recentGamesBusy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> runAccountAction({
    required Future<void> Function() action,
    required String successMessage,
    required String Function(Object) errorMessage,
  }) async {
    if (busy) return false;
    busy = true;
    message = null;
    messageIsError = false;
    notifyListeners();
    try {
      await action();
      message = successMessage;
      return true;
    } catch (error) {
      message = errorMessage(error);
      messageIsError = true;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> fetchFullGameEntitlement() =>
      _remoteConnection.fetchFullGameEntitlement();

  Future<bool> claimFullGamePurchase({
    required String provider,
    required String verificationData,
  }) => _remoteConnection.claimFullGamePurchase(
    provider: provider,
    verificationData: verificationData,
  );

  Future<void> deleteRemoteAccount() => _remoteConnection.deleteAccount();

  Future<List<OnlineComradeProfile>> fetchLeaderboard() =>
      _remoteConnection.fetchLeaderboard();

  Future<OnlineGameReplay> fetchReplay(String sessionID) =>
      _remoteConnection.fetchReplay(sessionID);

  Future<OnlineComradeProfile> fetchPublicProfile(String userID) =>
      _remoteConnection.fetchPublicProfile(userID);

  Future<OnlineComradesResponse> fetchComrades() =>
      _remoteConnection.fetchComrades();

  Future<OnlineComradeProfile> sendComradeRequest(String comradeCode) async {
    final profile = await _remoteConnection.sendComradeRequest(comradeCode);
    await refreshComrades();
    return profile;
  }

  Future<OnlineComradeProfile> sendComradeRequestToUser(String userID) async {
    final profile = await _remoteConnection.sendComradeRequestToUser(userID);
    await refreshComrades();
    return profile;
  }

  Future<void> respondToComradeRequest({
    required String userID,
    required bool accept,
  }) async {
    await _remoteConnection.respondToComradeRequest(
      userID: userID,
      accept: accept,
    );
    await refreshComrades();
  }

  Future<void> removeComrade(String userID) async {
    await _remoteConnection.removeComrade(userID);
    await refreshComrades();
  }

  void updateDisplayName(String displayName) =>
      _identity.updateDisplayName(displayName);

  Future<void> clearIdentity() => _identity.clear();

  void _handleIdentityChanged() => notifyListeners();

  @override
  void dispose() {
    _profileSaveTimer?.cancel();
    _identity.removeListener(_handleIdentityChanged);
    super.dispose();
  }
}
