import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/brigade_layout.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';

class PlanningPhasePanel extends StatelessWidget {
  const PlanningPhasePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.focusedSuit,
    this.onAction,
    this.onRewardsRevealed,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;
  final VoidCallback? onRewardsRevealed;

  @override
  Widget build(BuildContext context) {
    final revealAction = model.legalActions
        .where(
          (action) =>
              action.kind == actionRevealReward ||
              action.kind == actionRevealTrump,
        )
        .firstOrNull;
    if (model.table.isFamine &&
        (revealAction?.kind == actionRevealTrump ||
            model.table.finalYearTrumpCard != null)) {
      return FinalTrumpRevealPanel(
        model: model,
        tokens: tokens,
        language: language,
      );
    }
    return PlanningRewardsPanel(
      model: model,
      tokens: tokens,
      language: language,
      focusedSuit: focusedSuit,
      onAction: onAction,
      onRewardsRevealed: onRewardsRevealed,
    );
  }
}

class PlanningRewardsPanel extends StatefulWidget {
  const PlanningRewardsPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.focusedSuit,
    this.onAction,
    this.onRewardsRevealed,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;
  final VoidCallback? onRewardsRevealed;

  @override
  State<PlanningRewardsPanel> createState() => _PlanningRewardsPanelState();
}

class _PlanningRewardsPanelState extends State<PlanningRewardsPanel> {
  final Map<String, String> completedRewardIDs = {};
  bool reportedAllRewards = false;

  @override
  void didUpdateWidget(PlanningRewardsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentRewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward?.id,
    };
    completedRewardIDs.removeWhere(
      (suit, cardID) => currentRewards[suit] != cardID,
    );
    if (!_allRewardsCompleted(currentRewards)) {
      reportedAllRewards = false;
    }
  }

  void _handleRewardCompleted(String suit, TableCard reward) {
    if (completedRewardIDs[suit] == reward.id) {
      return;
    }
    setState(() => completedRewardIDs[suit] = reward.id);
    final rewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward?.id,
    };
    if (_allRewardsCompleted(rewards) && !reportedAllRewards) {
      reportedAllRewards = true;
      widget.onRewardsRevealed?.call();
    }
  }

  bool _allRewardsCompleted(Map<String, String?> rewards) =>
      displaySuitOrder.every(
        (suit) =>
            rewards[suit] != null && completedRewardIDs[suit] == rewards[suit],
      );

  @override
  Widget build(BuildContext context) {
    final cardSize = widget.tokens.card.small;
    final rewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward,
    };
    final rewardsReady = displaySuitOrder.every(
      (suit) => rewards[suit] != null,
    );
    final options = planningTrumpOptions(
      widget.model.legalActions,
      language: widget.language,
    );
    final aiSelecting =
        planningTrumpSelectorIsAI(widget.model) && widget.focusedSuit != null;
    return PanelStyleSurface(
      key: const Key('planning-rewards-panel'),
      tokens: widget.tokens,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          PixelText(
            widget.language == KolkhozLanguage.en
                ? 'REWARD REVEAL'
                : 'ОТКРЫТИЕ НАГРАД',
            textAlign: TextAlign.center,
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: widget.tokens.colors.gold,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: planningRewardColumnSpacing,
            children: [
              for (final suit in displaySuitOrder)
                SizedBox(
                  width: cardSize.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      MotionTrackedRegion(
                        motionKey: rewardPileMotionSourceKey(suit),
                        child: RewardFlipCard(
                          key: ValueKey('reward-flip-$suit'),
                          reward: rewards[suit],
                          tokens: widget.tokens,
                          size: cardSize,
                          onCompleted: rewards[suit] == null
                              ? null
                              : () => _handleRewardCompleted(
                                  suit,
                                  rewards[suit]!,
                                ),
                        ),
                      ),
                      SizedBox(
                        height: planningTrumpButtonSize,
                        child: AnimatedSwitcher(
                          duration: GameMotion.of(context).handInteraction,
                          child: rewardsReady
                              ? GestureDetector(
                                  key: ValueKey('planning-trump-$suit'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap:
                                      optionForSuit(options, suit)?.action !=
                                              null &&
                                          widget.onAction != null
                                      ? () => widget.onAction!(
                                          optionForSuit(options, suit)!.action!,
                                        )
                                      : null,
                                  child: TrumpSelectionButton(
                                    suit: suit,
                                    label:
                                        optionForSuit(options, suit)?.label ??
                                        widget.language.suitName(suit),
                                    selected:
                                        !aiSelecting &&
                                        suit == widget.focusedSuit,
                                    aiFocused:
                                        aiSelecting &&
                                        suit == widget.focusedSuit,
                                    tokens: widget.tokens,
                                    size: planningTrumpButtonSize,
                                    iconSize: planningTrumpIconSize,
                                  ),
                                )
                              : Center(
                                  key: ValueKey('planning-reward-suit-$suit'),
                                  child: SuitMark(
                                    suit: suit,
                                    tokens: widget.tokens,
                                    size: 22,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          PixelText(
            rewardsReady
                ? widget.language.strings.boardviewChooseTrump
                : (widget.language == KolkhozLanguage.en
                      ? 'REVEALING REWARDS…'
                      : 'ОТКРЫВАЕМ НАГРАДЫ…'),
            key: const Key('planning-reward-status'),
            textAlign: TextAlign.center,
            size: PixelTextSize.xSmall,
            variant: PixelTextVariant.heavy,
            color: rewardsReady
                ? widget.tokens.colors.gold
                : widget.tokens.colors.cream,
          ),
        ],
      ),
    );
  }
}

TrumpActionOption? optionForSuit(
  List<TrumpActionOption> options,
  String suit,
) => options.where((option) => option.suit == suit).firstOrNull;

const planningRewardColumnSpacing = 7.0;

class RewardFlipCard extends StatelessWidget {
  const RewardFlipCard({
    required this.reward,
    required this.tokens,
    required this.size,
    this.onCompleted,
    super.key,
  });

  final TableCard? reward;
  final DesignTokens tokens;
  final TokenCardSize size;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final reward = this.reward;
    return CardFlip(
      showFront: reward != null,
      frontKey: reward == null ? null : ValueKey('reward-face-${reward.id}'),
      backKey: const ValueKey('reward-back'),
      onCompleted: onCompleted,
      front: reward == null
          ? const SizedBox.shrink()
          : GameCard(card: reward, tokens: tokens, sizeOverride: size),
      back: ScaledCardBack(tokens: tokens, size: size),
    );
  }
}

class FinalTrumpRevealPanel extends StatelessWidget {
  const FinalTrumpRevealPanel({
    required this.model,
    required this.tokens,
    required this.language,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final finalTrump = model.table.finalYearTrumpCard;
    final cardSize = tokens.card.small;
    return PanelStyleSurface(
      key: const Key('final-trump-reveal-panel'),
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: [
          PixelText(
            language == KolkhozLanguage.en ? 'REVEAL TRUMP' : 'ОТКРЫТЬ КОЗЫРЬ',
            textAlign: TextAlign.center,
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              MotionTrackedRegion(
                motionKey: finalTrumpMotionSourceKey,
                child: ScaledCardBack(tokens: tokens, size: cardSize),
              ),
              if (finalTrump != null)
                GameCard(
                  card: finalTrump,
                  tokens: tokens,
                  sizeOverride: cardSize,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlanningTrumpPanel extends StatelessWidget {
  const PlanningTrumpPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.focusedSuit,
    this.onAction,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final isFamine = model.table.isFamine;
    final aiSelecting = planningTrumpSelectorIsAI(model) && focusedSuit != null;
    final actionHandler = onAction;
    final trumpOptions = planningTrumpOptions(
      model.legalActions,
      language: language,
    );
    final title = isFamine
        ? language.strings.boardviewFamineYear
        : language.strings.boardviewChooseTrump;
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: planningTrumpPanelSpacing,
        children: [
          SizedBox(
            width: planningTrumpPanelWidth,
            child: PixelText(
              title,
              textAlign: TextAlign.center,
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: isFamine ? tokens.colors.redBright : tokens.colors.gold,
              maxLines: 2,
              overflow: TextOverflow.clip,
              softWrap: true,
            ),
          ),
          if (isFamine)
            Image.asset(
              'assets/ui/Icons/icon-famine.png',
              width: planningTrumpFamineIconSize,
              height: planningTrumpFamineIconSize,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
            SizedBox(
              width: planningTrumpPanelWidth,
              child: Wrap(
                spacing: planningTrumpGridSpacing,
                runSpacing: planningTrumpGridSpacing,
                alignment: WrapAlignment.center,
                children: [
                  for (final option in trumpOptions)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: option.action != null && actionHandler != null
                          ? () => actionHandler(option.action!)
                          : null,
                      child: TrumpSelectionButton(
                        suit: option.suit,
                        label: option.label,
                        selected: !aiSelecting && option.suit == focusedSuit,
                        aiFocused: aiSelecting && option.suit == focusedSuit,
                        tokens: tokens,
                        size: planningTrumpButtonSize,
                        iconSize: planningTrumpIconSize,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

bool planningTrumpSelectorIsAI(TableViewModel model) {
  if (model.table.phase != phasePlanning || model.table.isFamine) {
    return false;
  }
  for (final seat in model.table.seats) {
    if (seat.id == model.table.currentPlayerID) {
      return seat.controller == controllerHeuristicAI ||
          seat.controller == controllerMediumAI ||
          seat.controller == controllerNeuralAI;
    }
  }
  return false;
}

const planningTrumpPanelWidth = 112.0;
const planningTrumpButtonSize = 46.0;
const planningTrumpIconSize = 29.0;
const planningTrumpGridSpacing = 6.0;
const planningTrumpPanelSpacing = 7.0;
const planningTrumpFamineIconSize = 46.0;

class TrumpSelectionButton extends StatelessWidget {
  const TrumpSelectionButton({
    required this.suit,
    required this.label,
    required this.selected,
    required this.tokens,
    this.aiFocused = false,
    this.size = 54,
    this.iconSize = 34,
    super.key,
  });

  final String suit;
  final String label;
  final bool selected;
  final DesignTokens tokens;
  final bool aiFocused;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final motion = GameMotion.of(context);
    final scale = size / 54;
    return Tooltip(
      message: label,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: selected
                    ? tokens.colors.red.withValues(alpha: 0.38)
                    : tokens.colors.gold.withValues(alpha: 0.16),
                blurRadius: (selected ? 8 : 4) * scale,
                offset: Offset(0, 3 * scale),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ChromeButtonBackground(
                  asset: selected
                      ? chromeButtonPrimaryCurrentAsset
                      : chromeButtonSecondaryCurrentAsset,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: selected ? 2 * scale : 0),
                child: SuitMark(suit: suit, tokens: tokens, size: iconSize),
              ),
              if (aiFocused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: motion.trumpSelectorFrame,
                      curve: GameMotion.medalInCurve,
                      margin: EdgeInsets.all(2 * scale),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7 * scale),
                        border: Border.all(
                          color: tokens.colors.green,
                          width: 3 * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.colors.green.withValues(alpha: 0.62),
                            blurRadius: 10 * scale,
                            spreadRadius: 1.5 * scale,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
