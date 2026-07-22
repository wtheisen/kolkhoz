import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/card_art_display.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'card_motion.dart';

export 'card_motion.dart';

const panelTitleScaleBaseWidth = 520.0;
const panelTitleScaleMin = 0.78;
const panelTitleScaleMax = 1.0;
const panelTitleIconBoxBase = 40.0;
const panelTitleIconSizeBase = 24.0;
const panelTitleHorizontalPaddingBase = 9.0;
const panelTitleVerticalPaddingBase = 7.0;
const panelTitleSpacingBase = 10.0;
const panelTitleOrnamentWidth = 104.0;
const panelTitleOrnamentHeight = 24.0;
const panelTitleOrnamentTrailingPadding = 8.0;
const panelTitleOrnamentFadeStartWidth = 320.0;
const panelTitleOrnamentFadeDistance = 180.0;
const panelTitleOrnamentMaxOpacity = 0.52;
const panelTitleUrgentOrnamentMaxOpacity = 0.42;

double panelTitleScale(double width) {
  return clampDouble(
    width / panelTitleScaleBaseWidth,
    panelTitleScaleMin,
    panelTitleScaleMax,
  );
}

double panelTitleIconBox(double width) =>
    panelTitleIconBoxBase * panelTitleScale(width);

double panelTitleIconSize(double width) =>
    panelTitleIconSizeBase * panelTitleScale(width);

double panelTitleHorizontalPadding(double width) =>
    panelTitleHorizontalPaddingBase * panelTitleScale(width);

double panelTitleVerticalPadding(double width) =>
    panelTitleVerticalPaddingBase * panelTitleScale(width);

double panelTitleSpacing(double width) =>
    panelTitleSpacingBase * panelTitleScale(width);

double panelTitleOrnamentOpacity(double width, {required bool urgent}) {
  return clampDouble(
    (width - panelTitleOrnamentFadeStartWidth) / panelTitleOrnamentFadeDistance,
    0,
    urgent ? panelTitleUrgentOrnamentMaxOpacity : panelTitleOrnamentMaxOpacity,
  );
}

double panelTitleEffectiveOrnamentOpacity(
  double width, {
  required bool urgent,
}) {
  return panelTitleOrnamentOpacity(width, urgent: urgent);
}

class ChromePixelLabel extends StatelessWidget {
  const ChromePixelLabel(
    this.text, {
    required this.size,
    required this.color,
    this.variant = PixelTextVariant.heavy,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.softWrap = false,
    this.uppercase = true,
    super.key,
  });

  final String text;
  final PixelTextSize size;
  final PixelTextVariant variant;
  final Color color;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return PixelText(
      uppercase ? text.toUpperCase() : text,
      size: size,
      variant: variant,
      color: color,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.clip,
      softWrap: softWrap,
    );
  }
}

class CommandPanelSurface extends StatelessWidget {
  const CommandPanelSurface({
    required this.tokens,
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final DesignTokens tokens;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.26)),
        gradient: LinearGradient(
          colors: [
            tokens.colors.panel,
            tokens.colors.iron,
            tokens.colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.md),
          gradient: LinearGradient(
            colors: [
              tokens.colors.gold.withValues(alpha: 0.14),
              Colors.transparent,
              tokens.colors.redDark.withValues(alpha: 0.14),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PanelStyleSurface extends StatelessWidget {
  const PanelStyleSurface({
    required this.tokens,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.constraints,
    super.key,
  });

  final DesignTokens tokens;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.colors.panel,
            tokens.colors.iron.withValues(alpha: 0.96),
            tokens.colors.black.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
        border: Border.all(
          color: tokens.colors.gold.withValues(alpha: 0.72),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.colors.gold.withValues(alpha: 0.16),
                      Colors.transparent,
                      tokens.colors.redDark.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      tokens.radius.panelInner,
                    ),
                    border: Border.all(
                      color: tokens.colors.redDark.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KolkhozScrollbar extends StatefulWidget {
  const KolkhozScrollbar({
    required this.tokens,
    required this.childBuilder,
    this.orientation,
    this.thumbVisibility = true,
    this.trackVisibility = true,
    super.key,
  });

  final DesignTokens tokens;
  final ScrollbarOrientation? orientation;
  final bool thumbVisibility;
  final bool trackVisibility;
  final Widget Function(BuildContext context, ScrollController controller)
  childBuilder;

  @override
  State<KolkhozScrollbar> createState() => _KolkhozScrollbarState();
}

class _KolkhozScrollbarState extends State<KolkhozScrollbar> {
  late final ScrollController controller;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(widget.thumbVisibility),
        trackVisibility: WidgetStatePropertyAll(widget.trackVisibility),
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          widget.tokens.colors.gold.withValues(alpha: 0.68),
        ),
        trackColor: WidgetStatePropertyAll(
          widget.tokens.colors.black.withValues(alpha: 0.12),
        ),
        trackBorderColor: WidgetStatePropertyAll(
          widget.tokens.colors.steel.withValues(alpha: 0.28),
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: widget.thumbVisibility,
        trackVisibility: widget.trackVisibility,
        scrollbarOrientation: widget.orientation,
        child: widget.childBuilder(context, controller),
      ),
    );
  }
}

class PanelTitleRow extends StatelessWidget {
  const PanelTitleRow({
    required this.title,
    required this.iconPath,
    required this.tokens,
    this.subtitle,
    this.urgent = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String iconPath;
  final bool urgent;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconBox = panelTitleIconBox(constraints.maxWidth);
        final iconSize = panelTitleIconSize(constraints.maxWidth);
        final horizontalPadding = panelTitleHorizontalPadding(
          constraints.maxWidth,
        );
        final verticalPadding = panelTitleVerticalPadding(constraints.maxWidth);
        final spacing = panelTitleSpacing(constraints.maxWidth);
        final ornamentOpacity = panelTitleEffectiveOrnamentOpacity(
          constraints.maxWidth,
          urgent: urgent,
        );
        final titleColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            PixelText(
              title.toUpperCase(),
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: urgent ? tokens.colors.redBright : tokens.colors.gold,
            ),
            if (subtitle != null)
              PixelText(
                subtitle!,
                size: PixelTextSize.caption,
                color: tokens.colors.creamDim,
              ),
          ],
        );
        final titleContent = constraints.hasBoundedHeight
            ? SizedBox(
                height: math.max(
                  0,
                  constraints.maxHeight - verticalPadding * 2,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: titleColumn,
                  ),
                ),
              )
            : titleColumn;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                right: panelTitleOrnamentTrailingPadding,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: ornamentOpacity,
                    child: Image.asset(
                      'assets/ui/Embellishments/panel-divider-pixel.png',
                      width: panelTitleOrnamentWidth,
                      height: panelTitleOrnamentHeight,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Row(
                spacing: spacing,
                children: [
                  Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: urgent
                            ? [
                                tokens.colors.redDark,
                                tokens.colors.red.withValues(alpha: 0.82),
                              ]
                            : [
                                tokens.colors.black.withValues(alpha: 0.58),
                                tokens.colors.steel.withValues(alpha: 0.36),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: urgent
                            ? tokens.colors.redBright
                            : tokens.colors.gold.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        iconPath,
                        width: iconSize,
                        height: iconSize,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  Expanded(child: titleContent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({
    required this.card,
    required this.tokens,
    this.trump,
    this.small = false,
    this.highlightColorOverride,
    this.highlightGlowEnabled = true,
    this.highlightedStrokeWidthOverride,
    this.highlightedBorderRadiusOverride,
    this.selectedColorOverride,
    this.selectedStrokeWidthOverride,
    this.sizeOverride,
    this.motionTracked = true,
    this.fieldPlanSeatID,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final bool small;
  final Color? highlightColorOverride;
  final bool highlightGlowEnabled;
  final double? highlightedStrokeWidthOverride;
  final double? highlightedBorderRadiusOverride;
  final Color? selectedColorOverride;
  final double? selectedStrokeWidthOverride;
  final TokenCardSize? sizeOverride;
  final bool motionTracked;
  final int? fieldPlanSeatID;

  @override
  Widget build(BuildContext context) {
    final size =
        sizeOverride ?? (small ? tokens.card.small : tokens.card.large);
    final plantedFace =
        configuredKolkhozArtStyle.usesNewArt && fieldPlanSeatID != null;
    final highlightColor = card.highlighted
        ? highlightColorOverride ??
              cardHighlightColor(card: card, trump: trump, tokens: tokens)
        : null;
    final highlightGlow = highlightGlowEnabled ? highlightColor : null;
    final highlightBorder = card.selected
        ? selectedColorOverride ?? tokens.colors.green
        : card.highlighted
        ? highlightColor
        : null;
    final highlightBorderWidth = card.selected
        ? selectedStrokeWidthOverride ?? tokens.stroke.active
        : card.highlighted
        ? highlightedStrokeWidthOverride ?? tokens.stroke.active
        : 0.0;
    final cardSurface = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: plantedFace ? Colors.transparent : tokens.colors.panel,
        borderRadius: BorderRadius.circular(
          plantedFace ? 0 : cardViewCornerRadius,
        ),
        boxShadow: highlightGlow == null
            ? null
            : [
                BoxShadow(
                  color: highlightGlow.withValues(
                    alpha: cardHighlightShadowOpacity,
                  ),
                  blurRadius: cardHighlightShadowRadius,
                ),
              ],
      ),
      child: Stack(
        children: [
          if (!plantedFace)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cardViewCornerRadius),
                child: Image.asset(
                  cardTemplateAssetPath(
                    card: card,
                    tokens: tokens,
                    trump: trump,
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (plantedFace)
            Positioned.fill(
              child: Image.asset(
                fieldPlanPlantedCardFacePath(fieldPlanSeatID!),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(size.faceInset),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CardCenterFace(
                    card: card,
                    size: size,
                    tokens: tokens,
                    trump: trump,
                  ),
                ),
                Positioned(
                  left: cardCornerHorizontalInset(size) + (plantedFace ? 4 : 0),
                  top: cardTopCornerVerticalInset(size) + (plantedFace ? 2 : 0),
                  child: CardCornerIndex(
                    card: card,
                    size: size,
                    tokens: tokens,
                    placement: CardCornerPlacement.top,
                    trump: trump,
                  ),
                ),
                Positioned(
                  right:
                      cardCornerHorizontalInset(size) + (plantedFace ? 4 : 0),
                  bottom:
                      cardBottomCornerVerticalInset(size) +
                      (plantedFace ? 2 : 0),
                  child: CardCornerIndex(
                    card: card,
                    size: size,
                    tokens: tokens,
                    placement: CardCornerPlacement.bottom,
                    trump: trump,
                  ),
                ),
              ],
            ),
          ),
          if (!plantedFace)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardViewCornerRadius),
                    border: Border.all(
                      color: tokens.colors.black.withValues(
                        alpha: tokens.colors.cardStrokeOpacity,
                      ),
                      width: cardViewStrokeWidth,
                    ),
                  ),
                ),
              ),
            ),
          if (highlightBorder != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      highlightedBorderRadiusOverride ?? cardViewCornerRadius,
                    ),
                    border: Border.all(
                      color: highlightBorder,
                      width: highlightBorderWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!motionTracked) {
      return cardSurface;
    }
    return MotionTrackedCard(card: card, child: cardSurface);
  }
}

double cardCornerHorizontalInset(TokenCardSize size) => 0;

double cardTopCornerVerticalInset(TokenCardSize size) => -(size.height * 0.006);

double cardBottomCornerVerticalInset(TokenCardSize size) => 0;

double cardFaceValueRankGap(TokenCardSize size) =>
    (size.cornerRankFontSize * 0.16).clamp(2, 8).toDouble();

double cardCornerRankSuitGap(TokenCardSize size) =>
    (size.cornerSuitSize * 0.01).clamp(0, 0.5).toDouble();

double cardBottomCornerRankSuitGap(TokenCardSize size) =>
    (size.cornerSuitSize * 0.08).clamp(0.5, 2).toDouble();

double cardCornerSuitOutwardOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.12).clamp(0.5, 2.5).toDouble();

double cardCornerSuitVisualSize(TableCard card, TokenCardSize size) {
  final suitScale = card.suit == wreckerSuit ? 1.5 : 1.0;
  return size.cornerSuitSize * 1.1 * suitScale;
}

double cardCornerSuitTowardRankOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.25).clamp(1.5, 5).toDouble();

double cardBottomCornerRankDownOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.2).clamp(1, 4).toDouble();

double cardCornerRankVisualHeight(TokenCardSize size) {
  final rankSize = pixelTextSizeForCardRank(size);
  return (rankSize.value + PixelText.opticalYOffset) *
      pixelTextScaleForCardRank(size);
}

enum CardCornerPlacement { top, bottom }

class CardCornerIndex extends StatelessWidget {
  const CardCornerIndex({
    required this.card,
    required this.size,
    required this.tokens,
    required this.placement,
    this.trump,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;
  final CardCornerPlacement placement;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    final countsAsTrump =
        trump != null && (card.suit == trump || card.suit == wreckerSuit);
    final top = placement == CardCornerPlacement.top;
    final spacing = top
        ? cardCornerRankSuitGap(size)
        : cardBottomCornerRankSuitGap(size);
    final rankSize = pixelTextSizeForCardRank(size);
    final rankScale = pixelTextScaleForCardRank(size);
    final rankHeight = cardCornerRankVisualHeight(size);
    final suitSize = cardCornerSuitVisualSize(card, size);
    final frameHeight = rankHeight + suitSize + spacing;
    final showFaceValue = cardShowsFaceNumericValue(card);
    final labelWidth = showFaceValue
        ? size.cornerWidth + size.cornerRankFontSize * 1.15
        : size.cornerWidth;
    final rankColor = countsAsTrump ? tokens.colors.red : tokens.colors.cream;
    final rankText = SizedBox(
      height: rankHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: Transform.scale(
          scale: rankScale,
          alignment: top ? Alignment.centerLeft : Alignment.centerRight,
          child: PixelText(
            card.rank,
            size: rankSize,
            variant: PixelTextVariant.heavy,
            color: rankColor,
            textAlign: top ? TextAlign.start : TextAlign.end,
          ),
        ),
      ),
    );
    final valueText = Padding(
      padding: EdgeInsets.zero,
      child: PixelText(
        '${card.value}',
        size: pixelTextSizeForCardFaceValue(size),
        variant: PixelTextVariant.heavy,
        color: rankColor,
      ),
    );
    final rankContent = showFaceValue
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: top
                ? [
                    rankText,
                    SizedBox(width: cardFaceValueRankGap(size)),
                    valueText,
                  ]
                : [
                    valueText,
                    SizedBox(width: cardFaceValueRankGap(size)),
                    rankText,
                  ],
          )
        : rankText;
    final rank = SizedBox(
      width: labelWidth,
      height: rankHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: top ? Alignment.centerLeft : Alignment.centerRight,
          child: rankContent,
        ),
      ),
    );
    final suit = Transform.translate(
      offset: Offset(
        top
            ? size.topCornerSuitXOffset - cardCornerSuitOutwardOffset(size)
            : size.bottomCornerSuitXOffset + cardCornerSuitOutwardOffset(size),
        0,
      ),
      child: SuitMark(suit: card.suit, tokens: tokens, size: suitSize),
    );

    return SizedBox(
      width: size.cornerWidth,
      height: frameHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: top
            ? [
                Positioned(left: 0, top: 0, child: rank),
                Positioned(
                  left: 0,
                  top:
                      rankHeight +
                      spacing -
                      cardCornerSuitTowardRankOffset(size),
                  child: SizedBox(
                    width: suitSize,
                    height: suitSize,
                    child: suit,
                  ),
                ),
              ]
            : [
                Positioned(
                  right: 0,
                  top: cardCornerSuitTowardRankOffset(size),
                  child: SizedBox(
                    width: suitSize,
                    height: suitSize,
                    child: suit,
                  ),
                ),
                Positioned(
                  right: 0,
                  top:
                      suitSize + spacing + cardBottomCornerRankDownOffset(size),
                  child: rank,
                ),
              ],
      ),
    );
  }
}

class CardCenterFace extends StatelessWidget {
  const CardCenterFace({
    required this.card,
    required this.size,
    required this.tokens,
    this.trump,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    final countsAsTrump =
        trump != null && (card.suit == trump || card.suit == wreckerSuit);
    if (size.width <= tokens.card.small.width + 0.1) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              SuitMark(suit: card.suit, tokens: tokens, size: 14),
              PixelText(
                cardRankDisplayLabel(card),
                size: PixelTextSize.caption2,
                variant: PixelTextVariant.heavy,
                color: countsAsTrump ? tokens.colors.red : tokens.colors.cream,
              ),
            ],
          ),
        ),
      );
    }

    if (card.suit == wreckerSuit || card.value >= 11) {
      final portraitWidth = facePortraitArtWidth(card, size);
      final fieldPlanFace = cardUsesFieldPlanFaceArt(card);
      return Center(
        child: SizedBox(
          width: portraitWidth,
          height: portraitWidth * 1.5,
          child: Image.asset(
            faceAssetPath(card),
            fit: fieldPlanFace ? BoxFit.contain : BoxFit.cover,
            filterQuality: fieldPlanFace
                ? FilterQuality.high
                : FilterQuality.none,
            isAntiAlias: fieldPlanFace,
            errorBuilder: (_, _, _) => Image.asset(
              genericFaceAssetPath(card),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => SuitMark(
                suit: card.suit,
                tokens: tokens,
                size: size.width * 0.34,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.16,
        vertical: size.height * 0.02,
      ),
      child: PipPattern(card: card, size: size, tokens: tokens),
    );
  }
}

class PipPattern extends StatelessWidget {
  const PipPattern({
    required this.card,
    required this.size,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (configuredKolkhozArtStyle.usesNewArt &&
        card.suit == 'sunflower' &&
        card.value == 8) {
      return FieldPlanSunflowerRows(size: size);
    }

    final positions = pipPositions(card.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final point in positions)
              Positioned(
                left: constraints.maxWidth * point.dx - size.pipSize / 2,
                top: constraints.maxHeight * point.dy - size.pipSize / 2,
                child: SuitMark(
                  suit: card.suit,
                  tokens: tokens,
                  size: size.pipSize,
                ),
              ),
          ],
        );
      },
    );
  }
}

class FieldPlanSunflowerRows extends StatelessWidget {
  const FieldPlanSunflowerRows({required this.size, super.key});

  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    const crops = <({double x, double y, double scale})>[
      (x: 0.38, y: 0.20, scale: 0.70),
      (x: 0.62, y: 0.20, scale: 0.70),
      (x: 0.24, y: 0.48, scale: 0.88),
      (x: 0.50, y: 0.48, scale: 0.88),
      (x: 0.76, y: 0.48, scale: 0.88),
      (x: 0.22, y: 0.78, scale: 1.06),
      (x: 0.50, y: 0.78, scale: 1.06),
      (x: 0.78, y: 0.78, scale: 1.06),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: const Key('field-plan-sunflower-crop-rows'),
          clipBehavior: Clip.none,
          children: [
            for (final crop in crops)
              Positioned(
                left:
                    constraints.maxWidth * crop.x -
                    size.pipSize * crop.scale * 1.55 / 2,
                top:
                    constraints.maxHeight * crop.y -
                    size.pipSize * crop.scale * 1.55 / 2,
                child: FieldPlanSunflowerCropMark(
                  size: size.pipSize * crop.scale * 1.55,
                ),
              ),
          ],
        );
      },
    );
  }
}

class FieldPlanSunflowerCropMark extends StatelessWidget {
  const FieldPlanSunflowerCropMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      size <= 24
          ? fieldPlanPlantedSunflowerMipPath
          : fieldPlanPlantedSunflowerPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

class MiniRewardCard extends StatelessWidget {
  const MiniRewardCard({
    required this.card,
    required this.claimed,
    required this.height,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final bool claimed;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 24 / 34,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.cardFill,
            borderRadius: BorderRadius.circular(tokens.radius.xs),
            border: Border.all(
              color: claimed
                  ? tokens.colors.green
                  : tokens.colors.black.withValues(
                      alpha: tokens.colors.cardStrokeOpacity,
                    ),
              width: claimed ? 2 : 1,
            ),
          ),
          child: SizedBox(
            width: 24,
            height: 34,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: miniRewardRankTop,
                  child: SizedBox(
                    width: 24,
                    child: Center(
                      child: PixelText(
                        cardRankDisplayLabel(card),
                        size: PixelTextSize.caption,
                        variant: PixelTextVariant.heavy,
                        color: tokens.colors.cardInk,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: miniRewardSuitTop,
                  child: SuitMark(suit: card.suit, tokens: tokens, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const miniRewardRankTop = -1.0;
const miniRewardSuitTop = 13.0;
const topInfoEmptyRewardCheckSize = 17.0;
const jobTileEmptyRewardCheckSize = 18.0;

class EmptyRewardMarker extends StatelessWidget {
  const EmptyRewardMarker({
    required this.size,
    required this.tokens,
    this.checkSize = jobTileEmptyRewardCheckSize,
    super.key,
  });

  final double size;
  final DesignTokens tokens;
  final double checkSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 24 / 34,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.xs),
            border: Border.all(
              color: tokens.colors.green.withValues(alpha: 0.7),
            ),
          ),
          child: SizedBox(
            width: 24,
            height: 34,
            child: Center(
              child: Image.asset(
                'assets/ui/Icons/icon-check.png',
                width: checkSize,
                height: checkSize,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    required this.complete,
    required this.tokens,
    super.key,
  });

  final double value;
  final bool complete;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final clampedValue = clampDouble(value, 0, 1);
          final fillWidth = clampedValue <= 0 || constraints.maxWidth <= 0
              ? 0.0
              : clampDouble(
                  constraints.maxWidth * clampedValue,
                  math.min(4.0, constraints.maxWidth),
                  constraints.maxWidth,
                );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.black,
              borderRadius: BorderRadius.circular(tokens.radius.xs),
              border: Border.all(
                color: tokens.colors.steel.withValues(alpha: 0.8),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: fillWidth,
                  height: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: complete
                            ? [tokens.colors.green, tokens.colors.gold]
                            : [
                                const Color.fromRGBO(138, 105, 20, 1),
                                tokens.colors.gold,
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
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

class SuitDot extends StatelessWidget {
  const SuitDot({
    required this.suit,
    required this.tokens,
    this.size = 12,
    super.key,
  });

  final String suit;
  final DesignTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: suitColor(tokens, suit),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SuitMark extends StatelessWidget {
  const SuitMark({
    required this.suit,
    required this.tokens,
    required this.size,
    super.key,
  });

  final String suit;
  final DesignTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fieldPlanSuit =
        configuredKolkhozArtStyle.usesNewArt &&
        fieldPlanCardSuitAssetPath(suit) != null;
    final useMip = fieldPlanSuit && size <= 24;
    return Image.asset(
      suitAssetPath(suit, mip: useMip),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: fieldPlanSuit ? FilterQuality.high : FilterQuality.none,
      isAntiAlias: fieldPlanSuit,
      errorBuilder: (_, _, _) =>
          SuitDot(suit: suit, tokens: tokens, size: size),
    );
  }
}

const opponentPlotMiniSectionRadius = 4.0;
const opponentPlotMiniExileRadius = 6.0;

class NaturalSizeViewport extends StatelessWidget {
  const NaturalSizeViewport({
    required this.width,
    required this.height,
    required this.naturalWidth,
    required this.naturalHeight,
    required this.child,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final double width;
  final double height;
  final double naturalWidth;
  final double naturalHeight;
  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final viewportChild = OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: naturalWidth,
      maxWidth: naturalWidth,
      minHeight: naturalHeight,
      maxHeight: naturalHeight,
      child: child,
    );
    return SizedBox(
      width: width,
      height: height,
      child: clipBehavior == Clip.none
          ? viewportChild
          : ClipRect(clipBehavior: clipBehavior, child: viewportChild),
    );
  }
}

const double cardViewCornerRadius = 8;
const double cardViewStrokeWidth = 0.8;
const double cardHighlightShadowOpacity = 0.34;
const double cardHighlightShadowRadius = 9;

class PlayerPortrait extends StatelessWidget {
  const PlayerPortrait({
    required this.seat,
    required this.tokens,
    required this.width,
    required this.height,
    this.badgeVisible,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final double width;
  final double height;
  final bool? badgeVisible;

  @override
  Widget build(BuildContext context) {
    final fieldPlan = configuredKolkhozArtStyle.usesNewArt;
    final imageWidth = width * 32 / 38;
    final imageHeight = height * 36 / 42;
    final medalSize = math.max(7.0, math.min(width, height) * 9 / 38);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: imageWidth,
              height: imageHeight,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(fieldPlan ? 0 : 3),
                border: Border.all(
                  color: tokens.colors.black.withValues(alpha: 0.68),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(fieldPlan ? 0 : 3),
                child: Image.asset(
                  portraitAssetPath(seat),
                  fit: BoxFit.cover,
                  filterQuality: fieldPlan
                      ? FilterQuality.medium
                      : FilterQuality.none,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/ui/worker4.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: tokens.colors.black.withValues(alpha: 0.42),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badgeVisible ?? isHumanControlledSeat(seat))
            Positioned(
              right: 2,
              top: 2,
              child: Image.asset(
                'assets/ui/Icons/icon-medal-star.png',
                width: medalSize,
                height: medalSize,
                filterQuality: FilterQuality.none,
              ),
            ),
        ],
      ),
    );
  }
}

const double playerPortraitFrameWidth = 38;
const double playerPortraitFrameHeight = 42;

class PortraitFrame extends StatelessWidget {
  const PortraitFrame({
    required this.seat,
    required this.tokens,
    required this.width,
    required this.height,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: math.max(width, playerPortraitFrameWidth),
        maxHeight: math.max(height, playerPortraitFrameHeight),
        child: PlayerPortrait(
          seat: seat,
          tokens: tokens,
          width: width,
          height: height,
        ),
      ),
    );
  }
}
