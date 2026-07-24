import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';
import '../main_menu_view.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_lobby_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';

class CreateGameView extends StatefulWidget {
  const CreateGameView({
    super.key,
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.gameLobby,
    required this.demoMode,
    required this.variants,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.favoriteSetup,
    required this.lastStartedSetup,
    required this.comradesSummary,
    required this.compactRail,
    required this.onStart,
    required this.onHostOnline,
    this.onHostOnlineSeries,
    required this.onInviteOnlineComrades,
    required this.onComradeRequestToUser,
    required this.onRememberStartedSetup,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    required this.onSaveFavoriteSetup,
    required this.onUseFavoriteSetup,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final GameLobby? gameLobby;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool compactRail;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  )
  onHostOnline;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
    int bestOf,
  )?
  onHostOnlineSeries;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;

  @override
  State<CreateGameView> createState() => _VariantPanelState();
}

class _VariantPanelState extends State<CreateGameView> {
  static const setupPageKey = ValueKey('create-game-setup-page');
  static const lobbyPageKey = ValueKey('create-game-lobby-page');

  late List<_LobbySeatChoice> seatChoices;
  final Map<int, String> selectedComradeUserIDsBySeat = {};
  bool showingSeatLobby = false;
  bool startingOnline = false;
  bool browserJoinable = true;
  int bestOf = 1;
  String? onlineStatus;
  bool onlineStatusIsError = false;
  bool onlineStatusDisablesAction = false;

  @override
  void initState() {
    super.initState();
    seatChoices = _initialSeatChoices();
    browserJoinable = widget.lastStartedSetup?.browserJoinable ?? true;
    showingSeatLobby = widget.lastStartedSetup != null && !widget.demoMode;
  }

  @override
  void didUpdateWidget(covariant CreateGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.demoMode && !oldWidget.demoMode) {
      showingSeatLobby = false;
    }
    if (widget.lastStartedSetup != oldWidget.lastStartedSetup &&
        widget.lastStartedSetup != null &&
        !showingSeatLobby &&
        !widget.demoMode) {
      seatChoices = _initialSeatChoices();
      browserJoinable = widget.lastStartedSetup!.browserJoinable;
      showingSeatLobby = true;
    }
  }

  List<_LobbySeatChoice> _initialSeatChoices() {
    final lastStartedSetup = widget.lastStartedSetup;
    if (lastStartedSetup == null || widget.demoMode) {
      return _LobbySeatChoice.emptySetupChoices();
    }
    return _LobbySeatChoice.fromStoredValues(
      lastStartedSetup.lobbySeats,
      fallbackControllers: lastStartedSetup.controllers,
    );
  }

  List<_LobbySeatChoice> get effectiveSeatChoices {
    if (widget.demoMode) {
      return _LobbySeatChoice.fromControllers(
        KolkhozPlayerController.demoControllers,
      );
    }
    return seatChoices;
  }

  List<KolkhozPlayerController> get effectiveControllers {
    return _LobbySeatChoice.toControllers(effectiveSeatChoices);
  }

  bool get hasOnlineSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.online) ||
      effectiveSeatChoices.contains(_LobbySeatChoice.comrade);

  bool get hasUnassignedSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.empty);

  bool get hasUnassignedComradeSeats {
    for (var playerID = 1; playerID < kolkhozPlayerCount; playerID += 1) {
      final userID = selectedComradeUserIDsBySeat[playerID];
      if (effectiveSeatChoices[playerID] == _LobbySeatChoice.comrade &&
          !_hasComradeUserID(userID)) {
        return true;
      }
    }
    return false;
  }

  void setOnlineStatus(String? message) {
    onlineStatus = message;
    onlineStatusIsError = false;
    onlineStatusDisablesAction = false;
  }

  void setOnlineFailure(Object exception) {
    onlineStatus = onlineFailureStatusMessage(exception, widget.language);
    onlineStatusIsError = true;
    onlineStatusDisablesAction = false;
  }

  List<String> get invitedComradeUserIDs {
    final userIDs = <String>{};
    for (var playerID = 1; playerID < kolkhozPlayerCount; playerID += 1) {
      if (effectiveSeatChoices[playerID] == _LobbySeatChoice.comrade) {
        final userID = selectedComradeUserIDsBySeat[playerID];
        if (_hasComradeUserID(userID)) {
          userIDs.add(userID!);
        }
      }
    }
    return userIDs.toList(growable: false);
  }

  bool _hasComradeUserID(String? userID) {
    if (userID == null || userID.isEmpty) {
      return false;
    }
    return widget.comradesSummary.comrades.any(
      (comrade) => comrade.userID == userID,
    );
  }

  void setSeatChoice(int playerID, _LobbySeatChoice choice) {
    final next = List<_LobbySeatChoice>.of(effectiveSeatChoices);
    next[playerID] = choice;
    final exclusive = _LobbySeatChoice.withExclusiveHumanMode(
      next,
      changedPlayerID: playerID,
    );
    setState(() {
      seatChoices = exclusive;
      if (choice == _LobbySeatChoice.comrade) {
        final comrades = widget.comradesSummary.comrades;
        if (selectedComradeUserIDsBySeat[playerID] == null &&
            comrades.isNotEmpty) {
          selectedComradeUserIDsBySeat[playerID] = comrades.first.userID;
        }
        browserJoinable = false;
      } else {
        selectedComradeUserIDsBySeat.remove(playerID);
      }
      for (var index = 1; index < kolkhozPlayerCount; index += 1) {
        if (exclusive[index] != _LobbySeatChoice.comrade) {
          selectedComradeUserIDsBySeat.remove(index);
        }
      }
      setOnlineStatus(null);
    });
    widget.onPlayerControllersChanged(
      _LobbySeatChoice.toControllers(exclusive),
    );
  }

  void setSeatComrade(int playerID, String userID) {
    setState(() {
      selectedComradeUserIDsBySeat[playerID] = userID;
      setOnlineStatus(null);
    });
  }

  Future<void> startGame() async {
    if (!hasOnlineSeats) {
      rememberEffectiveSetup();
      widget.onPlayerControllersChanged(effectiveControllers);
      widget.onStart();
      return;
    }
    if (startingOnline) {
      return;
    }
    setState(() {
      startingOnline = true;
      setOnlineStatus(null);
    });
    try {
      final sessionID = bestOf == 1 || widget.onHostOnlineSeries == null
          ? await widget.onHostOnline(
              onlineServerURL,
              effectiveControllers,
              false,
              false,
              browserJoinable,
            )
          : await widget.onHostOnlineSeries!(
              onlineServerURL,
              effectiveControllers,
              false,
              false,
              browserJoinable,
              bestOf,
            );
      await widget.onInviteOnlineComrades?.call(
        sessionID,
        invitedComradeUserIDs,
      );
      rememberEffectiveSetup();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        setOnlineFailure(exception);
      });
    } finally {
      if (mounted) {
        setState(() => startingOnline = false);
      }
    }
  }

  void rememberEffectiveSetup() {
    widget.onRememberStartedSetup?.call(
      effectiveControllers,
      _LobbySeatChoice.storedValues(effectiveSeatChoices),
      browserJoinable,
    );
  }

  void useFavoriteSetup() {
    final favorite = widget.favoriteSetup;
    if (favorite == null || widget.demoMode) {
      return;
    }
    setState(() {
      seatChoices = _LobbySeatChoice.fromControllers(favorite.controllers);
      setOnlineStatus(null);
    });
    widget.onUseFavoriteSetup?.call();
  }

  Future<void> copyHostedInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      setOnlineStatus(widget.language.strings.kolkhozappCopied);
    });
  }

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      MaterialPage<void>(key: setupPageKey, child: _buildSetupStep()),
      if (showingSeatLobby && !widget.demoMode)
        MaterialPage<void>(key: lobbyPageKey, child: _buildLobbyStep()),
    ],
    onDidRemovePage: (page) {
      if (page.key == lobbyPageKey && showingSeatLobby) {
        setState(() => showingSeatLobby = false);
      }
    },
  );

  void showLobbyStep(bool show) {
    if (showingSeatLobby == show) {
      return;
    }
    setState(() => showingSeatLobby = show);
  }

  Widget _buildSetupStep() => _buildFieldPlanSetupStep();

  Widget _buildFieldPlanSetupStep() {
    final custom =
        widget.selectedPreset == KolkhozGamePreset.custom && !widget.demoMode;
    return PrintedPaperSurface(
      child: Padding(
        padding: EdgeInsets.all(widget.compactRail ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: widget.compactRail ? 7 : 10,
          children: [
            _FieldPlanPresetSelector(
              language: widget.language,
              selectedPreset: widget.selectedPreset,
              compact: widget.compactRail,
              onPresetChanged: widget.demoMode ? null : widget.onPresetChanged,
            ),
            Expanded(
              child: KolkhozScrollbar(
                tokens: widget.tokens,
                childBuilder: (context, scrollController) =>
                    SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(right: 8, bottom: 12),
                      child: custom
                          ? CustomVariantOptions(
                              tokens: widget.tokens,
                              language: widget.language,
                              variants: widget.customVariants,
                              compact: widget.compactRail,
                              onChanged: widget.onCustomVariantsChanged,
                            )
                          : _FieldPlanVariantLedger(
                              language: widget.language,
                              variants: widget.variants,
                              demoMode: widget.demoMode,
                              compact: widget.compactRail,
                            ),
                    ),
              ),
            ),
            if (widget.demoMode)
              _primaryCommandButton(
                label: widget.language.strings.kolkhozappStartDemo,
                iconAsset: 'assets/ui/Icons/icon-demo.png',
                onPressed: startGame,
              )
            else
              _setupCommandRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyStep() {
    final hostedOnlineUpdate = widget.showHostedInviteCode
        ? widget.onlineSessionUpdate
        : null;
    if (hostedOnlineUpdate != null) {
      return _buildHostedOnlineLobbyStep(hostedOnlineUpdate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
        ),
        if (onlineStatus != null &&
            (!onlineStatusIsError || !onlineStatusDisablesAction))
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        MainMenuGoldDivider(tokens: widget.tokens),
        Expanded(
          child: KolkhozScrollbar(
            tokens: widget.tokens,
            childBuilder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    _SeatLobbyEditor(
                      tokens: widget.tokens,
                      language: widget.language,
                      choices: effectiveSeatChoices,
                      displayName: widget.displayName,
                      portraitAsset: widget.portraitAsset,
                      profileStats: widget.profileStats,
                      comrades: widget.comradesSummary.comrades,
                      selectedComradeUserIDsBySeat:
                          selectedComradeUserIDsBySeat,
                      onComradeChanged: widget.demoMode ? null : setSeatComrade,
                      onChanged: widget.demoMode ? null : setSeatChoice,
                      compact: widget.compactRail,
                    ),
                    if (hasOnlineSeats)
                      _MatchFormatSelector(
                        tokens: widget.tokens,
                        value: bestOf,
                        enabled: true,
                        onChanged: (value) => setState(() => bestOf = value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _lobbyCommandRow(),
      ],
    );
  }

  Widget _lobbyCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(height: height),
        ),
        _OnlineGameOptionToggle(
          tokens: widget.tokens,
          title: widget.language.strings.kolkhozappAccess,
          label: browserJoinable
              ? widget.language.strings.kolkhozappBrowser
              : widget.language.strings.kolkhozappLocked,
          selected: browserJoinable,
          enabled: hasOnlineSeats,
          iconAsset: browserJoinable
              ? 'assets/ui/Icons/icon-online.png'
              : 'assets/ui/Icons/icon-lock.png',
          onTap: () => setState(() => browserJoinable = !browserJoinable),
        ),
        Expanded(
          child: _primaryCommandButton(
            label: _startButtonLabel(),
            iconAsset: _startButtonIconAsset(),
            onPressed:
                startingOnline ||
                    _startButtonShowsBan() ||
                    hasUnassignedSeats ||
                    hasUnassignedComradeSeats
                ? null
                : startGame,
            enabled:
                !_startButtonShowsBan() &&
                !hasUnassignedSeats &&
                !hasUnassignedComradeSeats,
          ),
        ),
      ],
    );
  }

  Widget _backToSetupButton({
    required double height,
    Key? key,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: height,
      child: ChromeAssetButton.command(
        key: key,
        label: widget.language.strings.kolkhozappBackToSetup,
        prominent: false,
        tokens: widget.tokens,
        iconAsset: 'assets/ui/Icons/icon-toolbar-undo.png',
        iconSize: widget.compactRail ? 18 : 22,
        textSize: widget.compactRail
            ? PixelTextSize.caption
            : PixelTextSize.headline,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        expandLabel: false,
        onPressed: onPressed ?? () => showLobbyStep(false),
      ),
    );
  }

  Widget _buildHostedOnlineLobbyStep(OnlineSessionUpdate update) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
          ranked: update.ranked,
        ),
        if (onlineStatus != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        MainMenuGoldDivider(tokens: widget.tokens),
        Expanded(
          child: OnlineWaitingRoomPanel(
            tokens: widget.tokens,
            language: widget.language,
            update: update,
            lobby:
                widget.gameLobby ??
                gameLobbyFromOnlineUpdate(
                  update,
                  viewerSeatID: update.viewerID,
                ),
            inviteCode: widget.hostedInviteCode,
            onCopyInviteCode: widget.hostedInviteCode == null
                ? null
                : () =>
                      unawaited(copyHostedInviteCode(widget.hostedInviteCode!)),
            showHeaderCancel: false,
            showInviteCard: false,
            showJoinButton: false,
            showDetails: false,
            currentUserID: widget.comradesSummary.userID,
            comradeUserIDs: widget.comradesSummary.userIDs,
            incomingComradeRequestUserIDs: {
              for (final request in widget.comradesSummary.incomingRequests)
                request.userID,
            },
            outgoingComradeRequestUserIDs: {
              for (final request in widget.comradesSummary.outgoingRequests)
                request.userID,
            },
            onComradeRequestToUser: widget.onComradeRequestToUser,
            canKickPlayers: !update.started,
            onKickPlayer: widget.onKickOnlinePlayer,
            onEnterOnlineGame: widget.onEnterOnlineGame,
            onCancelOnlineGame: widget.onCancelOnlineGame,
          ),
        ),
        _hostedLobbyCommandRow(update),
      ],
    );
  }

  Widget _hostedLobbyCommandRow(OnlineSessionUpdate update) {
    final height = widget.compactRail ? 50.0 : 56.0;
    final countdownSeconds = update.lobbyCountdownSeconds;
    final waitingLabel = countdownSeconds == null
        ? widget.language.strings.kolkhozappWaitingForPlayers
        : widget.language.strings.kolkhozappGameStartsInValue1s(
            value1: countdownSeconds,
          );
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(
            height: height,
            key: const Key('hosted-online-back-to-setup'),
            onPressed: widget.onCancelOnlineGame ?? () => showLobbyStep(false),
          ),
        ),
        if (widget.hostedInviteCode != null)
          SizedBox(
            width: widget.compactRail ? 134 : 164,
            child: Semantics(
              button: true,
              label:
                  '${widget.language.strings.kolkhozappInviteCode} ${widget.hostedInviteCode!}',
              child: ExcludeSemantics(
                child: Tooltip(
                  message: widget.language.strings.kolkhozappCopyCode,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(
                      copyHostedInviteCode(widget.hostedInviteCode!),
                    ),
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
                                const MainMenuAssetIcon(
                                  'assets/ui/Icons/icon-add-friend.png',
                                  size: 22,
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 2,
                                    children: [
                                      ChromeScaledLabel(
                                        widget
                                            .language
                                            .strings
                                            .kolkhozappInviteCode,
                                        color: widget.tokens.colors.cardInk,
                                        size: PixelTextSize.xSmall,
                                        textAlign: TextAlign.start,
                                      ),
                                      ChromeScaledLabel(
                                        widget.hostedInviteCode!,
                                        color: widget.tokens.colors.cardInk,
                                        size: PixelTextSize.caption,
                                        textAlign: TextAlign.start,
                                      ),
                                    ],
                                  ),
                                ),
                                const MainMenuAssetIcon(
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
            ),
          ),
        Expanded(
          child: WaitingRoomEnterButton(
            tokens: widget.tokens,
            language: widget.language,
            tableReady: update.started,
            waitingLabel: waitingLabel,
            height: height,
            onPressed: widget.onEnterOnlineGame,
          ),
        ),
      ],
    );
  }

  Widget _primaryCommandButton({
    required String label,
    required String iconAsset,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      height: widget.compactRail ? 50.0 : 56.0,
      child: ChromeAssetButton.command(
        width: double.infinity,
        padding: widget.compactRail
            ? const EdgeInsets.symmetric(horizontal: 8)
            : null,
        label: label,
        prominent: true,
        tokens: widget.tokens,
        onPressed: onPressed,
        enabled: enabled,
        disabledOpacity: 0.72,
        iconAsset: iconAsset,
        iconSize: widget.compactRail ? 22 : 28,
        textSize: widget.compactRail
            ? PixelTextSize.headline
            : PixelTextSize.title,
        expandLabel: false,
      ),
    );
  }

  Widget _setupCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    final secondaryTextSize = widget.compactRail
        ? PixelTextSize.caption
        : PixelTextSize.headline;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.strings.kolkhozappSaveFavorite,
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.onSaveFavoriteSetup,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('save-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.strings.kolkhozappUseFavorite,
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.favoriteSetup != null ? useFavoriteSetup : null,
              enabled: widget.favoriteSetup != null,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('use-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              width: double.infinity,
              label: widget.language.strings.kolkhozappContinueToLobby,
              prominent: true,
              tokens: widget.tokens,
              onPressed: () => showLobbyStep(true),
              iconAsset: 'assets/ui/Icons/icon-add-friend.png',
              iconSize: widget.compactRail ? 22 : 28,
              textSize: widget.compactRail
                  ? PixelTextSize.headline
                  : PixelTextSize.title,
              padding: widget.compactRail
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : null,
              expandLabel: false,
            ),
          ),
        ),
      ],
    );
  }

  bool _startButtonShowsBan() {
    return onlineStatus != null && onlineStatusDisablesAction;
  }

  String _startButtonLabel() {
    if (_startButtonShowsBan()) {
      return onlineStatus!;
    }
    if (startingOnline) {
      return widget.language.strings.kolkhozappWorking;
    }
    if (hasOnlineSeats) {
      return widget.language.strings.kolkhozappStartOnlineGame;
    }
    return widget.language.strings.kolkhozappStartOfflineGame;
  }

  String _startButtonIconAsset() {
    if (_startButtonShowsBan()) {
      return 'assets/ui/Icons/icon-warning.png';
    }
    return 'assets/ui/Icons/icon-create-game.png';
  }
}

class _MatchFormatSelector extends StatelessWidget {
  const _MatchFormatSelector({
    required this.tokens,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          'MATCH FORMAT',
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Row(
          spacing: 8,
          children: [
            for (final option in const [
              (1, 'SINGLE', 'assets/ui/Icons/icon-match-single.png'),
              (3, 'BEST OF 3', 'assets/ui/Icons/icon-match-best-of-3.png'),
              (5, 'BEST OF 5', 'assets/ui/Icons/icon-match-best-of-5.png'),
            ])
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ChromeAssetButton.command(
                    label: option.$2,
                    prominent: value == option.$1,
                    tokens: tokens,
                    iconAsset: option.$3,
                    iconSize: 28,
                    expandLabel: false,
                    onPressed: enabled ? () => onChanged(option.$1) : null,
                    surfaceKey: Key('match-format-${option.$1}'),
                  ),
                ),
              ),
          ],
        ),
        Text(
          value == 1
              ? 'ONE GAME'
              : 'FIRST TO ${value ~/ 2 + 1} WINS • SEATS MAY CHANGE BETWEEN GAMES',
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PresetSummaryStrip extends StatelessWidget {
  const _PresetSummaryStrip({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.compact,
    this.ranked,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool compact;
  final bool? ranked;

  @override
  Widget build(BuildContext context) {
    final majorPreset = presetForVariants(variants);
    final icons = [
      if (majorPreset.iconAsset != null)
        _VariantHeaderIconData(
          label: presetTitle(majorPreset, language),
          description: VariantRowData.summaryRows(
            variants,
          ).map((row) => row.localizedTitle(language, variants)).join(' • '),
          iconAsset: majorPreset.iconAsset!,
          showLabel: true,
        ),
      for (final row in VariantRowData.summaryRows(variants))
        _VariantHeaderIconData(
          label: row.localizedTitle(language, variants),
          description: row.localizedDescription(language, variants),
          iconAsset: row.iconAssetFor(variants),
        ),
      if (ranked != null)
        _VariantHeaderIconData(
          label: language.t(
            ranked!
                ? KolkhozText.kolkhozappRanked
                : KolkhozText.kolkhozappCasual,
          ),
          iconAsset: ranked!
              ? 'assets/ui/Icons/icon-medal-star.png'
              : 'assets/ui/Icons/icon-foreman-misha.png',
        ),
    ];
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 5 : 7,
        runSpacing: compact ? 5 : 7,
        children: [
          for (final icon in icons)
            _VariantHeaderIconChip(
              label: icon.label,
              description: icon.description,
              iconAsset: icon.iconAsset,
              showLabel: icon.showLabel,
              tokens: tokens,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _VariantHeaderIconData {
  const _VariantHeaderIconData({
    required this.label,
    this.description = '',
    required this.iconAsset,
    this.showLabel = false,
  });

  final String label;
  final String description;
  final String iconAsset;
  final bool showLabel;
}

class _VariantHeaderIconChip extends StatelessWidget {
  const _VariantHeaderIconChip({
    required this.label,
    required this.description,
    required this.iconAsset,
    required this.showLabel,
    required this.tokens,
    required this.compact,
  });

  final String label;
  final String description;
  final String iconAsset;
  final bool showLabel;
  final DesignTokens tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = showLabel
        ? (compact ? 128.0 : 154.0)
        : (compact ? 42.0 : 48.0);
    final height = compact ? 38.0 : 44.0;
    final iconSize = showLabel
        ? (compact ? 25.0 : 29.0)
        : (compact ? 28.0 : 33.0);
    final tooltipText = TextSpan(
      style: kolkhozFontStyle.copyWith(
        color: tokens.colors.cardInk,
        fontSize: compact ? 13 : 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      children: [
        TextSpan(
          text: label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (description.isNotEmpty) TextSpan(text: '\n$description'),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          richMessage: tooltipText,
          triggerMode: TooltipTriggerMode.tap,
          waitDuration: const Duration(milliseconds: 250),
          showDuration: const Duration(seconds: 8),
          exitDuration: const Duration(milliseconds: 150),
          preferBelow: true,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: tokens.colors.cardFill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.82),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: ChromeButtonBackground(
                    asset: chromeButtonPrimaryAsset,
                  ),
                ),
                if (showLabel)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: compact ? 5 : 7,
                      children: [
                        VariantIcon(iconAsset, size: iconSize),
                        Expanded(
                          child: ChromeScaledLabel(
                            label,
                            color: tokens.colors.onAccent,
                            size: compact
                                ? PixelTextSize.caption2
                                : PixelTextSize.caption,
                            uppercase: false,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  VariantIcon(iconAsset, size: iconSize),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanPresetSelector extends StatelessWidget {
  const _FieldPlanPresetSelector({
    required this.language,
    required this.selectedPreset,
    required this.compact,
    required this.onPresetChanged,
  });

  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final bool compact;
  final ValueChanged<KolkhozGamePreset>? onPresetChanged;

  ArtAssetRef _assetFor(KolkhozGamePreset preset) => switch (preset) {
    KolkhozGamePreset.kolkhoz => fieldPlanPresetKolkhoz,
    KolkhozGamePreset.littleKolkhoz => fieldPlanPresetLittleKolkhoz,
    KolkhozGamePreset.campStyle => fieldPlanPresetCampStyle,
    KolkhozGamePreset.custom => fieldPlanPresetCustom,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        final height = compact || narrow ? 60.0 : 76.0;
        return SizedBox(
          height: narrow ? height * 2 + 6 : height,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: narrow ? 2 : 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: narrow
                ? constraints.maxWidth / 2 / height
                : constraints.maxWidth / 4 / height,
            children: [
              for (final preset in betaGamePresets)
                Semantics(
                  button: true,
                  selected: selectedPreset == preset,
                  label: presetTitle(preset, language),
                  child: InkWell(
                    key: Key('field-plan-preset-${preset.name}'),
                    onTap: onPresetChanged == null
                        ? null
                        : () => onPresetChanged!(preset),
                    child: PrintedUnderlay(
                      tone: selectedPreset == preset
                          ? PrintedUnderlayTone.primary
                          : PrintedUnderlayTone.neutral,
                      focused: selectedPreset == preset,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ArtAssetImage(
                            asset: _assetFor(preset),
                            width: compact ? 34 : 46,
                            height: compact ? 34 : 46,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              presetTitle(preset, language).toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: fieldPlanDisplayTextStyle.copyWith(
                                color: selectedPreset == preset
                                    ? const Color(0xfff4dfad)
                                    : const Color(0xff20251d),
                                fontSize: compact ? 14 : 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldPlanVariantLedger extends StatelessWidget {
  const _FieldPlanVariantLedger({
    required this.language,
    required this.variants,
    required this.demoMode,
    required this.compact,
  });

  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool demoMode;
  final bool compact;

  ArtAssetRef? _newAssetFor(VariantRowData row) {
    if (identical(row, VariantRowData.deckType)) return fieldPlanVariantDeck;
    if (identical(row, VariantRowData.maxYears)) {
      return fieldPlanVariantFiveYearPlan;
    }
    if (identical(row, VariantRowData.allowSwap)) {
      return fieldPlanVariantSwapCards;
    }
    if (identical(row, VariantRowData.passCards)) {
      return fieldPlanVariantPassCards;
    }
    if (identical(row, VariantRowData.finalYearTrump)) {
      return fieldPlanVariantFinalYearTrump;
    }
    if (identical(row, VariantRowData.highestCardsRequisition)) {
      return fieldPlanVariantHighestCardsRequisition;
    }
    if (identical(row, VariantRowData.lottoRewards)) {
      return fieldPlanVariantLottoRewards;
    }
    if (identical(row, VariantRowData.accumulateJobs)) {
      return fieldPlanVariantStakhanovite;
    }
    if (identical(row, VariantRowData.wrecker)) {
      return fieldPlanVariantSaboteur;
    }
    return null;
  }

  Widget _iconFor(VariantRowData row) {
    final newAsset = _newAssetFor(row);
    if (newAsset != null) {
      return ArtAssetImage(asset: newAsset, fit: BoxFit.contain);
    }
    return VariantIcon(row.iconAssetFor(variants), size: compact ? 42 : 56);
  }

  @override
  Widget build(BuildContext context) {
    final rows = VariantRowData.summaryRows(variants, demoMode: demoMode);
    return Column(
      spacing: compact ? 6 : 8,
      children: [
        for (var index = 0; index < rows.length; index++)
          SizedBox(
            height: compact ? 68 : 84,
            child: PrintedUnderlay(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: 6,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 30 : 40,
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: fieldPlanDisplayTextStyle.copyWith(
                        color: const Color(0xffa33a28),
                        fontSize: compact ? 22 : 28,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? 50 : 66,
                    child: _iconFor(rows[index]),
                  ),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[index]
                              .localizedTitle(language, variants)
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: fieldPlanDisplayTextStyle.copyWith(
                            color: const Color(0xff20251d),
                            fontSize: compact ? 17 : 23,
                          ),
                        ),
                        if (!compact &&
                            rows[index]
                                .localizedDescription(language, variants)
                                .isNotEmpty)
                          Text(
                            rows[index].localizedDescription(
                              language,
                              variants,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: fieldPlanBodyTextStyle.copyWith(
                              color: const Color(0xff3d4437),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PrintedSelectionStamp(size: 30),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SeatLobbyEditor extends StatelessWidget {
  const _SeatLobbyEditor({
    required this.tokens,
    required this.language,
    required this.choices,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.comrades,
    required this.selectedComradeUserIDsBySeat,
    required this.onComradeChanged,
    required this.onChanged,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_LobbySeatChoice> choices;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final List<OnlineComradeProfile> comrades;
  final Map<int, String> selectedComradeUserIDsBySeat;
  final void Function(int playerID, String userID)? onComradeChanged;
  final void Function(int playerID, _LobbySeatChoice choice)? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = _LobbySeatChoice.normalized(choices);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 660 && !compact
            ? 4
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 8.0;
        final columnWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
              SizedBox(
                width: columnWidth,
                child: _SeatLobbyColumn(
                  tokens: tokens,
                  language: language,
                  playerID: playerID,
                  choice: normalized[playerID],
                  displayName: displayName,
                  portraitAsset: portraitAsset,
                  profileStats: profileStats,
                  comrades: comrades,
                  selectedComradeUserID: selectedComradeUserIDsBySeat[playerID],
                  choices: normalized,
                  options: _LobbySeatChoice.optionsForPlayer(playerID),
                  onComradeChanged: onComradeChanged == null || playerID == 0
                      ? null
                      : (userID) => onComradeChanged!(playerID, userID),
                  onChanged: onChanged == null || playerID == 0
                      ? null
                      : (choice) => onChanged!(playerID, choice),
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatLobbyColumn extends StatelessWidget {
  const _SeatLobbyColumn({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.choice,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.comrades,
    required this.selectedComradeUserID,
    required this.choices,
    required this.options,
    required this.onComradeChanged,
    required this.onChanged,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final List<OnlineComradeProfile> comrades;
  final String? selectedComradeUserID;
  final List<_LobbySeatChoice> choices;
  final List<_LobbySeatChoice> options;
  final ValueChanged<String>? onComradeChanged;
  final ValueChanged<_LobbySeatChoice>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playerLabel = language.strings.kolkhozappPValue1(
      value1: playerID + 1,
    );
    final localProfile = playerID == 0 && choice == _LobbySeatChoice.local;
    final selectedComrade = choice == _LobbySeatChoice.comrade
        ? _selectedComrade()
        : null;
    final occupantLabel = localProfile
        ? displayName
        : selectedComrade != null
        ? selectedComrade.displayLabel
        : choice.shortTitle(language);
    final subtitle = localProfile
        ? profileRatingSummary(language, profileStats)
        : selectedComrade != null
        ? comradePresenceSummary(language, selectedComrade)
        : choice == _LobbySeatChoice.empty
        ? language.strings.kolkhozappOpen
        : choice.shortTitle(language);
    final semanticLabel = '$playerLabel $occupantLabel';
    final card = PlayerProfileBadge(
      tokens: tokens,
      displayName: occupantLabel,
      portraitAsset: localProfile
          ? portraitAsset
          : selectedComrade?.portraitAsset ??
                _seatPortraitAsset(playerID, choice),
      seatLabel: playerLabel,
      subtitle: subtitle,
      subtitleIconAsset: localProfile ? null : choice.iconAsset,
      portraitSize: compact ? 42 : 48,
      minHeight: compact ? 78 : 92,
      active: playerID == 0,
      muted: choice == _LobbySeatChoice.empty,
    );
    if (onChanged != null) {
      final visibleOptions = options
          .where((option) => option != _LobbySeatChoice.empty)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: compact ? 6 : 8,
        children: [
          ExcludeSemantics(child: card),
          for (final option in visibleOptions)
            _SeatChoiceOptionButton(
              tokens: tokens,
              language: language,
              playerLabel: playerLabel,
              option: option,
              selected: option == choice,
              enabled: _LobbySeatChoice.isOptionEnabledForPlayer(
                playerID,
                choices,
                option,
              ),
              compact: compact,
              onPressed: () => onChanged!(option),
            ),
          if (choice == _LobbySeatChoice.comrade)
            _SeatComradePicker(
              tokens: tokens,
              language: language,
              comrades: comrades,
              selectedUserID: selectedComradeUserID,
              compact: compact,
              onChanged: onComradeChanged,
            ),
        ],
      );
    }
    return Semantics(
      button: true,
      enabled: onChanged != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: PopupMenuButton<_LobbySeatChoice>(
            tooltip: semanticLabel,
            enabled: onChanged != null,
            offset: const Offset(0, -172),
            color: tokens.colors.panel,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (final option in options)
                PopupMenuItem(
                  value: option,
                  enabled: _LobbySeatChoice.isOptionEnabledForPlayer(
                    playerID,
                    choices,
                    option,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      MainMenuAssetIcon(
                        option.iconAsset,
                        size: 24,
                        opacity: option == choice ? 1 : 0.72,
                      ),
                      Text(
                        option.shortTitle(language).toUpperCase(),
                        style: kolkhozFontStyle.copyWith(
                          color: option == choice
                              ? tokens.colors.goldBright
                              : _LobbySeatChoice.isOptionEnabledForPlayer(
                                  playerID,
                                  choices,
                                  option,
                                )
                              ? tokens.colors.creamDim
                              : tokens.colors.creamDim.withValues(alpha: 0.48),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: card,
          ),
        ),
      ),
    );
  }

  OnlineComradeProfile? _selectedComrade() {
    for (final comrade in comrades) {
      if (comrade.userID == selectedComradeUserID) {
        return comrade;
      }
    }
    return null;
  }

  String _seatPortraitAsset(int playerID, _LobbySeatChoice choice) {
    if (choice == _LobbySeatChoice.empty) {
      return 'worker${playerID + 1}';
    }
    final iconAsset = choice.iconAsset;
    const prefix = 'assets/ui/';
    const suffix = '.png';
    if (iconAsset.startsWith(prefix) && iconAsset.endsWith(suffix)) {
      return iconAsset.substring(
        prefix.length,
        iconAsset.length - suffix.length,
      );
    }
    return 'worker${playerID + 1}';
  }
}

class _SeatComradePicker extends StatelessWidget {
  const _SeatComradePicker({
    required this.tokens,
    required this.language,
    required this.comrades,
    required this.selectedUserID,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineComradeProfile> comrades;
  final String? selectedUserID;
  final bool compact;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedComrade();
    final label =
        selected?.displayLabel ?? language.strings.kolkhozappNoComrades;
    final enabled = onChanged != null && comrades.isNotEmpty;
    return Tooltip(
      message: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: PopupMenuButton<String>(
          enabled: enabled,
          tooltip: label,
          color: tokens.colors.panel,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final comrade in comrades)
              PopupMenuItem(
                value: comrade.userID,
                child: Row(
                  spacing: 8,
                  children: [
                    PlayerProfilePortraitImage(
                      tokens: tokens,
                      asset:
                          comrade.portraitAsset ?? defaultProfilePortraitAsset,
                      size: 28,
                      selected: comrade.userID == selectedUserID,
                    ),
                    Expanded(
                      child: Text(
                        comrade.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kolkhozFontStyle.copyWith(
                          color: comrade.userID == selectedUserID
                              ? tokens.colors.goldBright
                              : tokens.colors.creamDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: SizedBox(
            height: compact ? 34 : 38,
            child: VariantRowBackground(
              tokens: tokens,
              active: selected != null,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 6 : 7,
              ),
              child: Row(
                spacing: 8,
                children: [
                  MainMenuAssetIcon(
                    'assets/ui/Icons/icon-comrade.png',
                    size: compact ? 20 : 24,
                    opacity: selected != null ? 1 : 0.7,
                  ),
                  Expanded(
                    child: ChromeScaledLabel(
                      label,
                      color: selected != null
                          ? tokens.colors.activeSurfaceText
                          : tokens.colors.cardInk.withValues(alpha: 0.72),
                      size: compact
                          ? PixelTextSize.caption2
                          : PixelTextSize.caption,
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

  OnlineComradeProfile? _selectedComrade() {
    for (final comrade in comrades) {
      if (comrade.userID == selectedUserID) {
        return comrade;
      }
    }
    return null;
  }
}

class _SeatChoiceOptionButton extends StatelessWidget {
  const _SeatChoiceOptionButton({
    required this.tokens,
    required this.language,
    required this.playerLabel,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String playerLabel;
  final _LobbySeatChoice option;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = option.shortTitle(language);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$playerLabel $label',
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: enabled ? 1 : 0.54,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: compact ? 34 : 38,
                child: VariantRowBackground(
                  tokens: tokens,
                  active: selected,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 6 : 7,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      MainMenuAssetIcon(
                        option.iconAsset,
                        size: compact ? 20 : 24,
                        opacity: selected ? 1 : 0.82,
                      ),
                      Expanded(
                        child: ChromeScaledLabel(
                          label,
                          color: selected
                              ? tokens.colors.activeSurfaceText
                              : tokens.colors.cardInk,
                          size: compact
                              ? PixelTextSize.caption2
                              : PixelTextSize.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineGameOptionToggle extends StatelessWidget {
  const _OnlineGameOptionToggle({
    required this.tokens,
    required this.title,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.iconAsset,
    required this.onTap,
  });

  final DesignTokens tokens;
  final String title;
  final String label;
  final bool selected;
  final bool enabled;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: enabled ? 1 : 0.58,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 138,
                height: 62,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ChromeButtonBackground(
                        asset: selected
                            ? chromeButtonPrimaryAsset
                            : chromeButtonSecondaryAsset,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                      child: Row(
                        spacing: 8,
                        children: [
                          MainMenuAssetIcon(
                            iconAsset,
                            size: 30,
                            opacity: selected ? 1 : 0.82,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 2,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 13,
                                  child: ChromeScaledLabel(
                                    title,
                                    color: foreground.withValues(alpha: 0.68),
                                    size: PixelTextSize.caption2,
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 18,
                                  child: ChromeScaledLabel(
                                    label,
                                    color: foreground,
                                    size: PixelTextSize.caption,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

enum _LobbySeatChoice {
  empty,
  local,
  online,
  comrade,
  easyAI,
  mediumAI,
  hardAI;

  static List<_LobbySeatChoice> emptySetupChoices() {
    return const [
      _LobbySeatChoice.local,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
    ];
  }

  static List<_LobbySeatChoice> fromControllers(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return [for (final controller in normalized) fromController(controller)];
  }

  static List<_LobbySeatChoice> fromStoredValues(
    List<String> values, {
    required List<KolkhozPlayerController> fallbackControllers,
  }) {
    if (values.isEmpty) {
      return fromControllers(fallbackControllers);
    }
    try {
      return withExclusiveHumanMode(
        normalized([
          for (final value in values)
            _LobbySeatChoice.values.firstWhere(
              (choice) => choice.name == value,
            ),
        ]),
      );
    } catch (_) {
      return fromControllers(fallbackControllers);
    }
  }

  static _LobbySeatChoice fromController(KolkhozPlayerController controller) {
    return switch (controller) {
      KolkhozPlayerController.human => _LobbySeatChoice.local,
      KolkhozPlayerController.heuristicAI => _LobbySeatChoice.easyAI,
      KolkhozPlayerController.mediumAI => _LobbySeatChoice.mediumAI,
      KolkhozPlayerController.neuralAI => _LobbySeatChoice.hardAI,
    };
  }

  static List<_LobbySeatChoice> normalized(List<_LobbySeatChoice> choices) {
    final normalized = List<_LobbySeatChoice>.generate(
      kolkhozPlayerCount,
      (index) => index < choices.length
          ? choices[index]
          : fromController(KolkhozPlayerController.defaultControllers[index]),
    );
    if (normalized.first == _LobbySeatChoice.empty ||
        normalized.first == _LobbySeatChoice.online ||
        normalized.first == _LobbySeatChoice.comrade) {
      normalized[0] = _LobbySeatChoice.local;
    }
    if (!normalized.any((choice) => choice == _LobbySeatChoice.local)) {
      normalized[0] = _LobbySeatChoice.local;
    }
    return normalized;
  }

  static List<_LobbySeatChoice> optionsForPlayer(int playerID) {
    if (playerID == 0) {
      return const [local];
    }
    return const [
      _LobbySeatChoice.local,
      _LobbySeatChoice.online,
      _LobbySeatChoice.comrade,
      _LobbySeatChoice.easyAI,
      _LobbySeatChoice.mediumAI,
      _LobbySeatChoice.hardAI,
      _LobbySeatChoice.empty,
    ];
  }

  static bool isOptionEnabledForPlayer(
    int playerID,
    List<_LobbySeatChoice> choices,
    _LobbySeatChoice option,
  ) {
    if (playerID == 0) {
      return option == _LobbySeatChoice.local;
    }
    if (option != _LobbySeatChoice.local &&
        option != _LobbySeatChoice.online &&
        option != _LobbySeatChoice.comrade) {
      return true;
    }
    final normalized = _LobbySeatChoice.normalized(choices);
    final otherSeats = [
      for (var index = 1; index < kolkhozPlayerCount; index += 1)
        if (index != playerID) normalized[index],
    ];
    if (option == _LobbySeatChoice.local) {
      return !otherSeats.contains(_LobbySeatChoice.online);
    }
    return !otherSeats.contains(_LobbySeatChoice.local);
  }

  static List<_LobbySeatChoice> withExclusiveHumanMode(
    List<_LobbySeatChoice> choices, {
    int? changedPlayerID,
  }) {
    final normalized = _LobbySeatChoice.normalized(choices);
    var chosenHumanMode = _LobbySeatChoice.local;
    if (changedPlayerID != null &&
        changedPlayerID > 0 &&
        changedPlayerID < kolkhozPlayerCount &&
        normalized[changedPlayerID].isHumanSeat) {
      chosenHumanMode = normalized[changedPlayerID];
    } else {
      for (var index = 1; index < kolkhozPlayerCount; index += 1) {
        if (normalized[index].isHumanSeat) {
          chosenHumanMode = normalized[index];
        }
      }
    }
    for (var index = 1; index < kolkhozPlayerCount; index += 1) {
      final choice = normalized[index];
      final incompatible =
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.local &&
              (chosenHumanMode == _LobbySeatChoice.online ||
                  chosenHumanMode == _LobbySeatChoice.comrade)) ||
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.comrade) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.online);
      if (incompatible) {
        normalized[index] = _LobbySeatChoice.empty;
      }
    }
    return normalized;
  }

  static List<KolkhozPlayerController> toControllers(
    List<_LobbySeatChoice> choices,
  ) {
    return KolkhozPlayerController.normalized([
      for (final choice in normalized(choices)) choice.controller,
    ]);
  }

  static List<String> storedValues(List<_LobbySeatChoice> choices) {
    return [
      for (final choice in normalized(choices))
        choice == _LobbySeatChoice.comrade
            ? _LobbySeatChoice.online.name
            : choice.name,
    ];
  }

  bool get isHumanSeat {
    return this == _LobbySeatChoice.local ||
        this == _LobbySeatChoice.online ||
        this == _LobbySeatChoice.comrade;
  }

  KolkhozPlayerController get controller {
    return switch (this) {
      _LobbySeatChoice.empty => KolkhozPlayerController.neuralAI,
      _LobbySeatChoice.local ||
      _LobbySeatChoice.online ||
      _LobbySeatChoice.comrade => KolkhozPlayerController.human,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI,
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI,
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI,
    };
  }

  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      _LobbySeatChoice.empty => language.strings.kolkhozappOpen,
      _LobbySeatChoice.local => language.strings.kolkhozappHotseat,
      _LobbySeatChoice.online => language.strings.kolkhozappOnline,
      _LobbySeatChoice.comrade => language.strings.kolkhozappComrade,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI.shortTitle(
        language,
      ),
    };
  }

  String get iconAsset {
    return switch (this) {
      _LobbySeatChoice.empty => 'assets/ui/Icons/icon-human-seat.png',
      _LobbySeatChoice.local =>
        'assets/ui/Icons/icon-controller-hotseat-player.png',
      _LobbySeatChoice.online =>
        'assets/ui/Icons/icon-controller-online-player.png',
      _LobbySeatChoice.comrade => 'assets/ui/Icons/icon-comrade.png',
      _LobbySeatChoice.easyAI => 'assets/ui/Icons/icon-controller-easy-ai.png',
      _LobbySeatChoice.mediumAI =>
        'assets/ui/Icons/icon-controller-medium-ai.png',
      _LobbySeatChoice.hardAI => 'assets/ui/Icons/icon-controller-hard-ai.png',
    };
  }
}

class ImageTabButton extends StatelessWidget {
  const ImageTabButton({
    super.key,
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.iconAsset,
    this.iconSize = 18,
    this.height = 48,
    this.textSize = PixelTextSize.caption,
    this.horizontalPadding,
    this.contentSpacing = 8,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final double iconSize;
  final double height;
  final PixelTextSize textSize;
  final double? horizontalPadding;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final active = selected && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: ChromeAssetButton(
          label: enabled ? label : '',
          backgroundAsset: active
              ? chromeButtonPrimaryAsset
              : chromeButtonSecondaryAsset,
          tokens: tokens,
          textColor: active
              ? tokens.colors.onAccent
              : tokens.colors.cardInk.withValues(alpha: enabled ? 1 : 0.58),
          textSize: textSize,
          onPressed: onPressed,
          iconAsset: enabled ? iconAsset : 'assets/ui/Icons/icon-lock.png',
          iconSize: iconSize,
          height: height,
          padding: EdgeInsets.fromLTRB(
            enabled && iconAsset == null ? 10 : horizontalPadding ?? 14,
            3,
            horizontalPadding == null ? 10 : horizontalPadding!,
            0,
          ),
          spacing: enabled ? contentSpacing : 0,
          expandLabel: false,
          uppercase: enabled,
          enabled: enabled,
          disabledOpacity: 0.56,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
