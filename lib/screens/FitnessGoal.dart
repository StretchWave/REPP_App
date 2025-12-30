import 'package:ai_fitness_tracker/screens/Home.dart';
import 'package:flutter/material.dart';

class FitnessGoalsScreen extends StatefulWidget {
  const FitnessGoalsScreen({super.key});

  @override
  State<FitnessGoalsScreen> createState() => _FitnessGoalsScreenState();
}

class _FitnessGoalsScreenState extends State<FitnessGoalsScreen> {
  // State Variables
  String? _selectedPrimaryGoal;
  String? _selectedTimeline;
  int _workoutFrequency = 3; // Default 3 days
  String? _selectedIntensity;
  String? _selectedAdvancedMode;

  final List<Map<String, dynamic>> _primaryGoals = [
    {'name': 'Fat Loss', 'icon': '🔥'},
    {'name': 'Muscle Gain', 'icon': '💪'},
    {'name': 'Strength', 'icon': '🏋️'},
    {'name': 'Endurance', 'icon': '🏃'},
    {'name': 'Mobility / Flexibility', 'icon': '🧘'},
    {'name': 'General Fitness', 'icon': '⭐'},
  ];

  final List<String> _timelines = [
    '4 Weeks',
    '8 Weeks',
    '12 Weeks',
    '∞ Long term',
  ];

  final List<Map<String, dynamic>> _intensities = [
    {'name': 'Light', 'desc': 'Easy pace, building habits', 'icon': '🌱'},
    {
      'name': 'Moderate',
      'desc': 'Balanced challenge and recovery',
      'icon': '⚡',
    },
    {
      'name': 'Intense',
      'desc': 'Push limits, serious commitment',
      'icon': '🔥',
    },
  ];

  final List<Map<String, dynamic>> _modes = [
    {'name': 'Cutting', 'desc': 'Fat loss with muscle retention', 'icon': '✂️'},
    {'name': 'Lean Bulk', 'desc': 'Muscle gain with minimal fat', 'icon': '📈'},
    {'name': 'Bulking', 'desc': 'Maximum muscle gain', 'icon': '🚀'},
    {'name': 'Recomp', 'desc': 'Fat loss + muscle gain', 'icon': '⚖️'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF485563,
      ), // Dark background matching theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Overlay
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.track_changes,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fitness Goals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let\'s define your path to success',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(
                    value: 0.6, // Step 2/3 approx
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),

          // White Card Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // 1. Primary Goal
                  _buildSectionHeader(1, 'PRIMARY GOAL'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6, // Rectangular cards
                        ),
                    itemCount: _primaryGoals.length,
                    itemBuilder: (context, index) {
                      final goal = _primaryGoals[index];
                      return _buildSelectableCard(
                        title: goal['name'],
                        icon: goal['icon'],
                        isSelected: _selectedPrimaryGoal == goal['name'],
                        onTap: () =>
                            setState(() => _selectedPrimaryGoal = goal['name']),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // 2. Goal Timeline
                  _buildSectionHeader(2, 'GOAL TIMELINE'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2x2 grid
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2, // Flatter cards
                        ),
                    itemCount: _timelines.length,
                    itemBuilder: (context, index) {
                      final time = _timelines[index];
                      return _buildTimelineCard(
                        title: time,
                        isSelected: _selectedTimeline == time,
                        onTap: () => setState(() => _selectedTimeline = time),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // 3. Workout Frequency
                  _buildSectionHeader(3, 'WORKOUT FREQUENCY'),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCounterButton(Icons.remove, () {
                              if (_workoutFrequency > 1)
                                setState(() => _workoutFrequency--);
                            }),
                            SizedBox(
                              width: 100,
                              child: Text(
                                '$_workoutFrequency',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            _buildCounterButton(Icons.add, () {
                              if (_workoutFrequency < 7)
                                setState(() => _workoutFrequency++);
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'days per week',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTip(
                    'We recommend 3-5 days per week for optimal results and recovery',
                  ),
                  const SizedBox(height: 32),

                  // 4. Goal Intensity / Commitment
                  _buildSectionHeader(4, 'GOAL INTENSITY / COMMITMENT'),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _intensities.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final intensity = _intensities[index];
                      return _buildIntensityCard(
                        title: intensity['name'],
                        desc: intensity['desc'],
                        icon: intensity['icon'],
                        isSelected: _selectedIntensity == intensity['name'],
                        onTap: () => setState(
                          () => _selectedIntensity = intensity['name'],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // 5. Goal Mode / Phase (Advanced)
                  Row(
                    children: [
                      _buildSectionHeader(5, 'GOAL MODE / PHASE'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADVANCED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6, // Rectangular
                        ),
                    itemCount: _modes.length,
                    itemBuilder: (context, index) {
                      final mode = _modes[index];
                      return _buildModeCard(
                        title: mode['name'],
                        desc: mode['desc'],
                        icon: mode['icon'],
                        isSelected: _selectedAdvancedMode == mode['name'],
                        onTap: () => setState(
                          () => _selectedAdvancedMode = mode['name'],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTip(
                    'This option is for advanced users. It will override some AI recommendations based on your selected phase.',
                  ),

                  const SizedBox(height: 48),

                  // Navigation Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('← Back'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C757D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Continue →'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(int number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFB0BEC5), // Light Grey circle
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB0BEC5),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableCard({
    required String title,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black87 : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Extract subtext if needed (e.g. "Quick Start", "Balanced") but for now keeping it simple as per screenshot logic
    // Actually the screenshot has secondary text. Let's add basic logic for it.
    String subtitle = 'Plan';
    if (title.contains('4')) subtitle = 'Quick Start';
    if (title.contains('8')) subtitle = 'Balanced';
    if (title.contains('12')) subtitle = 'Recommended';
    if (title.contains('Long')) subtitle = 'Lifestyle';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black87 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.grey[400], size: 20),
      ),
    );
  }

  Widget _buildIntensityCard({
    required String title,
    required String desc,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String desc,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black87 : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
