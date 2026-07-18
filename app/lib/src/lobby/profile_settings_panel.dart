part of '../kolkhoz_app.dart';

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({
    required this.tokens,
    required this.language,
    required this.onTutorialPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onTutorialPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              final twoColumn = contentWidth >= 560;
              final ruleWidth = twoColumn
                  ? (contentWidth - 12) / 2
                  : contentWidth;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        const _AssetIcon(
                          'assets/ui/Icons/icon-rules-scroll.png',
                          size: 30,
                        ),
                        Text(
                          language.t(KolkhozText.kolkhozappHowToPlay),
                          style: kolkhozFontStyle.copyWith(
                            color: tokens.colors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Image.asset(
                        'assets/ui/Embellishments/art-rules-divider.png',
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final rule in lobbyRuleSummaries)
                          SizedBox(
                            width: ruleWidth,
                            child: _RuleBlock(
                              tokens: tokens,
                              title: rule.title(language),
                              body: rule.body(language),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            height: 44,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappTutorial),
              prominent: true,
              tokens: tokens,
              onPressed: onTutorialPressed,
              iconAsset: 'assets/ui/Icons/icon-foreman-misha.png',
              iconSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({
    required this.tokens,
    required this.language,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
    required this.onCloudDeleteAccount,
    required this.clientFactory,
    required this.onStartDailyChallenge,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final Future<void> Function()? onCloudDeleteAccount;
  final KolkhozOnlineClient Function()? clientFactory;
  final Future<void> Function()? onStartDailyChallenge;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  late final TextEditingController displayNameController;
  late String lastSubmittedName;
  List<OnlineRecentGame> recentGames = const [];
  bool recentGamesLoading = false;
  Object? recentGamesError;
  int recentGamesLoadGeneration = 0;
  OnlineDailyChallenge? dailyChallenge;
  bool dailyLoading = false;

  @override
  void initState() {
    super.initState();
    lastSubmittedName = widget.displayName;
    displayNameController = TextEditingController(text: widget.displayName);
    displayNameController.addListener(notifyDisplayNameChanged);
    if (widget.cloudSignedIn) {
      unawaited(loadRecentGames());
      unawaited(loadDailyChallenge());
    }
  }

  Future<void> loadDailyChallenge() async {
    final factory = widget.clientFactory;
    if (factory == null) return;
    setState(() => dailyLoading = true);
    try {
      final value = await factory().fetchDailyChallenge();
      if (mounted) setState(() => dailyChallenge = value);
    } catch (_) {
      // Profile history remains usable when the optional challenge is offline.
    } finally {
      if (mounted) setState(() => dailyLoading = false);
    }
  }

  Future<void> loadRecentGames() async {
    final factory = widget.clientFactory;
    if (factory == null) return;
    final generation = ++recentGamesLoadGeneration;
    setState(() {
      recentGamesLoading = true;
      recentGamesError = null;
    });
    try {
      final games = await factory().fetchRecentGames();
      if (mounted &&
          widget.cloudSignedIn &&
          generation == recentGamesLoadGeneration) {
        setState(() => recentGames = games);
      }
    } catch (exception) {
      if (mounted && generation == recentGamesLoadGeneration) {
        setState(() => recentGamesError = exception);
      }
    } finally {
      if (mounted && generation == recentGamesLoadGeneration) {
        setState(() => recentGamesLoading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.cloudSignedIn && widget.cloudSignedIn) {
      unawaited(loadRecentGames());
    } else if (oldWidget.cloudSignedIn && !widget.cloudSignedIn) {
      recentGamesLoadGeneration++;
      recentGames = const [];
      recentGamesLoading = false;
      recentGamesError = null;
    }
    if (widget.displayName != lastSubmittedName &&
        widget.displayName != displayNameController.text) {
      displayNameController.text = widget.displayName;
      lastSubmittedName = widget.displayName;
    }
  }

  @override
  void dispose() {
    displayNameController.removeListener(notifyDisplayNameChanged);
    displayNameController.dispose();
    super.dispose();
  }

  void notifyDisplayNameChanged() {
    final next = displayNameController.text;
    if (next == lastSubmittedName) {
      return;
    }
    lastSubmittedName = next;
    widget.onDisplayNameChanged?.call(next);
  }

  Future<void> showPortraitPicker() async {
    if (widget.onPortraitChanged == null) {
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.tokens.colors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.tokens.colors.gold.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tokens.colors.black.withValues(alpha: 0.42),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final asset in profilePortraitAssets)
                _ProfilePortraitChoice(
                  tokens: widget.tokens,
                  asset: asset,
                  selected: widget.portraitAsset == asset,
                  unlocked: isProfilePortraitUnlocked(
                    widget.progression,
                    asset,
                  ),
                  onPressed:
                      isProfilePortraitUnlocked(widget.progression, asset)
                      ? () => Navigator.of(context).pop(asset)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != widget.portraitAsset) {
      widget.onPortraitChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (widget.cloudSignedIn) ...[
                  PlayerProfilePanel(
                    tokens: widget.tokens,
                    displayName: displayNameController.text.trim().isEmpty
                        ? defaultProfileDisplayName
                        : displayNameController.text.trim(),
                    portraitAsset: widget.portraitAsset,
                    active: true,
                    portraitSelected: true,
                    portraitSize: 74,
                    minHeight: 94,
                    padding: const EdgeInsets.all(10),
                    onPortraitPressed: widget.onPortraitChanged == null
                        ? null
                        : showPortraitPicker,
                    portraitSemanticsLabel: widget.portraitAsset,
                    title: TextField(
                      controller: displayNameController,
                      maxLength: 24,
                      minLines: 1,
                      maxLines: 1,
                      style: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.cream,
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: widget.tokens.colors.goldBright,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: defaultProfileDisplayName,
                        hintStyle: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.creamDim.withValues(
                            alpha: 0.74,
                          ),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text(
                        widget.language.t(KolkhozText.kolkhozappStats),
                        style: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnCount = constraints.maxWidth >= 520
                              ? 3
                              : 1;
                          return PlayerProfileStatsGrid(
                            tokens: widget.tokens,
                            groups: kolkhozProfileStatGroups(
                              stats: widget.profileStats,
                              language: widget.language,
                            ),
                            columnsForWidth: (_) => columnCount,
                          );
                        },
                      ),
                      _RecentGamesPanel(
                        tokens: widget.tokens,
                        games: recentGames,
                        loading: recentGamesLoading,
                        error: recentGamesError,
                        onRetry: loadRecentGames,
                        clientFactory: widget.clientFactory,
                      ),
                      _DailyChallengePanel(
                        tokens: widget.tokens,
                        challenge: dailyChallenge,
                        loading: dailyLoading,
                        onPlay: widget.onStartDailyChallenge,
                      ),
                    ],
                  ),
                ],
                _CloudAuthPanel(
                  tokens: widget.tokens,
                  language: widget.language,
                  configured: widget.cloudConfigured,
                  ready: widget.cloudReady,
                  signedIn: widget.cloudSignedIn,
                  email: widget.cloudEmail,
                  busy: widget.cloudAuthBusy,
                  message: widget.cloudAuthMessage,
                  messageIsError: widget.cloudAuthIsError,
                  onSignIn: widget.onCloudSignIn,
                  onSignUp: widget.onCloudSignUp,
                  onResetPassword: widget.onCloudResetPassword,
                  onSignOut: widget.onCloudSignOut,
                  onDeleteAccount: widget.onCloudDeleteAccount,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminOperationsPanel extends StatefulWidget {
  const _AdminOperationsPanel({
    required this.tokens,
    required this.clientFactory,
  });

  final DesignTokens tokens;
  final KolkhozOnlineClient Function()? clientFactory;

  @override
  State<_AdminOperationsPanel> createState() => _AdminOperationsPanelState();
}

class _AdminOperationsPanelState extends State<_AdminOperationsPanel> {
  Map<String, Object?>? value;
  Object? error;
  bool loading = true;
  bool restarting = false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final factory = widget.clientFactory;
    if (factory == null) {
      setState(() {
        loading = false;
        error = 'Sign in to view operations.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await factory().fetchAdminOperations();
      if (mounted) setState(() => value = next);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> restart() async {
    final factory = widget.clientFactory;
    if (factory == null || restarting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart production server?'),
        content: const Text(
          'This restarts only kolkhoz-greenfield.service. Active clients may '
          'briefly reconnect. A five-minute cooldown applies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESTART'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => restarting = true);
    try {
      await factory().restartProductionServer();
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => restarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && value == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADMIN ACCESS REQUIRED',
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
              ),
            ),
            TextButton(onPressed: load, child: const Text('RETRY')),
          ],
        ),
      );
    }
    final operations = value ?? const <String, Object?>{};
    final games = onlineObjectList(operations['games'] ?? const []);
    final suspicious = onlineObjectList(
      operations['suspiciousGames'] ?? const [],
    );
    final outbox = onlineObjectMap(
      operations['notificationOutbox'] ?? const <String, Object?>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PRODUCTION • ${operations['deploymentVersion'] ?? 'unknown'}',
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.goldBright,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(onPressed: load, child: const Text('REFRESH')),
            TextButton(
              onPressed: restarting ? null : restart,
              child: Text(restarting ? 'RESTARTING…' : 'RESTART SERVER'),
            ),
          ],
        ),
        Text(
          'ACTIVE ${games.length}   SUSPICIOUS ${suspicious.length}   '
          'OUTBOX PENDING ${outbox['pending'] ?? 0}   FAILED ${outbox['failed'] ?? 0}',
          style: kolkhozFontStyle.copyWith(color: widget.tokens.colors.cream),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final raw in games)
                Builder(
                  builder: (_) {
                    final game = onlineObjectMap(raw);
                    return ListTile(
                      dense: true,
                      title: Text('${game['sessionID']}'),
                      subtitle: Text(
                        'PHASE ${game['phase']} • ACTOR ${game['currentActor'] ?? '—'} • '
                        '${game['expectedActor'] ?? '—'} • '
                        '${(game['lastActionAgeSeconds'] as num?)?.round() ?? 0}s',
                      ),
                      trailing: game['suspicious'] == true
                          ? const Text('STUCK?')
                          : null,
                    );
                  },
                ),
              const Divider(),
              Text('AI CANARY  ${operations['aiCanary']}'),
              Text('BACKUP  ${operations['backup']}'),
              Text('WATCHDOG  ${operations['watchdog']}'),
              Text('RECENT ERRORS  ${operations['recentServerErrors']}'),
              Text('OUTBOX FAILURES  ${outbox['failures']}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentGamesPanel extends StatelessWidget {
  const _RecentGamesPanel({
    required this.tokens,
    required this.games,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.clientFactory,
  });

  final DesignTokens tokens;
  final List<OnlineRecentGame> games;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final KolkhozOnlineClient Function()? clientFactory;

  String placement(int rank) => switch (rank) {
    1 => '1ST',
    2 => '2ND',
    3 => '3RD',
    _ => '${rank}TH',
  };

  String date(double seconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
    ).toLocal();
    return '${value.month}/${value.day}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 7,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'RECENT GAMES',
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (error != null)
              TextButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
        if (loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (error != null)
          Text(
            'RECENT RESULTS UNAVAILABLE',
            style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
          )
        else if (games.isEmpty)
          Text(
            'NO COMPLETED ONLINE GAMES YET',
            style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
          )
        else
          for (final game in games)
            InkWell(
              onTap: clientFactory == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (context) => _ReplayDialog(
                        tokens: tokens,
                        replay: clientFactory!().fetchReplay(game.sessionID),
                      ),
                    ),
              child: Container(
                key: Key('recent-game-${game.sessionID}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.black.withValues(alpha: 0.22),
                  border: Border.all(
                    color: game.won
                        ? tokens.colors.gold.withValues(alpha: 0.7)
                        : tokens.colors.creamDim.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        game.won ? 'WIN' : placement(game.rank),
                        style: kolkhozFontStyle.copyWith(
                          color: game.won
                              ? tokens.colors.goldBright
                              : tokens.colors.cream,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${game.score} PTS  •  ${game.ranked ? 'RANKED' : 'CASUAL'}',
                        style: kolkhozFontStyle.copyWith(
                          color: tokens.colors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      date(game.completedAt),
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.creamDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DailyChallengePanel extends StatelessWidget {
  const _DailyChallengePanel({
    required this.tokens,
    required this.challenge,
    required this.loading,
    required this.onPlay,
  });
  final DesignTokens tokens;
  final OnlineDailyChallenge? challenge;
  final bool loading;
  final Future<void> Function()? onPlay;

  @override
  Widget build(BuildContext context) {
    final value = challenge;
    return Container(
      key: const Key('daily-collective-challenge'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.colors.gold.withValues(alpha: 0.1),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            'DAILY COLLECTIVE CHALLENGE',
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.goldBright,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            Text(
              value?.bestScore == null
                  ? 'One shared seed. Unlimited attempts. Your best score counts.'
                  : 'PERSONAL BEST  ${value!.bestScore} PTS',
              style: kolkhozFontStyle.copyWith(color: tokens.colors.cream),
            ),
            if (value != null && value.leaders.isNotEmpty)
              Text(
                'LEADER  ${value.leaders.first.displayName}  ${value.leaders.first.score}',
                style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('daily-challenge-play-button'),
                onPressed: onPlay == null ? null : () => onPlay!(),
                child: Text(value?.bestScore == null ? 'PLAY' : 'PLAY AGAIN'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplayDialog extends StatefulWidget {
  const _ReplayDialog({required this.tokens, required this.replay});
  final DesignTokens tokens;
  final Future<OnlineGameReplay> replay;
  @override
  State<_ReplayDialog> createState() => _ReplayDialogState();
}

class _ReplayDialogState extends State<_ReplayDialog> {
  int revision = 0;

  String actionLabel(OnlineReplayEvent event) {
    final action = event.action;
    return [
      'R${event.revision}',
      'ACTION ${action.kind}',
      'P${action.playerID + 1}',
      if (action.card.isValid) '${action.card.suit}-${action.card.value}',
    ].join('  ');
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: widget.tokens.colors.panel,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
      child: FutureBuilder<OnlineGameReplay>(
        future: widget.replay,
        builder: (context, snapshot) {
          final replay = snapshot.data;
          if (replay == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            );
          }
          final events = replay.events;
          final selected = events.isEmpty
              ? null
              : events[revision.clamp(0, events.length - 1)];
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  'MATCH REPLAY',
                  style: kolkhozFontStyle.copyWith(
                    color: widget.tokens.colors.goldBright,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'SEED ${replay.seed}  •  ${replay.ranked ? 'RANKED' : 'CASUAL'}  •  ${events.length} ACTIONS',
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final result in replay.results)
                      Text(
                        '${result.rank}. ${result.displayName} ${result.score}',
                      ),
                  ],
                ),
                const Divider(),
                if (selected != null) ...[
                  Text(
                    actionLabel(selected),
                    key: const Key('replay-current-action'),
                  ),
                  Slider(
                    value: revision.toDouble(),
                    min: 0,
                    max: (events.length - 1).toDouble(),
                    divisions: events.length - 1 > 0 ? events.length - 1 : null,
                    onChanged: (value) =>
                        setState(() => revision = value.round()),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: revision == 0
                            ? null
                            : () => setState(() => revision--),
                        child: const Text('PREVIOUS'),
                      ),
                      TextButton(
                        onPressed: revision >= events.length - 1
                            ? null
                            : () => setState(() => revision++),
                        child: const Text('NEXT'),
                      ),
                      const Spacer(),
                      Text('${revision + 1}/${events.length}'),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) => ListTile(
                        dense: true,
                        selected: index == revision,
                        title: Text(actionLabel(events[index])),
                        onTap: () => setState(() => revision = index),
                      ),
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Center(child: Text('NO RECORDED ACTIONS')),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _CloudAuthPanel extends StatefulWidget {
  const _CloudAuthPanel({
    required this.tokens,
    required this.language,
    required this.configured,
    required this.ready,
    required this.signedIn,
    required this.email,
    required this.busy,
    required this.message,
    required this.messageIsError,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool configured;
  final bool ready;
  final bool signedIn;
  final String? email;
  final bool busy;
  final String? message;
  final bool messageIsError;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;

  @override
  State<_CloudAuthPanel> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<_CloudAuthPanel> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;
  String? localMessage;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void clearLocalMessage() {
    if (localMessage == null) {
      return;
    }
    setState(() => localMessage = null);
  }

  void submitSignUp() {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() {
        localMessage = widget.language.t(
          KolkhozText.kolkhozappPasswordsDoNotMatch,
        );
      });
      return;
    }
    clearLocalMessage();
    widget.onSignUp?.call(emailController.text, password);
  }

  Future<void> confirmAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.language.t(KolkhozText.kolkhozappDeleteAccountQuestion),
        ),
        content: Text(
          widget.language.t(KolkhozText.kolkhozappDeleteAccountWarning),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.language.t(KolkhozText.kolkhozappCancel)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
            child: Text(widget.language.t(KolkhozText.kolkhozappDeleteAccount)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.onDeleteAccount?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = !widget.configured
        ? widget.language.t(
            KolkhozText.kolkhozappCloudProfilesAreNotConfiguredForThisBuild,
          )
        : !widget.ready
        ? widget.language.t(KolkhozText.kolkhozappCloudProfilesAreStarting)
        : widget.signedIn
        ? widget.language.t(KolkhozText.kolkhozappSignedInAsValue1, {
            'value1': widget.email ?? 'player',
            'value2': widget.email ?? 'игрок',
          })
        : widget.language.t(
            KolkhozText.kolkhozappSignInToSyncProfileAndOnlineSeats,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.t(KolkhozText.kolkhozappAccount),
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.configured && widget.ready && widget.signedIn)
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _VariantRowBackground(
                  tokens: widget.tokens,
                  active: true,
                  child: Row(
                    spacing: 8,
                    children: [
                      const _AssetIcon(
                        'assets/ui/Icons/icon-status-connected.png',
                        size: 24,
                      ),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kolkhozFontStyle.copyWith(
                            color: widget.tokens.colors.activeSurfaceText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 142,
                height: 42,
                child: ChromeAssetButton.command(
                  label: widget.busy
                      ? widget.language.t(KolkhozText.kolkhozappWorking)
                      : widget.language.t(KolkhozText.kolkhozappSignOut),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignOut == null
                      ? null
                      : widget.onSignOut,
                ),
              ),
              SizedBox(
                width: 128,
                height: 42,
                child: TextButton(
                  onPressed: widget.busy || widget.onDeleteAccount == null
                      ? null
                      : confirmAccountDeletion,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade300,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.language.t(KolkhozText.kolkhozappDeleteAccount),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          _VariantRowBackground(
            tokens: widget.tokens,
            active: false,
            child: Text(
              status,
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.creamDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.message != null &&
            (!widget.signedIn || widget.messageIsError))
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: widget.message!,
            isError: widget.messageIsError,
          ),
        if (widget.configured &&
            widget.ready &&
            !widget.signedIn &&
            localMessage != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: localMessage!,
            isError: true,
          ),
        if (widget.configured && widget.ready && !widget.signedIn) ...[
          _ProfileTextField(
            tokens: widget.tokens,
            controller: emailController,
            label: widget.language.t(KolkhozText.kolkhozappEmail),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: maxAccountEmailLength,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: passwordController,
            label: widget.language.t(KolkhozText.kolkhozappPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: confirmPasswordController,
            label: widget.language.t(KolkhozText.kolkhozappConfirmPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.busy
                      ? widget.language.t(KolkhozText.kolkhozappWorking)
                      : widget.language.t(KolkhozText.kolkhozappSignIn),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignIn == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onSignIn!(
                            emailController.text,
                            passwordController.text,
                          );
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappReset),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onResetPassword == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onResetPassword!(emailController.text);
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappCreate),
                  prominent: true,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignUp == null
                      ? null
                      : submitSignUp,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComradesSettingsPanel extends StatefulWidget {
  const _ComradesSettingsPanel({
    required this.tokens,
    required this.language,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesSettingsPanel> createState() => _ComradesSettingsPanelState();
}

class _ComradesSettingsPanelState extends State<_ComradesSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    if (widget.cloudSignedIn) {
      return _ComradesPanel(
        tokens: widget.tokens,
        language: widget.language,
        initialComrades: widget.comradesSummary,
        onComradesChanged: widget.onComradesChanged,
      );
    }

    return SingleChildScrollView(
      child: _CloudAuthPanel(
        tokens: widget.tokens,
        language: widget.language,
        configured: widget.cloudConfigured,
        ready: widget.cloudReady,
        signedIn: widget.cloudSignedIn,
        email: widget.cloudEmail,
        busy: widget.cloudAuthBusy,
        message: widget.cloudAuthMessage,
        messageIsError: widget.cloudAuthIsError,
        onSignIn: widget.onCloudSignIn,
        onSignUp: widget.onCloudSignUp,
        onResetPassword: widget.onCloudResetPassword,
        onSignOut: null,
        onDeleteAccount: null,
      ),
    );
  }
}

class _ComradesPanel extends StatefulWidget {
  const _ComradesPanel({
    required this.tokens,
    required this.language,
    required this.initialComrades,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse initialComrades;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesPanel> createState() => _ComradesPanelState();
}

class _ComradesPanelState extends State<_ComradesPanel> {
  late final TextEditingController codeController;
  bool busy = false;
  String? message;
  bool messageIsError = false;
  OnlineComradesResponse comrades = const OnlineComradesResponse();

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    comrades = widget.initialComrades;
    unawaited(loadComrades());
  }

  @override
  void didUpdateWidget(covariant _ComradesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialComrades != oldWidget.initialComrades && !busy) {
      comrades = widget.initialComrades;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  KolkhozOnlineClient _client() {
    return KolkhozOnlineClient(
      _onlineServerURL,
      accessTokenProvider: _currentSupabaseAccessToken,
    );
  }

  Future<void> loadComrades() async {
    await runComradeAction(() async {
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
    }, showWorking: false);
  }

  Future<void> addComrade() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    await runComradeAction(() async {
      await _client().sendComradeRequest(code);
      codeController.clear();
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      messageIsError = false;
    });
  }

  Future<void> respondToComradeRequest(String userID, bool accept) async {
    await runComradeAction(() async {
      await _client().respondToComradeRequest(userID: userID, accept: accept);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(
        accept
            ? KolkhozText.kolkhozappComradeRequestAccepted
            : KolkhozText.kolkhozappComradeRequestDeclined,
      );
      messageIsError = false;
    });
  }

  Future<void> removeComrade(String userID) async {
    await runComradeAction(() async {
      await _client().removeComrade(userID);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(KolkhozText.kolkhozappComradeRemoved);
      messageIsError = false;
    });
  }

  Future<void> copyComradeCode() async {
    final code = comrades.comradeCode;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    setState(() {
      message = widget.language.t(KolkhozText.kolkhozappCopied);
      messageIsError = false;
    });
  }

  Future<void> runComradeAction(
    Future<void> Function() action, {
    bool showWorking = true,
  }) async {
    if (busy) {
      return;
    }
    if (mounted) {
      setState(() {
        busy = showWorking;
        if (showWorking) {
          message = null;
          messageIsError = false;
        }
      });
    }
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          message = _comradeSyncErrorMessage(exception);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String _comradeSyncErrorMessage(Object exception) {
    if (exception is OnlineRequestException || exception is SocketException) {
      return onlineFailureStatusMessage(exception, widget.language);
    }
    return widget.language.t(KolkhozText.kolkhozappProfileSyncFailed);
  }

  @override
  Widget build(BuildContext context) {
    final code = comrades.comradeCode ?? '-----';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                _ComradeSectionTitle(
                  tokens: widget.tokens,
                  label: widget.language.t(KolkhozText.kolkhozappComrades),
                  iconAsset: 'assets/ui/Icons/icon-friends-list.png',
                ),
                if (comrades.comrades.isEmpty)
                  _ComradeEmptyRow(
                    tokens: widget.tokens,
                    label: widget.language.t(KolkhozText.kolkhozappNoComrades),
                  )
                else
                  for (final comrade in comrades.comrades)
                    _ComradeRow(
                      tokens: widget.tokens,
                      language: widget.language,
                      comrade: comrade,
                      busy: busy,
                      onRemove: () => removeComrade(comrade.userID),
                    ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final requestColumns = <Widget>[
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappIncomingRequests,
                        ),
                        iconAsset: 'assets/ui/Icons/icon-add-friend.png',
                        requests: comrades.incomingRequests,
                        busy: busy,
                        incoming: true,
                        onAccept: (request) =>
                            respondToComradeRequest(request.userID, true),
                        onDecline: (request) =>
                            respondToComradeRequest(request.userID, false),
                      ),
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappOutgoingRequests,
                        ),
                        iconAsset: 'assets/ui/Icons/icon-friends-list.png',
                        requests: comrades.outgoingRequests,
                        busy: busy,
                        incoming: false,
                        onAccept: null,
                        onDecline: null,
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return Column(spacing: 8, children: requestColumns);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        for (final column in requestColumns)
                          Expanded(child: column),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (message != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: message!,
            isError: messageIsError,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            const footerControlHeight = 38.0;
            final codeBox = Container(
              height: footerControlHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _comradeFooterBoxDecoration(widget.tokens),
              child: SelectableText(
                code,
                maxLines: 1,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.cardInk,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            );
            final copyButton = SizedBox(
              width: 126,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: widget.language.t(KolkhozText.kolkhozappCopyCode),
                prominent: false,
                tokens: widget.tokens,
                iconAsset: 'assets/ui/Icons/icon-comrade.png',
                expandLabel: false,
                onPressed: comrades.comradeCode == null
                    ? null
                    : copyComradeCode,
              ),
            );
            final inputBox = Container(
              height: footerControlHeight,
              alignment: Alignment.center,
              decoration: _comradeFooterBoxDecoration(widget.tokens),
              child: TextField(
                controller: codeController,
                maxLength: 12,
                minLines: 1,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.cardInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                cursorColor: widget.tokens.colors.redDark,
                decoration: InputDecoration(
                  hintText: widget.language
                      .t(KolkhozText.kolkhozappComradeCode)
                      .toUpperCase(),
                  counterText: '',
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  hintStyle: kolkhozFontStyle.copyWith(
                    color: widget.tokens.colors.cardInk.withValues(alpha: 0.44),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            );
            final addButton = SizedBox(
              width: 142,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: busy
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.language.t(KolkhozText.kolkhozappAddComrade),
                prominent: true,
                tokens: widget.tokens,
                iconAsset: 'assets/ui/Icons/icon-add-friend.png',
                onPressed: busy ? null : addComrade,
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: codeBox),
                      copyButton,
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: inputBox),
                      addButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              spacing: 8,
              children: [
                Expanded(flex: 2, child: codeBox),
                copyButton,
                Expanded(flex: 3, child: inputBox),
                addButton,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComradeRequestColumn extends StatelessWidget {
  const _ComradeRequestColumn({
    required this.tokens,
    required this.language,
    required this.label,
    required this.iconAsset,
    required this.requests,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String label;
  final String iconAsset;
  final List<OnlineComradeProfile> requests;
  final bool busy;
  final bool incoming;
  final ValueChanged<OnlineComradeProfile>? onAccept;
  final ValueChanged<OnlineComradeProfile>? onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _ComradeSectionTitle(
          tokens: tokens,
          label: label,
          iconAsset: iconAsset,
        ),
        if (requests.isEmpty)
          _ComradeEmptyRow(
            tokens: tokens,
            label: language.t(KolkhozText.kolkhozappNoComradeRequests),
          )
        else
          for (final request in requests)
            _ComradeRequestRow(
              tokens: tokens,
              language: language,
              request: request,
              busy: busy,
              incoming: incoming,
              onAccept: onAccept == null ? null : () => onAccept!(request),
              onDecline: onDecline == null ? null : () => onDecline!(request),
            ),
      ],
    );
  }
}

class _ComradeSectionTitle extends StatelessWidget {
  const _ComradeSectionTitle({
    required this.tokens,
    required this.label,
    required this.iconAsset,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        spacing: 6,
        children: [
          Image.asset(
            iconAsset,
            width: 18,
            height: 18,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComradeEmptyRow extends StatelessWidget {
  const _ComradeEmptyRow({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Text(
        label,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.creamDim,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComradeRequestRow extends StatelessWidget {
  const _ComradeRequestRow({
    required this.tokens,
    required this.language,
    required this.request,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile request;
  final bool busy;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: incoming,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: request.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: incoming,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  request.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: incoming
                        ? tokens.colors.onAccent
                        : tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  _profileRatingSummary(language, request.stats),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color:
                        (incoming
                                ? tokens.colors.onAccent
                                : tokens.colors.cardInk)
                            .withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-check.png',
              label: language.t(KolkhozText.kolkhozappAccept),
              onPressed: busy ? null : onAccept,
            ),
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-warning.png',
              label: language.t(KolkhozText.kolkhozappDecline),
              onPressed: busy ? null : onDecline,
            ),
          ] else
            Image.asset(
              'assets/ui/Icons/icon-status-connecting.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.none,
            ),
        ],
      ),
    );
  }
}

class _ComradeIconButton extends StatelessWidget {
  const _ComradeIconButton({
    required this.tokens,
    required this.iconAsset,
    required this.label,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String iconAsset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 36,
        height: 32,
        child: ChromeAssetButton.command(
          label: '',
          prominent: false,
          tokens: tokens,
          iconAsset: iconAsset,
          iconSize: 22,
          expandLabel: false,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ComradeRow extends StatelessWidget {
  const _ComradeRow({
    required this.tokens,
    required this.language,
    required this.comrade,
    required this.busy,
    required this.onRemove,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile comrade;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = _comradePresenceSummary(language, comrade);
    final statusColor = (comrade.isOnline || comrade.inGame || comrade.inLobby)
        ? tokens.colors.green
        : tokens.colors.cardInk.withValues(alpha: 0.62);
    return _VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: comrade.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: false,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  comrade.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  '$status / ${_profileRatingSummary(language, comrade.stats)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 32,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappRemove),
              prominent: false,
              tokens: tokens,
              iconAsset: 'assets/ui/Icons/icon-warning.png',
              onPressed: busy ? null : onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

String _comradePresenceSummary(
  KolkhozLanguage language,
  OnlineComradeProfile comrade,
) {
  if (comrade.inGame) {
    return language.t(KolkhozText.kolkhozappInGame);
  }
  if (comrade.inLobby) {
    return language.t(KolkhozText.kolkhozappInLobby);
  }
  if (comrade.isOnline) {
    return language.t(KolkhozText.kolkhozappOnline);
  }
  return language.t(KolkhozText.kolkhozappOfflineStatus);
}

String _profileRatingSummary(
  KolkhozLanguage language,
  KolkhozProfileStats stats,
) {
  return '${language.t(KolkhozText.kolkhozappRanked)} ${stats.rating}  '
      '${language.t(KolkhozText.kolkhozappCasual)} ${stats.casualRating}';
}

BoxDecoration _comradeFooterBoxDecoration(DesignTokens tokens) {
  return BoxDecoration(
    color: tokens.colors.cardFill.withValues(alpha: 0.74),
    borderRadius: BorderRadius.circular(5),
    border: Border.all(
      color: tokens.colors.gold.withValues(alpha: 0.56),
      width: 1,
    ),
  );
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.tokens,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLength = 24,
    this.onChanged,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLength;
  final ValueChanged<String>? onChanged;

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
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        maxLength: maxLength,
        onChanged: onChanged,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _ProfilePortraitChoice extends StatelessWidget {
  const _ProfilePortraitChoice({
    required this.tokens,
    required this.asset,
    required this.selected,
    required this.unlocked,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final bool selected;
  final bool unlocked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        label: unlocked ? asset : '$asset (locked)',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.42,
              child: PlayerProfilePortraitImage(
                tokens: tokens,
                asset: asset,
                size: 58,
                selected: selected,
              ),
            ),
            if (!unlocked)
              Image.asset(
                'assets/ui/Icons/icon-lock.png',
                width: 22,
                height: 22,
                filterQuality: FilterQuality.none,
              ),
          ],
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.tokens,
    required this.title,
    required this.body,
  });

  final DesignTokens tokens;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title.toUpperCase(),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            body,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 15,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: 0.35),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon(this.asset, {this.size = 18, this.opacity = 1});

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
