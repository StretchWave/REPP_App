import 'dart:async';
import 'package:ai_fitness_tracker/services/settings_service.dart';
import 'package:ai_fitness_tracker/logic/difficulty_scaler.dart';
import 'package:ai_fitness_tracker/logic/pose_bridge.dart';
import 'package:ai_fitness_tracker/logic/rep_counter.dart';
import 'package:ai_fitness_tracker/painters/skeleton_painter.dart';
import 'package:ai_fitness_tracker/screens/home_screen.dart';
import 'package:ai_fitness_tracker/widgets/camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalibrationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CalibrationScreen({super.key, required this.userData});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // Logic
  final PoseBridge _bridge = PoseBridge();
  final RepCounter _repCounter = RepCounter();
  final GlobalKey _cameraKey = GlobalKey();
  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );

  // State
  int _currentStep =
      0; // 0:Intro, 1:Pushups, 2:Break, 3:Squats, 4:Break, 5:Situps, 6:Results
  bool _isExerciseActive = false;
  int _timeLeft = 60;
  Timer? _timer;
  int _currentReps = 0;
  bool _hasStarted = false; // Timer starts on first rep
  bool _permissionGranted = false;

  // Results
  int _pushupsCount = 0;
  int _squatsCount = 0;
  int _situpsCount = 0;
  int _powerLevel = 0;
  bool _isSaving = false;

  late ValueNotifier<int> _repNotifier;
  late ValueNotifier<List<Map<String, double>>> _skeletonNotifier;
  StreamSubscription? _poseSubscription;

  @override
  void initState() {
    super.initState();
    _repNotifier = ValueNotifier<int>(0);
    _skeletonNotifier = ValueNotifier<List<Map<String, double>>>([]);
    _checkPermission();
    _startPoseStream();
  }

  void _startPoseStream() {
    _poseSubscription?.cancel();
    _poseSubscription = _bridge.poseStream.listen((landmarks) {
      if (!mounted) return;

      // 1. Update Skeleton
      _skeletonNotifier.value = landmarks;

      // 2. Process Reps (only if exercise active)
      if (_isExerciseActive) {
        String exercise = "";
        if (_currentStep == 1) exercise = "Pushups";
        if (_currentStep == 3) exercise = "Squats";
        if (_currentStep == 5) exercise = "Situps";

        if (exercise.isNotEmpty) {
          _repCounter.processLandmarks(landmarks, exercise);

          if (_repCounter.count > _repNotifier.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _repNotifier.value = _repCounter.count;
                _onRepDetected(_repCounter.count);
              }
            });
          }
        }
      }
    });
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _permissionGranted = status.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _repNotifier.dispose();
    _skeletonNotifier.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _finishExercise();
        }
      });
    });
  }

  void _finishExercise() {
    _timer?.cancel();
    _isExerciseActive = false;
    _hasStarted = false;

    // Save Reps
    if (_currentStep == 1) _pushupsCount = _currentReps;
    if (_currentStep == 3) _squatsCount = _currentReps;
    if (_currentStep == 5) _situpsCount = _currentReps;

    // Reset for next
    _repCounter.reset();
    _currentReps = 0;
    _repNotifier.value = 0; // Reset rep notifier
    _timeLeft = 60; // Reset time for next, or break time

    // Move to next step
    setState(() {
      _currentStep++;
      if (_currentStep == 2 || _currentStep == 4) {
        // Break Steps
        _timeLeft = 10; // 10s Break
        _startBreakTimer();
      } else if (_currentStep > 5) {
        // Results
        _calculateResults();
      }
    });
  }

  void _startBreakTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          // Auto advance from break
          _currentStep++;
          _timeLeft = 60;
        }
      });
    });
  }

  Future<void> _calculateResults() async {
    _powerLevel = DifficultyScaler.calculatePowerLevel(
      pushups: _pushupsCount,
      squats: _squatsCount,
      situps: _situpsCount,
    );

    // Save to Supabase (Full Data + Power Level)
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Just update the power level, profile already exists
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

  void _onRepDetected(int reps) {
    if (!_isExerciseActive) return; // Ignore if in break or intro

    // Start timer on first rep
    if (!_hasStarted && reps > 0) {
      _hasStarted = true;
      _startTimer();
    }

    // _currentReps is still used for saving the final count, but _repNotifier drives the UI
    _currentReps = reps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF343A40),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = "Calibration";
    if (_currentStep == 1) title = "Push-ups Test";
    if (_currentStep == 3) title = "Squats Test";
    if (_currentStep == 5) title = "Sit-ups Test";
    if (_currentStep == 6) title = "Results";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Time: ${_timeLeft}s',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _repNotifier,
                    builder: (context, reps, child) {
                      return Text(
                        'Reps: $reps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: _timeLeft / 60.0, // Approximate progress
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_currentStep == 0) return _buildIntro();
    if (_currentStep == 2 || _currentStep == 4) return _buildBreak();
    if (_currentStep == 6) return _buildResults();

    // Check Permissions
    if (!_permissionGranted) {
      return Center(
        child: ElevatedButton(
          onPressed: _checkPermission,
          child: const Text("Grant Camera Permission"),
        ),
      );
    }

    // Camera View for Exercises (1, 3, 5)
    String exerciseName = "";
    if (_currentStep == 1) exerciseName = "Push-Ups";
    if (_currentStep == 3) exerciseName = "Squats";
    if (_currentStep == 5) exerciseName = "Sit-Ups";

    // Enforce Aspect Ratio to prevent distortion (Crucial for accuracy)
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: _buildCameraView(exerciseName),
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
              // Icon/Emoji Placeholder
              const Text('🏋️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 32),

              // Title
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

              // Subtitle
              Text(
                'We will measure your fitness level with 3 quick tests:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // List
              const _TestItem(text: '1. Push-ups (60s)'),
              const SizedBox(height: 16),
              const _TestItem(text: '2. Squats (60s)'),
              const SizedBox(height: 16),
              const _TestItem(text: '3. Sit-ups (60s)'),

              const SizedBox(height: 48),

              // Instruction
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

          // Buttons
          ElevatedButton(
            onPressed: () {
              _checkPermission().then((_) {
                if (!context.mounted) return;
                if (_permissionGranted) {
                  setState(() {
                    _currentStep = 1; // Start Pushups
                    _isExerciseActive = true;
                    _timeLeft = 60;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Camera permission required."),
                    ),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(
                0.2,
              ), // Light gray/translucent
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

  Widget _buildBreak() {
    String nextEx = _currentStep == 2 ? "Squats" : "Sit-ups";
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Take a Breath",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              "$_timeLeft",
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Next: $nextEx",
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _currentStep++;
                  _timeLeft = 60;
                  _isExerciseActive = true;
                });
              },
              child: const Text("Skip Break"),
            ),
          ],
        ),
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

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
    } on PlatformException {
      // Handle error silently
    }
  }

  Widget _buildCameraView(String exercise) {
    return Stack(
      children: [
        // Camera Layer
        Positioned.fill(child: PoseCameraPreview(key: _cameraKey)),

        // Skeleton Layer
        Positioned.fill(
          child: ValueListenableBuilder<List<Map<String, double>>>(
            valueListenable: _skeletonNotifier,
            builder: (context, landmarks, _) {
              if (landmarks.isEmpty) return const SizedBox.shrink();

              return CustomPaint(
                painter: SettingsService().showSkeleton
                    ? SkeletonPainter(landmarks)
                    : null,
              );
            },
          ),
        ),

        // Controls Overlay (Switch Camera)
        Positioned(
          top: 10,
          right: 10,
          child: SafeArea(
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                onPressed: _switchCamera,
              ),
            ),
          ),
        ),

        // Start Instruction Overlay (if timer hasn't started)
        if (!_hasStarted)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Do 1 rep to start timer!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
