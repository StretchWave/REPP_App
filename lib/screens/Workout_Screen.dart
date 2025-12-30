import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Map<String, dynamic> _progress = {};

  final List<Map<String, dynamic>> _workouts = [
    {
      'title': 'Box Push-Ups',
      'lookupName': 'Box Push-Ups',
      'icon': '💪',
      'sets': '3 sets × 10 reps',
      'cal': '30 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility,
      'color': Colors.teal[100],
    },
    {
      'title': 'Push-Ups',
      'lookupName': 'Push-Ups',
      'icon': '🏋️',
      'sets': '3 sets × 15 reps',
      'cal': '50 cal',
      'time': '5 min',
      'illustration_icon': Icons.fitness_center,
      'color': Colors.blue[100],
    },
    {
      'title': 'Pike Push-Ups',
      'lookupName': 'Pike Push-Ups',
      'icon': '🤸',
      'sets': '3 sets × 12 reps',
      'cal': '45 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility_new,
      'color': Colors.deepOrange[100],
    },
    {
      'title': 'Chair Dips',
      'lookupName': 'Chair Dips',
      'icon': '🪑',
      'sets': '3 sets × 15 reps',
      'cal': '40 cal',
      'time': '5 min',
      'illustration_icon': Icons.chair,
      'color': Colors.cyan[100],
    },
    {
      'title': 'Floor Dips',
      'lookupName': 'Floor Dips',
      'icon': '🛋️',
      'sets': '3 sets × 15 reps',
      'cal': '35 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility_new,
      'color': Colors.indigo[100],
    },
    {
      'title': 'Bird Dog',
      'lookupName': 'Bird Dog',
      'icon': '🐕',
      'sets': '3 sets × 10 reps',
      'cal': '25 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility_new,
      'color': Colors.teal[100],
    },
    {
      'title': 'Leg Raises',
      'lookupName': 'Leg Raises',
      'icon': '🦵',
      'sets': '3 sets × 15 reps',
      'cal': '30 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility_new,
      'color': Colors.cyan[100],
    },
    {
      'title': 'Sit-Ups',
      'lookupName': 'Sit-Ups',
      'icon': '🔥',
      'sets': '3 sets × 20 reps',
      'cal': '40 cal',
      'time': '6 min',
      'illustration_icon': Icons.accessibility,
      'color': Colors.orange[100],
    },
    {
      'title': 'Squats',
      'lookupName': 'Squats',
      'icon': '🦵',
      'sets': '3 sets × 20 reps',
      'cal': '60 cal',
      'time': '7 min',
      'illustration_icon': Icons.directions_walk,
      'color': Colors.purple[100],
    },
    {
      'title': 'Jogging',
      'lookupName': 'Jogging',
      'icon': '🏃',
      'sets': '15 minutes',
      'cal': '150 cal',
      'time': '15 min',
      'illustration_icon': Icons.directions_run,
      'color': Colors.green[100],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await WorkoutService().getTodayProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
      });
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._workouts.map(
                    (workout) => _buildDetailedWorkoutCard(workout),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 100), // Space for floating button
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
                MaterialPageRoute(builder: (context) => const PoseDemoScreen()),
              );
              _loadProgress();
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
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () async {
                  await WorkoutService().clearTodayProgress();
                  _loadProgress();
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
            ? Border.all(color: Colors.greenAccent, width: 2)
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
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
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
}
