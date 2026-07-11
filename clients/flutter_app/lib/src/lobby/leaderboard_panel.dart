part of '../kolkhoz_app.dart';

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel({
    required this.tokens,
    required this.language,
    required this.clientFactory,
    required this.signedIn,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozOnlineClient Function()? clientFactory;
  final bool signedIn;

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  List<OnlineComradeProfile> players = const [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await widget.clientFactory!().fetchLeaderboard();
      if (mounted) setState(() => players = values);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showProfile(OnlineComradeProfile player) async {
    OnlineComradeProfile profile = player;
    try {
      profile = await widget.clientFactory!().fetchPublicProfile(player.userID);
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: widget.tokens.colors.panel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExpandedPlayerProfile(
              tokens: widget.tokens,
              displayName: profile.displayLabel,
              portraitAsset:
                  profile.portraitAsset ?? defaultProfilePortraitAsset,
              subtitle: 'GLOBAL PLAYER PROFILE',
              statGroups: kolkhozProfileStatGroups(
                stats: profile.stats,
                language: widget.language,
              ),
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

  @override
  Widget build(BuildContext context) {
    if (!widget.signedIn) {
      return Center(
        child: Text(
          'SIGN IN TO VIEW THE GLOBAL LEADERBOARD',
          textAlign: TextAlign.center,
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.creamDim,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    if (widget.clientFactory == null) return const SizedBox.shrink();
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: TextButton(
          onPressed: load,
          child: const Text('RETRY LEADERBOARD'),
        ),
      );
    }
    if (players.isEmpty) {
      return Center(
        child: Text(
          'NO RANKED PLAYERS YET',
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.creamDim,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.separated(
        itemCount: players.length,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final player = players[index];
          return InkWell(
            onTap: () => showProfile(player),
            child: PlayerProfileBadge(
              tokens: widget.tokens,
              displayName: player.displayLabel,
              portraitAsset:
                  player.portraitAsset ?? defaultProfilePortraitAsset,
              seatLabel: '#${player.rank ?? index + 1}',
              subtitle: '${player.stats.rating} RATING',
              portraitSize: 46,
              minHeight: 66,
              trailing: Icon(
                Icons.chevron_right,
                color: widget.tokens.colors.gold,
              ),
              statGroups: [
                PlayerProfileStatGroup(
                  label: 'RECORD',
                  stats: [
                    PlayerProfileStat(
                      label: 'WINS',
                      value: '${player.stats.onlineWins}',
                    ),
                    PlayerProfileStat(
                      label: 'GAMES',
                      value: '${player.stats.onlinePlays}',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
