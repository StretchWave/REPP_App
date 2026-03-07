import 'dart:math';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. Data Models & Enums
// ==========================================

enum DifficultyTier {
  tier1, // Easy (Beginner)
  tier2, // Medium (Intermediate)
  tier3, // Hard (Advanced)
}

enum ExerciseType { reps, duration }

enum BodyPart { upperBody, lowerBody }

/// Model representing a specific exercise configuration
class Exercise {
  final String id;
  final String name;
  final DifficultyTier tier;
  final ExerciseType type;
  final double baseValue; // Base reps or seconds
  final double levelMultiplier; // How much it increases per level
  final List<BodyPart> requiredBodyParts;

  const Exercise({
    required this.id,
    required this.name,
    required this.tier,
    required this.type,
    this.baseValue = 10.0,
    this.levelMultiplier = 0.5,
    required this.requiredBodyParts,
  });
}

/// Result object for a generated workout item
class WorkoutItem {
  final Exercise exercise;
  final int targetValue; // Reps or Seconds
  final String unit; // "reps" or "seconds"

  WorkoutItem({
    required this.exercise,
    required this.targetValue,
    required this.unit,
  });

  @override
  String toString() => '$name: $targetValue $unit';

  String get name => exercise.name;
}

// ==========================================
// 2. Service Class
// ==========================================

class LevelProgressionService {
  // Singleton
  static final LevelProgressionService _instance =
      LevelProgressionService._internal();
  factory LevelProgressionService() => _instance;
  LevelProgressionService._internal();

  // --- Data Definition ---

  static const List<Exercise> _allExercises = [
    // Tier 1 (Beginner)
    Exercise(
      id: 'box_pushups',
      name: 'Box Push-Ups',
      tier: DifficultyTier.tier1,
      type: ExerciseType.reps,
      baseValue: 10,
      levelMultiplier: 0.5,
      requiredBodyParts: [BodyPart.upperBody],
    ),
    Exercise(
      id: 'floor_dips',
      name: 'Floor Dips',
      tier: DifficultyTier.tier1,
      type: ExerciseType.reps,
      baseValue: 10,
      levelMultiplier: 0.5,
      requiredBodyParts: [BodyPart.upperBody],
    ),
    Exercise(
      id: 'bird_dogs',
      name: 'Bird Dogs',
      tier: DifficultyTier.tier1,
      type: ExerciseType.reps,
      baseValue: 12,
      levelMultiplier: 0.4,
      requiredBodyParts: [BodyPart.upperBody, BodyPart.lowerBody],
    ),
    Exercise(
      id: 'squats',
      name: 'Squats',
      tier: DifficultyTier.tier1,
      type: ExerciseType.reps,
      baseValue: 15,
      levelMultiplier: 0.6, // Legs can handle more vol
      requiredBodyParts: [BodyPart.lowerBody],
    ),

    // Tier 2 (Intermediate)
    Exercise(
      id: 'pushups',
      name: 'Push-Ups',
      tier: DifficultyTier.tier2,
      type: ExerciseType.reps,
      baseValue: 8, // Harder than Box Pushups
      levelMultiplier: 0.4,
      requiredBodyParts: [BodyPart.upperBody],
    ),
    Exercise(
      id: 'chair_dips',
      name: 'Chair Dips',
      tier: DifficultyTier.tier2,
      type: ExerciseType.reps,
      baseValue: 10,
      levelMultiplier: 0.5,
      requiredBodyParts: [BodyPart.upperBody],
    ),
    Exercise(
      id: 'situps',
      name: 'Sit-Ups',
      tier: DifficultyTier.tier2,
      type: ExerciseType.reps,
      baseValue: 15,
      levelMultiplier: 0.5,
      requiredBodyParts: [BodyPart.upperBody],
    ),

    // Tier 3 (Advanced)
    Exercise(
      id: 'pike_pushups',
      name: 'Pike Push-Ups',
      tier: DifficultyTier.tier3,
      type: ExerciseType.reps,
      baseValue: 5, // Much harder
      levelMultiplier: 0.3,
      requiredBodyParts: [BodyPart.upperBody],
    ),
    Exercise(
      id: 'leg_raises',
      name: 'Leg Raises',
      tier: DifficultyTier.tier3,
      type: ExerciseType.reps,
      baseValue: 8,
      levelMultiplier: 0.4,
      requiredBodyParts: [BodyPart.lowerBody],
    ),
    Exercise(
      id: 'jogging',
      name: 'Jogging',
      tier: DifficultyTier.tier3,
      type: ExerciseType.duration,
      baseValue: 300, // 5 minutes (in seconds)
      levelMultiplier: 15, // +15 sec per level
      requiredBodyParts: [BodyPart.lowerBody],
    ),
  ];

  // --- Workout Generation Logic ---

  /// Generates a workout routine based on the user's level (1-100)
  List<WorkoutItem> getWorkoutForLevel(
    int level, {
    bool canFocusUpperBody = true,
    bool canFocusLowerBody = true,
  }) {
    // Clamp level to valid range
    final int safeLevel = level.clamp(
      0,
      150,
    ); // Allow 0 and >100 for super users

    // 1. Determine Phase & Filter Exercises
    List<Exercise> levelExercises = [];

    if (safeLevel <= 20) {
      // Phase 1: Beginner
      levelExercises = _allExercises
          .where((e) => e.tier == DifficultyTier.tier1)
          .toList();
    } else if (safeLevel <= 40) {
      // Phase 2: Intermediate
      // Tier 2 main + Tier 1 (Warmups/Volume)
      levelExercises = _allExercises
          .where(
            (e) =>
                e.tier == DifficultyTier.tier1 ||
                e.tier == DifficultyTier.tier2,
          )
          .toList();
    } else if (safeLevel <= 60) {
      // Phase 3: Advanced
      // All Tiers allowed, focus shifting to Tier 3
      levelExercises = _allExercises.toList();
    } else {
      // Phase 4: Elite (61+)
      // High volume, all tiers
      levelExercises = _allExercises.toList();
    }

    // Then filter by Physical Limitations
    List<Exercise> eligibleExercises = levelExercises.where((e) {
      // If exercise needs upper body, and user can't do upper body -> exclude
      if (e.requiredBodyParts.contains(BodyPart.upperBody) &&
          !canFocusUpperBody) {
        return false;
      }
      // If exercise needs lower body, and user can't do lower body -> exclude
      if (e.requiredBodyParts.contains(BodyPart.lowerBody) &&
          !canFocusLowerBody) {
        return false;
      }
      return true;
    }).toList();

    // 2. Select Exercises
    // We prioritize higher tier exercises for higher levels.
    // Randomize order for variety
    final now = DateTime.now();
    var rng = Random(
      safeLevel + (now.year * 10000 + now.month * 100 + now.day),
    );
    eligibleExercises.shuffle(rng);

    // Dynamic Exercise Count Logic
    // Level 1-20: 4 exercises
    // Level 21-40: 5 exercises
    // Level 41-60: 6 exercises
    // Level 61-80: 8 exercises
    // Level 81+:   10 exercises (Full circuit)
    int exerciseCount = 4;
    if (safeLevel > 80) {
      exerciseCount = 10;
    } else if (safeLevel > 60) {
      exerciseCount = 8;
    } else if (safeLevel > 40) {
      exerciseCount = 6;
    } else if (safeLevel > 20) {
      exerciseCount = 5;
    }

    // Ensure we don't try to take more than available
    final int takeCount = min(exerciseCount, eligibleExercises.length);
    final selected = eligibleExercises.take(takeCount).toList();

    // 3. Calc Reps (Progressive Overload)
    return selected.map((ex) {
      return _calculateWorkoutItem(ex, safeLevel);
    }).toList();
  }

  WorkoutItem _calculateWorkoutItem(Exercise ex, int level) {
    // Formula: Target = Base + (Level * Multiplier)

    // Adjustment: Tier 3 exercises should not scale as aggressively as Tier 1
    // to maintain balance at high levels.
    // We can dampen the level factor for lower tiers if they are just warmups,
    // but the requirement says "Tier 3 should have lower rep counts".
    // This is handled by 'baseValue' being lower for Tier 3.

    double rawValue = ex.baseValue + (level * ex.levelMultiplier);

    // Rounding & Unit Handling
    int finalValue = rawValue.round();
    String unit = 'reps';

    if (ex.type == ExerciseType.duration) {
      unit = 'seconds';
      // Maybe convert to minutes for display, but logic keeps seconds
    }

    return WorkoutItem(exercise: ex, targetValue: finalValue, unit: unit);
  }

  // --- Power Level Adjustment Logic ---

  /// Evaluates progress over the last 7 days and returns the net change in power level.
  /// - Returns negative value if failed 7 days consecutively.
  /// - Returns positive value if succeeded 7 days consecutively.
  /// - Returns 0 otherwise.
  /// Evaluates progress over the last 7 days and returns the net change in power level.
  /// - Returns negative value if failed 7 days consecutively (0 success).
  /// - Returns positive value if succeeded 7 days consecutively.
  Future<int> checkPowerLevelAdjustment() async {
    final result = await WorkoutLogService().checkWeeklyConsistency();
    final int successDays = result['successDays'] ?? 0;

    // "if the user fails to finish a workout for 1 week consecutively"
    // We interpret "fail" as 0 successful days in the last 7 days.
    if (successDays == 0) {
      return -5; // Decrease level significantly
    }

    // "if the user succeeds ... for one week consecutively"
    if (successDays >= 7) {
      return 2; // Increase level
    }

    return 0;
  }

  /// Checks and applies power level updates based on consistency.
  /// Returns the new power level if updated, or null if no change.
  Future<int?> evaluateAndApplyPowerLevelUpdate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Get Current Level
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('power_level')
          .eq('id', user.id)
          .single();
      final int currentLevel = profile['power_level'] ?? 0;

      // 2. Calculate Adjustment
      final int adjustment = await checkPowerLevelAdjustment();
      if (adjustment == 0) return null;

      // 3. Apply Update
      final newLevel = (currentLevel + adjustment).clamp(0, 999);

      // Safety: Don't update if no change (e.g. already lvl 1 and penalty)
      if (newLevel == currentLevel) return null;

      // NOTE: In a real app, we should check if we already updated recently to avoid
      // spamming level ups every day of a streak. For now, we allow it.
      await Supabase.instance.client
          .from('profiles')
          .update({
            'power_level': newLevel,
            'power_level_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      return newLevel;
    } catch (e) {
      // ignore: avoid_print
      print("Error updating power level: $e");
      return null;
    }
  }
}
