part of 'kolkhoz_app.dart';

class _OnlinePanel extends StatefulWidget {
  const _OnlinePanel({
    required this.tokens,
    required this.language,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.onJoinOnline,
    required this.onMatchmakeOnline,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
    required this.comradesSummary,
    required this.onComradesChanged,
    required this.onComradeRequestToUser,
    required this.onlineClientFactory,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final OnlineComradesResponse comradesSummary;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final KolkhozOnlineClient Function()? onlineClientFactory;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;

  @override
  State<_OnlinePanel> createState() => _OnlinePanelState();
}

class _OnlinePanelState extends State<_OnlinePanel> {
  static const _browserRefreshInterval = Duration(seconds: 15);

  late final TextEditingController inviteController;
  Timer? browserRefreshTimer;
  int secondsUntilBrowserRefresh = _browserRefreshInterval.inSeconds;
  bool busy = false;
  String? status;
  bool statusIsError = false;
  bool statusDisablesAction = false;
  List<OnlineSessionListing> openSessions = const [];
  int? citizensOnline;
  Set<String> comradeUserIDs = const {};
  Set<String> incomingComradeRequestUserIDs = const {};
  Set<String> outgoingComradeRequestUserIDs = const {};
  String? currentUserID;
  String? selectedSessionID;

  Future<void> copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      status = widget.language.t(KolkhozText.kolkhozappCopied);
      statusIsError = false;
      statusDisablesAction = false;
    });
  }

  @override
  void initState() {
    super.initState();
    inviteController = TextEditingController();
    inviteController.addListener(_handleInviteCodeChanged);
    unawaited(refreshSessions());
    browserRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickBrowserRefresh();
    });
  }

  @override
  void dispose() {
    browserRefreshTimer?.cancel();
    inviteController.removeListener(_handleInviteCodeChanged);
    inviteController.dispose();
    super.dispose();
  }

  void _handleInviteCodeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void tickBrowserRefresh() {
    if (!mounted) {
      return;
    }
    if (secondsUntilBrowserRefresh <= 1) {
      setState(() {
        secondsUntilBrowserRefresh = _browserRefreshInterval.inSeconds;
      });
      unawaited(refreshSessions());
      return;
    }
    setState(() {
      secondsUntilBrowserRefresh -= 1;
    });
  }

  Future<void> refreshSessions() async {
    unawaited(loadComrades());
    await runOnlineAction(() async {
      final client = _onlineClient();
      final sessions = await client.fetchSessions();
      var nextCitizensOnline = _citizensOnlineFromSessions(sessions);
      try {
        nextCitizensOnline = (await client.fetchServerStatus()).citizensOnline;
      } catch (_) {
        // The session list is enough to keep the join panel usable.
      }
      openSessions = sessions;
      citizensOnline = nextCitizensOnline;
      selectedSessionID = _sessionStillOpen(selectedSessionID, openSessions)
          ? selectedSessionID
          : null;
      secondsUntilBrowserRefresh = _browserRefreshInterval.inSeconds;
      statusIsError = false;
      statusDisablesAction = false;
    });
  }

  int _citizensOnlineFromSessions(List<OnlineSessionListing> sessions) {
    return sessions.fold<int>(
      0,
      (total, session) => total + session.connectedHumanSeatCount,
    );
  }

  Future<void> joinSession(OnlineSessionListing session) async {
    await runOnlineAction(() async {
      final seat = session.openSeats.isEmpty ? null : session.openSeats.first;
      await widget.onJoinOnline(_onlineServerURL, session.sessionID, seat);
      status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
        'value1': session.shortID,
      });
      statusIsError = false;
      statusDisablesAction = false;
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
    try {
      final response = await _onlineClient().fetchComrades();
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserID = response.userID;
        comradeUserIDs = response.userIDs;
        incomingComradeRequestUserIDs = {
          for (final request in response.incomingRequests) request.userID,
        };
        outgoingComradeRequestUserIDs = {
          for (final request in response.outgoingRequests) request.userID,
        };
      });
      widget.onComradesChanged?.call(response);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserID = widget.comradesSummary.userID;
        comradeUserIDs = widget.comradesSummary.userIDs;
        incomingComradeRequestUserIDs = {
          for (final request in widget.comradesSummary.incomingRequests)
            request.userID,
        };
        outgoingComradeRequestUserIDs = {
          for (final request in widget.comradesSummary.outgoingRequests)
            request.userID,
        };
      });
    }
  }

  KolkhozOnlineClient _onlineClient() {
    return widget.onlineClientFactory?.call() ??
        KolkhozOnlineClient(
          _onlineServerURL,
          accessTokenProvider: _currentSupabaseAccessToken,
        );
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
      await loadComrades();
      status = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      statusIsError = false;
      statusDisablesAction = false;
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
        _onlineServerURL,
        inviteController.text.trim(),
        null,
      );
      status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
        'value1': inviteController.text.trim(),
      });
      statusIsError = false;
      statusDisablesAction = false;
    });
  }

  Future<void> matchmake() async {
    if (widget.onMatchmakeOnline == null) {
      await join();
      return;
    }
    await runOnlineAction(() async {
      final inviteCode = await widget.onMatchmakeOnline!(
        _onlineServerURL,
        true,
        false,
      );
      status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
        'value1': inviteCode,
      });
      statusIsError = false;
      statusDisablesAction = false;
    });
  }

  Future<void> assignGame() async {
    if (inviteController.text.trim().isNotEmpty) {
      await join();
      return;
    }
    await matchmake();
  }

  Future<void> runOnlineAction(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
      statusIsError = false;
      statusDisablesAction = false;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          status = onlineFailureStatusMessage(exception, widget.language);
          statusIsError = true;
          statusDisablesAction = onlineFailureLocksOnlinePlay(exception);
          if (statusDisablesAction) {
            selectedSessionID = null;
          }
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
    final onlineUpdate = widget.onlineSessionUpdate;
    if (onlineUpdate != null) {
      return _OnlineWaitingRoomPanel(
        tokens: widget.tokens,
        language: widget.language,
        update: onlineUpdate,
        inviteCode: widget.showHostedInviteCode
            ? widget.hostedInviteCode
            : null,
        onCopyInviteCode: widget.hostedInviteCode == null
            ? null
            : () => copyInviteCode(widget.hostedInviteCode!),
        currentUserID: currentUserID ?? widget.comradesSummary.userID,
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
        : widget.language.t(KolkhozText.kolkhozappValue1CitizensOnline, {
            'value1': citizensOnline!,
          });
    final refreshMessage = widget.language.t(
      KolkhozText.kolkhozappRefreshInValue1s,
      {'value1': secondsUntilBrowserRefresh},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            const _AssetIcon('assets/ui/Icons/icon-online.png', size: 26),
            Text(
              widget.language.t(KolkhozText.kolkhozappJoinGame),
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                widget.language.t(
                  KolkhozText.kolkhozappJoinAnOpenGameOrEnterAnInviteCode,
                ),
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
        if (browserHiddenByBan)
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: _OnlineStatusBanner(
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
              currentUserID: currentUserID ?? widget.comradesSummary.userID,
              comradeUserIDs: comradeUserIDs.isEmpty
                  ? widget.comradesSummary.userIDs
                  : comradeUserIDs,
              incomingComradeRequestUserIDs:
                  incomingComradeRequestUserIDs.isEmpty
                  ? {
                      for (final request
                          in widget.comradesSummary.incomingRequests)
                        request.userID,
                    }
                  : incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs:
                  outgoingComradeRequestUserIDs.isEmpty
                  ? {
                      for (final request
                          in widget.comradesSummary.outgoingRequests)
                        request.userID,
                    }
                  : outgoingComradeRequestUserIDs,
              onSelected: selectSession,
              onComradeRequestToUser: sendComradeRequestToUser,
            ),
          ),
        ],
        if (status != null && (!statusIsError || !statusDisablesAction))
          _OnlineStatusBanner(
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
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappRefresh),
                  prominent: false,
                  tokens: widget.tokens,
                  iconAsset: 'assets/ui/Icons/icon-status-connecting.png',
                  onPressed: busy ? null : refreshSessions,
                ),
              ),
              Expanded(
                child: _OnlineTextField(
                  tokens: widget.tokens,
                  controller: inviteController,
                  label: widget.language.t(KolkhozText.kolkhozappInviteCode),
                ),
              ),
              SizedBox(
                width: 220,
                child: Opacity(
                  opacity: busy ? 0.55 : 1,
                  child: ChromeAssetButton.command(
                    label: buttonShowsBan
                        ? status!
                        : busy
                        ? widget.language.t(KolkhozText.kolkhozappWorking)
                        : joinsExistingGame
                        ? widget.language.t(KolkhozText.kolkhozappJoinGame)
                        : widget.language.t(KolkhozText.kolkhozappAssignGame),
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

class _HostedInviteCodeFooterButton extends StatelessWidget {
  const _HostedInviteCodeFooterButton({
    required this.tokens,
    required this.language,
    required this.inviteCode,
    required this.height,
    required this.onCopy,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String inviteCode;
  final double height;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${language.t(KolkhozText.kolkhozappInviteCode)} $inviteCode',
      child: ExcludeSemantics(
        child: Tooltip(
          message: language.t(KolkhozText.kolkhozappCopyCode),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCopy,
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: chromeButtonSecondaryAsset,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Row(
                      spacing: 7,
                      children: [
                        const _AssetIcon(
                          'assets/ui/Icons/icon-add-friend.png',
                          size: 22,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              ChromeScaledLabel(
                                language.t(KolkhozText.kolkhozappInviteCode),
                                color: tokens.colors.cardInk,
                                size: PixelTextSize.xSmall,
                                textAlign: TextAlign.start,
                              ),
                              ChromeScaledLabel(
                                inviteCode,
                                color: tokens.colors.cardInk,
                                size: PixelTextSize.caption,
                                textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                        ),
                        const _AssetIcon(
                          'assets/ui/Icons/icon-check.png',
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

class _OnlineWaitingRoomPanel extends StatelessWidget {
  const _OnlineWaitingRoomPanel({
    required this.tokens,
    required this.language,
    required this.update,
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
    final profilesBySeat = <int, OnlinePlayerProfile>{
      for (final profile in update.playerProfiles) profile.playerID: profile,
    };
    final presenceBySeat = <int, OnlineSeatPresence>{
      for (final presence in update.seatPresence) presence.playerID: presence,
    };
    final countdownSeconds = update.lobbyCountdownSeconds;
    final status = update.started
        ? language.t(KolkhozText.kolkhozappJoinGame)
        : countdownSeconds != null
        ? language.t(KolkhozText.kolkhozappGameStartsInValue1s, {
            'value1': countdownSeconds,
          })
        : language.t(KolkhozText.kolkhozappWaitingForPlayers);
    final subtitle =
        '${update.playerProfiles.length}/${update.controllers.length} '
        '${language.t(KolkhozText.kolkhozappSeats)}';

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
                  message: language.t(KolkhozText.kolkhozappCancel),
                  child: Semantics(
                    button: true,
                    label: language.t(KolkhozText.kolkhozappCancel),
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
              const _AssetIcon(
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
                label: language.t(KolkhozText.kolkhozappGameType),
                value: update.ranked
                    ? language.t(KolkhozText.kolkhozappRanked)
                    : language.t(KolkhozText.kolkhozappCasual),
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappSeats),
                value:
                    '${update.playerProfiles.length}/${update.controllers.length}',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappMoves),
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
                    for (
                      var index = 0;
                      index < update.controllers.length;
                      index += 1
                    )
                      SizedBox(
                        width: cardWidth,
                        child: _OnlineWaitingRoomSeatCard(
                          tokens: tokens,
                          language: language,
                          playerID: index,
                          controller: update.controllers[index],
                          profile: profilesBySeat[index],
                          presence: presenceBySeat[index],
                          ranked: update.ranked,
                          local: update.viewerID == index,
                          currentUserID: currentUserID,
                          comradeUserIDs: comradeUserIDs,
                          incomingComradeRequestUserIDs:
                              incomingComradeRequestUserIDs,
                          outgoingComradeRequestUserIDs:
                              outgoingComradeRequestUserIDs,
                          onComradeRequestToUser: onComradeRequestToUser,
                          canKick:
                              canKickPlayers &&
                              update.controllers[index] ==
                                  KolkhozPlayerController.human &&
                              profilesBySeat[index] != null &&
                              update.viewerID != index &&
                              onKickPlayer != null,
                          onKick: onKickPlayer == null
                              ? null
                              : () => onKickPlayer!(index),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (showJoinButton)
          _WaitingRoomEnterButton(
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

class _WaitingRoomEnterButton extends StatelessWidget {
  const _WaitingRoomEnterButton({
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
          label: language.t(KolkhozText.kolkhozappJoinGame),
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
                        const _AssetIcon(
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
    required this.playerID,
    required this.controller,
    required this.profile,
    required this.presence,
    required this.ranked,
    required this.local,
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
  final int playerID;
  final KolkhozPlayerController controller;
  final OnlinePlayerProfile? profile;
  final OnlineSeatPresence? presence;
  final bool ranked;
  final bool local;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final bool canKick;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
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
              profile: profile!,
              currentUserID: currentUserID,
              comradeUserIDs: comradeUserIDs,
              incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
              onComradeRequestToUser: onComradeRequestToUser,
            ),
      seatLabel: language.t(KolkhozText.kolkhozappPValue1, {
        'value1': playerID + 1,
      }),
      subtitle: _seatStatus(open, connected),
      title: open
          ? _AnimatedEllipsisLabel(
              label: language.t(KolkhozText.kolkhozappSearchingForPlayer),
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
      active: local,
      muted: open,
      action: canKick
          ? PlayerProfileAction(
              label: language.t(KolkhozText.kolkhozappKick),
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
      return language.t(KolkhozText.kolkhozappOpen);
    }
    return language.t(KolkhozText.kolkhozappHuman);
  }

  String _seatStatus(bool open, bool connected) {
    if (open) {
      return language.t(KolkhozText.kolkhozappWaiting);
    }
    if (profile != null) {
      return '${language.t(KolkhozText.kolkhozappRating)} '
          '${profile!.stats.ratingForGameType(ranked: ranked)}';
    }
    return connected
        ? controller.shortTitle(language)
        : language.t(KolkhozText.kolkhozappWaiting);
  }
}

Future<void> _showLobbyPlayerProfile({
  required BuildContext context,
  required DesignTokens tokens,
  required KolkhozLanguage language,
  required OnlinePlayerProfile profile,
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
      ? language.t(KolkhozText.kolkhozappComrade)
      : hasOutgoingRequest
      ? language.t(KolkhozText.kolkhozappPending)
      : language.t(KolkhozText.kolkhozappNotComrade);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: tokens.colors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ExpandedPlayerProfile(
            key: Key('lobby-player-profile-${profile.playerID}'),
            tokens: tokens,
            displayName: displayName == null || displayName.isEmpty
                ? language.t(KolkhozText.kolkhozappHuman)
                : displayName,
            portraitAsset: profile.portraitAsset ?? defaultProfilePortraitAsset,
            subtitle: language.t(KolkhozText.kolkhozappPlayer),
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
    return language.t(
      KolkhozText.kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom,
    );
  }
  if (exception is OnlineRequestException) {
    return onlineFailureMessageFromServerError(
      exception.message,
      language,
      sentAuthorization: exception.sentAuthorization,
    );
  }
  if (exception is HttpException) {
    return onlineFailureMessageFromServerError(exception.message, language);
  }
  return language.t(KolkhozText.kolkhozappOnlineRequestFailedTryAgain);
}

bool onlineFailureLocksOnlinePlay(Object exception) {
  if (exception is OnlineRequestException) {
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
    return language.t(
      KolkhozText.kolkhozappSentNorthOnlinePlayIsLockedForThisAccount,
    );
  }
  if (normalized.contains('missing auth token')) {
    return sentAuthorization == true
        ? language.t(KolkhozText.kolkhozappCouldNotVerifyOnlineAccountTryAgain)
        : language.t(KolkhozText.kolkhozappSignInBeforeJoiningOnlinePlay);
  }
  if (normalized.contains('invalid auth token')) {
    return language.t(KolkhozText.kolkhozappOnlineSignInExpiredSignInAgain);
  }
  if (normalized.contains('no open games')) {
    return language.t(KolkhozText.kolkhozappNoOpenGames);
  }
  if (normalized.contains('supabase auth')) {
    return language.t(
      KolkhozText.kolkhozappCouldNotVerifyOnlineAccountTryAgain,
    );
  }
  final detail = onlineServerErrorDetail(message);
  if (detail == null) {
    return language.t(KolkhozText.kolkhozappTheOnlineServerRejectedTheRequest);
  }
  return '${language.t(KolkhozText.kolkhozappTheOnlineServerRejectedTheRequest)} '
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

final Uri _onlineServerURL = Uri.parse(
  'https://online.kolkhoz.williamtheisen.com',
);

Future<String?> _currentSupabaseAccessToken() async {
  return KolkhozSupabaseRuntime
      .instance
      .client
      ?.auth
      .currentSession
      ?.accessToken;
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
                  label: language.t(KolkhozText.kolkhozappCopyCode),
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
                      const _AssetIcon(
                        'assets/ui/Icons/icon-online.png',
                        size: 26,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              language.t(KolkhozText.kolkhozappYourInviteCode),
                              style: kolkhozFontStyle.copyWith(
                                color: tokens.colors.onAccent,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              language.t(
                                KolkhozText.kolkhozappWaitingForPlayers,
                              ),
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

class _OnlineStatusBanner extends StatelessWidget {
  const _OnlineStatusBanner({
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
          _AssetIcon(
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
      child: _OpenSessionsChromeSurface(
        padding: const EdgeInsets.all(18),
        child: sessions.isEmpty
            ? Align(
                alignment: Alignment.topLeft,
                child: Text(
                  language.t(KolkhozText.kolkhozappNoOpenGames),
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

class _OpenSessionsChromeSurface extends StatelessWidget {
  const _OpenSessionsChromeSurface({
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
        _AssetIcon(iconAsset, size: 18),
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
        .map(
          (seat) =>
              language.t(KolkhozText.kolkhozappPValue1, {'value1': seat + 1}),
        )
        .join(' ');
    final hostProfile = session.playerProfiles
        .where((profile) => profile.playerID == 0)
        .firstOrNull;
    final hostName = hostProfile?.displayName?.trim();
    final gameType = session.ranked
        ? language.t(KolkhozText.kolkhozappRanked)
        : language.t(KolkhozText.kolkhozappCasual);
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
              '${session.ranked ? language.t(KolkhozText.kolkhozappRanked) : language.t(KolkhozText.kolkhozappCasual)}'
              '${hasComrade ? ', ${language.t(KolkhozText.kolkhozappComrade)}' : ''}',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: _VariantRowBackground(
                tokens: tokens,
                active: expanded,
                child: Row(
                  spacing: 10,
                  children: [
                    _OpenSessionBadgeIcon(
                      tokens: tokens,
                      label: session.ranked
                          ? language.t(KolkhozText.kolkhozappRanked)
                          : language.t(KolkhozText.kolkhozappCasual),
                      asset: session.ranked
                          ? 'assets/ui/Icons/icon-medal-star.png'
                          : 'assets/ui/Icons/icon-foreman-misha.png',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          _VariantPixelLine(
                            height: _pixelTextSlotHeight(PixelTextSize.caption),
                            child: PixelText(
                              title,
                              color: titleColor,
                              size: PixelTextSize.caption,
                              variant: PixelTextVariant.heavy,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                          _VariantPixelLine(
                            height: _pixelTextSlotHeight(
                              PixelTextSize.caption2,
                            ),
                            child: PixelText(
                              language.t(KolkhozText.kolkhozappOpenOpenseats, {
                                'openSeats': openSeats,
                              }),
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
                        label: language.t(KolkhozText.kolkhozappComrade),
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
                ? language.t(KolkhozText.kolkhozappWaiting)
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
        child: _AssetIcon(asset, size: 19),
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
        ? language.t(KolkhozText.kolkhozappWaiting)
        : (ratings.reduce((left, right) => left + right) / ratings.length)
              .round()
              .toString();
    final turn = session.turnPlayerID == null
        ? language.t(KolkhozText.kolkhozappWaiting)
        : language.t(KolkhozText.kolkhozappPValue1, {
            'value1': session.turnPlayerID! + 1,
          });
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
                label: language.t(KolkhozText.kolkhozappHost),
                value: hostName,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappSeats),
                value: '$occupiedSeats / $openSeats',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappTurn),
                value: turn,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappMoves),
                value: '${session.actionLogCount}',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappAverageRating),
                value: averageRating,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappGameType),
                value: session.ranked
                    ? language.t(KolkhozText.kolkhozappRanked)
                    : language.t(KolkhozText.kolkhozappCasual),
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappAccess),
                value: session.browserJoinable
                    ? language.t(KolkhozText.kolkhozappBrowser)
                    : language.t(KolkhozText.kolkhozappLocked),
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
      return language.t(KolkhozText.kolkhozappWaiting);
    }
    return seats
        .map(
          (seat) =>
              language.t(KolkhozText.kolkhozappPValue1, {'value1': seat + 1}),
        )
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
    final player = language.t(KolkhozText.kolkhozappPValue1, {
      'value1': playerID + 1,
    });
    final name = profile?.displayName?.trim();
    final occupied = !open;
    final displayName = name == null || name.isEmpty
        ? occupied
              ? language.t(KolkhozText.kolkhozappHuman)
              : language.t(KolkhozText.kolkhozappOpen)
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
        ? language.t(KolkhozText.kolkhozappComrade)
        : hasOutgoingRequest
        ? language.t(KolkhozText.kolkhozappPending)
        : hasIncomingRequest
        ? language.t(KolkhozText.kolkhozappAccept)
        : language.t(KolkhozText.kolkhozappAddComrade);
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
              profile: profile!,
              currentUserID: currentUserID,
              comradeUserIDs: comradeUserIDs,
              incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
              outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
              onComradeRequestToUser: onComradeRequestToUser,
            ),
      seatLabel: player,
      subtitle: occupied
          ? '${language.t(KolkhozText.kolkhozappRating)} $rating'
          : language.t(KolkhozText.kolkhozappOpen),
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

class _OnlineTextField extends StatelessWidget {
  const _OnlineTextField({
    required this.tokens,
    required this.controller,
    required this.label,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
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
    );
  }
}
