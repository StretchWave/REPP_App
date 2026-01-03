import 'package:ai_fitness_tracker/screens/Login.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_tracker/screens/Settings.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';
import 'package:ai_fitness_tracker/services/level_progression_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile Data
  String _fullName = "Loading...";
  String _joinDate = "Loading...";
  String _email = "Loading...";
  String _phone = "Not set";
  int _age = 0;
  String _gender = "Not set";

  // Stats
  int _powerLevel = 0;
  int _workoutsCount = 0;
  int _totalCalories = 0;
  int _streak = 0; // Placeholder for now

  // Body Metrics
  double _height = 0;
  double _weight = 0;
  String _bodyType = "Not set";
  String _bmi = "--";

  // Goals
  String _primaryGoal = "General Fitness";
  String _duration = "4 Weeks";
  String _frequency = "3 days/week";
  String _intensity = "Moderate";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 1. Auth Data
        _email = user.email ?? "No Email";
        if (user.createdAt.isNotEmpty) {
          try {
            final date = DateTime.parse(user.createdAt);
            _joinDate = "${_getMonth(date.month)} ${date.year}";
          } catch (_) {
            _joinDate = "Unknown";
          }
        }

        // 2. Profile Data
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        // 3. Workout Stats (Aggregate)
        final workoutData = await Supabase.instance.client
            .from('workout_logs')
            .select('calories_burned');

        // Calculate Stats
        int wCount = workoutData.length;
        double cTotal = 0;
        for (var w in workoutData) {
          cTotal += (w['calories_burned'] as num? ?? 0).toDouble();
        }

        // 4. Fetch Streak
        int streak = await WorkoutLogService().calculateCurrentStreak();

        // 5. Check Level Progression
        await LevelProgressionService().evaluateAndApplyPowerLevelUpdate();

        // Refresh profile data to get latest level if updated
        final updatedProfile = await Supabase.instance.client
            .from('profiles')
            .select('power_level')
            .eq('id', user.id)
            .single();
        data['power_level'] = updatedProfile['power_level'];

        if (mounted) {
          setState(() {
            _fullName = data['full_name'] ?? "User";
            _powerLevel = data['power_level'] ?? 0;
            _phone = data['phone_number'] ?? "Not set";
            _age = data['age'] ?? 0;
            _gender = data['gender'] ?? "Not set";

            _height = (data['height'] as num?)?.toDouble() ?? 0.0;
            _weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
            _bodyType = data['body_type'] ?? "Not set";

            _duration = data['goal_timeline'] ?? "4 Weeks";
            _frequency = "${data['workout_frequency'] ?? 3} days/week";
            _intensity = data['goal_intensity'] ?? "Moderate";

            // Infer Goal
            if (_intensity.contains("Intense"))
              _primaryGoal = "Body Building";
            else if (_intensity.contains("Light"))
              _primaryGoal = "Maintenance";
            else
              _primaryGoal = "Fitness";

            // Calculate BMI
            if (_height > 0 && _weight > 0) {
              double hM = _height / 100;
              _bmi = (_weight / (hM * hM)).toStringAsFixed(1);
            }

            _workoutsCount = wCount;
            _totalCalories = cTotal.toInt();
            _streak = streak;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) {
        setState(() {
          _fullName = "Error";
          _isLoading = false;
        });
      }
    }
  }

  String _getMonth(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "Jan";
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F25),
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.blueAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // User Header
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF2C313A),
                        child: Icon(Icons.person, size: 60, color: Colors.blue),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Join Date: $_joinDate",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(
                        "Power Level: $_powerLevel",
                        Icons.bolt,
                        Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        "Top 10%",
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Workouts",
                          "$_workoutsCount",
                          Icons.fitness_center,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Calories",
                          "$_totalCalories",
                          Icons.local_fire_department,
                          Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Streak",
                          "$_streak Days",
                          Icons.bolt,
                          Colors.yellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Goal Progress
                  _buildGoalProgressCard(),
                  const SizedBox(height: 24),

                  // Information Sections
                  _buildInfoSection("Personal Information", [
                    {"Full Name": _fullName},
                    {"Age": "$_age years"},
                    {"Gender": _gender},
                    {"Email": _email},
                    {"Phone": _phone},
                  ], icon: Icons.person_outline),
                  const SizedBox(height: 16),

                  _buildInfoSection("Body Metrics", [
                    {"Height": "${_height.toStringAsFixed(0)} cm"},
                    {"Current Weight": "${_weight.toStringAsFixed(1)} kg"},
                    {"Body Type": _bodyType},
                    {"BMI": _bmi},
                  ], icon: Icons.straighten),
                  const SizedBox(height: 16),

                  _buildInfoSection("Fitness Goals", [
                    {"Primary Goal": _primaryGoal},
                    {"Duration": _duration},
                    {"Frequency": _frequency},
                    {"Goal Mode": _intensity},
                  ], icon: Icons.flag_outlined),
                  const SizedBox(height: 16),

                  _buildInfoSection("Health Information", [
                    {"Medical Conditions": "None"},
                    {"Physical Limitations": "None"},
                  ], icon: Icons.medical_services_outlined),
                  const SizedBox(height: 24),

                  // Achievements
                  _buildSectionHeader("Achievements"),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildAchievementIcon(
                        "Early Bird",
                        Icons.wb_sunny,
                        Colors.orange,
                      ),
                      _buildAchievementIcon(
                        "Muscle Up",
                        Icons.fitness_center,
                        Colors.amber,
                      ),
                      _buildAchievementIcon(
                        "Non-Stop",
                        Icons.directions_run,
                        Colors.red,
                      ),
                      _buildAchievementIcon("Fast", Icons.bolt, Colors.yellow),
                      _buildAchievementIcon(
                        "Star",
                        Icons.star,
                        Colors.yellowAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Settings Menu
                  _buildSectionHeader("Settings"),
                  const SizedBox(height: 8),
                  _buildSettingsItem(
                    "Notifications",
                    Icons.notifications,
                    Colors.amber,
                  ),
                  _buildSettingsItem(
                    "Privacy & Security",
                    Icons.lock,
                    Colors.yellow,
                  ),
                  _buildSettingsItem(
                    "Help & Support",
                    Icons.help_outline,
                    Colors.redAccent,
                  ),
                  const SizedBox(height: 32),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        "Log Out",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C313A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2C313A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24), // Colored icon
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C313A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Goal Progress",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.track_changes,
                  color: Colors.redAccent,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Placeholder progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Progress",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Text(
                "0%", // Placeholder
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.05,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: Colors.white,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile(Map<String, dynamic> updates) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update(updates)
            .eq('id', user.id);

        await _fetchProfile(); // Refresh data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
      }
    }
  }

  void _showEditPersonalDetails() {
    final nameCtrl = TextEditingController(text: _fullName);
    final ageCtrl = TextEditingController(text: _age.toString());
    final phoneCtrl = TextEditingController(text: _phone);
    String selectedGender = _gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Edit Personal Details",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildTextFieldLabel("Full Name"),
                    _buildEditTextField(nameCtrl, "Enter full name"),
                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Age"),
                    _buildEditTextField(ageCtrl, "Enter age", isNumber: true),
                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Phone Number"),
                    _buildEditTextField(
                      phoneCtrl,
                      "Enter phone number",
                      isNumber: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Gender"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectableButton(
                            "Male",
                            selectedGender == "Male",
                            () => setModalState(() => selectedGender = "Male"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableButton(
                            "Female",
                            selectedGender == "Female",
                            () =>
                                setModalState(() => selectedGender = "Female"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateProfile({
                    'full_name': nameCtrl.text.trim(),
                    'age': int.tryParse(ageCtrl.text) ?? _age,
                    'phone_number': phoneCtrl.text.trim(),
                    'gender': selectedGender,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C757D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBodyMetrics() {
    final heightCtrl = TextEditingController(text: _height.toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: _weight.toStringAsFixed(1));
    String selectedBodyType = _bodyType;
    List<String> bodyTypes = ["Ectomorph", "Mesomorph", "Endomorph"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Edit Body Metrics",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildTextFieldLabel("Height (cm)"),
                    _buildEditTextField(
                      heightCtrl,
                      "Enter height",
                      isNumber: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Weight (kg)"),
                    _buildEditTextField(
                      weightCtrl,
                      "Enter weight",
                      isNumber: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Body Type"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bodyTypes
                          .map(
                            (type) => GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedBodyType = type),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedBodyType == type
                                      ? Colors.blue[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selectedBodyType == type
                                        ? Colors.blue
                                        : Colors.grey[300]!,
                                    width: selectedBodyType == type ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: selectedBodyType == type
                                        ? Colors.blue
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateProfile({
                    'height': double.tryParse(heightCtrl.text) ?? _height,
                    'weight': double.tryParse(weightCtrl.text) ?? _weight,
                    'body_type': selectedBodyType,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C757D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditFitnessGoals() {
    String selectedTimeline = _duration;
    int selectedFreq = int.tryParse(_frequency.split(' ')[0]) ?? 3;
    String selectedIntensity = _intensity;

    List<String> timelines = ['4 Weeks', '8 Weeks', '12 Weeks', '∞ Long term'];
    List<String> intensities = ['Light', 'Moderate', 'Intense'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Edit Fitness Goals",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildTextFieldLabel("Goal Timeline"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timelines
                          .map(
                            (t) => _buildSelectablePill(
                              t,
                              selectedTimeline,
                              (val) =>
                                  setModalState(() => selectedTimeline = val),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),

                    _buildTextFieldLabel(
                      "Workout Frequency ($selectedFreq days/week)",
                    ),
                    Slider(
                      value: selectedFreq.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      activeColor: Colors.amber,
                      label: "$selectedFreq days",
                      onChanged: (val) =>
                          setModalState(() => selectedFreq = val.round()),
                    ),

                    const SizedBox(height: 16),
                    _buildTextFieldLabel("Perceived Intensity"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: intensities
                          .map(
                            (i) => _buildSelectablePill(
                              i,
                              selectedIntensity,
                              (val) =>
                                  setModalState(() => selectedIntensity = val),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateProfile({
                    'goal_timeline': selectedTimeline,
                    'workout_frequency': selectedFreq,
                    'goal_intensity': selectedIntensity,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C757D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers for Dialogs
  Widget _buildTextFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildEditTextField(
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSelectableButton(
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectablePill(
    String text,
    String selectedValue,
    Function(String) onTap,
  ) {
    final isSelected = text == selectedValue;
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    List<Map<String, String>> data, {
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  if (title.contains("Personal"))
                    _showEditPersonalDetails();
                  else if (title.contains("Body Metrics"))
                    _showEditBodyMetrics();
                  else if (title.contains("Fitness Goals"))
                    _showEditFitnessGoals();
                },
                child: const Text(
                  "Edit",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.grey),
          ...data.map((item) {
            String key = item.keys.first;
            String value = item.values.first;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _getIconForKey(key),
                      const SizedBox(width: 12),
                      Text(
                        key,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _getIconForKey(String key) {
    IconData iconData = Icons.circle;
    Color color = Colors.grey;

    if (key.contains("Name")) {
      iconData = Icons.person;
      color = Colors.blue;
    } else if (key.contains("Age")) {
      iconData = Icons.cake;
      color = Colors.orange;
    } else if (key.contains("Gender")) {
      iconData = Icons.wc;
      color = Colors.purple;
    } else if (key.contains("Email")) {
      iconData = Icons.email;
      color = Colors.blueGrey;
    } else if (key.contains("Phone")) {
      iconData = Icons.phone_android;
      color = Colors.black;
    } else if (key.contains("Height")) {
      iconData = Icons.height;
      color = Colors.amber;
    } else if (key.contains("Weight")) {
      iconData = Icons.monitor_weight;
      color = Colors.teal;
    } else if (key.contains("Body Fat")) {
      iconData = Icons.percent;
      color = Colors.red;
    } else if (key.contains("Body Type")) {
      iconData = Icons.accessibility_new;
      color = Colors.indigo;
    } else if (key.contains("BMI")) {
      iconData = Icons.calculate;
      color = Colors.green;
    } else if (key.contains("Goal")) {
      iconData = Icons.flag;
      color = Colors.redAccent;
    } else if (key.contains("Duration")) {
      iconData = Icons.timer;
      color = Colors.grey;
    } else if (key.contains("Frequency")) {
      iconData = Icons.calendar_today;
      color = Colors.blue;
    } else if (key.contains("Conditions")) {
      iconData = Icons.healing;
      color = Colors.lightBlue;
    } else if (key.contains("Limitations")) {
      iconData = Icons.warning;
      color = Colors.amberAccent;
    }

    return Icon(iconData, size: 16, color: color);
  }

  Widget _buildAchievementIcon(String label, IconData icon, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        dense: true,
        onTap: () {},
      ),
    );
  }
}
