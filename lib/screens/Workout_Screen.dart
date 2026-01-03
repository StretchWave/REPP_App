import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';
import 'package:ai_fitness_tracker/services/level_progression_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load Progress
    final progress = await WorkoutService().getTodayProgress();

    // 2. Load Power Level
    int powerLevel = 1; // Default to 1
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('power_level')
            .eq('id', userId)
            .single();
        powerLevel = data['power_level'] ?? 1;
      }
    } catch (e) {
      debugPrint("Error loading power level: $e");
    }

    if (mounted) {
      setState(() {
        _progress = progress;
        _powerLevel = powerLevel;
        _generateWorkout();
      });

      // Retry Logic: Check if workouts are empty
      if (_workouts.isEmpty) {
        if (_retryCount < 3) {
          // Wait 5 seconds before retrying
          await Future.delayed(const Duration(seconds: 5));
          if (mounted && _workouts.isEmpty) {
            _retryCount++;
            debugPrint("Retrying workout load... Attempt $_retryCount");
            _loadData();
          }
        } else {
          // Stop loading and show error
          setState(() {
            _isError = true;
          });
        }
      } else {
        // Success, reset counters
        _retryCount = 0;
        _isError = false;
      }
    }
  }

  void _generateWorkout() {
    // 1. Get Generated Routine from Service
    final items = LevelProgressionService().getWorkoutForLevel(_powerLevel);

    // 2. Map to UI format
    _workouts = items.map((item) {
      final meta = _getExerciseMetadata(item.exercise.id);

      // Format Sets/Reps string
      // Format Sets/Reps string
      String setsText = "3 sets × ${item.targetValue} ${item.unit}";

      dynamic finalTargetValue = item.targetValue;
      String finalUnit = item.unit;

      if (item.exercise.name == 'Jogging') {
        // Convert seconds to steps (approx 1.5 steps/sec)
        int steps = (item.targetValue * 1.5).round();
        setsText = "$steps steps";
        finalTargetValue = steps;
        finalUnit = 'steps';
      } else if (item.exercise.type == ExerciseType.duration) {
        // Convert seconds to minutes for clean display if needed
        if (item.unit == 'seconds') {
          int mins = (item.targetValue / 60).round();
          setsText = "$mins minutes";
        }
      }

      return {
        'title': item.exercise.name,
        'lookupName': item.exercise.name, // Used for progress tracking key
        'icon': meta['icon'],
        'sets': setsText,
        'cal': meta['cal'],
        'time': meta['time'],
        'illustration_icon': meta['illustration_icon'],
        'color': meta['color'],
        // Store raw targets if needed for camera
        'targetValue': finalTargetValue,
        'unit': finalUnit,
      };
    }).toList();

    // Ensure Jogging is last
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
      case 'bird_dogs': // Note: Service uses 'bird_dogs', UI used 'Bird Dog'
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
            child: _isError
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
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PoseDemoScreen(workoutPlan: _workouts),
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
                    color: Colors.white.withOpacity(0.7),
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.bug_report,
                      color: Colors.amberAccent,
                    ),
                    onPressed: _showDebugMenu,
                    tooltip: "Debug Menu",
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    onPressed: () async {
                      await WorkoutService().clearTodayProgress();
                      _loadData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Dev: Progress Reset")),
                        );
                      }
                    },
                    tooltip: "Dev: Reset Progress",
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "AI-selected for your goals",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
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
            color: Colors.black.withOpacity(0.05),
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
                        Text(
                          workout['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2126),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildStatBadge(Icons.bar_chart, workout['sets']),
                        const SizedBox(width: 12),
                        _buildStatBadge(
                          Icons.local_fire_department,
                          workout['cal'],
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
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
                  color: Colors.white.withOpacity(0.3),
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
            "Based on your fitness level and goal to lose 5kg, I've selected high-intensity interval exercises to maximize calorie burn.",
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

  void _showDebugMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Debug Controls",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                ),
                title: const Text(
                  "Complete Today's Workout",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Marks all exercises as done & logs to DB",
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _debugCompleteAll();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  "Go to Next Day",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Simulates tomorrow date for testing streaks",
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _debugNextDay();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.orangeAccent),
                title: const Text(
                  "Reset to Today",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Resets debug date offset to zero",
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _debugResetDate();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _debugCompleteAll() async {
    final timestamp = WorkoutService().now; // Use debug date

    for (var w in _workouts) {
      final name = w['lookupName'];
      if (_progress[name]?['isCompleted'] == true) continue;

      // 1. Save to SharedPrefs (UI Checkmarks)
      await WorkoutService().saveExerciseProgress(
        exerciseName: name,
        isCompleted: true,
        durationSeconds: 300,
        progressValue: 100,
        feedback: "Debug Auto-Complete",
      );

      // 2. Log to Supabase (Analytics)
      // Extract numeric stats from metadata or defaults
      // e.g., 'cal': '30 cal' -> 30.0
      double calories = 50.0;
      try {
        final calStr = (w['cal'] as String).split(' ').first;
        calories = double.tryParse(calStr) ?? 50.0;
      } catch (_) {}

      await WorkoutLogService().logWorkout(
        exerciseName: name,
        repsCompleted: 10,
        durationSeconds: 300,
        isCompleted: true,
        caloriesOverride: calories,
        timestamp: timestamp,
      );
    }

    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Debug: All workouts completed for ${timestamp.toLocal().toString().split(' ')[0]}",
          ),
        ),
      );
    }
  }

  void _debugNextDay() {
    WorkoutService().debugAdvanceDay();
    // No need to clear progress explicitly unless we want to ensure empty state,
    // but _getTodayKey() will now return a new key which is naturally empty.
    _loadData();

    if (mounted) {
      final newDate = WorkoutService().now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Debug: Advanced to ${newDate.toLocal().toString().split(' ')[0]}",
          ),
        ),
      );
    }
  }

  void _debugResetDate() {
    WorkoutService().debugResetToToday();
    _loadData();

    if (mounted) {
      final newDate = WorkoutService().now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Debug: Date reset to ${newDate.toLocal().toString().split(' ')[0]}",
          ),
        ),
      );
    }
  }
}
