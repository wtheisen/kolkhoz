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
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final revealAction = model.legalActions
        .where(
          (action) =>
              action.kind == actionRevealReward ||
              action.kind == actionRevealTrump,
        )
        .firstOrNull;
    final rewardsRevealed = model.table.jobs
        .where((job) => job.reward != null)
        .length;
    if (revealAction != null ||
        (rewardsRevealed > 0 && rewardsRevealed < displaySuitOrder.length)) {
      return RewardRevealPanel(
        model: model,
        tokens: tokens,
        language: language,
        revealingSuit: revealAction?.kind == actionRevealReward
            ? revealAction?.engineAction.suit
            : null,
        revealingTrump: revealAction?.kind == actionRevealTrump,
      );
    }
    if (model.table.isFamine && model.table.finalYearTrumpCard != null) {
      return RewardRevealPanel(
        model: model,
        tokens: tokens,
        language: language,
        revealingTrump: true,
      );
    }
    return PlanningTrumpPanel(
      model: model,
      tokens: tokens,
      language: language,
      focusedSuit: focusedSuit,
      onAction: onAction,
    );
  }
}

class RewardRevealPanel extends StatelessWidget {
  const RewardRevealPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.revealingSuit,
    this.revealingTrump = false,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? revealingSuit;
  final bool revealingTrump;

  @override
  Widget build(BuildContext context) {
    final finalTrump = model.table.finalYearTrumpCard;
    final cardSize = tokens.card.small;
    return PanelStyleSurface(
      key: const Key('reward-reveal-panel'),
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: [
          PixelText(
            revealingTrump
                ? (language == KolkhozLanguage.en
                      ? 'REVEAL TRUMP'
                      : 'ОТКРЫТЬ КОЗЫРЬ')
                : (language == KolkhozLanguage.en ? 'REWARD PILES' : 'НАГРАДЫ'),
            textAlign: TextAlign.center,
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
          ),
          if (revealingTrump)
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
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                for (final suit in displaySuitOrder)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: suit == revealingSuit
                                ? tokens.colors.gold
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: MotionTrackedRegion(
                            motionKey: rewardPileMotionSourceKey(suit),
                            child: ScaledCardBack(
                              tokens: tokens,
                              size: cardSize,
                            ),
                          ),
                        ),
                      ),
                      PixelText(
                        '${displaySuitOrder.indexOf(suit) + 1}',
                        size: PixelTextSize.xSmall,
                        color: tokens.colors.cream,
                      ),
                    ],
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
                child: Image.asset(
                  'assets/ui/Icons/icon-trump-$suit.png',
                  width: iconSize,
                  height: iconSize,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) =>
                      SuitMark(suit: suit, tokens: tokens, size: 28 * scale),
                ),
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
