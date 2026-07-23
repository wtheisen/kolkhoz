import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:simple_animations/simple_animations.dart';
import 'board_widgets.dart' show GameCard;
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
    return PlayAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: scaledGameAnimationDuration(duration, flight.durationScale),
      curve: GameMotion.cardFlightCurve,
      onCompleted: onDone,
      builder: (context, value, child) {
        final rect = Rect.lerp(flight.from, flight.to, value)!;
        return Positioned.fromRect(
          rect: rect,
          child: Opacity(
            opacity: visible ? 1 : 0,
            child: Transform.scale(
              scale: lerpDouble(1.04, 1, value)!,
              child: child,
            ),
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.fill,
        child: GameCard(
          card: flight.card,
          tokens: tokens,
          trump: trump,
          sizeOverride: cardFlightRenderSize(flight.from, flight.to, tokens),
          motionTracked: false,
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
