import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'board_view.dart';
import 'design_tokens.dart';
import 'pixel_text.dart';
import 'rule_content.dart';

class TutorialWalkthroughOverlay extends StatefulWidget {
  const TutorialWalkthroughOverlay({
    required this.tokens,
    required this.language,
    required this.onClose,
    this.steps = tutorialStepContents,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
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
                        language: widget.language,
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
    required this.language,
    required this.onBack,
    required this.onNext,
    required this.onClose,
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
                TutorialHeader(
                  step: step,
                  tokens: tokens,
                  language: language,
                  onClose: onClose,
                ),
                Text(
                  step.body(language),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TutorialTip(step: step, tokens: tokens, language: language),
                TutorialCallout(step: step, tokens: tokens, language: language),
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
                      label: language.text(en: 'Back', ru: 'Назад'),
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
                          ? language.text(en: 'Done', ru: 'Готово')
                          : language.text(en: 'Next', ru: 'Далее'),
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
            'ios_resources/Embellishments/art-tutorial-foreman.png',
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
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;
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
                language.text(en: 'FOREMAN MISHA', ru: 'БРИГАДИР МИША'),
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
              language.text(en: 'TIP', ru: 'СОВЕТ'),
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
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;

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
              step.callout(language).toUpperCase(),
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
