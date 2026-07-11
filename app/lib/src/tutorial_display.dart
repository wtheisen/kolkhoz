import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'board_view.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'pixel_text.dart';
import 'render_model.dart';
import 'rule_content.dart';

bool _trickHasViewerPlay(Trick trick, int? viewerSeatID) {
  return trick.plays.any(
    (play) => viewerSeatID == null || play.seatID == viewerSeatID,
  );
}

/// Returns true when the live game state satisfies a step's advance event.
bool tutorialStepSatisfied(TutorialAdvance advance, TableViewModel? model) {
  if (model == null) {
    return false;
  }
  final table = model.table;
  switch (advance) {
    case TutorialAdvance.manual:
      return false;
    case TutorialAdvance.trumpChosen:
      return table.trump != null || table.phase != phasePlanning;
    case TutorialAdvance.cardPlayed:
      return _trickHasViewerPlay(table.trick, model.viewer.seatID) ||
          _trickHasViewerPlay(table.lastTrick, model.viewer.seatID);
    case TutorialAdvance.trickTaken:
      return table.lastTrick.plays.isNotEmpty ||
          table.seats.any((seat) => seat.medals > 0);
    case TutorialAdvance.workAssigned:
      return table.jobs.any(
        (job) => job.hours > 0 || job.assignedCards.isNotEmpty,
      );
    case TutorialAdvance.jobCompleted:
      return table.jobs.any(
        (job) => job.claimed || job.hours >= job.requiredHours,
      );
    case TutorialAdvance.yearEnd:
      return table.phase == phaseRequisition || table.year > 1;
    case TutorialAdvance.swapPhase:
      return table.phase == phaseSwap || table.year > 1;
    case TutorialAdvance.famineYear:
      return table.isFamine;
  }
}

/// Approximate board region for a tutorial focus glow, matching the wide
/// board layout: rail on the left, jobs strip on top, hand tray at the
/// bottom. Rough alignment is fine — this is a soft spotlight, not a mask.
Rect? tutorialFocusRect(
  TutorialFocus focus,
  BoxConstraints constraints,
  DesignTokens tokens,
) {
  if (focus == TutorialFocus.none) {
    return null;
  }
  final size = Size(constraints.maxWidth, constraints.maxHeight);
  final metrics = ResponsiveBoardMetrics.fromSize(size, tokens);
  final margin = metrics.margin;
  final railWidth = metrics.railWidth(constraints.maxWidth - margin * 2);
  final gameLeft = margin + railWidth + metrics.separatorWidth;
  final gameWidth = math.max(0.0, constraints.maxWidth - margin - gameLeft);
  final gameHeight = math.max(0.0, constraints.maxHeight - margin * 2);
  switch (focus) {
    case TutorialFocus.none:
      return null;
    case TutorialFocus.rail:
      return Rect.fromLTWH(margin, margin, railWidth, gameHeight);
    case TutorialFocus.jobs:
      return Rect.fromLTWH(gameLeft, margin, gameWidth, gameHeight * 0.15);
    case TutorialFocus.table:
      return Rect.fromLTWH(
        gameLeft,
        margin + gameHeight * 0.17,
        gameWidth,
        gameHeight * 0.45,
      );
    case TutorialFocus.hand:
      return Rect.fromLTWH(
        gameLeft,
        margin + gameHeight * 0.66,
        gameWidth,
        gameHeight * 0.34,
      );
  }
}

class TutorialWalkthroughOverlay extends StatefulWidget {
  const TutorialWalkthroughOverlay({
    required this.tokens,
    required this.language,
    required this.onClose,
    this.model,
    this.steps = tutorialStepContents,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onClose;
  final TableViewModel? model;
  final List<TutorialStepContent> steps;

  @override
  State<TutorialWalkthroughOverlay> createState() =>
      _TutorialWalkthroughOverlayState();
}

/// True while the local player has an urgent affordance in the hand tray's
/// corner (confirming a selected trick card, or submitting assignments).
/// The tutorial panel folds away so it never covers those buttons.
bool tutorialShouldAutoCollapse(TableViewModel? model) {
  if (model == null) {
    return false;
  }
  final table = model.table;
  final pendingPlay =
      table.phase == phaseTrick && model.selection.handCardID != null;
  final viewerSeat = model.viewer.seatID;
  final assigning =
      table.phase == phaseAssignment &&
      viewerSeat != null &&
      table.lastTrick.winnerSeatID == viewerSeat;
  return pendingPlay || assigning;
}

class _TutorialWalkthroughOverlayState
    extends State<TutorialWalkthroughOverlay> {
  int stepIndex = 0;
  bool autoAdvanced = false;
  Timer? autoAdvanceTimer;

  /// null follows the auto-collapse rules; true/false is a manual override
  /// that lasts until the auto-collapse condition changes again.
  bool? manualCollapse;

  TutorialStepContent get step => widget.steps[stepIndex];
  bool get isLastStep => stepIndex == widget.steps.length - 1;

  @override
  void dispose() {
    autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TutorialWalkthroughOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (tutorialShouldAutoCollapse(oldWidget.model) !=
        tutorialShouldAutoCollapse(widget.model)) {
      manualCollapse = null;
    }
    if (isLastStep || step.advance == TutorialAdvance.manual) {
      return;
    }
    final wasSatisfied = tutorialStepSatisfied(step.advance, oldWidget.model);
    final nowSatisfied = tutorialStepSatisfied(step.advance, widget.model);
    if (!wasSatisfied && nowSatisfied) {
      autoAdvanceTimer?.cancel();
      setState(() {
        stepIndex += 1;
        autoAdvanced = true;
      });
      autoAdvanceTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() => autoAdvanced = false);
        }
      });
    }
  }

  void goBack() {
    if (stepIndex == 0) {
      return;
    }
    setState(() {
      stepIndex -= 1;
      autoAdvanced = false;
    });
  }

  void goNext() {
    if (isLastStep) {
      widget.onClose();
      return;
    }
    setState(() {
      stepIndex += 1;
      autoAdvanced = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final collapsed =
        manualCollapse ?? tutorialShouldAutoCollapse(widget.model);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final panelWidth = math
                .min(
                  wide ? constraints.maxWidth * 0.5 : constraints.maxWidth - 20,
                  520,
                )
                .toDouble();
            final glowRect = wide
                ? tutorialFocusRect(step.focus, constraints, widget.tokens)
                : null;
            final satisfied = tutorialStepSatisfied(step.advance, widget.model);
            return Stack(
              children: [
                if (glowRect != null)
                  TutorialFocusGlow(rect: glowRect, tokens: widget.tokens),
                if (collapsed)
                  Positioned(
                    right: 12,
                    bottom: math.min(300, constraints.maxHeight * 0.42),
                    child: TutorialCollapsedBadge(
                      tokens: widget.tokens,
                      onExpand: () => setState(() => manualCollapse = false),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 16 : 10),
                      child: SizedBox(
                        width: panelWidth,
                        child: TutorialDialoguePanel(
                          step: step,
                          index: stepIndex,
                          count: widget.steps.length,
                          tokens: widget.tokens,
                          language: widget.language,
                          satisfied: satisfied,
                          celebrating: autoAdvanced,
                          onBack: goBack,
                          onNext: goNext,
                          onCollapse: () =>
                              setState(() => manualCollapse = true),
                          onClose: widget.onClose,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The folded-away tutorial: a small Misha badge that re-opens the panel.
class TutorialCollapsedBadge extends StatelessWidget {
  const TutorialCollapsedBadge({
    required this.tokens,
    required this.onExpand,
    super.key,
  });

  final DesignTokens tokens;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('tutorial-expand'),
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: PanelStyleSurface(
        tokens: tokens,
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/ui/Embellishments/art-tutorial-foreman.png',
              width: 44,
              height: 52,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            PixelText(
              '?',
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft pulsing spotlight over the board region a step refers to. Ignores
/// pointer events so the board underneath stays fully playable.
class TutorialFocusGlow extends StatefulWidget {
  const TutorialFocusGlow({
    required this.rect,
    required this.tokens,
    super.key,
  });

  final Rect rect;
  final DesignTokens tokens;

  @override
  State<TutorialFocusGlow> createState() => _TutorialFocusGlowState();
}

class _TutorialFocusGlowState extends State<TutorialFocusGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: widget.rect,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final pulse = 0.30 + controller.value * 0.45;
            final gold = widget.tokens.colors.gold;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gold.withValues(alpha: pulse),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: pulse * 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TutorialDialoguePanel extends StatelessWidget {
  const TutorialDialoguePanel({
    required this.step,
    required this.index,
    required this.count,
    required this.tokens,
    required this.language,
    required this.onBack,
    required this.onNext,
    required this.onClose,
    this.onCollapse,
    this.satisfied = false,
    this.celebrating = false,
    super.key,
  });

  final TutorialStepContent step;
  final int index;
  final int count;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback? onCollapse;
  final bool satisfied;
  final bool celebrating;

  bool get isLastStep => index == count - 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: celebrating
            ? [
                BoxShadow(
                  color: tokens.colors.gold.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: PanelStyleSurface(
        tokens: tokens,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 10,
          children: [
            Flexible(
              flex: 0,
              child: Image.asset(
                'assets/ui/Embellishments/art-tutorial-foreman.png',
                width: 92,
                height: 110,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  TutorialHeader(
                    step: step,
                    tokens: tokens,
                    language: language,
                    onCollapse: onCollapse,
                    onClose: onClose,
                  ),
                  Text(
                    step.body(language),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.creamDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TutorialTip(step: step, tokens: tokens, language: language),
                  TutorialCallout(
                    step: step,
                    tokens: tokens,
                    language: language,
                    satisfied: satisfied,
                  ),
                  TutorialProgressDots(
                    index: index,
                    count: count,
                    tokens: tokens,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      ChromeAssetButton(
                        key: const Key('tutorial-back'),
                        label: language.t(KolkhozText.tutorialdisplayBack),
                        tokens: tokens,
                        enabled: index > 0,
                        backgroundAsset: chromeButtonSecondaryAsset,
                        textColor: tokens.colors.cardInk,
                        textSize: PixelTextSize.caption,
                        width: 110,
                        height: 34,
                        onPressed: onBack,
                      ),
                      ChromeAssetButton(
                        key: const Key('tutorial-next'),
                        label: isLastStep
                            ? language.t(KolkhozText.tutorialdisplayDone)
                            : language.t(KolkhozText.tutorialdisplayNext),
                        tokens: tokens,
                        backgroundAsset: chromeButtonPrimaryAsset,
                        textColor: tokens.colors.onAccent,
                        textSize: PixelTextSize.caption,
                        width: 110,
                        height: 34,
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForemanHintBubble extends StatelessWidget {
  const ForemanHintBubble({
    required this.message,
    required this.tokens,
    super.key,
  });

  final String message;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          Image.asset(
            'assets/ui/Embellishments/art-tutorial-foreman.png',
            width: 58,
            height: 70,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialHeader extends StatelessWidget {
  const TutorialHeader({
    required this.step,
    required this.tokens,
    required this.language,
    required this.onClose,
    this.onCollapse,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onClose;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Image.asset(
          step.iconPath,
          width: 23,
          height: 23,
          filterQuality: FilterQuality.none,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              PixelText(
                language.t(KolkhozText.tutorialdisplayForemanMisha),
                size: PixelTextSize.caption,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.gold,
              ),
              Text(
                step.title(language).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (onCollapse != null)
          GestureDetector(
            key: const Key('tutorial-collapse'),
            behavior: HitTestBehavior.opaque,
            onTap: onCollapse,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.56),
                ),
              ),
              child: PixelText(
                'V',
                size: PixelTextSize.caption,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.creamDim,
              ),
            ),
          ),
        GestureDetector(
          key: const Key('tutorial-close'),
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tokens.colors.steel.withValues(alpha: 0.56),
              ),
            ),
            child: PixelText(
              'X',
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.creamDim,
            ),
          ),
        ),
      ],
    );
  }
}

class TutorialTip extends StatelessWidget {
  const TutorialTip({
    required this.step,
    required this.tokens,
    required this.language,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: tokens.colors.redDark.withValues(alpha: 0.46),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.colors.redDark.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tokens.colors.redBright.withValues(alpha: 0.58),
              ),
            ),
            child: PixelText(
              language.t(KolkhozText.tutorialdisplayTip),
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.redBright,
            ),
          ),
          Expanded(
            child: Text(
              step.tip(language),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.cream,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialCallout extends StatelessWidget {
  const TutorialCallout({
    required this.step,
    required this.tokens,
    required this.language,
    this.satisfied = false,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final calloutText = satisfied
        ? language.t(KolkhozText.tutorialdisplayDoneWellWorkedComrade)
        : step.callout(language);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: tokens.colors.gold.withValues(alpha: satisfied ? 0.95 : 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Image.asset(
            satisfied
                ? 'assets/ui/Icons/icon-check.png'
                : 'assets/ui/Embellishments/tutorial-focus-spark.png',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              calloutText.toUpperCase(),
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.goldBright,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialProgressDots extends StatelessWidget {
  const TutorialProgressDots({
    required this.index,
    required this.count,
    required this.tokens,
    super.key,
  });

  final int index;
  final int count;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: [
        for (var dotIndex = 0; dotIndex < count; dotIndex += 1)
          Container(
            key: ValueKey('tutorial-dot-$dotIndex'),
            width: dotIndex == index ? 22 : 8,
            height: 6,
            decoration: BoxDecoration(
              color: dotIndex <= index
                  ? tokens.colors.gold
                  : tokens.colors.steel.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
