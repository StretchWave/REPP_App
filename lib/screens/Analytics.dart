import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // BMI Data
  double? _bmi;
  String _bmiCategory = "--";

  // Chart Data (Mon-Sun)
  List<double> _weeklyCalories = List.filled(7, 0.0);

  // Stats Data
  int _totalCaloriesWeek = 0;
  int _avgCaloriesDay = 0;
  int _workoutsThisWeek = 0;
  int _workoutsThisMonth = 0;
  int _totalWorkouts = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  String _insightMessage = "Keep working out to generate insights!";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Profile for BMI
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('height, weight')
          .eq('id', user.id)
          .single();

      // 2. Fetch Workout Logs
      final logsResponse = await Supabase.instance.client
          .from('workout_logs')
          .select('created_at, calories_burned')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final List<dynamic> logs = logsResponse;

      // --- Process BMI ---
      final heightCm = (profileResponse['height'] as num?)?.toDouble() ?? 0.0;
      final weightKg = (profileResponse['weight'] as num?)?.toDouble() ?? 0.0;
      _calculateBMI(heightCm, weightKg);

      // --- Process Logs ---
      _processWorkoutLogs(logs);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateBMI(double heightCm, double weightKg) {
    if (heightCm > 0 && weightKg > 0) {
      final heightM = heightCm / 100;
      final bmi = weightKg / (heightM * heightM);
      String category = "Normal";
      if (bmi < 18.5) {
        category = "Underweight";
      } else if (bmi >= 18.5 && bmi < 25) {
        category = "Normal";
      } else if (bmi >= 25 && bmi < 30) {
        category = "Overweight";
      } else {
        category = "Obesity";
      }
      _bmi = bmi;
      _bmiCategory = category;
    }
  }

  void _processWorkoutLogs(List<dynamic> logs) {
    if (logs.isEmpty) return;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Mon
    // reset stats
    _weeklyCalories = List.filled(7, 0.0);
    _totalCaloriesWeek = 0;
    _workoutsThisWeek = 0;
    _workoutsThisMonth = 0;
    _totalWorkouts = logs.length;

    // Streak Helpers
    Set<String> uniqueDays = {};
    List<DateTime> activityDates = [];

    for (var log in logs) {
      final date = DateTime.parse(log['created_at']).toLocal();
      final calories = (log['calories_burned'] as num? ?? 0).toDouble();

      // Weekly Chart & Stats
      // Check if date is in current week (Mon-Sun)
      // We compare dates by stripping time
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(startOfWeek.add(const Duration(days: 7)))) {
        // weekday 1=Mon, 7=Sun. List index 0=Mon, 6=Sun
        int index = date.weekday - 1;
        _weeklyCalories[index] += calories;
        _totalCaloriesWeek += calories.toInt();
        _workoutsThisWeek++;
      }

      // Monthly Stats
      if (date.year == now.year && date.month == now.month) {
        _workoutsThisMonth++;
      }

      // For streaks
      // We only care about the date part YYYY-MM-DD
      final dayStr = DateFormat('yyyy-MM-dd').format(date);
      if (!uniqueDays.contains(dayStr)) {
        uniqueDays.add(dayStr);
        activityDates.add(DateTime(date.year, date.month, date.day));
      }
    }

    _avgCaloriesDay =
        (_totalCaloriesWeek / (now.weekday == 0 ? 1 : now.weekday))
            .round(); // Avg based on passed days of week

    // Calculate Streak
    activityDates.sort((a, b) => a.compareTo(b)); // Ensure sorted
    _calculateStreaks(activityDates);

    // Generate Insight
    _generateInsight();
  }

  void _calculateStreaks(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return;

    int best = 0;
    int tempCurrent = 0;

    // Check if performed workout today or yesterday to keep streak alive
    final today = DateTime.now();
    final strippedToday = DateTime(today.year, today.month, today.day);
    final strippedYesterday = strippedToday.subtract(const Duration(days: 1));

    bool streakAlive = false;
    if (sortedDates.contains(strippedToday) ||
        sortedDates.contains(strippedYesterday)) {
      streakAlive = true;
    }

    // Iterate to find best streak
    for (int i = 0; i < sortedDates.length; i++) {
      if (i == 0) {
        tempCurrent = 1;
      } else {
        final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
        if (diff == 1) {
          tempCurrent++;
        } else {
          if (tempCurrent > best) best = tempCurrent;
          tempCurrent = 1;
        }
      }
    }
    if (tempCurrent > best) best = tempCurrent;

    // Calculate distinct current streak walking back from today
    int running = 0;
    DateTime checkDate = strippedToday;

    // Only verify current streak if we have activity today or yesterday
    if (streakAlive) {
      // Check today
      if (sortedDates.contains(checkDate)) {
        running++;
      }
      // Check backwards
      while (true) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        if (sortedDates.contains(checkDate)) {
          running++;
        } else {
          // if we didn't do it today, but did yesterday, the loop above missed the first increment
          // simple fix: logic is getting complex.
          // Simpler approach:
          // Join dates into one chain.
          break;
        }
      }
      // If running is 0 (didn't do today), but streak is alive (did yesterday), we need to check yesterday start
      if (running == 0 && sortedDates.contains(strippedYesterday)) {
        running = 0;
        checkDate = strippedYesterday;
        // Loop logic...
        // Let's rely on the simpler sorted array logic for "Best" and just walk back for "Current"
      }
    }

    // Re-do Current Streak robustly:
    // 1. Find the last activity date.
    // 2. If it's today or yesterday, streak is alive.
    // 3. Walk back day by day counting consecutive matches.

    if (sortedDates.isNotEmpty) {
      DateTime lastDate = sortedDates.last;
      final diff = strippedToday.difference(lastDate).inDays;

      if (diff <= 1) {
        // Streak is active
        _currentStreak = 1;
        DateTime target = lastDate.subtract(const Duration(days: 1));
        for (int i = sortedDates.length - 2; i >= 0; i--) {
          if (sortedDates[i].isAtSameMomentAs(target)) {
            _currentStreak++;
            target = target.subtract(const Duration(days: 1));
          }
        }
      } else {
        _currentStreak = 0;
      }
    }

    _bestStreak = best;
    if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
  }

  void _generateInsight() {
    if (_workoutsThisWeek > 3) {
      _insightMessage =
          "You're crushing it this week! Your activity level is high. Make sure to hydrate well.";
    } else if (_currentStreak >= 3) {
      _insightMessage =
          "Consistency is key! You have a $_currentStreak day streak going. Keep the momentum!";
    } else if (_bmiCategory == "Overweight" || _bmiCategory == "Obesity") {
      _insightMessage =
          "Focus on cardio and calorie deficits to improve your BMI score safely.";
    } else {
      _insightMessage =
          "Try to aim for at least 3 workouts a week to see consistent progress.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 30),
                    _buildBMISection(),
                    const SizedBox(height: 20),
                    _buildChartSection(),
                    const SizedBox(height: 20),
                    _buildCaloriesCard(),
                    const SizedBox(height: 20),
                    _buildWorkoutsCard(),
                    const SizedBox(height: 20),
                    _buildStreakCard(),
                    const SizedBox(height: 20),
                    _buildAiInsightCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ... [Widgets remain mostly same, but using variables] ...

  Widget _buildBMISection() {
    if (_bmi == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Your BMI is",
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFFC0392B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _bmi!.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Container(height: 8, color: Colors.green)),
                  const SizedBox(width: 4),
                  Expanded(child: Container(height: 8, color: Colors.orange)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBMILabel("Underweight", _bmi! < 18.5),
                  _buildBMILabel("Normal", _bmi! >= 18.5 && _bmi! < 25),
                  _buildBMILabel("Overweight", _bmi! >= 25 && _bmi! < 30),
                  _buildBMILabel("Obesity", _bmi! >= 30),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBMILabel(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        fontSize: isActive ? 14 : 10,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        color: isActive ? Colors.black : Colors.grey,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey),
              Text(
                'Back',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Progress Analysis',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2126),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your fitness journey',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    double maxVal = _weeklyCalories.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1; // Avoid divide by zero

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Calories Burned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2126),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(
                day: 'Mon',
                value: _weeklyCalories[0].toInt(),
                heightFactor: _weeklyCalories[0] / maxVal,
              ),
              _buildBar(
                day: 'Tue',
                value: _weeklyCalories[1].toInt(),
                heightFactor: _weeklyCalories[1] / maxVal,
              ),
              _buildBar(
                day: 'Wed',
                value: _weeklyCalories[2].toInt(),
                heightFactor: _weeklyCalories[2] / maxVal,
              ),
              _buildBar(
                day: 'Thu',
                value: _weeklyCalories[3].toInt(),
                heightFactor: _weeklyCalories[3] / maxVal,
              ),
              _buildBar(
                day: 'Fri',
                value: _weeklyCalories[4].toInt(),
                heightFactor: _weeklyCalories[4] / maxVal,
              ),
              _buildBar(
                day: 'Sat',
                value: _weeklyCalories[5].toInt(),
                heightFactor: _weeklyCalories[5] / maxVal,
              ),
              _buildBar(
                day: 'Sun',
                value: _weeklyCalories[6].toInt(),
                heightFactor: _weeklyCalories[6] / maxVal,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String day,
    required int value,
    required double heightFactor,
  }) {
    // protect against tiny bars
    double displayHeight = 120 * heightFactor;
    if (value > 0 && displayHeight < 4) displayHeight = 4;

    return Column(
      children: [
        if (value > 0)
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF495057),
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 6),
        Container(
          width: 30,
          height: displayHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF343A40),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCaloriesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Calories Burned',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '$_totalCaloriesWeek',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'This week',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Text(
                'Average: $_avgCaloriesDay cal/day',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.orangeAccent,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF495057),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workouts Completed',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_workoutsThisWeek',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'This week',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              Transform.rotate(
                angle: -0.2,
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.amber,
                  size: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This month',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_workoutsThisMonth',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_totalWorkouts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF6C757D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Streak',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentStreak Days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(7, (index) {
                      // Visual dash indicator - highlight first N dashes based on streak (mod 7 just for visual)
                      bool active =
                          index < (_currentStreak > 7 ? 7 : _currentStreak);
                      return Container(
                        width: 30,
                        height: 4,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: active ? Colors.orange : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Greatest Streak',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_bestStreak Days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Keep going!',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.show_chart, color: Colors.redAccent, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Insight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2126),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _insightMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
