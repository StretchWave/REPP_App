import 'dart:async';
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

  @override
  void dispose() {
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
        final fullProfileData = {
          ...widget.userData,
          'id': userId,
          'power_level': _powerLevel,
        };

        await Supabase.instance.client.from('profiles').upsert(fullProfileData);
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

    if (mounted) {
      setState(() {
        _currentReps = reps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep < 6)
            Text(
              "Time: ${_timeLeft}s",
              style: TextStyle(
                color: _timeLeft < 10 ? Colors.redAccent : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),

          if (_currentStep < 6)
            Text(
              "Reps: $_currentReps",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, color: Colors.amber, size: 80),
          const SizedBox(height: 30),
          const Text(
            "Strength Calibration",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "We will measure your fitness level with 3 quick tests:\n\n1. Push-ups (60s)\n2. Squats (60s)\n3. Sit-ups (60s)\n\nDo as many repetitions as you can with good form.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: () {
              _checkPermission().then((_) {
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
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text(
              "Start Calibration",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreak() {
    String nextEx = _currentStep == 2 ? "Squats" : "Sit-ups";
    return Center(
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
    );
  }

  Widget _buildResults() {
    return Center(
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
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
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
          child: StreamBuilder<List<Map<String, double>>>(
            stream: _bridge.poseStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty)
                return const SizedBox();

              // Process Logic
              _repCounter.processLandmarks(snapshot.data!, exercise);

              // Verify Reps
              if (_isExerciseActive) {
                // Only update if rep count increased
                if (_repCounter.count > _currentReps) {
                  // Schedule update to avoid build conflict
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onRepDetected(_repCounter.count);
                  });
                }
              }

              return CustomPaint(painter: SkeletonPainter(snapshot.data!));
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
