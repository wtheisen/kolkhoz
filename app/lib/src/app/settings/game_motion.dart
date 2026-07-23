import 'package:flutter/widgets.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';

/// Central motion policy for game presentation.
///
/// Durations, easing, and reduced-motion behavior live here so individual
/// widgets describe what moves rather than inventing their own animation rules.
class GameMotion {
  const GameMotion({required this.speed, this.disableAnimations = false});

  factory GameMotion.of(
    BuildContext context, {
    GameAnimationSpeed speed = GameAnimationSpeed.normal,
  }) {
    return GameMotion(
      speed: speed,
      disableAnimations:
          MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
  }

  final GameAnimationSpeed speed;
  final bool disableAnimations;

  bool get enabled =>
      !disableAnimations && speed.cardFlightDuration != Duration.zero;
  Duration get cardFlightDuration =>
      disableAnimations ? Duration.zero : speed.cardFlightDuration;
  Duration get cardLandingHold =>
      enabled ? const Duration(milliseconds: 140) : Duration.zero;
  Duration duration(Duration value) =>
      disableAnimations ? Duration.zero : value;

  Duration get cameraFocusIn => duration(_cameraFocusIn);
  Duration get cameraFocusOut => duration(_cameraFocusOut);
  Duration get trumpSelectorHop => duration(_trumpSelectorHopDuration);
  Duration get gaugeDelta => duration(_gaugeDeltaDuration);
  Duration get handInteraction => duration(_handInteractionDuration);
  Duration get medalAppear => duration(_medalAppearDuration);
  Duration get heroMedalPulse => duration(_heroMedalPulseDuration);
  Duration get activeCardSlotPulse => duration(_activeCardSlotPulseDuration);
  Duration get trumpSelectorFrame => duration(_trumpSelectorFrameDuration);
  Duration get logChevron => duration(_logChevronDuration);
  Duration get logSectionResize => duration(_logSectionResizeDuration);

  static const Curve cardFlightCurve = Curves.easeInOutCubic;
  static const Curve cameraFollowCurve = Curves.easeOut;
  static const Curve cameraTravelCurve = Curves.easeOutCubic;
  static const Curve focusCurve = Curves.easeInOutCubic;
  static const Curve gaugeDeltaCurve = Curves.easeOutCubic;
  static const Curve handInteractionCurve = Curves.easeOutCubic;
  static const Curve medalInCurve = Curves.easeOutBack;
  static const Curve medalOutCurve = Curves.easeInCubic;
  static const Curve ambientPulseCurve = Curves.easeInOut;
  static const double minimumFlightDistance = 8;
  static const Duration cameraFullTravelDuration = Duration(milliseconds: 760);

  static const Duration _cameraFocusIn = Duration(milliseconds: 440);
  static const Duration _cameraFocusOut = Duration(milliseconds: 320);
  static const Duration _trumpSelectorHopDuration = Duration(milliseconds: 230);
  static const Duration _gaugeDeltaDuration = Duration(milliseconds: 1600);
  static const Duration _handInteractionDuration = Duration(milliseconds: 150);
  static const Duration _medalAppearDuration = Duration(milliseconds: 520);
  static const Duration _heroMedalPulseDuration = Duration(milliseconds: 900);
  static const Duration _activeCardSlotPulseDuration = Duration(
    milliseconds: 1800,
  );
  static const Duration _trumpSelectorFrameDuration = Duration(
    milliseconds: 120,
  );
  static const Duration _logChevronDuration = Duration(milliseconds: 140);
  static const Duration _logSectionResizeDuration = Duration(milliseconds: 160);
}
