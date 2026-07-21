import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// Presentation-only North calibration resolved independently from camera Z.
@immutable
class NorthThreatState {
  const NorthThreatState({
    required this.threat,
    required this.landmarkHeightFraction,
    required this.landmarkWidthFraction,
    required this.contrast,
    required this.haze,
    required this.opacity,
    required this.warmth,
    required this.smoke,
  });

  static const baseAnchorX = 960.0;
  static const baseAnchorY = 413.0;

  static const year1 = NorthThreatState(
    threat: 0,
    landmarkHeightFraction: 0.18,
    landmarkWidthFraction: 0.16,
    contrast: 0.46,
    haze: 0.61,
    opacity: 0.78,
    warmth: 0.03,
    smoke: 0.10,
  );
  static const year3 = NorthThreatState(
    threat: 0.5,
    landmarkHeightFraction: 0.34,
    landmarkWidthFraction: 0.24,
    contrast: 0.72,
    haze: 0.34,
    opacity: 0.91,
    warmth: 0.22,
    smoke: 0.42,
  );
  static const year5 = NorthThreatState(
    threat: 1,
    landmarkHeightFraction: 0.50,
    landmarkWidthFraction: 0.34,
    contrast: 0.96,
    haze: 0.09,
    opacity: 1,
    warmth: 0.48,
    smoke: 0.88,
  );

  final double threat;
  final double landmarkHeightFraction;
  final double landmarkWidthFraction;
  final double contrast;
  final double haze;
  final double opacity;
  final double warmth;
  final double smoke;

  double get year => 1 + threat * 4;

  Rect landmarkRect(Size viewport) => Rect.fromLTRB(
    baseAnchorX - viewport.width * landmarkWidthFraction / 2,
    baseAnchorY - viewport.height * landmarkHeightFraction,
    baseAnchorX + viewport.width * landmarkWidthFraction / 2,
    baseAnchorY,
  );

  static NorthThreatState resolve(double normalizedThreat) {
    final threat = normalizedThreat.clamp(0.0, 1.0).toDouble();
    if (threat == year1.threat) return year1;
    if (threat == year3.threat) return year3;
    if (threat == year5.threat) return year5;
    if (threat <= year3.threat) {
      return _interpolate(year1, year3, threat / year3.threat);
    }
    return _interpolate(
      year3,
      year5,
      (threat - year3.threat) / (year5.threat - year3.threat),
    );
  }

  static NorthThreatState _interpolate(
    NorthThreatState from,
    NorthThreatState to,
    double amount,
  ) {
    double lerp(double a, double b) => a + (b - a) * amount;
    return NorthThreatState(
      threat: lerp(from.threat, to.threat),
      landmarkHeightFraction: lerp(
        from.landmarkHeightFraction,
        to.landmarkHeightFraction,
      ),
      landmarkWidthFraction: lerp(
        from.landmarkWidthFraction,
        to.landmarkWidthFraction,
      ),
      contrast: lerp(from.contrast, to.contrast),
      haze: lerp(from.haze, to.haze),
      opacity: lerp(from.opacity, to.opacity),
      warmth: lerp(from.warmth, to.warmth),
      smoke: lerp(from.smoke, to.smoke),
    );
  }

  Map<String, double> toJson() => {
    'threat': threat,
    'year': year,
    'landmarkHeightFraction': landmarkHeightFraction,
    'landmarkWidthFraction': landmarkWidthFraction,
    'contrast': contrast,
    'haze': haze,
    'opacity': opacity,
    'warmth': warmth,
    'smoke': smoke,
  };
}
