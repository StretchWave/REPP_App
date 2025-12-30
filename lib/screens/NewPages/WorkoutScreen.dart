import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Hardcoded detailed workout data for the new design
  final List<Map<String, dynamic>> _workouts = [
    {
      'title': 'Push-ups',
      'icon': '💪',
      'sets': '3 sets × 15 reps',
      'cal': '50 cal',
      'time': '5 min',
      'illustration_icon': Icons.accessibility_new, // Placeholder for SVG style
      'color': Colors.blueGrey[100],
      
    },
    {
      'title': 'Sit-ups',
      'icon': '🔥',
      'sets': '3 sets × 20 reps',
      'cal': '40 cal',
      'time': '6 min',
      'illustration_icon': Icons.accessibility,
      'color': Colors.blueGrey[100],
    },
    {
      'title': 'Squats',
      'icon': '🦵',
      'sets': '3 sets × 20 reps',
      'cal': '60 cal',
      'time': '7 min',
      'illustration_icon': Icons.directions_walk,
      'color': Colors.blueGrey[100],
    },
    {
      'title': 'Jogging',
      'icon': '🏃',
      'sets': '15 minutes', // Adjusted for jogging
      'cal': '150 cal',
      'time': '15 min',
      'illustration_icon': Icons.directions_run,
      'color': Colors.blueGrey[100],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light background
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
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PoseDemoScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2126), // Dark button
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text(
              'Start Workout with Camera',
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
            "Today's Workout",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
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
      ),
      child: Column(
        children: [
          // Illustration Area (Top Half)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: workout['color'], // Light grey/blue background
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                // Placeholder for actual illustration
                Center(
                  child: Icon(
                    workout['illustration_icon'],
                    size: 80,
                    color: Colors.black54,
                  ),
                ),
                // Decorative circle elements mimicking the design
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
                    Text(workout['icon'], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      workout['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2126),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Align to center
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
    );
  }

  Widget _buildStatBadge(
    IconData icon,
    String text, {
    Color color = Colors.grey,
  }) {
    // Determine color based on icon logic similar to design if needed,
    // but passing color is simpler.
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
