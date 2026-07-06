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

const optionsPanelLocalPadding = EdgeInsets.only(top: 8);
const optionsPanelSurfaceMinHeight = 230.0;
const optionsMenuTabSpacing = 6.0;
const optionsMenuTabHeight = 32.0;
const optionsMenuSettingSpacing = 8.0;
const optionsMenuSettingPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 7,
);
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
const optionsMenuActionWidth = 170.0;
const optionsMenuActionHeight = 34.0;
const optionsMenuActionHorizontalPadding = 12.0;
const optionsMenuActionContentSpacing = 7.0;
const optionsMenuActionIconSize = 15.0;
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

enum OptionsMenuTab {
  session,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      OptionsMenuTab.session => language.text(en: 'Session', ru: 'Партия'),
      OptionsMenuTab.assist => language.text(en: 'Assist', ru: 'Помощь'),
      OptionsMenuTab.display => language.text(en: 'Display', ru: 'Вид'),
      OptionsMenuTab.rules => language.text(en: 'Rules', ru: 'Правила'),
    };
  }
}

class OptionsPanel extends StatefulWidget {
  const OptionsPanel({
    required this.model,
    required this.tokens,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
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
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  State<OptionsPanel> createState() => _OptionsPanelState();
}

class _OptionsPanelState extends State<OptionsPanel> {
  OptionsMenuTab selectedTab = OptionsMenuTab.session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: optionsPanelLocalPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : optionsPanelSurfaceMinHeight;
          final surfaceHeight = clampDouble(
            availableHeight,
            optionsPanelSurfaceMinHeight,
            double.infinity,
          );
          final sectionSpacing = optionsMenuSectionSpacing(surfaceHeight);
          return PanelStyleSurface(
            tokens: widget.tokens,
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: surfaceHeight,
              maxHeight: surfaceHeight,
            ),
            padding: const EdgeInsets.all(12),
            child: KolkhozScrollbar(
              tokens: widget.tokens,
              childBuilder: (context, scrollController) =>
                  SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 10,
                        bottom: optionsMenuContentBottomPadding,
                      ),
                      child: OptionsMenuContent(
                        tokens: widget.tokens,
                        language: widget.language,
                        appearance: widget.appearance,
                        selectedTab: selectedTab,
                        onTabSelected: (tab) =>
                            setState(() => selectedTab = tab),
                        sectionSpacing: sectionSpacing,
                        onNewGame: widget.onNewGame,
                        onReturnToLobby: widget.onReturnToLobby,
                        onTutorial: widget.onTutorial,
                        animationSpeed: widget.animationSpeed,
                        onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
                        confirmNewGame: widget.confirmNewGame,
                        onConfirmNewGameChanged: widget.onConfirmNewGameChanged,
                        confirmMainMenu: widget.confirmMainMenu,
                        onConfirmMainMenuChanged:
                            widget.onConfirmMainMenuChanged,
                        showInvalidTapHints: widget.showInvalidTapHints,
                        onShowInvalidTapHintsChanged:
                            widget.onShowInvalidTapHintsChanged,
                        onLanguageToggle: widget.onLanguageToggle,
                        onAppearanceToggle: widget.onAppearanceToggle,
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

class OptionsMenuContent extends StatelessWidget {
  const OptionsMenuContent({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.selectedTab,
    required this.onTabSelected,
    required this.sectionSpacing,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final OptionsMenuTab selectedTab;
  final ValueChanged<OptionsMenuTab> onTabSelected;
  final double sectionSpacing;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: sectionSpacing,
      children: [
        OptionsMenuHeader(tokens: tokens, language: language),
        OptionsMenuTabs(
          tokens: tokens,
          language: language,
          selectedTab: selectedTab,
          onTabSelected: onTabSelected,
        ),
        OptionsMenuTabBody(
          tokens: tokens,
          language: language,
          appearance: appearance,
          selectedTab: selectedTab,
          onNewGame: onNewGame,
          onReturnToLobby: onReturnToLobby,
          onTutorial: onTutorial,
          animationSpeed: animationSpeed,
          onAnimationSpeedChanged: onAnimationSpeedChanged,
          confirmNewGame: confirmNewGame,
          onConfirmNewGameChanged: onConfirmNewGameChanged,
          confirmMainMenu: confirmMainMenu,
          onConfirmMainMenuChanged: onConfirmMainMenuChanged,
          showInvalidTapHints: showInvalidTapHints,
          onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
          onLanguageToggle: onLanguageToggle,
          onAppearanceToggle: onAppearanceToggle,
        ),
      ],
    );
  }
}

class OptionsMenuTabs extends StatelessWidget {
  const OptionsMenuTabs({
    required this.tokens,
    required this.language,
    required this.selectedTab,
    required this.onTabSelected,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OptionsMenuTab selectedTab;
  final ValueChanged<OptionsMenuTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: optionsMenuTabSpacing,
      children: [
        for (final tab in OptionsMenuTab.values)
          Expanded(
            child: OptionsMenuTabButton(
              tokens: tokens,
              label: tab.title(language),
              selected: selectedTab == tab,
              onPressed: () => onTabSelected(tab),
            ),
          ),
      ],
    );
  }
}

class OptionsMenuTabButton extends StatelessWidget {
  const OptionsMenuTabButton({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            height: optionsMenuTabHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? tokens.colors.gold.withValues(alpha: 0.18)
                  : tokens.colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: selected
                    ? tokens.colors.gold
                    : tokens.colors.steel.withValues(alpha: 0.5),
              ),
            ),
            child: ChromePixelLabel(
              label,
              size: PixelTextSize.caption,
              color: selected ? tokens.colors.gold : tokens.colors.creamDim,
            ),
          ),
        ),
      ),
    );
  }
}

class OptionsMenuTabBody extends StatelessWidget {
  const OptionsMenuTabBody({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.selectedTab,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final OptionsMenuTab selectedTab;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return switch (selectedTab) {
      OptionsMenuTab.session => OptionsSessionControls(
        tokens: tokens,
        language: language,
        onNewGame: onNewGame,
        onReturnToLobby: onReturnToLobby,
        onTutorial: onTutorial,
        confirmNewGame: confirmNewGame,
        onConfirmNewGameChanged: onConfirmNewGameChanged,
        confirmMainMenu: confirmMainMenu,
        onConfirmMainMenuChanged: onConfirmMainMenuChanged,
      ),
      OptionsMenuTab.assist => OptionsAssistControls(
        tokens: tokens,
        language: language,
        showInvalidTapHints: showInvalidTapHints,
        onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
      ),
      OptionsMenuTab.display => OptionsDisplayControls(
        tokens: tokens,
        language: language,
        appearance: appearance,
        animationSpeed: animationSpeed,
        onAnimationSpeedChanged: onAnimationSpeedChanged,
        onLanguageToggle: onLanguageToggle,
        onAppearanceToggle: onAppearanceToggle,
      ),
      OptionsMenuTab.rules => OptionsMenuRules(
        tokens: tokens,
        language: language,
      ),
    };
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

class OptionsSessionControls extends StatelessWidget {
  const OptionsSessionControls({
    required this.tokens,
    required this.language,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;

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
          ],
        ),
        Divider(color: tokens.colors.gold.withValues(alpha: 0.28)),
        ChromePixelLabel(
          language.text(en: 'Safeguards', ru: 'Защита'),
          size: PixelTextSize.caption,
          variant: PixelTextVariant.regular,
          color: tokens.colors.smoke,
        ),
        OptionsSettingToggle(
          tokens: tokens,
          label: language.text(
            en: 'Confirm new game',
            ru: 'Подтверждать новую игру',
          ),
          body: language.text(
            en: 'Ask before replacing the current game.',
            ru: 'Спросить перед заменой текущей партии.',
          ),
          value: confirmNewGame,
          onChanged: onConfirmNewGameChanged,
        ),
        OptionsSettingToggle(
          tokens: tokens,
          label: language.text(
            en: 'Confirm main menu',
            ru: 'Подтверждать выход',
          ),
          body: language.text(
            en: 'Ask before leaving the current game.',
            ru: 'Спросить перед выходом из текущей партии.',
          ),
          value: confirmMainMenu,
          onChanged: onConfirmMainMenuChanged,
        ),
      ],
    );
  }
}

class OptionsAssistControls extends StatelessWidget {
  const OptionsAssistControls({
    required this.tokens,
    required this.language,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: optionsMenuSettingSpacing,
      children: [
        ChromePixelLabel(
          language.text(en: 'Move help', ru: 'Помощь хода'),
          size: PixelTextSize.caption,
          variant: PixelTextVariant.regular,
          color: tokens.colors.smoke,
        ),
        OptionsSettingToggle(
          tokens: tokens,
          label: language.text(en: 'Invalid-tap hints', ru: 'Подсказки ошибок'),
          body: language.text(
            en: 'Show the Foreman reminder when you tap an illegal card.',
            ru: 'Показывать напоминание бригадира при неверной карте.',
          ),
          value: showInvalidTapHints,
          onChanged: onShowInvalidTapHintsChanged,
        ),
      ],
    );
  }
}

class OptionsDisplayControls extends StatelessWidget {
  const OptionsDisplayControls({
    required this.tokens,
    required this.language,
    required this.appearance,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final GameAnimationSpeed animationSpeed;
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
          language.text(en: 'Display', ru: 'Вид'),
          size: PixelTextSize.caption,
          variant: PixelTextVariant.regular,
          color: tokens.colors.smoke,
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
      ],
    );
  }
}

class OptionsSettingToggle extends StatelessWidget {
  const OptionsSettingToggle({
    required this.tokens,
    required this.label,
    required this.body,
    required this.value,
    this.onChanged,
    super.key,
  });

  final DesignTokens tokens;
  final String label;
  final String body;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final foreground = enabled
        ? tokens.colors.creamDim
        : tokens.colors.creamDim.withValues(alpha: 0.5);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      toggled: value,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Container(
            padding: optionsMenuSettingPadding,
            decoration: BoxDecoration(
              color: tokens.colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: value
                    ? tokens.colors.gold.withValues(alpha: 0.58)
                    : tokens.colors.steel.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 9,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value
                        ? tokens.colors.gold.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: value
                          ? tokens.colors.gold
                          : tokens.colors.steel.withValues(alpha: 0.72),
                    ),
                  ),
                  child: value
                      ? Icon(Icons.check, size: 13, color: tokens.colors.gold)
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      ChromePixelLabel(
                        label,
                        size: PixelTextSize.caption,
                        color: value ? tokens.colors.gold : foreground,
                      ),
                      Text(
                        body,
                        softWrap: true,
                        style: kolkhozFontStyle.copyWith(
                          color: foreground,
                          fontSize: menuRuleBodyFontSize,
                          fontWeight: FontWeight.w700,
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
