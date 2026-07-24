import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:simple_animations/simple_animations.dart';
import 'board_widgets.dart'
    show GameCard, cardViewCornerRadius, cardViewStrokeWidth;
import 'card_motion_plan.dart';

/// Renders one immutable flight instruction.
class FlyingCard extends StatelessWidget {
  const FlyingCard({
    required this.flight,
    required this.tokens,
    required this.duration,
    required this.onDone,
    this.trump,
    this.visible = true,
    super.key,
  });

  final CardFlight flight;
  final DesignTokens tokens;
  final Duration duration;
  final VoidCallback onDone;
  final String? trump;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final motion = GameMotion.of(context);
    final flightDuration = scaledGameAnimationDuration(
      duration,
      flight.durationScale,
    );
    final flipDuration = flight.revealBeforeFlight
        ? motion.rewardFlip
        : Duration.zero;
    final totalDuration = flipDuration + flightDuration;
    final flipFraction = totalDuration == Duration.zero
        ? 0.0
        : flipDuration.inMicroseconds / totalDuration.inMicroseconds;
    return PlayAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: totalDuration,
      curve: Curves.linear,
      onCompleted: onDone,
      builder: (context, value, _) {
        final flipProgress = flipFraction == 0
            ? 1.0
            : (value / flipFraction).clamp(0.0, 1.0);
        final rawFlightProgress = flipFraction >= 1
            ? 1.0
            : ((value - flipFraction) / (1 - flipFraction)).clamp(0.0, 1.0);
        final flightProgress = GameMotion.cardFlightCurve.transform(
          rawFlightProgress,
        );
        final rect = Rect.lerp(flight.from, flight.to, flightProgress)!;
        final card = _flyingCardFace(
          faceDown:
              flight.faceDown ||
              (flight.revealBeforeFlight && flipProgress < 0.5),
        );
        final flipTransform = flight.revealBeforeFlight && flipProgress < 1
            ? (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(
                  math.pi * GameMotion.rewardFlipCurve.transform(flipProgress),
                ))
            : null;
        return Positioned.fromRect(
          rect: rect,
          child: Opacity(
            opacity: visible ? 1 : 0,
            child: Transform.scale(
              scale: lerpDouble(1.04, 1, flightProgress)!,
              child: flipTransform == null
                  ? card
                  : Transform(
                      alignment: Alignment.center,
                      transform: flipTransform,
                      child: flipProgress >= 0.5
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: card,
                            )
                          : card,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _flyingCardFace({required bool faceDown}) {
    final size = cardFlightRenderSize(flight.from, flight.to, tokens);
    final card = FittedBox(
      fit: BoxFit.fill,
      child: faceDown
          ? _FlyingCardBack(
              key: ValueKey('flying-card-back-${flight.card.id}'),
              tokens: tokens,
              size: size,
            )
          : GameCard(
              key: ValueKey('flying-card-face-${flight.card.id}'),
              card: flight.card,
              tokens: tokens,
              trump: trump,
              sizeOverride: size,
              motionTracked: false,
            ),
    );
    if (!flight.requisitioned) {
      return card;
    }
    return Container(
      key: ValueKey('requisition-card-frame-${flight.card.id}'),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(color: tokens.colors.redBright, width: 3),
      ),
      child: card,
    );
  }
}

class _FlyingCardBack extends StatelessWidget {
  const _FlyingCardBack({required this.tokens, required this.size, super.key});

  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final cardBack = KolkhozCardBackScope.of(context);
    return Container(
      width: size.width,
      height: size.height,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(
          color: tokens.colors.black.withValues(
            alpha: tokens.colors.cardStrokeOpacity,
          ),
          width: cardViewStrokeWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        child: Image.asset(
          cardBack.displayedAssetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => ColoredBox(color: tokens.colors.iron),
        ),
      ),
    );
  }
}

TokenCardSize cardFlightRenderSize(Rect from, Rect to, DesignTokens tokens) {
  final height = math.max(from.height, to.height);
  if (height <= tokens.card.small.height + 8) {
    return tokens.card.small;
  }
  if (height <= tokens.card.medium.height + 8) {
    return tokens.card.medium;
  }
  return tokens.card.large;
}

Duration scaledDuration(Duration duration, double scale) =>
    scaledGameAnimationDuration(duration, scale);
