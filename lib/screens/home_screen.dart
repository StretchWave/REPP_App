import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_fitness_tracker/screens/workout_screen.dart';
import 'package:ai_fitness_tracker/screens/analytics_screen.dart';
import 'package:ai_fitness_tracker/screens/diet_screen.dart';
import 'package:ai_fitness_tracker/screens/profile_screen.dart';
import 'package:ai_fitness_tracker/screens/recommendation_screen.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';

import 'package:ai_fitness_tracker/screens/calibration_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _summaryMessage = "Loading daily motivation...";
  bool _isLoading = true;
  int _powerLevel = 0;
  Map<String, dynamic>? _userData;

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

  bool _isTodayWorkoutDay(int freq) {
    // 1 = Mon, 7 = Sun
    final weekday = DateTime.now().weekday;

    switch (freq) {
      case 3:
        // Mon(1), Wed(3), Fri(5)
        return weekday == 1 || weekday == 3 || weekday == 5;
      case 4:
        // Mon(1), Tue(2), Thu(4), Fri(5)
        return weekday == 1 || weekday == 2 || weekday == 4 || weekday == 5;
      case 5:
        // Mon(1), Tue(2), Wed(3), Fri(5), Sat(6)
        return weekday == 1 ||
            weekday == 2 ||
            weekday == 3 ||
            weekday == 5 ||
            weekday == 6;
      case 6:
        // Mon(1) -> Sat(6)
        return weekday != 7;
      default:
        // Fallback
        return weekday == 1 || weekday == 3 || weekday == 5;
    }
  }

  Future<void> _loadDailyMessage() async {
    try {
      // 1. Fetch User Data (Profile) First
      // We need this for Workout Frequency & Power Level
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        _userData = profile;
        _powerLevel = profile['power_level'] ?? 0;
      }

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month}-${now.day}";

      // 2. Check if message locked for today
      final savedDate = prefs.getString('daily_message_date');
      if (savedDate == todayKey) {
        final savedMsg = prefs.getString('daily_message_content');
        if (savedMsg != null && mounted) {
          setState(() {
            _summaryMessage = savedMsg;
            _isLoading = false;
          });
          return;
        }
      }

      // 3. Generate New Message
      final yesterday = now.subtract(const Duration(days: 1));
      final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      final calories = await WorkoutLogService().getCaloriesBurned(start, end);

      List<String> options = List.from(_motivationalQuotes);

      if (calories > 0) {
        // Worked out yesterday -> 1 option added
        options.add(
          "You burned ${calories.toInt()} calories yesterday! Consistency pays off. Keep it up! 🔥",
        );
      } else {
        // Missed workout -> 3 options added
        options.add(
          "Missed yesterday? No worries! Today is a new chance. Let's get moving! 🚀",
        );
        options.add(
          "Consistency is a journey, not a sprint. Let's make up for yesterday today! 💪",
        );
        options.add(
          "Everybody needs a rest day. But today, we're back in action! Let's go! 🔥",
        );
      }

      // 4. Pick Random
      final randomMsg = options[Random().nextInt(options.length)];

      // 5. Save
      await prefs.setString('daily_message_date', todayKey);
      await prefs.setString('daily_message_content', randomMsg);

      if (mounted) {
        setState(() {
          _summaryMessage = randomMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading message: $e");
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
                  const SizedBox(height: 24),
                  // Workout Button Logic
                  Builder(
                    builder: (context) {
                      final freq = _userData?['workout_frequency'] ?? 3;
                      final isWorkoutDay = _isTodayWorkoutDay(freq);
                      final isRest = !isWorkoutDay;

                      return _buildMenuOption(
                        icon: isRest
                            ? Icons.spa_outlined
                            : Icons.fitness_center,
                        title: isRest ? 'Rest Day 😴' : 'Workout',
                        subtitle: isRest
                            ? 'Recovery is key to growth'
                            : 'AI-powered training plans',
                        color: isRest ? const Color(0xFF3E444E) : null,
                        onTap: () {
                          if (_isLoading) return; // Wait for profile load

                          if (isRest) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "It's a rest day! Your muscles grow while you rest. Take it easy.",
                                ),
                                backgroundColor: Colors.blueGrey,
                              ),
                            );
                            return;
                          }

                          if (_powerLevel == 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CalibrationScreen(
                                  userData: _userData ?? {},
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WorkoutScreen(),
                              ),
                            );
                          }
                        },
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
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.event,
                    title: 'Events',
                    subtitle: 'Join community events',
                    isLocked: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("This feature is locked."),
                          duration: Duration(seconds: 2),
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
    Color? color,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF2C313A), // Dark button background
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
              isLocked ? Icons.lock : Icons.arrow_forward,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
