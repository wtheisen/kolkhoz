import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../pixel_text.dart';
import '../render_model.dart';
import 'board_widgets.dart';

const northColumnVerticalInset = 24.0;
const northHeaderHeight = 34.0;
const northCardScrollReservedHeight = 16.0;
const northEmptyYearMinHeight = 80.0;
const northEmptyYearSpacing = 32.0;
const northCardScaleFactor = 0.8;
const northCardExposedFraction = 0.5;

double northCardScrollHeight({
  required double columnHeight,
  required double headerHeight,
}) {
  return math.max(
    0,
    columnHeight - headerHeight - northCardScrollReservedHeight,
  );
}

class NorthPanel extends StatelessWidget {
  const NorthPanel({
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
    final exiledByYear = model.table.exiledByYear;
    return CommandPanelSurface(
      tokens: tokens,
      child: Stack(
        children: [
          Positioned(
            right: 14,
            bottom: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = clampDouble(constraints.maxWidth * 0.44, 0, 300);
                return Opacity(
                  opacity: 0.16,
                  child: Image.asset(
                    'ios_resources/Embellishments/art-north-requisition-banner.png',
                    width: width,
                    height: 58,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final columnHeight = math.max(
                0.0,
                constraints.maxHeight - northColumnVerticalInset,
              );
              const headerHeight = northHeaderHeight;
              final cardScrollHeight = northCardScrollHeight(
                columnHeight: columnHeight,
                headerHeight: headerHeight,
              );
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: spacing,
                  children: [
                    for (var year = 1; year <= finalGameYear; year++)
                      Expanded(
                        child: NorthYearColumn(
                          year: year,
                          cards: exiledByYear[year] ?? const [],
                          seats: model.table.seats,
                          currentYear: model.table.year,
                          headerHeight: headerHeight,
                          columnHeight: columnHeight,
                          cardScrollHeight: cardScrollHeight,
                          tokens: tokens,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class NorthYearColumn extends StatelessWidget {
  const NorthYearColumn({
    required this.year,
    required this.cards,
    required this.seats,
    required this.currentYear,
    required this.headerHeight,
    required this.columnHeight,
    required this.cardScrollHeight,
    required this.tokens,
    super.key,
  });

  final int year;
  final List<TableCard> cards;
  final List<Seat> seats;
  final int currentYear;
  final double headerHeight;
  final double columnHeight;
  final double cardScrollHeight;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final current = year == currentYear;
    return Container(
      height: columnHeight,
      padding: const EdgeInsets.only(top: 3, left: 3, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: current ? 0.38 : 0.24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: current
              ? tokens.colors.redBright
              : tokens.colors.steel.withValues(alpha: 0.6),
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                Image.asset(
                  'ios_resources/Icons/icon-year-$year.png',
                  width: 32,
                  height: 32,
                  filterQuality: FilterQuality.none,
                ),
                const Spacer(),
                PixelText(
                  '${cards.length}',
                  size: PixelTextSize.cardRank,
                  variant: PixelTextVariant.heavy,
                  color: tokens.colors.creamDim,
                ),
              ],
            ),
          ),
          Flexible(
            child: SizedBox(
              height: cardScrollHeight,
              child: ClipRect(
                child: NorthCardScrollRegion(
                  child: cards.isEmpty
                      ? NorthEmptyYear(current: current, tokens: tokens)
                      : NorthCardStack(
                          cards: cards,
                          seats: seats,
                          tokens: tokens,
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

class NorthCardScrollRegion extends StatelessWidget {
  const NorthCardScrollRegion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: child,
    );
  }
}

class NorthCardStack extends StatelessWidget {
  const NorthCardStack({
    required this.cards,
    required this.seats,
    required this.tokens,
    super.key,
  });

  final List<TableCard> cards;
  final List<Seat> seats;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * northCardScaleFactor;
        final cardScale = cardWidth / tokens.card.large.width;
        final cardHeight = tokens.card.large.height * cardScale;
        final cardStride = cardHeight * northCardExposedFraction;
        final stackHeight = cards.isEmpty
            ? 0.0
            : cardHeight + cardStride * (cards.length - 1);
        return SizedBox(
          width: constraints.maxWidth,
          height: stackHeight + cardWidth * 0.1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (index, card) in cards.indexed)
                Positioned(
                  left: (constraints.maxWidth - cardWidth) / 2,
                  top: index * cardStride,
                  child: SizedBox(
                    key: ValueKey('north-card-${card.id}'),
                    width: cardWidth,
                    height: cardHeight,
                    child: Stack(
                      children: [
                        NaturalSizeViewport(
                          width: cardWidth,
                          height: cardHeight,
                          naturalWidth: tokens.card.large.width,
                          naturalHeight: tokens.card.large.height,
                          child: Transform.scale(
                            alignment: Alignment.topLeft,
                            scale: cardScale,
                            child: GameCard(
                              card: card,
                              tokens: tokens,
                              sizeOverride: tokens.card.large,
                            ),
                          ),
                        ),
                        if (seatForCard(card) case final seat?)
                          Positioned(
                            right: 3,
                            top: 3,
                            child: PortraitFrame(
                              key: ValueKey('north-card-${card.id}-portrait'),
                              seat: seat,
                              tokens: tokens,
                              width: 24 * cardScale,
                              height: 27 * cardScale,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Seat? seatForCard(TableCard card) {
    final ownerSeatID = card.ownerSeatID;
    if (ownerSeatID == null) return null;
    for (final seat in seats) {
      if (seat.id == ownerSeatID) return seat;
    }
    return null;
  }
}

class NorthEmptyYear extends StatelessWidget {
  const NorthEmptyYear({
    required this.current,
    required this.tokens,
    super.key,
  });

  final bool current;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: northEmptyYearMinHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: northEmptyYearSpacing,
          children: [
            const SizedBox.shrink(),
            Image.asset(
              'ios_resources/Embellishments/art-official-crop-seal.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              opacity: AlwaysStoppedAnimation(current ? 0.86 : 0.5),
              errorBuilder: (_, _, _) => Image.asset(
                'ios_resources/Icons/icon-crop-seal.png',
                width: 64,
                height: 64,
                filterQuality: FilterQuality.none,
              ),
            ),
            PixelText(
              '-',
              size: PixelTextSize.cardRank,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.smoke.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}
