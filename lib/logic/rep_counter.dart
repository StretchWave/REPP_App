import 'package:ai_fitness_tracker/logic/exercises/exercise_logic.dart';
import 'package:ai_fitness_tracker/logic/exercises/push_up_logic.dart';
import 'package:ai_fitness_tracker/logic/exercises/squat_logic.dart';
import 'package:ai_fitness_tracker/logic/exercises/sit_up_logic.dart';
import 'package:ai_fitness_tracker/logic/exercises/others_logic.dart';

class RepCounter {
  ExerciseLogic? _currentStrategy;
  String _lastExercise = "";

  // Proxy Getters
  int get count => _currentStrategy?.count ?? 0;
  String get feedback => _currentStrategy?.feedback ?? "";
  double get accuracy => _currentStrategy?.accuracy ?? 0.0;
  bool get isProperForm => _currentStrategy?.isProperForm ?? true;
  Set<String> get formIssues => _currentStrategy?.formIssues ?? {};

  void reset() {
    _currentStrategy?.reset();
  }

  void processLandmarks(List<Map<String, double>> landmarks, String exercise) {
    // Switch Strategy if exercise changed
    if (_lastExercise != exercise) {
      _lastExercise = exercise;
      _currentStrategy = _getStrategy(exercise);
      _currentStrategy?.reset(); // Reset when switching
    }

    _currentStrategy?.processLandmarks(landmarks);
  }

  ExerciseLogic _getStrategy(String exercise) {
    switch (exercise) {
      case 'Push-Ups':
      case 'Box Push-Ups': // Box pushups share logic but with flag (handled inside logic or we can separate)
        // Note: PushUpLogic defaults for standard.
        // If we want detailed Box differentiation, we might need to pass params or subclass.
        // For now, using standard Logic as base.
        return PushUpLogic();
      case 'Squats':
        return SquatLogic();
      case 'Sit-Ups':
        return SitUpLogic();
      case 'Pike Push-Ups':
        return PikePushUpLogic();
      case 'Chair Dips':
        return ChairDipLogic();
      case 'Leg Raises':
        return LegRaiseLogic();
      // Add others as needed
      default:
        return PushUpLogic(); // Fallback
    }
  }
}
