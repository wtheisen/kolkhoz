import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../animation_speed.dart';
import '../app_settings.dart';
import '../chrome_button.dart';
import '../design_tokens.dart';
import '../pixel_text.dart';
import '../render_model.dart';
import '../rule_content.dart';
import 'board_widgets.dart';

const optionsPanelMaxWidth = 620.0;
const optionsPanelHorizontalPadding = 20.0;
const optionsPanelOuterShadowOpacity = 0.5;
const optionsPanelOuterShadowRadius = 16.0;
const optionsPanelOuterShadowYOffset = 8.0;
const optionsPanelContentMinHeight = 206.0;
const optionsPanelContentMaxHeight = 360.0;
const optionsPanelSurfaceVerticalPadding = 24.0;
const optionsPanelSurfaceMinHeight =
    optionsPanelContentMinHeight + optionsPanelSurfaceVerticalPadding;
const optionsPanelSurfaceMaxHeight =
    optionsPanelContentMaxHeight + optionsPanelSurfaceVerticalPadding;
const optionsMenuSectionSpacingFactor = 0.035;
const optionsMenuSectionSpacingMin = 7.0;
const optionsMenuSectionSpacingMax = 10.0;
const optionsMenuActionsSpacing = 10.0;
const optionsMenuControlsSpacing = 8.0;
const optionsMenuRulesSpacing = 8.0;
const optionsMenuChromeToggleSpacing = 8.0;
const optionsMenuContentBottomPadding = 24.0;
const optionsMenuHeaderIconSize = 18.0;
const optionsMenuHeaderSpacing = 8.0;
const optionsMenuHeaderFontSize = 17.0;
const optionsMenuSectionLabelFontSize = 11.0;
const optionsMenuRulesHeaderFontSize = 15.0;
const optionsMenuActionWidth = 170.0;
const optionsReadabilityButtonWidth = 190.0;
const optionsMenuActionHeight = 34.0;
const optionsMenuActionHorizontalPadding = 12.0;
const optionsMenuActionContentSpacing = 7.0;
const optionsMenuActionIconSize = 15.0;
const optionsMenuActionFontSize = 13.0;
const optionsReadabilityGlyphBoxWidth = 24.0;
const optionsReadabilityFontSize = 13.0;
const optionsChromeToggleSize = 48.0;
const optionsChromeToggleIconSize = 25.0;

double optionsMenuSectionSpacing(double height) {
  return clampDouble(
    height * optionsMenuSectionSpacingFactor,
    optionsMenuSectionSpacingMin,
    optionsMenuSectionSpacingMax,
  );
}

String animationSpeedLabel(GameAnimationSpeed speed, KolkhozLanguage language) {
  return switch (speed) {
    GameAnimationSpeed.instant => language.text(en: 'Instant', ru: 'Мигом'),
    GameAnimationSpeed.fast => language.text(en: 'Fast', ru: 'Быстро'),
    GameAnimationSpeed.normal => language.text(en: 'Normal', ru: 'Норма'),
    GameAnimationSpeed.slow => language.text(en: 'Slow', ru: 'Медленно'),
  };
}

const optionsAnimationSpeedControlWidth = 246.0;
const optionsAnimationSpeedPadding = 6.0;
const optionsAnimationSpeedSpacing = 5.0;
const optionsAnimationSpeedSegmentHeight = 28.0;

const menuRuleBodyFontSize = 13.0;

class OptionsPanel extends StatelessWidget {
  const OptionsPanel({
    required this.model,
    required this.tokens,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    required this.language,
    required this.appearance,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return OptionsPanelFrame(
      tokens: tokens,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : optionsPanelSurfaceMaxHeight;
          final maxHeight = math.min(
            optionsPanelSurfaceMaxHeight,
            math.max(optionsPanelContentMinHeight, availableHeight - 8),
          );
          final minHeight = math.min(optionsPanelSurfaceMinHeight, maxHeight);
          final sectionSpacing = optionsMenuSectionSpacing(maxHeight);
          return PanelStyleSurface(
            tokens: tokens,
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: maxHeight,
            ),
            padding: const EdgeInsets.all(12),
            child: KolkhozScrollbar(
              tokens: tokens,
              childBuilder: (context, scrollController) =>
                  SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 10,
                        bottom: optionsMenuContentBottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: sectionSpacing,
                        children: [
                          OptionsMenuHeader(tokens: tokens, language: language),
                          OptionsMenuActions(
                            tokens: tokens,
                            onNewGame: onNewGame,
                            onReturnToLobby: onReturnToLobby,
                            onTutorial: onTutorial,
                            animationSpeed: animationSpeed,
                            onAnimationSpeedChanged: onAnimationSpeedChanged,
                            language: language,
                            appearance: appearance,
                            onLanguageToggle: onLanguageToggle,
                            onAppearanceToggle: onAppearanceToggle,
                          ),
                          Divider(
                            color: tokens.colors.gold.withValues(alpha: 0.35),
                          ),
                          OptionsMenuRules(tokens: tokens, language: language),
                        ],
                      ),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}

class OptionsPanelFrame extends StatelessWidget {
  const OptionsPanelFrame({
    required this.tokens,
    required this.child,
    super.key,
  });

  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: optionsPanelHorizontalPadding,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          key: const Key('options-panel-frame'),
          constraints: const BoxConstraints(maxWidth: optionsPanelMaxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(
                    alpha: optionsPanelOuterShadowOpacity,
                  ),
                  blurRadius: optionsPanelOuterShadowRadius,
                  offset: const Offset(0, optionsPanelOuterShadowYOffset),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class OptionsMenuHeader extends StatelessWidget {
  const OptionsMenuHeader({
    required this.tokens,
    required this.language,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: optionsMenuHeaderSpacing,
      children: [
        Image.asset(
          'ios_resources/Icons/icon-menu.png',
          width: optionsMenuHeaderIconSize,
          height: optionsMenuHeaderIconSize,
          filterQuality: FilterQuality.none,
        ),
        ChromePixelLabel(
          language.text(en: 'Menu', ru: 'Меню'),
          size: PixelTextSize.title,
          color: tokens.colors.gold,
        ),
      ],
    );
  }
}

class OptionsMenuActions extends StatelessWidget {
  const OptionsMenuActions({
    required this.tokens,
    required this.language,
    required this.appearance,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.onAnimationSpeedChanged,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final GameAnimationSpeed animationSpeed;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: optionsMenuActionsSpacing,
      children: [
        ChromePixelLabel(
          language.text(en: 'Game controls', ru: 'Управление игрой'),
          size: PixelTextSize.caption,
          variant: PixelTextVariant.regular,
          color: tokens.colors.smoke,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: optionsMenuControlsSpacing,
          children: [
            Center(
              child: ChromeAssetButton.command(
                label: language.text(en: 'New game', ru: 'Новая игра'),
                prominent: true,
                tokens: tokens,
                onPressed: onNewGame,
                surfaceKey: const Key('command-surface-button'),
              ),
            ),
            Center(
              child: ChromeAssetButton(
                label: language.text(en: 'How to play', ru: 'Как играть'),
                tokens: tokens,
                backgroundColor: tokens.colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: tokens.colors.gold.withValues(alpha: 0.42),
                ),
                textColor: tokens.colors.creamDim,
                textSize: PixelTextSize.caption,
                onPressed: onTutorial,
                iconAsset: 'ios_resources/Icons/icon-tutorial.png',
                iconMuted: true,
                iconSize: optionsMenuActionIconSize,
                width: optionsMenuActionWidth,
                height: optionsMenuActionHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: optionsMenuActionHorizontalPadding,
                ),
                spacing: optionsMenuActionContentSpacing,
              ),
            ),
            Center(
              child: ChromeAssetButton(
                label: language.text(en: 'Main menu', ru: 'Главное меню'),
                tokens: tokens,
                backgroundColor: tokens.colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.5),
                ),
                textColor: tokens.colors.creamDim,
                textSize: PixelTextSize.caption,
                onPressed: onReturnToLobby,
                iconAsset: 'ios_resources/Icons/icon-menu.png',
                iconMuted: true,
                iconSize: optionsMenuActionIconSize,
                width: optionsMenuActionWidth,
                height: optionsMenuActionHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: optionsMenuActionHorizontalPadding,
                ),
                spacing: optionsMenuActionContentSpacing,
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: optionsMenuChromeToggleSpacing,
                children: [
                  OptionsChromeToggle(
                    iconPath: 'ios_resources/Icons/${language.toggleIconAsset}',
                    label: language.toggleTitle,
                    tokens: tokens,
                    onPressed: onLanguageToggle,
                  ),
                  OptionsChromeToggle(
                    iconPath: 'ios_resources/Icons/icon-appearance.png',
                    label: appearance.toggleTitle(language),
                    tokens: tokens,
                    onPressed: onAppearanceToggle,
                  ),
                ],
              ),
            ),
            Center(
              child: AnimationSpeedControl(
                selected: animationSpeed,
                tokens: tokens,
                language: language,
                onChanged: onAnimationSpeedChanged,
              ),
            ),
            Center(
              child: ReadabilitySurfaceButton(
                tokens: tokens,
                language: language,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class OptionsMenuRules extends StatelessWidget {
  const OptionsMenuRules({
    required this.tokens,
    required this.language,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: optionsMenuRulesSpacing,
      children: [
        ChromePixelLabel(
          language.text(en: 'Rules', ru: 'Правила'),
          size: PixelTextSize.headline,
          color: tokens.colors.gold,
        ),
        for (final rule in optionsRuleSummaries)
          MenuRuleRow(
            iconPath: rule.iconPath,
            title: rule.title(language),
            body: rule.body(language),
            tokens: tokens,
          ),
      ],
    );
  }
}

class OptionsChromeToggle extends StatelessWidget {
  const OptionsChromeToggle({
    required this.iconPath,
    required this.label,
    required this.tokens,
    this.onPressed,
    super.key,
  });

  final String iconPath;
  final String label;
  final DesignTokens tokens;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: optionsChromeToggleSize,
          height: optionsChromeToggleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'ios_resources/ui-nav-button-inactive.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Image.asset(
                iconPath,
                width: optionsChromeToggleIconSize,
                height: optionsChromeToggleIconSize,
                filterQuality: FilterQuality.none,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimationSpeedControl extends StatelessWidget {
  const AnimationSpeedControl({
    required this.selected,
    required this.tokens,
    required this.language,
    this.onChanged,
    super.key,
  });

  final GameAnimationSpeed selected;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<GameAnimationSpeed>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: optionsAnimationSpeedControlWidth,
      padding: const EdgeInsets.all(optionsAnimationSpeedPadding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.42)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: optionsAnimationSpeedSpacing,
        children: [
          ChromePixelLabel(
            language.text(en: 'Animation speed', ru: 'Скорость анимации'),
            size: PixelTextSize.caption,
            color: tokens.colors.smoke,
          ),
          Row(
            children: [
              for (final speed in GameAnimationSpeed.values)
                Expanded(
                  child: AnimationSpeedSegment(
                    speed: speed,
                    selected: speed == selected,
                    tokens: tokens,
                    language: language,
                    onTap: onChanged == null ? null : () => onChanged!(speed),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AnimationSpeedSegment extends StatelessWidget {
  const AnimationSpeedSegment({
    required this.speed,
    required this.selected,
    required this.tokens,
    required this.language,
    this.onTap,
    super.key,
  });

  final GameAnimationSpeed speed;
  final bool selected;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.colors.gold : tokens.colors.creamDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: optionsAnimationSpeedSegmentHeight,
        decoration: BoxDecoration(
          color: selected
              ? tokens.colors.gold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? tokens.colors.gold
                : tokens.colors.steel.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ChromePixelLabel(
              animationSpeedLabel(speed, language),
              size: PixelTextSize.caption2,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class ReadabilitySurfaceButton extends StatelessWidget {
  const ReadabilitySurfaceButton({
    required this.tokens,
    required this.language,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: optionsReadabilityButtonWidth,
      height: optionsMenuActionHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: optionsMenuActionHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: optionsMenuActionContentSpacing,
        children: [
          SizedBox(
            width: optionsReadabilityGlyphBoxWidth,
            child: Center(
              child: ChromePixelLabel(
                'Aa',
                size: PixelTextSize.caption,
                color: tokens.colors.creamDim,
                uppercase: false,
              ),
            ),
          ),
          Flexible(
            child: ChromePixelLabel(
              language.text(en: 'Clear text', ru: 'Четкий текст'),
              size: PixelTextSize.caption,
              color: tokens.colors.creamDim,
            ),
          ),
        ],
      ),
    );
  }
}

class MenuRuleRow extends StatelessWidget {
  const MenuRuleRow({
    required this.iconPath,
    required this.title,
    required this.body,
    required this.tokens,
    super.key,
  });

  final String iconPath;
  final String title;
  final String body;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Center(
              child: ChromeAssetIcon(
                asset: iconPath,
                width: 17,
                height: 17,
                muted: true,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                ChromePixelLabel(
                  title.toUpperCase(),
                  size: PixelTextSize.caption,
                  color: tokens.colors.gold,
                ),
                Text(
                  body,
                  softWrap: true,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: menuRuleBodyFontSize,
                    fontWeight: FontWeight.w700,
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
