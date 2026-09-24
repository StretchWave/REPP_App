import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/model_loading_screen.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';
import 'package:ai_fitness_tracker/services/level_progression_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_tracker/core/workout_day_utils.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Map<String, dynamic> _progress = {};
  int _powerLevel = 0;
  List<Map<String, dynamic>> _workouts = [];
  int _retryCount = 0;
  bool _isError = false;

  bool _canFocusUpperBody = true; // Default to true
  bool _canFocusLowerBody = true; // Default to true
  String _goalIntensity = 'Moderate';
  bool _isRestDay = false;
  String _userGoal = "Fitness"; // Added for info card

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load Progress
    final progress = await WorkoutService().getTodayProgress();

    // 2. Load Power Level
    int powerLevel = 1;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select(
              'power_level, is_admin, can_focus_upper_body, can_focus_lower_body, workout_frequency, goal_intensity',
            )
            .eq('id', userId)
            .single();
        powerLevel = data['power_level'] ?? 1;

        _canFocusUpperBody = data['can_focus_upper_body'] ?? true;
        _canFocusLowerBody = data['can_focus_lower_body'] ?? true;
        _goalIntensity = data['goal_intensity'] ?? 'Moderate';
        
        if (_goalIntensity.contains("Intense")) {
          _userGoal = "Body Building";
        } else if (_goalIntensity.contains("Light")) {
          _userGoal = "Maintenance";
        } else {
          _userGoal = "Fitness";
        }

        final freq = data['workout_frequency'] ?? 3;
        _isRestDay = !(await WorkoutDayUtils.isTodayWorkoutDay(freq));
      }
    } catch (e) {
      debugPrint("Error loading power level: $e");
    }

    if (mounted) {
      if (_isRestDay) {
        setState(() {});
        return;
      }

      // 3. Fetch Approved Dynamic Workouts
      List<Map<String, dynamic>> dynamicWorkouts = [];
      try {
        final dynamicData = await Supabase.instance.client
            .from('workout_definitions')
            .select()
            .eq('is_approved', true)
            .lte('unlock_power_level', powerLevel);
        dynamicWorkouts = List<Map<String, dynamic>>.from(dynamicData);
      } catch (e) {
        debugPrint("Error loading dynamic workouts: $e");
      }

      setState(() {
        _progress = progress;
        _powerLevel = powerLevel;
        _generateWorkout(dynamicWorkouts);
      });

      // Retry Logic...
      if (_workouts.isEmpty) {
        if (_retryCount < 3) {
          await Future.delayed(const Duration(seconds: 5));
          if (mounted && _workouts.isEmpty) {
            _retryCount++;
            _loadData();
          }
        } else {
          setState(() => _isError = true);
        }
      } else {
        _retryCount = 0;
        _isError = false;
      }
    }
  }

  void _generateWorkout(List<Map<String, dynamic>> customWorkouts) {
    // 1. Get Base Generated Routine
    final items = LevelProgressionService().getWorkoutForLevel(
      _powerLevel,
      canFocusUpperBody: _canFocusUpperBody,
      canFocusLowerBody: _canFocusLowerBody,
    );

    // 2. Map Base Workouts
    _workouts = items.map((item) {
      final meta = _getExerciseMetadata(item.exercise.id);
      double multiplier = _goalIntensity == 'Light'
          ? 0.5
          : (_goalIntensity == 'Moderate' ? 0.75 : 1.0);
      int adjustedTarget = (item.targetValue * multiplier).round();
      if (adjustedTarget < 1) adjustedTarget = 1;

      return {
        'title': item.exercise.name,
        'lookupName': item.exercise.name,
        'icon': meta['icon'],
        'sets': "3 sets × $adjustedTarget ${item.unit}",
        'cal': meta['cal'],
        'time': meta['time'],
        'illustration_icon': meta['illustration_icon'],
        'color': meta['color'],
        'targetValue': adjustedTarget,
        'unit': item.unit,
        'isCustom': false,
      };
    }).toList();

    // 3. Add & Scale Custom Approved Workouts
    for (final cw in customWorkouts) {
      final baseReps = (cw['base_reps'] ?? 10).toInt();
      final unlockLevel = (cw['unlock_power_level'] ?? 1).toInt();
      final repMultiplier = (cw['rep_multiplier'] ?? 1.0).toDouble();

      // Scaling Logic: base + (current - unlock) * multiplier
      final scaledReps =
          baseReps + ((_powerLevel - unlockLevel) * repMultiplier).round();

      final def = cw['definition_data'] as Map<String, dynamic>;

      _workouts.add({
        'title': cw['exercise_name'] ?? "Custom",
        'lookupName': cw['exercise_name'],
        'icon': '✨',
        'sets': "3 sets × $scaledReps reps",
        'cal': '40 cal', // Placeholder
        'time': '5 min', // Placeholder
        'illustration_icon': Icons.auto_awesome,
        'color': Colors.amber[100],
        'targetValue': scaledReps,
        'unit': 'reps',
        'isCustom': true,
        'definition': def,
      });
    }

    _workouts.sort((a, b) {
      if (a['title'] == 'Jogging') return 1;
      if (b['title'] == 'Jogging') return -1;
      return 0;
    });
  }



  Map<String, dynamic> _getExerciseMetadata(String id) {
    switch (id) {
      case 'box_pushups':
        return {
          'icon': '💪',
          'illustration_icon': Icons.accessibility,
          'color': Colors.teal[100],
          'cal': '30 cal',
          'time': '5 min',
        };
      case 'pushups':
        return {
          'icon': '🏋️',
          'illustration_icon': Icons.fitness_center,
          'color': Colors.blue[100],
          'cal': '50 cal',
          'time': '5 min',
        };
      case 'pike_pushups':
        return {
          'icon': '🤸',
          'illustration_icon': Icons.accessibility_new,
          'color': Colors.deepOrange[100],
          'cal': '45 cal',
          'time': '5 min',
        };
      case 'chair_dips':
        return {
          'icon': '🪑',
          'illustration_icon': Icons.chair,
          'color': Colors.cyan[100],
          'cal': '40 cal',
          'time': '5 min',
        };
      case 'floor_dips':
        return {
          'icon': '🛋️',
          'illustration_icon': Icons.accessibility_new,
          'color': Colors.indigo[100],
          'cal': '35 cal',
          'time': '5 min',
        };
      case 'bird_dogs':
        return {
          'icon': '🐕',
          'illustration_icon': Icons.accessibility_new,
          'color': Colors.teal[100],
          'cal': '25 cal',
          'time': '5 min',
        };
      case 'leg_raises':
        return {
          'icon': '🦵',
          'illustration_icon': Icons.accessibility_new,
          'color': Colors.cyan[100],
          'cal': '30 cal',
          'time': '5 min',
        };
      case 'situps':
        return {
          'icon': '🔥',
          'illustration_icon': Icons.accessibility,
          'color': Colors.orange[100],
          'cal': '40 cal',
          'time': '6 min',
        };
      case 'squats':
        return {
          'icon': '🦵',
          'illustration_icon': Icons.directions_walk,
          'color': Colors.purple[100],
          'cal': '60 cal',
          'time': '7 min',
        };
      case 'jogging':
        return {
          'icon': '🏃',
          'illustration_icon': Icons.directions_run,
          'color': Colors.green[100],
          'cal': '150 cal',
          'time': '15 min',
        };
      default:
        return {
          'icon': '❓',
          'illustration_icon': Icons.help,
          'color': Colors.grey[100],
          'cal': '?? cal',
          'time': '?? min',
        };
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
            child: _isRestDay
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.spa_outlined,
                            size: 64,
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Rest Day",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2126),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "This is a rest day per your workout frequency plan. Recovery is essential for muscle growth!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "If you want to workout more, change the workout frequency in the profile settings.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Failed to load workouts.",
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isError = false;
                              _retryCount = 0;
                            });
                            _loadData();
                          },
                          child: const Text("Retry Now"),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._workouts.map(
                          (workout) => _buildDetailedWorkoutCard(workout),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoCard(),
                        const SizedBox(
                          height: 100,
                        ), // Space for floating button
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () async {
              // Custom workout navigation (Sequence-based)
              // For simplicity, we just pass the full list to a handler
              // In this app, many standard exercises are hardcoded in PoseDemoScreen.
              // We'll update PoseDemoScreen to handle the 'definition' if present.
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ModelLoadingScreen(
                    nextScreen: PoseDemoScreen(workoutPlan: _workouts),
                  ),
                ),
              );
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2126),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text(
              'START CAMERA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Workout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Debug: Restart Workout',
                onPressed: () async {
                  await WorkoutService().clearTodayProgress();
                  _loadData();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Workout progress reset')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "AI-selected for your goals",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedWorkoutCard(Map<String, dynamic> workout) {
    final lookupName = workout['lookupName'];
    final isCompleted = _progress[lookupName]?['isCompleted'] == true;
    final isSkipped = _progress[lookupName]?['isSkipped'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isCompleted
            ? Border.all(
                color: isSkipped ? Colors.redAccent : Colors.greenAccent,
                width: 2,
              )
            : null,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Illustration Area (Top Half)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: workout['color'],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        workout['illustration_icon'],
                        size: 80,
                        color: Colors.black54,
                      ),
                    ),
                    Positioned(
                      right: 20,
                      top: 20,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 30,
                      bottom: 20,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: Text(
                          workout['title'].toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Stats Area (Bottom Half)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          workout['icon'],
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            workout['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2126),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          Icon(
                            isSkipped ? Icons.cancel : Icons.check_circle,
                            color: isSkipped ? Colors.redAccent : Colors.green,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatBadge(Icons.bar_chart, workout['sets']),
                        _buildStatBadge(
                          Icons.local_fire_department,
                          workout['cal'],
                          color: Colors.orange,
                        ),
                        _buildStatBadge(
                          Icons.timer_outlined,
                          workout['time'],
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCompleted)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    IconData icon,
    String text, {
    Color color = Colors.grey,
  }) {
    Color iconColor = color;
    if (icon == Icons.bar_chart) iconColor = Colors.blueGrey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Why These Workouts?",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E2126),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Based on your fitness level and your primary goal of $_userGoal, I've selected exercises tailored to your current capabilities.",
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
