import 'package:shared_preferences/shared_preferences.dart';

/// Shared utility for workout day scheduling logic.
/// Eliminates duplication across home_screen, workout_screen, and analytics_screen.
class WorkoutDayUtils {
  WorkoutDayUtils._();

  /// 7-day rolling patterns: true = workout, false = rest.
  /// Day 0 (anchored to user's start date) is always a workout day.
  static const Map<int, List<bool>> patterns = {
    3: [true, false, true, false, true, false, false],
    4: [true, true, false, true, true, false, false],
    5: [true, true, true, false, true, true, false],
    6: [true, true, true, true, true, true, false],
    7: [true, true, true, true, true, true, true],
  };

  /// Returns true if today is a workout day, based on a rolling schedule
  /// anchored to the user's start date (the first day they used the app).
  static Future<bool> isTodayWorkoutDay(int freq) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'workout_start_date';

    String? startStr = prefs.getString(key);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (startStr == null) {
      startStr = todayDate.toIso8601String();
      await prefs.setString(key, startStr);
    }

    final startDate = DateTime.parse(startStr);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final dayOffset = todayDate.difference(startDay).inDays;

    final cycle = patterns[freq] ?? patterns[3]!;
    return cycle[dayOffset % cycle.length];
  }

  /// Checks if a specific weekday index (1=Mon, 7=Sun) is a workout day
  /// for the given frequency, using the rolling pattern logic.
  /// Used by analytics chart to mark rest days correctly.
  static bool isWeekdayWorkoutDay(int weekday, int freq) {
    // Map weekday to pattern index using the same rolling logic.
    // Since the pattern is anchored to the user's start date, for
    // analytics display we use the pattern directly per weekday offset.
    // This is a best-effort approximation for the chart UI.
    final cycle = patterns[freq] ?? patterns[3]!;
    // weekday 1=Mon maps to index 0, weekday 7=Sun maps to index 6
    return cycle[(weekday - 1) % cycle.length];
  }
}
