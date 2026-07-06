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
      GameAnimationSpeed.fast => const Duration(milliseconds: 340),
      GameAnimationSpeed.normal => const Duration(milliseconds: 600),
      GameAnimationSpeed.slow => const Duration(milliseconds: 1200),
    };
  }

  Duration get automaticTrumpSelectionDelay {
    return switch (this) {
      GameAnimationSpeed.instant => Duration.zero,
      GameAnimationSpeed.fast => const Duration(milliseconds: 1400),
      GameAnimationSpeed.normal => const Duration(milliseconds: 2200),
      GameAnimationSpeed.slow => const Duration(milliseconds: 3200),
    };
  }

  Duration get cardFlightDuration {
    return switch (this) {
      GameAnimationSpeed.instant => Duration.zero,
      GameAnimationSpeed.fast => const Duration(milliseconds: 280),
      GameAnimationSpeed.normal => const Duration(milliseconds: 520),
      GameAnimationSpeed.slow => const Duration(milliseconds: 1040),
    };
  }
}

const defaultGameAnimationSpeed = GameAnimationSpeed.normal;
