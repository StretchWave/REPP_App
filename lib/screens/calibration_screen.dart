import 'package:ai_fitness_tracker/logic/difficulty_scaler.dart';
import 'package:ai_fitness_tracker/screens/home_screen.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalibrationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CalibrationScreen({super.key, required this.userData});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // Results
  int _pushupsCount = 0;
  int _squatsCount = 0;
  int _situpsCount = 0;
  int _powerLevel = 0;
  bool _isSaving = false;

  // 0:Intro, 1:Results
  int _currentStep = 0;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _permissionGranted = status.isGranted;
      });
    }
  }

  void _startCalibration() async {
    if (!_permissionGranted) {
      await _checkPermission();
      if (!_permissionGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Camera permission required.")),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    // Define the specific calibration workout plan
    final calibrationPlan = [
      {
        'title': 'Push-Ups',
        'targetValue': 9999, // Infinite for max test
        'unit': 'reps',
        'lookupName': 'pushups',
      },
      {
        'title': 'Squats',
        'targetValue': 9999,
        'unit': 'reps',
        'lookupName': 'squats',
      },
      {
        'title': 'Sit-Ups',
        'targetValue': 9999,
        'unit': 'reps',
        'lookupName': 'situps',
      },
    ];

    // Navigate to PoseDemoScreen in Calibration Mode
    final results = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PoseDemoScreen(workoutPlan: calibrationPlan, isCalibration: true),
      ),
    );

    // Handle Results
    if (results != null && results is Map<String, int>) {
      setState(() {
        _pushupsCount = results['Push-Ups'] ?? 0;
        _squatsCount = results['Squats'] ?? 0;
        _situpsCount = results['Sit-Ups'] ?? 0;
        _currentStep = 1; // Show Results
        _calculateResults();
      });
    }
  }

  Future<void> _calculateResults() async {
    _powerLevel = DifficultyScaler.calculatePowerLevel(
      pushups: _pushupsCount,
      squats: _squatsCount,
      situps: _situpsCount,
    );

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'power_level': _powerLevel})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint("Error saving power level: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving results: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF343A40),
      body: SafeArea(
        child: _currentStep == 0 ? _buildIntro() : _buildResults(),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Content
          Column(
            children: [
              const Text('🏋️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 32),
              const Text(
                'Strength Calibration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We will measure your fitness level with 3 quick tests:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const _TestItem(text: '1. Push-ups (60s)'),
              const SizedBox(height: 16),
              const _TestItem(text: '2. Squats (60s)'),
              const SizedBox(height: 16),
              const _TestItem(text: '3. Sit-ups (60s)'),
              const SizedBox(height: 48),
              Text(
                'Do as many repetitions as you can with good form.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _startCalibration,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Start Calibration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Skip for Now',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Calibration Complete!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              _buildStatRow("Push-ups", _pushupsCount),
              const SizedBox(height: 10),
              _buildStatRow("Squats", _squatsCount),
              const SizedBox(height: 10),
              _buildStatRow("Sit-ups", _situpsCount),
              const SizedBox(height: 40),
              const Text(
                "Your Power Level",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                "$_powerLevel",
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),
              if (_isSaving)
                const CircularProgressIndicator()
              else
                ElevatedButton(
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
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Go Home",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        Text(
          "$count reps",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TestItem extends StatelessWidget {
  final String text;

  const _TestItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      textAlign: TextAlign.center,
    );
  }
}
