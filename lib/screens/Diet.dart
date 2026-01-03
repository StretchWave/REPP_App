import 'dart:ui';
import 'package:ai_fitness_tracker/services/diet_service.dart';
import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';
import 'package:ai_fitness_tracker/screens/meal_selection_screen.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final DietService _dietService = DietService();
  List<FoodLog> _todayLogs = [];
  bool _isLoading = true;
  int _totalCalories = 0;
  final int _calorieGoal = 2000;

  // Calorie Burn Params
  double _burnedToday = 0;
  double _burnedWeek = 0;
  double _burnedMonth = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final logs = await _dietService.getTodayLogs();

    // 1. Calculate Food Calories
    int total = 0;
    for (var log in logs) {
      total += log.calories;
    }

    // 2. Fetch Burned Calories
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(
      Duration(days: now.weekday - 1),
    ); // Start of week (Mon)
    final monthStart = DateTime(now.year, now.month, 1);

    final bToday = await WorkoutLogService().getCaloriesBurned(todayStart, now);
    final bWeek = await WorkoutLogService().getCaloriesBurned(weekStart, now);
    final bMonth = await WorkoutLogService().getCaloriesBurned(monthStart, now);

    if (mounted) {
      setState(() {
        _todayLogs = logs;
        _totalCalories = total;
        _burnedToday = bToday;
        _burnedWeek = bWeek;
        _burnedMonth = bMonth;
        _isLoading = false;
      });
    }
  }

  Future<void> _addMeal() async {
    // Navigate to Selection Screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealSelectionScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      debugPrint("Adding Meal: $result");
      try {
        await _dietService.addFoodLog(
          foodName: result['name'],
          calories: result['calories'],
          protein: result['protein'],
          carbs: result['carbs'],
          fats: result['fats'],
        );
        _loadData(); // Refresh
      } catch (e) {
        debugPrint("Error adding meal details: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error adding meal: $e")));
        }
      }
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      await _dietService.deleteFoodLog(id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting log: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildDarkHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildWeightCard(),
                        const SizedBox(height: 30),
                        _buildMealsSection(),
                        const SizedBox(height: 30),
                        _buildDailySummaryCard(),
                        const SizedBox(height: 20),
                        _buildRemainingCaloriesCard(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkHeader(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2126),
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Diet Tracker',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calories Burned',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("Today", _burnedToday),
              _buildStatItem("This Week", _burnedWeek),
              _buildStatItem("This Month", _burnedMonth),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Meals",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2126),
          ),
        ),
        const SizedBox(height: 16),
        // List of Meals
        if (_todayLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              "No meals logged yet today.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ..._todayLogs.map(
          (log) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.foodName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2126),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'P: ${log.protein}g  C: ${log.carbs}g  F: ${log.fats}g',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${log.calories} kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () => _deleteLog(log.id),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Add Meal Button (Dashed)
        GestureDetector(
          onTap: _addMeal,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: Colors.grey[400]!,
              strokeWidth: 1.5,
              gap: 4.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Add Meal',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12, // Small label
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${value.toStringAsFixed(0)} kcal",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16, // Prominent value
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDailySummaryCard() {
    double progress = _totalCalories / _calorieGoal;
    if (progress > 1.0) progress = 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF495057), // Dark grey
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calories',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '$_totalCalories / $_calorieGoal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress == 0 ? 0.01 : progress, // Minimum visual
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingCaloriesCard() {
    int remaining = _calorieGoal - _totalCalories;
    if (remaining < 0) remaining = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF), // Light grey
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Remaining Today',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$remaining cal',
            style: const TextStyle(
              color: Color(0xFF1E2126),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep it up!',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12),
        ),
      );

    final Path dashedPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + 5.0),
          Offset.zero,
        );
        distance += 5.0 + gap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// _AddMealDialog removed (moved to MealSelectionScreen)
