import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutService {
  static const String _workoutKeyPrefix = 'workout_progress_';

  // Singleton pattern
  static final WorkoutService _instance = WorkoutService._internal();
  factory WorkoutService() => _instance;
  WorkoutService._internal();

  // Debug: Offset to simulate future/past dates
  Duration _debugOffset = Duration.zero;

  void debugSetOffset(Duration offset) {
    _debugOffset = offset;
  }

  void debugAdvanceDay() {
    _debugOffset += const Duration(days: 1);
  }

  void debugResetToToday() {
    _debugOffset = Duration.zero;
  }

  DateTime get now => DateTime.now().add(_debugOffset);

  /// Returns the key for today's workout data: "workout_progress_YYYY-MM-DD"
  String _getTodayKey() {
    final d = now;
    return '$_workoutKeyPrefix${d.year}-${d.month}-${d.day}';
  }

  /// Saves the completion status and duration for a specific exercise
  Future<void> saveExerciseProgress({
    required String exerciseName,
    required bool isCompleted,
    required int durationSeconds,
    int? progressValue,
    String? feedback,
    bool isSkipped = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTodayKey();

    // Load existing data
    final String? rawData = prefs.getString(key);
    Map<String, dynamic> data = {};
    if (rawData != null) {
      data = jsonDecode(rawData);
    }

    // Update specific exercise
    data[exerciseName] = {
      'isCompleted': isCompleted,
      'isSkipped': isSkipped,
      'durationSeconds': durationSeconds,
      'progressValue': progressValue,
      'feedback': feedback,
      'timestamp': now.toIso8601String(),
    };

    // Save back
    await prefs.setString(key, jsonEncode(data));
  }

  /// Retrieves the progress for today
  /// Returns a Map where keys are exercise names and values are details
  Future<Map<String, dynamic>> getTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTodayKey();

    final String? rawData = prefs.getString(key);
    if (rawData == null) return {};

    return jsonDecode(rawData);
  }

  /// Checks if a specific exercise is completed today
  Future<bool> isExerciseCompleted(String exerciseName) async {
    final progress = await getTodayProgress();
    if (progress.containsKey(exerciseName)) {
      return progress[exerciseName]['isCompleted'] == true;
    }
    return false;
  }

  /// Clears today's progress (Dev utility)
  Future<void> clearTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getTodayKey());
  }
}
