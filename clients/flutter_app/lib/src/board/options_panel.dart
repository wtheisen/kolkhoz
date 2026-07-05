part of '../board_view.dart';

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
const optionsMenuContentBottomPadding = 6.0;
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

const commandButtonProminentWidth = commandButtonProminentMinHeight * 4;
const commandButtonProminentMinHeight = 58.0;
const commandButtonProminentHorizontalPadding = 42.0;
const commandButtonProminentTopPadding = 14.0;
const commandButtonProminentBottomPadding = 10.0;
const commandButtonProminentOuterShadowOpacity = 0.34;
const commandButtonProminentOuterShadowRadius = 8.0;
const commandButtonProminentOuterShadowYOffset = 3.0;

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
          final sectionSpacing = optionsMenuSectionSpacing(
            constraints.maxHeight.isFinite ? constraints.maxHeight : 300,
          );
          return PanelStyleSurface(
            tokens: tokens,
            constraints: const BoxConstraints(
              minHeight: optionsPanelSurfaceMinHeight,
              maxHeight: optionsPanelSurfaceMaxHeight,
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
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
                    Divider(color: tokens.colors.gold.withValues(alpha: 0.35)),
                    OptionsMenuRules(tokens: tokens, language: language),
                  ],
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
              child: ActionSurfaceButton(
                label: language.text(en: 'New game', ru: 'Новая игра'),
                iconPath: null,
                prominent: true,
                tokens: tokens,
                onPressed: onNewGame,
              ),
            ),
            Center(
              child: ActionSurfaceButton(
                label: language.text(en: 'How to play', ru: 'Как играть'),
                iconPath: 'ios_resources/Icons/icon-tutorial.png',
                prominent: false,
                tokens: tokens,
                onPressed: onTutorial,
              ),
            ),
            Center(
              child: ActionSurfaceButton(
                label: language.text(en: 'Main menu', ru: 'Главное меню'),
                iconPath: 'ios_resources/Icons/icon-menu.png',
                prominent: false,
                mutedBorder: true,
                tokens: tokens,
                onPressed: onReturnToLobby,
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
        MenuRuleRow(
          iconPath: 'ios_resources/Icons/icon-jobs.png',
          title: language.text(en: 'Work', ru: 'Работы'),
          body: language.text(
            en: 'Win tricks, then assign captured cards to matching jobs.',
            ru: 'Выигрывайте взятки и назначайте карты на подходящие работы.',
          ),
          tokens: tokens,
        ),
        MenuRuleRow(
          iconPath: 'ios_resources/Icons/icon-plot.png',
          title: language.text(en: 'Protect', ru: 'Защита'),
          body: language.text(
            en: 'Keep plot cards safe from failed-job requisition.',
            ru: 'Берегите карты участка от реквизиции за проваленные работы.',
          ),
          tokens: tokens,
        ),
        MenuRuleRow(
          iconPath: 'ios_resources/Icons/icon-warning.png',
          title: language.text(en: 'Trump faces', ru: 'Козырные карты'),
          body: language.text(
            en: 'Jack goes north, Queen exposes, King doubles exile.',
            ru: 'Валет уходит на Север, Дама раскрывает, Король удваивает ссылку.',
          ),
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

class ActionSurfaceButton extends StatelessWidget {
  const ActionSurfaceButton({
    required this.label,
    required this.iconPath,
    required this.prominent,
    required this.tokens,
    this.mutedBorder = false,
    this.onPressed,
    super.key,
  });

  final String label;
  final String? iconPath;
  final bool prominent;
  final bool mutedBorder;
  final DesignTokens tokens;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = _buttonSurface();
    if (onPressed == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: child,
    );
  }

  Widget _buttonSurface() {
    if (prominent) {
      return CommandSurfaceButton(label: label, tokens: tokens);
    }
    return Container(
      width: optionsMenuActionWidth,
      height: optionsMenuActionHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: optionsMenuActionHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: mutedBorder
              ? tokens.colors.steel.withValues(alpha: 0.5)
              : tokens.colors.gold.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        spacing: optionsMenuActionContentSpacing,
        children: [
          if (iconPath != null)
            Opacity(
              opacity: iconMutedOpacity,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(
                  iconMutedSaturationMatrix,
                ),
                child: Image.asset(
                  iconPath!,
                  width: optionsMenuActionIconSize,
                  height: optionsMenuActionIconSize,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          Flexible(
            child: ChromePixelLabel(
              label.toUpperCase(),
              size: PixelTextSize.caption,
              color: tokens.colors.creamDim,
            ),
          ),
        ],
      ),
    );
  }
}

class CommandSurfaceButton extends StatelessWidget {
  const CommandSurfaceButton({
    required this.label,
    required this.tokens,
    super.key,
  });

  final String label;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('command-surface-button'),
      width: commandButtonProminentWidth,
      height: commandButtonProminentMinHeight,
      constraints: const BoxConstraints(
        minHeight: commandButtonProminentMinHeight,
      ),
      padding: const EdgeInsets.only(
        left: commandButtonProminentHorizontalPadding,
        right: commandButtonProminentHorizontalPadding,
        top: commandButtonProminentTopPadding,
        bottom: commandButtonProminentBottomPadding,
      ),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('ios_resources/ui-button-primary.png'),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(
              alpha: commandButtonProminentOuterShadowOpacity,
            ),
            blurRadius: commandButtonProminentOuterShadowRadius,
            offset: const Offset(0, commandButtonProminentOuterShadowYOffset),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: CommandSurfaceButtonLabel(label.toUpperCase(), tokens: tokens),
        ),
      ),
    );
  }
}

class CommandSurfaceButtonLabel extends StatelessWidget {
  const CommandSurfaceButtonLabel(
    this.label, {
    required this.tokens,
    super.key,
  });

  final String label;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ChromePixelLabel(
      label.toUpperCase(),
      size: PixelTextSize.headline,
      color: tokens.colors.onAccent,
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
              child: Opacity(
                opacity: 0.82,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(
                    iconMutedSaturationMatrix,
                  ),
                  child: Image.asset(
                    iconPath,
                    width: 17,
                    height: 17,
                    filterQuality: FilterQuality.none,
                  ),
                ),
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
