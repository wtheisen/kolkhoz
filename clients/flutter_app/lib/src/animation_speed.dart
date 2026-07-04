enum GameAnimationSpeed {
  instant,
  fast,
  normal,
  slow;

  String get label {
    return switch (this) {
      GameAnimationSpeed.instant => 'Instant',
      GameAnimationSpeed.fast => 'Fast',
      GameAnimationSpeed.normal => 'Normal',
      GameAnimationSpeed.slow => 'Slow',
    };
  }

  Duration get automaticStepDelay {
    return switch (this) {
      GameAnimationSpeed.instant => Duration.zero,
      GameAnimationSpeed.fast => const Duration(milliseconds: 170),
      GameAnimationSpeed.normal => const Duration(milliseconds: 300),
      GameAnimationSpeed.slow => const Duration(milliseconds: 600),
    };
  }

  Duration get cardFlightDuration {
    return switch (this) {
      GameAnimationSpeed.instant => Duration.zero,
      GameAnimationSpeed.fast => const Duration(milliseconds: 140),
      GameAnimationSpeed.normal => const Duration(milliseconds: 260),
      GameAnimationSpeed.slow => const Duration(milliseconds: 520),
    };
  }
}

const defaultGameAnimationSpeed = GameAnimationSpeed.normal;
