import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_error.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_profile.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import '../main_menu_view.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_lobby_projection.dart';

class JoinGameView extends StatefulWidget {
  const JoinGameView({
    super.key,
    required this.tokens,
    required this.language,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.gameLobby,
    required this.showHostedInviteCode,
    required this.onJoinOnline,
    required this.onWatchOnline,
    required this.onMatchmakeOnline,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onSyncActiveSession,
    required this.onCancelOnlineGame,
    required this.comradesSummary,
    required this.onComradeRequestToUser,
    required this.mainMenuController,
    required this.profileController,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final GameLobby? gameLobby;
  final bool showHostedInviteCode;
  final OnlineComradesResponse comradesSummary;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final MainMenuController? mainMenuController;
  final ProfileController? profileController;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final Future<void> Function(Uri baseURL, String sessionID)? onWatchOnline;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final Future<void> Function() onSyncActiveSession;
  final VoidCallback? onCancelOnlineGame;

  @override
  State<JoinGameView> createState() => _OnlinePanelState();
}

class _OnlinePanelState extends State<JoinGameView> {
  late final TextEditingController inviteController;
  bool busy = false;
  String? status;
  bool statusIsError = false;
  bool statusDisablesAction = false;
  String? selectedSessionID;
  Object? handledBrowserError;

  MainMenuController? get mainMenuController => widget.mainMenuController;
  List<OnlineSessionListing> get openSessions =>
      mainMenuController?.openSessions ?? const [];
  int? get citizensOnline => mainMenuController?.citizensOnline;
  int get secondsUntilBrowserRefresh =>
      mainMenuController?.secondsUntilBrowserRefresh ?? 0;
  OnlineWeeklyTournament? get weeklyTournament =>
      mainMenuController?.weeklyTournament;
  OnlineComradesResponse get comrades =>
      widget.profileController?.comrades ?? widget.comradesSummary;
  String? get currentUserID => comrades.userID;
  Set<String> get comradeUserIDs => comrades.userIDs;
  Set<String> get incomingComradeRequestUserIDs => {
    for (final request in comrades.incomingRequests) request.userID,
  };
  Set<String> get outgoingComradeRequestUserIDs => {
    for (final request in comrades.outgoingRequests) request.userID,
  };

  void setStatus(String? message) {
    status = message;
    statusIsError = false;
    statusDisablesAction = false;
  }

  void setFailure(Object exception) {
    status = onlineFailureStatusMessage(exception, widget.language);
    statusIsError = true;
    statusDisablesAction = onlineFailureLocksOnlinePlay(exception);
    if (statusDisablesAction) {
      selectedSessionID = null;
    }
  }

  Future<void> copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      setStatus(widget.language.strings.kolkhozappCopied);
    });
  }

  @override
  void initState() {
    super.initState();
    inviteController = TextEditingController();
    inviteController.addListener(_handleInviteCodeChanged);
    mainMenuController?.addListener(_handleMainMenuChanged);
    widget.profileController?.addListener(_handleProfileChanged);
    mainMenuController?.startBrowserRefresh();
    unawaited(loadComrades());
  }

  @override
  void dispose() {
    mainMenuController?.removeListener(_handleMainMenuChanged);
    widget.profileController?.removeListener(_handleProfileChanged);
    mainMenuController?.stopBrowserRefresh();
    inviteController.removeListener(_handleInviteCodeChanged);
    inviteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JoinGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mainMenuController != widget.mainMenuController) {
      oldWidget.mainMenuController?.removeListener(_handleMainMenuChanged);
      oldWidget.mainMenuController?.stopBrowserRefresh();
      mainMenuController?.addListener(_handleMainMenuChanged);
      mainMenuController?.startBrowserRefresh();
    }
    if (oldWidget.profileController != widget.profileController) {
      oldWidget.profileController?.removeListener(_handleProfileChanged);
      widget.profileController?.addListener(_handleProfileChanged);
      unawaited(loadComrades());
    }
  }

  void _handleProfileChanged() {
    if (mounted) setState(() {});
  }

  void _handleInviteCodeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleMainMenuChanged() {
    if (!mounted) return;
    final browserError = mainMenuController?.browserError;
    setState(() {
      if (browserError != null && browserError != handledBrowserError) {
        handledBrowserError = browserError;
        setFailure(browserError);
      } else if (browserError == null && handledBrowserError != null) {
        handledBrowserError = null;
        setStatus(null);
      }
      if (!_sessionStillOpen(selectedSessionID, openSessions)) {
        selectedSessionID = null;
      }
    });
  }

  Future<void> refreshSessions() async {
    unawaited(loadComrades());
    await mainMenuController?.refreshBrowser();
  }

  Future<void> joinSession(OnlineSessionListing session) async {
    await runOnlineAction(() async {
      if (session.started) {
        await widget.onWatchOnline?.call(onlineServerURL, session.sessionID);
        setStatus('WATCHING ${session.shortID}');
        return;
      }
      final seat = session.openSeats.isEmpty ? null : session.openSeats.first;
      await widget.onJoinOnline(onlineServerURL, session.sessionID, seat);
      setStatus(
        widget.language.strings.kolkhozappJoinedValue1(value1: session.shortID),
      );
    });
  }

  OnlineSessionListing? get selectedSession {
    final id = selectedSessionID;
    if (id == null) {
      return null;
    }
    for (final session in filteredSessions) {
      if (session.sessionID == id) {
        return session;
      }
    }
    return null;
  }

  Future<void> loadComrades() async {
    await widget.profileController?.refreshComrades();
  }

  void selectSession(OnlineSessionListing session) {
    setState(() {
      selectedSessionID = selectedSessionID == session.sessionID
          ? null
          : session.sessionID;
    });
  }

  Future<void> sendComradeRequestToUser(String userID) async {
    if (widget.onComradeRequestToUser == null) {
      return;
    }
    await runOnlineAction(() async {
      await widget.onComradeRequestToUser!(userID);
      setStatus(widget.language.strings.kolkhozappComradeRequestSent);
    });
  }

  List<OnlineSessionListing> get filteredSessions => openSessions;

  bool _sessionStillOpen(
    String? sessionID,
    List<OnlineSessionListing> sessions,
  ) {
    if (sessionID == null) {
      return false;
    }
    return sessions.any((session) => session.sessionID == sessionID);
  }

  Future<void> join() async {
    await runOnlineAction(() async {
      await widget.onJoinOnline(
        onlineServerURL,
        inviteController.text.trim(),
        null,
      );
      setStatus(
        widget.language.strings.kolkhozappJoinedValue1(
          value1: inviteController.text.trim(),
        ),
      );
    });
  }

  Future<void> matchmake() async {
    if (widget.onMatchmakeOnline == null) {
      await join();
      return;
    }
    await runOnlineAction(() async {
      final inviteCode = await widget.onMatchmakeOnline!(
        onlineServerURL,
        true,
        false,
      );
      setStatus(
        widget.language.strings.kolkhozappJoinedValue1(value1: inviteCode),
      );
    });
  }

  Future<void> assignGame() async {
    if (inviteController.text.trim().isNotEmpty) {
      await join();
      return;
    }
    await matchmake();
  }

  Future<void> joinWeeklyTournament() async {
    await runOnlineAction(() async {
      await mainMenuController!.joinWeeklyTournament();
      setStatus('YOU ARE ENTERED IN THE WEEKLY TOURNAMENT');
    });
  }

  Future<void> leaveWeeklyTournament() async {
    await runOnlineAction(() async {
      final forfeiting = weeklyTournament?.status == 'playing';
      await mainMenuController!.leaveWeeklyTournament();
      setStatus(
        forfeiting
            ? 'TOURNAMENT ENTRY FORFEITED'
            : 'TOURNAMENT ENTRY WITHDRAWN',
      );
    });
  }

  Future<void> enterTournamentRound() async {
    await runOnlineAction(() async {
      await widget.onSyncActiveSession();
      setStatus('TOURNAMENT TABLE READY');
    });
  }

  Future<void> runOnlineAction(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      setStatus(null);
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          setFailure(exception);
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = this.busy || (mainMenuController?.browserBusy ?? false);
    final onlineUpdate = widget.onlineSessionUpdate;
    if (onlineUpdate != null) {
      return OnlineWaitingRoomPanel(
        tokens: widget.tokens,
        language: widget.language,
        update: onlineUpdate,
        lobby:
            widget.gameLobby ??
            gameLobbyFromOnlineUpdate(
              onlineUpdate,
              viewerSeatID: onlineUpdate.viewerID,
            ),
        inviteCode: widget.showHostedInviteCode
            ? widget.hostedInviteCode
            : null,
        onCopyInviteCode: widget.hostedInviteCode == null
            ? null
            : () => copyInviteCode(widget.hostedInviteCode!),
        currentUserID: currentUserID,
        comradeUserIDs: comradeUserIDs,
        incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
        outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
        onComradeRequestToUser: sendComradeRequestToUser,
        canKickPlayers: widget.showHostedInviteCode && !onlineUpdate.started,
        onKickPlayer: widget.onKickOnlinePlayer,
        onEnterOnlineGame: widget.onEnterOnlineGame,
        onCancelOnlineGame: widget.onCancelOnlineGame,
      );
    }
    final visibleSessions = filteredSessions;
    final selected = selectedSession;
    final hasInviteCode = inviteController.text.trim().isNotEmpty;
    final joinsExistingGame = selected != null || hasInviteCode;
    final browserHiddenByBan = statusDisablesAction;
    final buttonShowsBan =
        status != null && statusDisablesAction && !hasInviteCode;
    final citizensOnlineMessage = citizensOnline == null
        ? null
        : widget.language.strings.kolkhozappValue1CitizensOnline(
            value1: citizensOnline!,
          );
    final refreshMessage = widget.language.strings.kolkhozappRefreshInValue1s(
      value1: secondsUntilBrowserRefresh,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            const MainMenuAssetIcon(
              'assets/ui/Icons/icon-online.png',
              size: 26,
            ),
            Text(
              widget.language.strings.kolkhozappJoinGame,
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                widget
                    .language
                    .strings
                    .kolkhozappJoinAnOpenGameOrEnterAnInviteCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.creamDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!browserHiddenByBan)
              Expanded(
                child: _OnlineBrowserFooter(
                  tokens: widget.tokens,
                  citizensOnlineMessage: citizensOnlineMessage,
                  refreshMessage: refreshMessage,
                ),
              ),
          ],
        ),
        if (widget.hostedInviteCode != null)
          _HostedInviteCodeCard(
            tokens: widget.tokens,
            language: widget.language,
            inviteCode: widget.hostedInviteCode!,
            onCopy: () => copyInviteCode(widget.hostedInviteCode!),
          ),
        if (weeklyTournament case final tournament?)
          _WeeklyTournamentCard(
            tokens: widget.tokens,
            tournament: tournament,
            busy: busy,
            onJoin: joinWeeklyTournament,
            onLeave: leaveWeeklyTournament,
            onEnterRound: enterTournamentRound,
          ),
        if (browserHiddenByBan)
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: OnlineStatusBanner(
                tokens: widget.tokens,
                message: status!,
                isError: true,
              ),
            ),
          )
        else ...[
          Expanded(
            child: _OpenSessionsList(
              tokens: widget.tokens,
              language: widget.language,
              sessions: visibleSessions,
              selectedSessionID: selectedSessionID,
              currentUserID: currentUserID,
              comradeUserIDs: comradeUserIDs,
              incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
              onSelected: selectSession,
              onComradeRequestToUser: sendComradeRequestToUser,
            ),
          ),
        ],
        if (status != null && (!statusIsError || !statusDisablesAction))
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: status!,
            isError: statusIsError,
          ),
        SizedBox(
          height: 44,
          child: Row(
            spacing: 10,
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child: ChromeAssetButton.command(
                  label: widget.language.strings.kolkhozappRefresh,
                  prominent: false,
                  tokens: widget.tokens,
                  iconAsset: 'assets/ui/Icons/icon-status-connecting.png',
                  onPressed: busy ? null : refreshSessions,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.tokens.colors.black.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: widget.tokens.colors.steel.withValues(alpha: 0.34),
                    ),
                  ),
                  child: TextField(
                    controller: inviteController,
                    minLines: 1,
                    maxLines: 1,
                    style: kolkhozFontStyle.copyWith(
                      color: widget.tokens.colors.cream,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.language.strings.kolkhozappInviteCode,
                      labelStyle: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.creamDim.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                height: double.infinity,
                child: Opacity(
                  opacity: busy ? 0.55 : 1,
                  child: ChromeAssetButton.command(
                    label: buttonShowsBan
                        ? status!
                        : busy
                        ? widget.language.strings.kolkhozappWorking
                        : joinsExistingGame
                        ? selected?.started == true
                              ? 'WATCH GAME'
                              : widget.language.strings.kolkhozappJoinGame
                        : widget.language.strings.kolkhozappAssignGame,
                    prominent: true,
                    tokens: widget.tokens,
                    iconAsset: buttonShowsBan
                        ? 'assets/ui/Icons/icon-warning.png'
                        : 'assets/ui/Icons/icon-join-game.png',
                    expandLabel: false,
                    onPressed: busy || buttonShowsBan
                        ? null
                        : hasInviteCode || selected == null
                        ? assignGame
                        : () => joinSession(selected),
                    enabled: !buttonShowsBan,
                    disabledOpacity: 0.72,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedEllipsisLabel extends StatefulWidget {
  const _AnimatedEllipsisLabel({required this.label, required this.builder});

  final String label;
  final Widget Function(String label) builder;

  @override
  State<_AnimatedEllipsisLabel> createState() => _AnimatedEllipsisLabelState();
}

class _AnimatedEllipsisLabelState extends State<_AnimatedEllipsisLabel> {
  Timer? timer;
  int dotCount = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) {
        return;
      }
      setState(() => dotCount = (dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.filled(dotCount, '.').join();
    return widget.builder('${widget.label}$dots');
  }
}

class OnlineWaitingRoomPanel extends StatelessWidget {
  const OnlineWaitingRoomPanel({
    super.key,
    required this.tokens,
    required this.language,
    required this.update,
    required this.lobby,
    required this.inviteCode,
    required this.onCopyInviteCode,
    this.showHeaderCancel = true,
    this.showInviteCard = true,
    this.showJoinButton = true,
    this.showDetails = true,
    this.currentUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    required this.canKickPlayers,
    required this.onKickPlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionUpdate update;
  final GameLobby lobby;
  final String? inviteCode;
  final VoidCallback? onCopyInviteCode;
  final bool showHeaderCancel;
  final bool showInviteCard;
  final bool showJoinButton;
  final bool showDetails;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final bool canKickPlayers;
  final Future<void> Function(int playerID)? onKickPlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;

  @override
  Widget build(BuildContext context) {
    final countdownSeconds = update.lobbyCountdownSeconds;
    final status = update.started
        ? language.strings.kolkhozappJoinGame
        : countdownSeconds != null
        ? language.strings.kolkhozappGameStartsInValue1s(
            value1: countdownSeconds,
          )
        : language.strings.kolkhozappWaitingForPlayers;
    final subtitle =
        '${lobby.seats.where((seat) => seat.ready).length}/${lobby.seats.length} '
        '${language.strings.kolkhozappSeats}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        if (showHeaderCancel)
          Row(
            spacing: 8,
            children: [
              if (showHeaderCancel && onCancelOnlineGame != null)
                Tooltip(
                  message: language.strings.kolkhozappCancel,
                  child: Semantics(
                    button: true,
                    label: language.strings.kolkhozappCancel,
                    child: GestureDetector(
                      key: const Key('online-waiting-cancel'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onCancelOnlineGame,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.colors.black.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: tokens.colors.gold.withValues(alpha: 0.48),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: tokens.colors.cream,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              const MainMenuAssetIcon(
                'assets/ui/Icons/icon-status-connected.png',
                size: 26,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.gold,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.creamDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (showInviteCard && inviteCode != null && onCopyInviteCode != null)
          _HostedInviteCodeCard(
            tokens: tokens,
            language: language,
            inviteCode: inviteCode!,
            onCopy: onCopyInviteCode!,
          ),
        if (showDetails)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappGameType,
                value: update.ranked
                    ? language.strings.kolkhozappRanked
                    : language.strings.kolkhozappCasual,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappSeats,
                value:
                    '${lobby.seats.where((seat) => seat.ready).length}/${lobby.seats.length}',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappMoves,
                value: '${update.actionLogCount}',
              ),
            ],
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 430
                  ? (constraints.maxWidth - 24) / 4
                  : constraints.maxWidth;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final seat in lobby.seats)
                      SizedBox(
                        width: cardWidth,
                        child: _OnlineWaitingRoomSeatCard(
                          tokens: tokens,
                          language: language,
                          seat: seat,
                          ranked: update.ranked,
                          currentUserID: currentUserID,
                          comradeUserIDs: comradeUserIDs,
                          incomingComradeRequestUserIDs:
                              incomingComradeRequestUserIDs,
                          outgoingComradeRequestUserIDs:
                              outgoingComradeRequestUserIDs,
                          onComradeRequestToUser: onComradeRequestToUser,
                          canKick:
                              canKickPlayers &&
                              seat.player.controller ==
                                  KolkhozPlayerController.human &&
                              seat.profile != null &&
                              !seat.isViewer &&
                              onKickPlayer != null,
                          onKick: onKickPlayer == null
                              ? null
                              : () => onKickPlayer!(seat.seatID),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (showJoinButton)
          WaitingRoomEnterButton(
            tokens: tokens,
            language: language,
            tableReady: update.started,
            waitingLabel: status,
            height: 46,
            onPressed: onEnterOnlineGame,
          ),
      ],
    );
  }
}

class WaitingRoomEnterButton extends StatelessWidget {
  const WaitingRoomEnterButton({
    super.key,
    required this.tokens,
    required this.language,
    required this.tableReady,
    required this.waitingLabel,
    required this.height,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool tableReady;
  final String waitingLabel;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (tableReady) {
      return SizedBox(
        key: const Key('waiting-room-enter-game'),
        width: double.infinity,
        height: height,
        child: ChromeAssetButton.command(
          label: language.strings.kolkhozappJoinGame,
          prominent: true,
          tokens: tokens,
          iconAsset: 'assets/ui/Icons/icon-join-game.png',
          expandLabel: false,
          onPressed: onPressed,
        ),
      );
    }
    return Semantics(
      key: const Key('waiting-room-countdown'),
      button: true,
      enabled: false,
      label: waitingLabel,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.86,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: ChromeButtonBackground(
                    asset: chromeButtonPrimaryAsset,
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        const MainMenuAssetIcon(
                          'assets/ui/Icons/icon-status-connecting.png',
                          size: 22,
                        ),
                        Flexible(
                          child: _AnimatedEllipsisLabel(
                            label: waitingLabel,
                            builder: (label) => ChromeScaledLabel(
                              label,
                              color: tokens.colors.onAccent,
                              size: PixelTextSize.headline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineWaitingRoomSeatCard extends StatelessWidget {
  const _OnlineWaitingRoomSeatCard({
    required this.tokens,
    required this.language,
    required this.seat,
    required this.ranked,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
    required this.canKick,
    required this.onKick,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final GameSeat seat;
  final bool ranked;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final bool canKick;
  final VoidCallback? onKick;

  KolkhozPlayerController get controller => seat.player.controller;
  PlayerProfile? get profile => seat.profile;

  @override
  Widget build(BuildContext context) {
    final playerID = seat.seatID;
    final controller = seat.player.controller;
    final profile = seat.profile;
    final presence = seat.presence;
    final open = controller == KolkhozPlayerController.human && profile == null;
    final name = _seatName(open);
    final portraitAsset = profile?.portraitAsset ?? 'worker${playerID + 1}';
    final connected = presence?.connected ?? profile != null;
    return PlayerProfileBadge(
      tokens: tokens,
      displayName: name,
      portraitAsset: portraitAsset,
      portraitSemanticsLabel: profile == null ? null : '$name profile',
      onPortraitPressed: profile == null
          ? null
          : () => _showLobbyPlayerProfile(
              context: context,
              tokens: tokens,
              language: language,
              profile: profile,
              currentUserID: currentUserID,
              comradeUserIDs: comradeUserIDs,
              incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
              onComradeRequestToUser: onComradeRequestToUser,
            ),
      seatLabel: language.strings.kolkhozappPValue1(value1: playerID + 1),
      subtitle: _seatStatus(open, connected),
      title: open
          ? _AnimatedEllipsisLabel(
              label: language.strings.kolkhozappSearchingForPlayer,
              builder: (label) => Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.creamDim.withValues(alpha: 0.74),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            )
          : null,
      portraitSize: 48,
      minHeight: 92,
      active: seat.isViewer,
      muted: open,
      action: canKick
          ? PlayerProfileAction(
              label: language.strings.kolkhozappKick,
              iconAsset: 'assets/ui/Icons/icon-warning.png',
              onPressed: onKick,
              textSize: PixelTextSize.caption2,
            )
          : null,
    );
  }

  String _seatName(bool open) {
    final trimmed = profile?.displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    if (open) {
      return language.strings.kolkhozappOpen;
    }
    return language.strings.kolkhozappHuman;
  }

  String _seatStatus(bool open, bool connected) {
    if (open) {
      return language.strings.kolkhozappWaiting;
    }
    if (profile != null) {
      return '${language.strings.kolkhozappRating} '
          '${profile!.stats.ratingForGameType(ranked: ranked)}';
    }
    return connected
        ? controller.shortTitle(language)
        : language.strings.kolkhozappWaiting;
  }
}

Future<void> _showLobbyPlayerProfile({
  required BuildContext context,
  required DesignTokens tokens,
  required KolkhozLanguage language,
  required PlayerProfile profile,
  String? currentUserID,
  Set<String> comradeUserIDs = const {},
  Set<String> incomingComradeRequestUserIDs = const {},
  Set<String> outgoingComradeRequestUserIDs = const {},
  Future<void> Function(String userID)? onComradeRequestToUser,
}) {
  final displayName = profile.displayName?.trim();
  final userID = profile.userID;
  final canManageRelationship =
      userID != null &&
      userID != currentUserID &&
      onComradeRequestToUser != null;
  final isComrade = userID != null && comradeUserIDs.contains(userID);
  final hasIncomingRequest =
      userID != null && incomingComradeRequestUserIDs.contains(userID);
  final hasOutgoingRequest =
      userID != null && outgoingComradeRequestUserIDs.contains(userID);
  final relationshipLabel = isComrade
      ? language.strings.kolkhozappComrade
      : hasOutgoingRequest
      ? language.strings.kolkhozappPending
      : language.strings.kolkhozappNotComrade;
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: tokens.colors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ExpandedPlayerProfile(
            key: Key('lobby-player-profile-${profile.seatID}'),
            tokens: tokens,
            displayName: displayName == null || displayName.isEmpty
                ? language.strings.kolkhozappHuman
                : displayName,
            portraitAsset: profile.portraitAsset ?? defaultProfilePortraitAsset,
            subtitle: language.strings.kolkhozappPlayer,
            statGroups: kolkhozProfileStatGroups(
              stats: profile.stats,
              language: language,
            ),
            chips: canManageRelationship
                ? [
                    PlayerProfileChip(
                      label: relationshipLabel,
                      active: isComrade,
                    ),
                  ]
                : const [],
            action: canManageRelationship && !isComrade && !hasOutgoingRequest
                ? PlayerProfileAction(
                    label: language.t(
                      hasIncomingRequest
                          ? KolkhozText.kolkhozappAccept
                          : KolkhozText.kolkhozappAddComrade,
                    ),
                    iconAsset: 'assets/ui/Icons/icon-add-friend.png',
                    prominent: hasIncomingRequest,
                    onPressed: () => unawaited(onComradeRequestToUser(userID)),
                  )
                : null,
            footer: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String onlineFailureStatusMessage(Object exception, KolkhozLanguage language) {
  if (exception is SocketException) {
    return language
        .strings
        .kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom;
  }
  if (exception is RemoteRequestException) {
    return onlineFailureMessageFromServerError(
      exception.message,
      language,
      sentAuthorization: exception.sentAuthorization,
    );
  }
  if (exception is RemoteRequestException) {
    return onlineFailureMessageFromServerError(
      exception.message,
      language,
      sentAuthorization: exception.sentAuthorization,
    );
  }
  if (exception is HttpException) {
    return onlineFailureMessageFromServerError(exception.message, language);
  }
  return language.strings.kolkhozappOnlineRequestFailedTryAgain;
}

bool onlineFailureLocksOnlinePlay(Object exception) {
  if (exception is RemoteRequestException) {
    return _messageIsOnlineBan(exception.message);
  }
  if (exception is RemoteRequestException) {
    return _messageIsOnlineBan(exception.message);
  }
  if (exception is HttpException) {
    return _messageIsOnlineBan(exception.message);
  }
  return _messageIsOnlineBan('$exception');
}

bool _messageIsOnlineBan(String message) {
  return message.toLowerCase().contains('sent north');
}

String onlineFailureMessageFromServerError(
  String message,
  KolkhozLanguage language, {
  bool? sentAuthorization,
}) {
  final normalized = message.toLowerCase();
  if (normalized.contains('sent north')) {
    return language.strings.kolkhozappSentNorthOnlinePlayIsLockedForThisAccount;
  }
  if (normalized.contains('missing auth token')) {
    return sentAuthorization == true
        ? language.strings.kolkhozappCouldNotVerifyOnlineAccountTryAgain
        : language.strings.kolkhozappSignInBeforeJoiningOnlinePlay;
  }
  if (normalized.contains('invalid auth token')) {
    return language.strings.kolkhozappOnlineSignInExpiredSignInAgain;
  }
  if (normalized.contains('no open games')) {
    return language.strings.kolkhozappNoOpenGames;
  }
  final detail = onlineServerErrorDetail(message);
  if (detail == null) {
    return language.strings.kolkhozappTheOnlineServerRejectedTheRequest;
  }
  return '${language.strings.kolkhozappTheOnlineServerRejectedTheRequest} '
      '$detail';
}

String? onlineServerErrorDetail(String message) {
  try {
    final decoded = jsonDecode(message);
    if (decoded is Map<String, Object?>) {
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
    }
  } catch (_) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed == 'Online request failed') {
      return null;
    }
    return trimmed;
  }
  return null;
}

final Uri onlineServerURL = Uri.parse(
  'https://online.kolkhoz.williamtheisen.com',
);

class _WeeklyTournamentCard extends StatelessWidget {
  const _WeeklyTournamentCard({
    required this.tokens,
    required this.tournament,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onEnterRound,
  });

  final DesignTokens tokens;
  final OnlineWeeklyTournament tournament;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onEnterRound;

  String _timeLabel(BuildContext context) {
    final seconds = tournament.startsAt;
    if (seconds == null) {
      return 'SCHEDULE PENDING';
    }
    final date = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return '${_weekday(date.weekday)} $time';
  }

  String _statusLabel(BuildContext context) {
    if (tournament.forfeited) {
      return 'FORFEITED • PROFILE BOT CONTINUES';
    }
    if (tournament.status == 'playing') {
      final table = tournament.table;
      return table == null
          ? 'ROUND ${tournament.roundNumber} • WAITING FOR TABLES'
          : 'ROUND ${tournament.roundNumber} OF ${tournament.totalRounds} • TABLE ${table.tableNumber}';
    }
    if (tournament.status == 'completed') {
      return 'TOURNAMENT COMPLETE';
    }
    if (tournament.enrollmentOpen) {
      return tournament.joined
          ? 'ENTRY CONFIRMED • ${tournament.entrantCount} PLAYERS'
          : 'JOIN WINDOW OPEN • ${tournament.entrantCount} ENTERED';
    }
    return 'ENROLLMENT OPENS 30 MINUTES BEFORE START';
  }

  static String _weekday(int weekday) => const {
    DateTime.monday: 'MON',
    DateTime.tuesday: 'TUE',
    DateTime.wednesday: 'WED',
    DateTime.thursday: 'THU',
    DateTime.friday: 'FRI',
    DateTime.saturday: 'SAT',
    DateTime.sunday: 'SUN',
  }[weekday]!;

  @override
  Widget build(BuildContext context) {
    final tableReady =
        tournament.joined && tournament.table?.status == 'active';
    final canJoin = tournament.enrollmentOpen && !tournament.joined;
    final canLeave = tournament.joined && tournament.status != 'completed';
    final leaders = tournament.standings.take(4).toList();
    final label = tableReady
        ? 'ENTER ROUND'
        : canJoin
        ? 'JOIN TOURNAMENT'
        : canLeave
        ? tournament.status == 'playing'
              ? 'FORFEIT'
              : 'LEAVE'
        : tournament.status == 'completed'
        ? 'FINAL'
        : 'WEEKLY';
    final action = tableReady
        ? onEnterRound
        : canJoin
        ? onJoin
        : canLeave
        ? onLeave
        : null;
    return Container(
      key: const ValueKey('weekly-tournament-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: tokens.colors.redDark.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          MainMenuAssetIcon('assets/ui/Icons/icon-medal-star.png', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'WEEKLY KOLKHOZ TOURNAMENT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kolkhozFontStyle.copyWith(
                          color: tokens.colors.goldBright,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(context),
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (leaders.isNotEmpty &&
                    tournament.status != 'enrollment') ...[
                  const SizedBox(height: 4),
                  Text(
                    leaders
                        .map(
                          (value) =>
                              '${value.rank}. ${value.displayName} ${value.points.toStringAsFixed(value.points % 1 == 0 ? 0 : 1)}',
                        )
                        .join('   '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 154,
            height: 38,
            child: ChromeAssetButton.command(
              label: label,
              prominent: tableReady || canJoin,
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-medal-star.png',
              onPressed: busy ? null : action,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostedInviteCodeCard extends StatelessWidget {
  const _HostedInviteCodeCard({
    required this.tokens,
    required this.language,
    required this.inviteCode,
    required this.onCopy,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String inviteCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ChromeButtonBackground(asset: chromeButtonPrimaryAsset),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final codeBlock = Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.black.withValues(alpha: 0.28),
                  border: Border.all(
                    color: tokens.colors.gold.withValues(alpha: 0.72),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  inviteCode,
                  maxLines: 2,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              );
              final copyButton = SizedBox(
                width: compact ? double.infinity : 158,
                height: 44,
                child: ChromeAssetButton.command(
                  label: language.strings.kolkhozappCopyCode,
                  prominent: false,
                  tokens: tokens,
                  onPressed: onCopy,
                  iconAsset: 'assets/ui/Icons/icon-check.png',
                  iconSize: 20,
                  textSize: PixelTextSize.caption,
                  expandLabel: false,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    spacing: 9,
                    children: [
                      const MainMenuAssetIcon(
                        'assets/ui/Icons/icon-online.png',
                        size: 26,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              language.strings.kolkhozappYourInviteCode,
                              style: kolkhozFontStyle.copyWith(
                                color: tokens.colors.onAccent,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              language.strings.kolkhozappWaitingForPlayers,
                              style: kolkhozFontStyle.copyWith(
                                color: tokens.colors.onAccent.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [codeBlock, copyButton],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Expanded(child: codeBlock),
                        copyButton,
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class OnlineStatusBanner extends StatelessWidget {
  const OnlineStatusBanner({
    super.key,
    required this.tokens,
    required this.message,
    required this.isError,
  });

  final DesignTokens tokens;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? tokens.colors.redBright : tokens.colors.creamDim;
    final borderColor = isError
        ? tokens.colors.redBright.withValues(alpha: 0.62)
        : tokens.colors.steel.withValues(alpha: 0.44);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        spacing: 8,
        children: [
          MainMenuAssetIcon(
            isError
                ? 'assets/ui/Icons/icon-warning.png'
                : 'assets/ui/Icons/icon-status-connected.png',
            size: 18,
          ),
          Expanded(
            child: Text(
              message,
              style: kolkhozFontStyle.copyWith(
                color: color,
                fontSize: 13,
                height: 1.12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSessionsList extends StatelessWidget {
  const _OpenSessionsList({
    required this.tokens,
    required this.language,
    required this.sessions,
    required this.selectedSessionID,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onSelected,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineSessionListing> sessions;
  final String? selectedSessionID;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final ValueChanged<OnlineSessionListing> onSelected;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: OpenSessionsChromeSurface(
        padding: const EdgeInsets.all(18),
        child: sessions.isEmpty
            ? Align(
                alignment: Alignment.topLeft,
                child: Text(
                  language.strings.kolkhozappNoOpenGames,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : ClipRect(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 7,
                    children: [
                      for (final session in sessions)
                        _OpenSessionRow(
                          tokens: tokens,
                          language: language,
                          session: session,
                          expanded: selectedSessionID == session.sessionID,
                          onToggle: () => onSelected(session),
                          currentUserID: currentUserID,
                          comradeUserIDs: comradeUserIDs,
                          incomingComradeRequestUserIDs:
                              incomingComradeRequestUserIDs,
                          outgoingComradeRequestUserIDs:
                              outgoingComradeRequestUserIDs,
                          onComradeRequestToUser: onComradeRequestToUser,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class OpenSessionsChromeSurface extends StatelessWidget {
  const OpenSessionsChromeSurface({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ChromeButtonBackground(
            asset: chromeButtonSecondaryAsset,
            maxScale: 0.14,
          ),
        ),
        Positioned.fill(
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

class _OnlineBrowserFooter extends StatelessWidget {
  const _OnlineBrowserFooter({
    required this.tokens,
    required this.citizensOnlineMessage,
    required this.refreshMessage,
  });

  final DesignTokens tokens;
  final String? citizensOnlineMessage;
  final String refreshMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        if (citizensOnlineMessage != null)
          Expanded(
            child: _OnlineBrowserFooterItem(
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-profile.png',
              message: citizensOnlineMessage!,
            ),
          )
        else
          const Spacer(),
        Expanded(
          child: _OnlineBrowserFooterItem(
            tokens: tokens,
            iconAsset: 'assets/ui/Icons/icon-status-connecting.png',
            message: refreshMessage,
            alignment: MainAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

class _OnlineBrowserFooterItem extends StatelessWidget {
  const _OnlineBrowserFooterItem({
    required this.tokens,
    required this.iconAsset,
    required this.message,
    this.alignment = MainAxisAlignment.start,
  });

  final DesignTokens tokens;
  final String iconAsset;
  final String message;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      spacing: 6,
      children: [
        MainMenuAssetIcon(iconAsset, size: 18),
        Flexible(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenSessionRow extends StatelessWidget {
  const _OpenSessionRow({
    required this.tokens,
    required this.language,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionListing session;
  final bool expanded;
  final VoidCallback onToggle;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final openSeats = session.openSeats
        .map((seat) => language.strings.kolkhozappPValue1(value1: seat + 1))
        .join(' ');
    final hostProfile = session.playerProfiles
        .where((profile) => profile.playerID == 0)
        .firstOrNull;
    final hostName = hostProfile?.displayName?.trim();
    final gameType = session.ranked
        ? language.strings.kolkhozappRanked
        : language.strings.kolkhozappCasual;
    final title = hostName == null || hostName.isEmpty ? gameType : hostName;
    final titleColor = expanded
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    final bodyColor = expanded
        ? tokens.colors.activeSurfaceTextMuted
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    final hasComrade = session.playerProfiles.any((profile) {
      final userID = profile.userID;
      return userID != null &&
          userID != currentUserID &&
          comradeUserIDs.contains(userID);
    });
    return Column(
      spacing: 0,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label:
              '$title, '
              '${session.ranked ? language.strings.kolkhozappRanked : language.strings.kolkhozappCasual}'
              '${hasComrade ? ', ${language.strings.kolkhozappComrade}' : ''}',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: VariantRowBackground(
                tokens: tokens,
                active: expanded,
                child: Row(
                  spacing: 10,
                  children: [
                    _OpenSessionBadgeIcon(
                      tokens: tokens,
                      label: session.ranked
                          ? language.strings.kolkhozappRanked
                          : language.strings.kolkhozappCasual,
                      asset: session.ranked
                          ? 'assets/ui/Icons/icon-medal-star.png'
                          : 'assets/ui/Icons/icon-foreman-misha.png',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          VariantPixelLine(
                            height: pixelTextSlotHeight(PixelTextSize.caption),
                            child: PixelText(
                              title,
                              color: titleColor,
                              size: PixelTextSize.caption,
                              variant: PixelTextVariant.heavy,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                          VariantPixelLine(
                            height: pixelTextSlotHeight(PixelTextSize.caption2),
                            child: PixelText(
                              language.strings.kolkhozappOpenOpenseats(
                                openSeats: openSeats,
                              ),
                              color: bodyColor,
                              size: PixelTextSize.caption2,
                              variant: PixelTextVariant.regular,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasComrade)
                      _OpenSessionBadgeIcon(
                        tokens: tokens,
                        label: language.strings.kolkhozappComrade,
                        asset: 'assets/ui/Icons/icon-comrade.png',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          _OpenSessionDetails(
            tokens: tokens,
            language: language,
            session: session,
            hostName: hostName == null || hostName.isEmpty
                ? language.strings.kolkhozappWaiting
                : hostName,
            currentUserID: currentUserID,
            comradeUserIDs: comradeUserIDs,
            incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
            outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
            onComradeRequestToUser: onComradeRequestToUser,
          ),
      ],
    );
  }
}

class _OpenSessionBadgeIcon extends StatelessWidget {
  const _OpenSessionBadgeIcon({
    required this.tokens,
    required this.label,
    required this.asset,
  });

  final DesignTokens tokens;
  final String label;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.black.withValues(alpha: 0.18),
          border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: MainMenuAssetIcon(asset, size: 19),
      ),
    );
  }
}

class _OpenSessionDetails extends StatelessWidget {
  const _OpenSessionDetails({
    required this.tokens,
    required this.language,
    required this.session,
    required this.hostName,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionListing session;
  final String hostName;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final openSeats = _seatList(session.openSeats);
    final occupiedSeats = _seatList(session.occupiedSeats);
    final profilesBySeat = <int, OnlinePlayerProfile>{
      for (final profile in session.playerProfiles) profile.playerID: profile,
    };
    final ratings = [
      for (final seat in session.occupiedSeats)
        profilesBySeat[seat]?.stats.ratingForGameType(ranked: session.ranked) ??
            defaultProfileStats.ratingForGameType(ranked: session.ranked),
    ];
    final averageRating = ratings.isEmpty
        ? language.strings.kolkhozappWaiting
        : (ratings.reduce((left, right) => left + right) / ratings.length)
              .round()
              .toString();
    final turn = session.turnPlayerID == null
        ? language.strings.kolkhozappWaiting
        : language.strings.kolkhozappPValue1(value1: session.turnPlayerID! + 1);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.34),
        border: Border(
          left: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
          right: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
          bottom: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappHost,
                value: hostName,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappSeats,
                value: '$occupiedSeats / $openSeats',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappTurn,
                value: turn,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappMoves,
                value: '${session.actionLogCount}',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappAverageRating,
                value: averageRating,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappGameType,
                value: session.ranked
                    ? language.strings.kolkhozappRanked
                    : language.strings.kolkhozappCasual,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.strings.kolkhozappAccess,
                value: session.browserJoinable
                    ? language.strings.kolkhozappBrowser
                    : language.strings.kolkhozappLocked,
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 660
                  ? (constraints.maxWidth - 24) / 4
                  : constraints.maxWidth >= 420
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < 4; index++)
                    SizedBox(
                      width: cardWidth,
                      child: _OpenSessionPlayerCard(
                        tokens: tokens,
                        language: language,
                        playerID: index,
                        profile: profilesBySeat[index],
                        open: session.openSeats.contains(index),
                        ranked: session.ranked,
                        currentTurn: session.turnPlayerID == index,
                        currentUserID: currentUserID,
                        comradeUserIDs: comradeUserIDs,
                        incomingComradeRequestUserIDs:
                            incomingComradeRequestUserIDs,
                        outgoingComradeRequestUserIDs:
                            outgoingComradeRequestUserIDs,
                        onComradeRequestToUser: onComradeRequestToUser,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _seatList(List<int> seats) {
    if (seats.isEmpty) {
      return language.strings.kolkhozappWaiting;
    }
    return seats
        .map((seat) => language.strings.kolkhozappPValue1(value1: seat + 1))
        .join(' ');
  }
}

class _OpenSessionPlayerCard extends StatelessWidget {
  const _OpenSessionPlayerCard({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.profile,
    required this.open,
    required this.ranked,
    required this.currentTurn,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final OnlinePlayerProfile? profile;
  final bool open;
  final bool ranked;
  final bool currentTurn;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final player = language.strings.kolkhozappPValue1(value1: playerID + 1);
    final name = profile?.displayName?.trim();
    final occupied = !open;
    final displayName = name == null || name.isEmpty
        ? occupied
              ? language.strings.kolkhozappHuman
              : language.strings.kolkhozappOpen
        : name;
    final portraitAsset = profile?.portraitAsset ?? 'worker${playerID + 1}';
    final rating =
        profile?.stats.ratingForGameType(ranked: ranked) ??
        defaultProfileStats.ratingForGameType(ranked: ranked);
    final profileUserID = profile?.userID;
    final showComradeAction =
        occupied &&
        profileUserID != null &&
        profileUserID != currentUserID &&
        onComradeRequestToUser != null;
    final isComrade =
        profileUserID != null && comradeUserIDs.contains(profileUserID);
    final hasIncomingRequest =
        profileUserID != null &&
        incomingComradeRequestUserIDs.contains(profileUserID);
    final hasOutgoingRequest =
        profileUserID != null &&
        outgoingComradeRequestUserIDs.contains(profileUserID);
    final actionLabel = isComrade
        ? language.strings.kolkhozappComrade
        : hasOutgoingRequest
        ? language.strings.kolkhozappPending
        : hasIncomingRequest
        ? language.strings.kolkhozappAccept
        : language.strings.kolkhozappAddComrade;
    final actionIcon = isComrade
        ? 'assets/ui/Icons/icon-comrade.png'
        : hasOutgoingRequest
        ? 'assets/ui/Icons/icon-status-connecting.png'
        : 'assets/ui/Icons/icon-add-friend.png';
    final actionEnabled =
        showComradeAction && !isComrade && !hasOutgoingRequest;
    return PlayerProfileBadge(
      tokens: tokens,
      displayName: displayName,
      portraitAsset: portraitAsset,
      portraitSemanticsLabel: profile == null ? null : '$displayName profile',
      onPortraitPressed: profile == null
          ? null
          : () => _showLobbyPlayerProfile(
              context: context,
              tokens: tokens,
              language: language,
              profile: playerProfileFromOnline(profile!),
              currentUserID: currentUserID,
              comradeUserIDs: comradeUserIDs,
              incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
              onComradeRequestToUser: onComradeRequestToUser,
            ),
      seatLabel: player,
      subtitle: occupied
          ? '${language.strings.kolkhozappRating} $rating'
          : language.strings.kolkhozappOpen,
      subtitleIconAsset: occupied
          ? 'assets/ui/Icons/icon-medal-star.png'
          : 'assets/ui/Icons/icon-human-seat.png',
      portraitSize: 46,
      minHeight: 82,
      active: currentTurn,
      muted: !occupied,
      action: showComradeAction
          ? PlayerProfileAction(
              label: actionLabel,
              iconAsset: actionIcon,
              onPressed: actionEnabled
                  ? () => unawaited(onComradeRequestToUser!(profileUserID))
                  : null,
              prominent: hasIncomingRequest,
              height: 24,
              iconSize: 14,
            )
          : null,
    );
  }
}

class _OpenSessionDetailChip extends StatelessWidget {
  const _OpenSessionDetailChip({
    required this.tokens,
    required this.label,
    required this.value,
  });

  final DesignTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: tokens.colors.gold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
