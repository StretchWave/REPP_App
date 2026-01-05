import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutLogService {
  static final WorkoutLogService _instance = WorkoutLogService._internal();
  factory WorkoutLogService() => _instance;
  WorkoutLogService._internal();

  final _client = Supabase.instance.client;

  /// Logs a completed or failed exercise attempt
  Future<void> logWorkout({
    required String exerciseName,
    required int repsCompleted,
    required int durationSeconds,
    required bool isCompleted,
    double? caloriesOverride, // If passed, use this, else calculate
    DateTime? timestamp, // For debug/backfilling
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final double calories =
        caloriesOverride ??
        _calculateCalories(exerciseName, repsCompleted, durationSeconds);

    final data = {
      'user_id': user.id,
      'exercise_name': exerciseName,
      'calories_burned': calories,
      'reps_completed': repsCompleted,
      'duration_seconds': durationSeconds,
      'is_completed': isCompleted,
    };

    if (timestamp != null) {
      data['created_at'] = timestamp.toIso8601String();
    }

    await _client.from('workout_logs').insert(data);
  }

  /// Calculates estimated calories based on exercise type and intensity
  double _calculateCalories(String name, int reps, int duration) {
    // Rough estimates per rep or per second
    switch (name) {
      case 'Push-Ups':
      case 'Box Push-Ups':
      case 'Pike Push-Ups':
        return reps * 0.5;
      case 'Squats':
        return reps * 0.6;
      case 'Sit-Ups':
      case 'Leg Raises':
        return reps * 0.4;
      case 'Chair Dips':
      case 'Floor Dips':
        return reps * 0.45;
      case 'Bird Dog': // Often duration based or per side
        return reps * 0.3;
      case 'Plank':
        return (duration / 60) * 4.0; // ~4 cal per minute
      case 'Jogging':
        // Usually calculated via steps elsewhere, but fail-safe:
        return (duration / 60) * 8.0; // ~8 cal per minute
      default:
        return reps * 0.4;
    }
  }

  /// Get total calories burned within a date range
  Future<double> getCaloriesBurned(DateTime start, DateTime end) async {
    final user = _client.auth.currentUser;
    if (user == null) return 0.0;

    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    try {
      final response = await _client
          .from('workout_logs')
          .select('calories_burned')
          .eq('user_id', user.id)
          .gte('created_at', startStr)
          .lte('created_at', endStr);

      final List<dynamic> data = response;
      double total = 0.0;
      for (var row in data) {
        total += (row['calories_burned'] as num).toDouble();
      }
      return total;
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching calories: $e");
      return 0.0;
    }
  }

  /// Checks consistency over the last 7 days.
  /// Returns a Map with 'successDays' count and 'totalDays' (7).
  Future<Map<String, int>> checkWeeklyConsistency() async {
    final user = _client.auth.currentUser;
    if (user == null) return {'successDays': 0, 'totalDays': 7};

    final now = DateTime.now();
    final startOfWindow = now.subtract(
      const Duration(days: 6),
    ); // 7 days inclusive

    // We want to verify if there is at least ONE completed workout per day.
    try {
      final response = await _client
          .from('workout_logs')
          .select('created_at, is_completed')
          .eq('user_id', user.id)
          .eq('is_completed', true)
          .gte('created_at', startOfWindow.toIso8601String());

      final List<dynamic> data = response;
      Set<String> uniqueDays = {};

      for (var row in data) {
        final date = DateTime.parse(row['created_at']).toLocal();
        final dayKey = "${date.year}-${date.month}-${date.day}";
        uniqueDays.add(dayKey);
      }

      return {'successDays': uniqueDays.length, 'totalDays': 7};
    } catch (e) {
      // ignore: avoid_print
      print("Error checking consistency: $e");
      return {'successDays': 0, 'totalDays': 7};
    }
  }

  /// Calculates the current streak based on workout logs
  Future<int> calculateCurrentStreak() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _client
          .from('workout_logs')
          .select('created_at')
          .eq('user_id', user.id);

      final List<dynamic> data = response;
      if (data.isEmpty) return 0;

      // Extract unique dates
      final Set<DateTime> uniqueDates = {};
      for (var row in data) {
        final dt = DateTime.parse(row['created_at']).toLocal();
        uniqueDates.add(DateTime(dt.year, dt.month, dt.day));
      }
      final sortedDates = uniqueDates.toList()..sort();

      if (sortedDates.isEmpty) return 0;

      // Check if streak is alive (Today or Yesterday)
      final today = DateTime.now();
      final strippedToday = DateTime(today.year, today.month, today.day);
      final strippedYesterday = strippedToday.subtract(const Duration(days: 1));

      bool streakAlive =
          sortedDates.contains(strippedToday) ||
          sortedDates.contains(strippedYesterday);

      if (!streakAlive) return 0;

      int currentStreak = 0;
      DateTime checkDate = strippedToday;

      // If today is missed but yesterday was good, streak starts from yesterday
      if (!sortedDates.contains(strippedToday)) {
        checkDate = strippedYesterday;
      }

      while (sortedDates.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      return currentStreak;
    } catch (e) {
      // ignore: avoid_print
      print("Error calculating streak: $e");
      return 0;
    }
  }

  /// Calculates the maximum streak ever achieved by the user
  Future<int> calculateMaxStreak() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _client
          .from('workout_logs')
          .select('created_at')
          .eq('user_id', user.id);

      final List<dynamic> data = response;
      if (data.isEmpty) return 0;

      // Extract unique dates
      final Set<DateTime> uniqueDates = {};
      for (var row in data) {
        final dt = DateTime.parse(row['created_at']).toLocal();
        uniqueDates.add(DateTime(dt.year, dt.month, dt.day));
      }
      final sortedDates = uniqueDates.toList()..sort();

      if (sortedDates.isEmpty) return 0;

      int maxStreak = 0;
      int currentStreak = 0;
      DateTime? lastDate;

      for (var date in sortedDates) {
        if (lastDate == null) {
          currentStreak = 1;
        } else {
          final difference = date.difference(lastDate).inDays;
          if (difference == 1) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
        }
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
        lastDate = date;
      }

      return maxStreak;
    } catch (e) {
      // ignore: avoid_print
      print("Error calculating max streak: $e");
      return 0;
    }
  }
}
