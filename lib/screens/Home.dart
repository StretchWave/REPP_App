import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/Workout_Screen.dart';
import 'package:ai_fitness_tracker/screens/Analytics.dart';
import 'package:ai_fitness_tracker/screens/Diet.dart';
import 'package:ai_fitness_tracker/screens/profile_screen.dart';
import 'package:ai_fitness_tracker/screens/Recommendation.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _summaryMessage = "Loading daily motivation...";
  bool _isLoading = true;

  final List<String> _motivationalQuotes = [
    "Consistency is key! Keep showing up.",
    "Your only limit is you. Push harder!",
    "Small steps every day lead to big results.",
    "Don't stop when you're tired. Stop when you're done.",
    "Sweat is just fat crying. Keep it up!",
    "Make yourself proud today.",
    "You are stronger than you think.",
    "Focus on progress, not perfection.",
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyMessage();
  }

  Future<void> _loadDailyMessage() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      final calories = await WorkoutLogService().getCaloriesBurned(start, end);

      String message = "";

      // 50/50 Chance to show stats IF we have data, otherwise always show quote
      bool showStats = calories > 0 && Random().nextBool();

      if (showStats) {
        message =
            "You burned ${calories.toInt()} calories yesterday! Your consistency is improving. Keep up the momentum! 🔥";
      } else {
        message =
            _motivationalQuotes[Random().nextInt(_motivationalQuotes.length)];
      }

      if (mounted) {
        setState(() {
          _summaryMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryMessage =
              _motivationalQuotes[Random().nextInt(_motivationalQuotes.length)];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Overlapping card visual effect can be improved here,
                  // but effectively we just want the card to separate header and menu.
                  // Move margins to the card itself if needed.
                  const SizedBox(height: 20),
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  _buildMenuOption(
                    icon: Icons.fitness_center,
                    title: 'Workout',
                    subtitle: 'AI-powered training plans',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkoutScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.apple_outlined,
                    title: 'Diet',
                    subtitle: 'Track your nutrition goals',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DietScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.show_chart,
                    title: 'Analysis',
                    subtitle: 'View your progress stats',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ...
                  _buildMenuOption(
                    icon: Icons.favorite_border,
                    title: 'Recommendations',
                    subtitle: 'Personalized AI suggestions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecommendationScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E2126), // Dark header background
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'FitAI Trainer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF383D47),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF434852), // Card dark grey
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: Colors.white,
                size: 20,
              ), // Placeholder icon
              SizedBox(width: 8),
              Text(
                'Daily Message For you', // Changed from "Great Job!" (generic title)
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _summaryMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2C313A), // Dark button background
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
