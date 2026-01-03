class DifficultyScaler {
  /// Calculates a 'Power Level' from 1-100 based on calibration results.
  ///
  /// Weights:
  /// - Push-ups: 1.5x
  /// - Squats: 1.0x
  /// - Sit-ups: 1.2x
  static int calculatePowerLevel({
    required int pushups,
    required int squats,
    required int situps,
  }) {
    // 1. Calculate weighted raw score
    // Example Baseline for "Fit": 30 Pushups, 40 Squats, 30 Situps
    // Raw = (30*1.5) + (40*1.0) + (30*1.2) = 45 + 40 + 36 = 121

    double rawScore = (pushups * 1.5) + (squats * 1.0) + (situps * 1.2);

    // 2. Normalize to 1-100 scale
    // We'll define a "Max Logic" raw score indicating level 100.
    // Let's say: 60 Pushups, 80 Squats, 60 Situps = ~240 Raw Score for Level 100
    const double maxRawScore = 240.0;

    double normalized = (rawScore / maxRawScore) * 100;

    // Clamp between 1 and 100
    int level = normalized.round().clamp(1, 100);

    return level;
  }

  /// Scales the target reps for a workout based on the user's Power Level.
  ///
  /// Formula: targetReps = baseReps + (powerLevel * 0.5)
  static int getScaledReps(int baseReps, int powerLevel) {
    if (powerLevel <= 0) return baseReps;

    double addedReps = powerLevel * 0.5;
    return (baseReps + addedReps).round();
  }
}
