import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  // User Data
  String _bodyType = 'Mesomorph'; // Default
  String _goal = 'General Fitness';
  int _age = 25;
  double _weight = 70;
  double _height = 175;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _bodyType = data['body_type'] ?? 'Mesomorph';
            _goal =
                data['goal_intensity'] ??
                'Moderate'; // Using intensity as proxy for now, or fetch goal_timeline
            // If you have a specific goal column like 'primary_goal' use that.
            // Based on previous files, 'goal_intensity' (Light/Moderate/Intense) gives a hint,
            // but let's see if we can infer better or just use body type heavily.
            _age = data['age'] ?? 25;
            _weight = (data['weight'] as num?)?.toDouble() ?? 70.0;
            _height = (data['height'] as num?)?.toDouble() ?? 175.0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to load profile. Using default recommendations.';
          _isLoading = false;
        });
      }
    }
  }

  // --- Logic Engines ---

  Map<String, dynamic> _getTrainingStrategy() {
    if (_bodyType == 'Ectomorph') {
      return {
        'title': 'Hypertrophy & Strength',
        'summary':
            'Your fast metabolism makes gaining muscle harder. Focus on heavy, compound lifts and conserve energy.',
        'split': '3-4 Day Split (Push/Pull/Legs or Upper/Lower)',
        'reps': '6-10 reps (Heavy weight)',
        'rest': '2-3 minutes between sets',
        'cardio':
            'Minimal. 1-2 times/week (Low Intensity) to preserve calories for growth.',
        'focus': ['Squats', 'Deadlifts', 'Bench Press', 'Overhead Press'],
      };
    } else if (_bodyType == 'Endomorph') {
      return {
        'title': 'Metabolic Conditioning',
        'summary':
            'You gain weight easily. High intensity and volume are key to revving up your metabolism.',
        'split': '4-6 Day Split (Full Body or Body Part Split)',
        'reps': '12-15+ reps (Moderate weight, high volume)',
        'rest': '30-60 seconds (Keep heart rate up)',
        'cardio': 'Critical. 3-4 days/week (HIIT + Steady State).',
        'focus': ['Circuit Training', 'Supersets', 'Burpees', 'Kettlebells'],
      };
    } else {
      // Mesomorph
      return {
        'title': 'Athletic Performance',
        'summary':
            'You respond well to most stimuli. A balanced mix of strength and size work yields best results.',
        'split': '4-5 Day Split (Body Part Split)',
        'reps': '8-12 reps (Standard Hypertrophy)',
        'rest': '60-90 seconds',
        'cardio': 'Moderate. 2-3 days/week (Mix of HIIT and runs).',
        'focus': ['Compound Lifts', 'Isolation Movements', 'Plyometrics'],
      };
    }
  }

  Map<String, dynamic> _getNutritionPlan() {
    if (_bodyType == 'Ectomorph') {
      return {
        'title': 'Eat Big to Get Big',
        'macros': '50% Carbs / 30% Protein / 20% Fats',
        'strategy': 'You need a calorie surplus. Never skip meals.',
        'tips': [
          'Eat every 2-3 hours.',
          'Focus on calorie-dense foods (nuts, oats, steak).',
          'Use liquid calories (shakes) if you can\'t eat enough.',
          'Carbs are your friend – eat plenty of rice, potatoes, and pasta.',
        ],
        'foods': ['Oats', 'Rice', 'Red Meat', 'Nut Butters', 'Whole Milk'],
        'avoid': ['Skipping breakfast', 'Low-calorie salads (add oils!)'],
      };
    } else if (_bodyType == 'Endomorph') {
      return {
        'title': 'Carb Control',
        'macros': '25% Carbs / 40% Protein / 35% Fats',
        'strategy': 'Control insulin levels. Time your carbs around workouts.',
        'tips': [
          'Focus on fiber-rich vegetables to stay full.',
          'Prioritize protein at every meal.',
          'Try Intermittent Fasting (16:8 window) if stuck.',
          'Limit starchy carbs to post-workout only.',
        ],
        'foods': ['Chicken', 'Fish', 'Leafy Greens', 'Berries', 'Avocado'],
        'avoid': ['Sugar', 'White Bread', 'Pasta', 'Soda', 'Late night snacks'],
      };
    } else {
      return {
        'title': 'Balanced Performance',
        'macros': '40% Carbs / 30% Protein / 30% Fats',
        'strategy': 'Fuel enough for workouts, but don\'t overeat.',
        'tips': [
          'Eat a balanced meal 2 hours before training.',
          'Protein shake immediately post-workout.',
          'Hydrate well throughout the day.',
          'Adjust carbs based on activity level (eat more on leg days).',
        ],
        'foods': ['Lean Beef', 'Sweet Potato', 'Eggs', 'Quinoa', 'Fruits'],
        'avoid': ['Processed junk', 'Excessive alcohol'],
      };
    }
  }

  List<Map<String, dynamic>> _getLifestyleTips() {
    return [
      {
        'title': 'Sleep Optimization',
        'desc':
            'Growth hormone is released during deep sleep. Aim for 7-9 hours.',
        'icon': Icons.bed,
        'color': Colors.deepPurpleAccent,
      },
      {
        'title': 'Stress Management',
        'desc': _bodyType == 'Endomorph'
            ? 'Cortisol promotes belly fat storage. Try yoga or meditation.'
            : 'High stress kills gains. Take time to relax.',
        'icon': Icons.self_improvement,
        'color': Colors.teal,
      },
      {
        'title': 'Hydration Strategy',
        'desc': 'Drink ${_weight * 0.04} liters of water daily.',
        'icon': Icons.local_drink,
        'color': Colors.blue,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Recalculate based on current state
    final training = _getTrainingStrategy();
    final nutrition = _getNutritionPlan();
    final lifestyle = _getLifestyleTips();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F25), // Dark background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C313A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "AI Recommendations",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Tailored to your DNA",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSummary(),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Training Section
                      _buildSectionHeader(
                        "Training Strategy",
                        Icons.fitness_center,
                        Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildTrainingCard(training),
                      const SizedBox(height: 24),

                      // Nutrition Section
                      _buildSectionHeader(
                        "Nutrition Plan",
                        Icons.restaurant_menu,
                        Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildNutritionCard(nutrition),
                      const SizedBox(height: 12),
                      _buildFoodGrid(nutrition['foods']),
                      const SizedBox(height: 24),

                      // Lifestyle Section
                      _buildSectionHeader(
                        "Lifestyle & Recovery",
                        Icons.wb_sunny,
                        Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      ...lifestyle.map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildLifestyleItem(
                            tip['title'],
                            tip['desc'],
                            tip['icon'],
                            tip['color'],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B5563), Color(0xFF374151)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Analyzed Body Profile",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  _bodyType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Goal: $_goal",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildTrainingCard(Map<String, dynamic> data) {
    return _buildGlassCard(
      borderColor: Colors.redAccent.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['summary'],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildDetailRow("Split", data['split']),
          _buildDetailRow("Reps", data['reps']),
          _buildDetailRow("Rest", data['rest']),
          _buildDetailRow("Cardio", data['cardio']),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (data['focus'] as List<String>)
                .map(
                  (e) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      e,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(Map<String, dynamic> data) {
    return _buildGlassCard(
      borderColor: Colors.orange.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.pie_chart_outline,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['macros'],
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['strategy'],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...(data['tips'] as List<String>).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodGrid(List<String> foods) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: Text(
              foods[index],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLifestyleItem(
    String title,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
