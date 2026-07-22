import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import '../main_menu_view.dart';

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({
    super.key,
    required this.tokens,
    required this.language,
    required this.profileController,
    required this.signedIn,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ProfileController? profileController;
  final bool signedIn;

  @override
  State<LeaderboardView> createState() => _LeaderboardPanelState();
}

enum _LeaderboardView { casual, ranked, comrades }

class _LeaderboardPanelState extends State<LeaderboardView> {
  List<OnlineComradeProfile> players = const [];
  Object? error;
  bool loading = true;
  _LeaderboardView view = _LeaderboardView.ranked;

  bool get usesRankedRating => view != _LeaderboardView.casual;

  List<OnlineComradeProfile> get sortedPlayers {
    final values = [
      for (final player in players)
        if (view != _LeaderboardView.comrades || player.isComrade) player,
    ];
    values.sort((left, right) {
      final ratingComparison = right.stats
          .ratingForGameType(ranked: usesRankedRating)
          .compareTo(left.stats.ratingForGameType(ranked: usesRankedRating));
      if (ratingComparison != 0) return ratingComparison;
      final winsComparison =
          (usesRankedRating ? right.stats.rankedWins : right.stats.casualWins)
              .compareTo(
                usesRankedRating
                    ? left.stats.rankedWins
                    : left.stats.casualWins,
              );
      if (winsComparison != 0) return winsComparison;
      return left.displayLabel.toLowerCase().compareTo(
        right.displayLabel.toLowerCase(),
      );
    });
    return values;
  }

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
      final values = await widget.profileController!.fetchLeaderboard();
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
      profile = await widget.profileController!.fetchPublicProfile(
        player.userID,
      );
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
    if (widget.profileController == null) return const SizedBox.shrink();
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
          'NO PLAYERS YET',
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.creamDim,
          ),
        ),
      );
    }
    final visiblePlayers = sortedPlayers;
    return Column(
      children: [
        Expanded(
          child: SizedBox.expand(
            child: OpenSessionsChromeSurface(
              padding: const EdgeInsets.all(14),
              child: RefreshIndicator(
                onRefresh: load,
                child: visiblePlayers.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'NO COMRADES ON THE LEADERBOARD YET',
                              textAlign: TextAlign.center,
                              style: kolkhozFontStyle.copyWith(
                                color: widget.tokens.colors.creamDim,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visiblePlayers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final player = visiblePlayers[index];
                          return _LeaderboardRow(
                            tokens: widget.tokens,
                            player: player,
                            rating: player.stats.ratingForGameType(
                              ranked: usesRankedRating,
                            ),
                            rank: index + 1,
                            onTap: () => showProfile(player),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: ChromeAssetButton.command(
                  label: 'CASUAL',
                  prominent: view == _LeaderboardView.casual,
                  tokens: widget.tokens,
                  iconAsset: 'assets/ui/Icons/icon-hand.png',
                  expandLabel: false,
                  onPressed: () =>
                      setState(() => view = _LeaderboardView.casual),
                ),
              ),
              Expanded(
                child: ChromeAssetButton.command(
                  label: 'RANKED',
                  prominent: view == _LeaderboardView.ranked,
                  tokens: widget.tokens,
                  iconAsset: 'assets/ui/Icons/icon-medal-star.png',
                  expandLabel: false,
                  onPressed: () =>
                      setState(() => view = _LeaderboardView.ranked),
                ),
              ),
              Expanded(
                child: ChromeAssetButton.command(
                  label: 'COMRADES',
                  prominent: view == _LeaderboardView.comrades,
                  tokens: widget.tokens,
                  iconAsset: 'assets/ui/Icons/icon-comrade.png',
                  expandLabel: false,
                  onPressed: () =>
                      setState(() => view = _LeaderboardView.comrades),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.tokens,
    required this.player,
    required this.rating,
    required this.rank,
    required this.onTap,
  });

  final DesignTokens tokens;
  final OnlineComradeProfile player;
  final int rating;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${player.displayLabel}, rank $rank',
      child: Material(
        color: tokens.colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.sm),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.sm),
              border: Border.all(
                color: tokens.colors.gold.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              children: [
                PlayerProfilePortraitImage(
                  tokens: tokens,
                  asset: player.portraitAsset ?? defaultProfilePortraitAsset,
                  size: 34,
                  selected: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    player.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _LeaderboardStatusIcon(
                  asset: 'assets/ui/Icons/icon-controller-online-player.png',
                  active: player.inGame,
                  activeLabel: 'IN GAME',
                  inactiveLabel: player.isOnline ? 'ONLINE' : 'NOT IN GAME',
                ),
                const SizedBox(width: 5),
                _LeaderboardStatusIcon(
                  asset: 'assets/ui/Icons/icon-comrade.png',
                  active: player.isComrade,
                  activeLabel: 'COMRADE',
                  inactiveLabel: 'NOT A COMRADE',
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Text(
                    '$rating',
                    textAlign: TextAlign.end,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.cardInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '#',
                        style: kolkhozFontStyle.copyWith(
                          color: tokens.colors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      PixelText(
                        '$rank',
                        color: tokens.colors.gold,
                        size: PixelTextSize.caption,
                        variant: PixelTextVariant.heavy,
                        maxLines: 1,
                      ),
                    ],
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

class _LeaderboardStatusIcon extends StatelessWidget {
  const _LeaderboardStatusIcon({
    required this.asset,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  final String asset;
  final bool active;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final label = active ? activeLabel : inactiveLabel;
    return Semantics(
      label: label,
      image: true,
      child: Tooltip(
        message: label,
        child: Opacity(
          opacity: active ? 1 : 0.22,
          child: MainMenuAssetIcon(asset, size: 20),
        ),
      ),
    );
  }
}
