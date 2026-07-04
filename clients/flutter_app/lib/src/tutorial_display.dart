import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_view.dart';
import 'design_tokens.dart';
import 'pixel_text.dart';

class TutorialStepContent {
  const TutorialStepContent({
    required this.title,
    required this.body,
    required this.tip,
    required this.callout,
    required this.iconPath,
  });

  final String title;
  final String body;
  final String tip;
  final String callout;
  final String iconPath;
}

const tutorialStepContents = [
  TutorialStepContent(
    title: 'First, read the table',
    body:
        'Every year has four jobs. Your hand wins tricks; your cellar keeps the points that survive requisition.',
    tip:
        'High hidden cards are your bank. Losing one to the North can swing the final score.',
    callout: 'Tap the Cellar icon to inspect your kept card.',
    iconPath: 'ios_resources/Icons/icon-plot.png',
  ),
  TutorialStepContent(
    title: 'Pick the trump crop',
    body:
        'In planning, the selector chooses one crop as trump. Trump cards can beat the led crop.',
    tip:
        'Pick trump for the hand you expect to play, not only for the biggest card you see.',
    callout: 'Tap Wheat as trump.',
    iconPath: 'ios_resources/Icons/icon-jobs.png',
  ),
  TutorialStepContent(
    title: 'Win the trick',
    body:
        'Follow suit when you can. Highest card in the winning suit takes the trick.',
    tip:
        'Winning is power, but it paints a target on your cellar for the rest of the year.',
    callout: 'Tap a highlighted legal card.',
    iconPath: 'ios_resources/Icons/icon-hand.png',
  ),
  TutorialStepContent(
    title: 'Medal now, risk later',
    body:
        'Trick winners earn medals. Medals break ties, but winning also exposes you to requisition.',
    tip:
        'Sometimes ducking a trick is correct if your cellar holds a card you cannot afford to lose.',
    callout: 'Continue to see where the risk lands.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
  TutorialStepContent(
    title: 'The winner assigns work',
    body:
        'As brigade leader, you send captured cards into jobs to protect matching crops.',
    tip: 'Assign work to protect the suits that match your best cellar cards.',
    callout: 'Tap the Jobs icon to view the work board.',
    iconPath: 'ios_resources/Icons/icon-jobs.png',
  ),
  TutorialStepContent(
    title: 'Finish jobs for rewards',
    body:
        'When a job reaches 40 hours, the revealed reward card goes into the winner\'s cellar.',
    tip:
        'A finished job both pays you and stops that crop from causing requisition this year.',
    callout: 'Inspect completed job rewards, then continue.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
  TutorialStepContent(
    title: 'This is requisition',
    body:
        'Failed crops can reveal and exile matching cellar cards from players who won tricks.',
    tip:
        'A medal may break a tie later, but losing a high cellar card hurts immediately.',
    callout: 'Tap the requisition report.',
    iconPath: 'ios_resources/Icons/icon-north.png',
  ),
  TutorialStepContent(
    title: 'Swap before later years',
    body:
        'From year two, you may trade one hand card with your cellar before tricks begin.',
    tip:
        'Swap high cards into the cellar when they can stay safe; pull danger cards out before requisition.',
    callout: 'Tap the Cellar icon again before you swap.',
    iconPath: 'ios_resources/Icons/icon-cellar.png',
  ),
  TutorialStepContent(
    title: 'Year five is famine',
    body:
        'The last year has no trump and only three tricks. It is short and usually decisive.',
    tip:
        'Save flexible high cards for famine; no trump means a bad lead is harder to escape.',
    callout: 'Continue when you have seen the famine board.',
    iconPath: 'ios_resources/Icons/icon-famine.png',
  ),
  TutorialStepContent(
    title: 'Highest final cellar wins',
    body:
        'At the end, hidden cellar cards count too. Highest cellar score wins; medals break ties.',
    tip:
        'Bigger ranks mean bigger cellar points. One protected high card can decide the whole game.',
    callout: 'Review the final score, then finish.',
    iconPath: 'ios_resources/Icons/icon-medal-star.png',
  ),
];

class TutorialWalkthroughOverlay extends StatefulWidget {
  const TutorialWalkthroughOverlay({
    required this.tokens,
    required this.onClose,
    this.steps = tutorialStepContents,
    super.key,
  });

  final DesignTokens tokens;
  final VoidCallback onClose;
  final List<TutorialStepContent> steps;

  @override
  State<TutorialWalkthroughOverlay> createState() =>
      _TutorialWalkthroughOverlayState();
}

class _TutorialWalkthroughOverlayState
    extends State<TutorialWalkthroughOverlay> {
  int stepIndex = 0;

  TutorialStepContent get step => widget.steps[stepIndex];
  bool get isLastStep => stepIndex == widget.steps.length - 1;

  void goBack() {
    if (stepIndex == 0) {
      return;
    }
    setState(() => stepIndex -= 1);
  }

  void goNext() {
    if (isLastStep) {
      widget.onClose();
      return;
    }
    setState(() => stepIndex += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.tokens.colors.black.withValues(alpha: 0.56),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final panelWidth = math
                .min(
                  wide
                      ? constraints.maxWidth * 0.58
                      : constraints.maxWidth - 20,
                  540,
                )
                .toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          widget.tokens.colors.gold.withValues(alpha: 0.16),
                          widget.tokens.colors.black.withValues(alpha: 0),
                        ],
                        radius: 0.78,
                      ),
                    ),
                  ),
                ),
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
                        onBack: goBack,
                        onNext: goNext,
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

class TutorialDialoguePanel extends StatelessWidget {
  const TutorialDialoguePanel({
    required this.step,
    required this.index,
    required this.count,
    required this.tokens,
    required this.onBack,
    required this.onNext,
    required this.onClose,
    super.key,
  });

  final TutorialStepContent step;
  final int index;
  final int count;
  final DesignTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;

  bool get isLastStep => index == count - 1;

  @override
  Widget build(BuildContext context) {
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 10,
        children: [
          Flexible(
            flex: 0,
            child: Image.asset(
              'ios_resources/Embellishments/art-tutorial-foreman.png',
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
                TutorialHeader(step: step, tokens: tokens, onClose: onClose),
                Text(
                  step.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TutorialTip(step: step, tokens: tokens),
                TutorialCallout(step: step, tokens: tokens),
                TutorialProgressDots(
                  index: index,
                  count: count,
                  tokens: tokens,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    TutorialChromeButton(
                      key: const Key('tutorial-back'),
                      label: 'Back',
                      tokens: tokens,
                      enabled: index > 0,
                      prominent: false,
                      onPressed: onBack,
                    ),
                    TutorialChromeButton(
                      key: const Key('tutorial-next'),
                      label: isLastStep ? 'Done' : 'Next',
                      tokens: tokens,
                      prominent: true,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ],
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
    required this.onClose,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final VoidCallback onClose;

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
                'FOREMAN MISHA',
                size: PixelTextSize.caption,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.gold,
              ),
              Text(
                step.title.toUpperCase(),
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
  const TutorialTip({required this.step, required this.tokens, super.key});

  final TutorialStepContent step;
  final DesignTokens tokens;

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
              'TIP',
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.redBright,
            ),
          ),
          Expanded(
            child: Text(
              step.tip,
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
  const TutorialCallout({required this.step, required this.tokens, super.key});

  final TutorialStepContent step;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Image.asset(
            'ios_resources/Embellishments/tutorial-focus-spark.png',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              step.callout.toUpperCase(),
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

class TutorialChromeButton extends StatelessWidget {
  const TutorialChromeButton({
    required this.label,
    required this.tokens,
    required this.onPressed,
    this.enabled = true,
    this.prominent = false,
    super.key,
  });

  final String label;
  final DesignTokens tokens;
  final VoidCallback onPressed;
  final bool enabled;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 110,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                prominent
                    ? 'ios_resources/ui-button-primary.png'
                    : 'ios_resources/ui-button-secondary.png',
              ),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          child: PixelText(
            label.toUpperCase(),
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: prominent ? tokens.colors.onAccent : tokens.colors.cardInk,
          ),
        ),
      ),
    );
  }
}
