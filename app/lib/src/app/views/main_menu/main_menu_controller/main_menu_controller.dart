import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';

class MainMenuController extends ChangeNotifier {
  MainMenuController(
    this._connection,
    this._signedIn,
    this._activeSessionID, {
    this.invitePollInterval = const Duration(seconds: 5),
    this.browserRefreshInterval = const Duration(seconds: 15),
  });

  final MenuRemoteConnection _connection;
  final bool Function() _signedIn;
  final String? Function() _activeSessionID;
  final Duration invitePollInterval;
  final Duration browserRefreshInterval;

  final Set<String> _dismissedInviteSessionIDs = {};
  Timer? _inviteTimer;
  Timer? _browserTimer;
  bool _invitePollBusy = false;
  bool _disposed = false;
  OnlineSessionInvite? _pendingInvite;
  bool _browserBusy = false;
  Object? _browserError;
  List<OnlineSessionListing> _openSessions = const [];
  int? _citizensOnline;
  OnlineWeeklyTournament? _weeklyTournament;
  int _secondsUntilBrowserRefresh = 15;

  OnlineSessionInvite? get pendingInvite => _pendingInvite;
  bool get invitePolling => _inviteTimer != null;
  bool get browserBusy => _browserBusy;
  Object? get browserError => _browserError;
  List<OnlineSessionListing> get openSessions =>
      List.unmodifiable(_openSessions);
  int? get citizensOnline => _citizensOnline;
  OnlineWeeklyTournament? get weeklyTournament => _weeklyTournament;
  int get secondsUntilBrowserRefresh => _secondsUntilBrowserRefresh;

  void startBrowserRefresh() {
    if (_disposed || _browserTimer != null) return;
    _secondsUntilBrowserRefresh = browserRefreshInterval.inSeconds;
    unawaited(refreshBrowser());
    _browserTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsUntilBrowserRefresh <= 1) {
        _secondsUntilBrowserRefresh = browserRefreshInterval.inSeconds;
        unawaited(refreshBrowser());
      } else {
        _secondsUntilBrowserRefresh -= 1;
      }
      notifyListeners();
    });
  }

  void stopBrowserRefresh() {
    _browserTimer?.cancel();
    _browserTimer = null;
  }

  Future<void> refreshBrowser() async {
    if (_disposed || _browserBusy) return;
    _browserBusy = true;
    _browserError = null;
    notifyListeners();
    try {
      final sessions = [...await _connection.fetchSessions()];
      try {
        sessions.addAll(await _connection.fetchWatchableSessions());
      } catch (_) {
        // Older servers can still provide the joinable-session browser.
      }
      var nextCitizensOnline = sessions.fold<int>(
        0,
        (total, session) => total + session.connectedHumanSeatCount,
      );
      try {
        _weeklyTournament = await _connection.fetchWeeklyTournament();
      } catch (_) {
        // Tournament rollout is additive to the normal session browser.
      }
      try {
        nextCitizensOnline =
            (await _connection.fetchServerStatus()).citizensOnline;
      } catch (_) {
        // The session list provides a usable population fallback.
      }
      _openSessions = sessions;
      _citizensOnline = nextCitizensOnline;
      _secondsUntilBrowserRefresh = browserRefreshInterval.inSeconds;
    } catch (error) {
      _browserError = error;
    } finally {
      _browserBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> joinWeeklyTournament() async {
    _weeklyTournament = await _connection.joinWeeklyTournament();
    notifyListeners();
  }

  Future<void> leaveWeeklyTournament() async {
    _weeklyTournament = await _connection.leaveWeeklyTournament();
    notifyListeners();
  }

  void startInvitePolling() {
    if (_disposed || _inviteTimer != null) return;
    unawaited(pollInvites());
    _inviteTimer = Timer.periodic(
      invitePollInterval,
      (_) => unawaited(pollInvites()),
    );
  }

  void stopInvitePolling() {
    _inviteTimer?.cancel();
    _inviteTimer = null;
  }

  Future<void> pollInvites() async {
    if (_disposed ||
        _invitePollBusy ||
        !_signedIn() ||
        _activeSessionID() != null ||
        _pendingInvite != null) {
      return;
    }
    _invitePollBusy = true;
    try {
      final invites = await _connection.fetchSessionInvites();
      if (_disposed) return;
      for (final invite in invites) {
        if (!_dismissedInviteSessionIDs.contains(invite.sessionID)) {
          _pendingInvite = invite;
          notifyListeners();
          break;
        }
      }
    } catch (_) {
      // Polling is best effort; explicit menu actions surface their own errors.
    } finally {
      _invitePollBusy = false;
    }
  }

  void acceptPendingInvite(String sessionID) {
    if (_pendingInvite?.sessionID != sessionID) return;
    _pendingInvite = null;
    notifyListeners();
  }

  void dismissPendingInvite(String sessionID) {
    if (_pendingInvite?.sessionID == sessionID) {
      _pendingInvite = null;
    }
    _dismissedInviteSessionIDs.add(sessionID);
    notifyListeners();
    unawaited(_declineInvite(sessionID));
  }

  Future<void> _declineInvite(String sessionID) async {
    try {
      await _connection.declineSessionInvite(sessionID);
    } catch (_) {
      // The invitation remains dismissed locally if the server is unavailable.
    }
  }

  void resetInvites() {
    _pendingInvite = null;
    _dismissedInviteSessionIDs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stopInvitePolling();
    stopBrowserRefresh();
    super.dispose();
  }
}
