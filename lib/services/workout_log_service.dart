import 'package:flutter/foundation.dart';
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
    try {
      await _client.from('workout_logs').insert(data);
    } catch (e) {
      debugPrint("Error logging workout: $e");
    }
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
      debugPrint("Error fetching calories: $e");
      return 0.0;
    }
  }

  /// Checks consistency over the last 7 days.
  /// Returns a Map with 'successDays' count and 'totalDays' (7).
  /// A day is successful if:
  /// 1. At least one workout is completed.
  /// 2. Fewer than 3 workouts are failed.
  ///
  /// Conversely, a day is considered "Failed" (not successful) if:
  /// - No workouts are performed (0 logs).
  /// - 3 or more workouts are failed (explicit failure).
  /// - Only failed workouts are performed (even if < 3), and no successes.
  Future<Map<String, int>> checkWeeklyConsistency() async {
    final user = _client.auth.currentUser;
    if (user == null) return {'successDays': 0, 'totalDays': 7};

    final now = DateTime.now();
    final startOfWindow = now.subtract(
      const Duration(days: 6),
    ); // 7 days inclusive

    try {
      // Fetch BOTH completed and failed logs
      final response = await _client
          .from('workout_logs')
          .select('created_at, is_completed')
          .eq('user_id', user.id)
          .gte('created_at', startOfWindow.toIso8601String());

      final List<dynamic> data = response;

      // Group by day (YYYY-MM-DD)
      final Map<String, List<Map<String, dynamic>>> dailyLogs = {};

      for (var row in data) {
        final date = DateTime.parse(row['created_at']).toLocal();
        final monthStr = date.month.toString().padLeft(2, '0');
        final dayStr = date.day.toString().padLeft(2, '0');
        final dayKey = "${date.year}-$monthStr-$dayStr";

        dailyLogs.putIfAbsent(dayKey, () => []).add(row);
      }

      int successDays = 0;

      // Iterate through the last 7 days to ensure we check specific windows if needed,
      // but here we just count how many "unique days" in the logs were successful.
      // Wait, we need to count successful days from the logs we FOUND.
      // If a day has NO logs, it is 0 successes automatically.

      for (var entry in dailyLogs.entries) {
        final logs = entry.value;

        int failures = 0;
        int successes = 0;

        for (var log in logs) {
          if (log['is_completed'] == true) {
            successes++;
          } else {
            failures++;
          }
        }

        // Logic: Failed if >= 3 failures, even if there are successes.
        if (failures >= 3) {
          // Failed day - do not count as success
          continue;
        }

        if (successes > 0) {
          successDays++;
        }
      }

      return {'successDays': successDays, 'totalDays': 7};
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error checking consistency: $e");
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
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1000);

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
      debugPrint("Error calculating streak: $e");
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
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(3000); // larger limit for max streak

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
      debugPrint("Error calculating max streak: $e");
      return 0;
    }
  }
}
