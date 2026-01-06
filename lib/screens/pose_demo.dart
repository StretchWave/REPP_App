import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/services/settings_service.dart';
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';
import 'package:ai_fitness_tracker/screens/workout_summary_screen.dart';
import 'package:ai_fitness_tracker/widgets/camera_view.dart';
import 'package:ai_fitness_tracker/widgets/workout_stats_panel.dart';
import 'package:ai_fitness_tracker/widgets/jogging_view.dart';
import 'package:ai_fitness_tracker/logic/pose_bridge.dart';
import 'package:ai_fitness_tracker/painters/skeleton_painter.dart';
import 'package:ai_fitness_tracker/logic/rep_counter.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_fitness_tracker/services/tts_service.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PoseDemoScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? workoutPlan;
  final bool isCalibration;

  const PoseDemoScreen({
    super.key,
    this.workoutPlan,
    this.isCalibration = false,
  });

  @override
  State<PoseDemoScreen> createState() => _PoseDemoScreenState();
}

class _PoseDemoScreenState extends State<PoseDemoScreen> {
  final PoseBridge _bridge = PoseBridge();
  final RepCounter _repCounter = RepCounter();
  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );

  // CRITICAL: GlobalKey to keep camera alive across layout changes
  final GlobalKey _cameraKey = GlobalKey();

  bool _permissionGranted = false;
  int _reps = 0;

  // Pedometer Vars
  Stream<StepCount>? _stepCountStream;
  int _steps = 0;
  int _initialSteps = -1;
  int _savedSteps = 0;
  int _targetSteps = 1000;

  // Dynamic Target Reps (Default 10 if not found)
  int _targetReps = 10;

  bool _isTransitioning = false;

  // Workout Sequence Data
  List<String> _exercises = [];
  List<Map<String, dynamic>> _plan = [];

  // Fallback default routine if no plan passed
  final List<String> _defaultExercises = [
    'Box Push-Ups',
    'Push-Ups',
    'Pike Push-Ups',
    'Chair Dips',
    'Floor Dips',
    'Bird Dog',
    'Leg Raises',
    'Sit-Ups',
    'Squats',
    'Jogging',
  ];

  int _currentExerciseIndex = 0;

  DateTime? _exerciseStartTime;

  // Calibration Results: Map<ExerciseName, RepsCount>
  final Map<String, int> _calibrationResults = {};

  // Timer for Rep-based exercises
  Timer? _timer;
  int _secondsRemaining = 0;
  int _totalTimeLimit = 0;
  double _bodyWeight = 70.0;
  bool _hasStartedTimer = false;

  late ValueNotifier<int> _repNotifier;
  late ValueNotifier<String> _feedbackNotifier;
  late ValueNotifier<double> _accuracyNotifier;
  late ValueNotifier<bool> _isProperFormNotifier;
  late ValueNotifier<List<Map<String, double>>> _skeletonNotifier;
  StreamSubscription? _poseSubscription;

  @override
  void initState() {
    super.initState();
    _repNotifier = ValueNotifier<int>(0);
    _feedbackNotifier = ValueNotifier<String>("");
    _accuracyNotifier = ValueNotifier<double>(100.0);
    _isProperFormNotifier = ValueNotifier<bool>(true);
    _skeletonNotifier = ValueNotifier<List<Map<String, double>>>([]);

    TtsService(); // Warm up TTS engine
    _checkPermission();
    _loadUserProfile();
    if (!widget.isCalibration)
      _loadInitialProgress(); // Skip loading progress for calibration
    _startPoseStream();

    // Initialize Workout Data
    if (widget.workoutPlan != null && widget.workoutPlan!.isNotEmpty) {
      _plan = widget.workoutPlan!;
      _exercises = _plan.map((e) => e['title'] as String).toList();
      _updateCurrentTargets();
    } else {
      _exercises = List.from(_defaultExercises);
      _updateCurrentTargets();
    }

    // Default orientation until loaded
    _updateOrientation();
    _exerciseStartTime = DateTime.now();

    if (!widget.isCalibration) {
      _loadInitialProgress();
    }
  }

  void _startPoseStream() {
    _poseSubscription?.cancel();
    _poseSubscription = _bridge.poseStream.listen((landmarks) {
      if (!mounted) return;

      // Stop processing if we are transitioning (e.g. Rest Timer, Saving)
      if (_isTransitioning) return;

      // 1. Normalize Landmarks (Rotate 90 CW to fix Sensor vs UI mismatch)
      // Input: (x,y) relative to Sensor (Landscape native).
      // Output: (x',y') relative to Portrait UI.
      // 90 Deg CW: x' = 1 - y, y' = x
      final List<Map<String, double>> normalized = landmarks.map((l) {
        return {
          'x': 1.0 - l['y']!,
          'y': l['x']!,
          'z': l['z']!,
          'visibility': l['visibility']!,
        };
      }).toList();

      // 2. Update Skeleton (Visuals)
      _skeletonNotifier.value = normalized;

      // 3. Process Landmarks (Logic)
      final currentExercise = _exercises[_currentExerciseIndex];
      if (_plan.isNotEmpty || _defaultExercises.contains(currentExercise)) {
        _repCounter.processLandmarks(normalized, currentExercise);
        _handleTtsAndLogic();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('weight')
            .eq('id', userId)
            .single();
        if (mounted && data['weight'] != null) {
          setState(() {
            _bodyWeight = (data['weight'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading weight: $e");
    }
  }

  void _updateCurrentTargets() {
    _timer?.cancel();
    _hasStartedTimer = false;

    if (widget.isCalibration) {
      // Calibration Mode: 60s Timer, No Rep Limit
      _targetReps = 9999;
      _totalTimeLimit = 60;
      _secondsRemaining = 60;
      return;
    }

    if (_plan.isNotEmpty && _currentExerciseIndex < _plan.length) {
      final item = _plan[_currentExerciseIndex];
      final val = item['targetValue'] as num;

      if (_exercises[_currentExerciseIndex] == 'Jogging' ||
          item['unit'] == 'steps') {
        // Steps based
        // If already steps (from Workout_Screen logic), use directly
        if (item['unit'] == 'steps') {
          _targetSteps = val.toInt();
        } else {
          // Fallback conversion
          _targetSteps = (val * 1.5).toInt();
        }
      } else {
        // Reps based
        _targetReps = val.toInt();
        // Timer Logic: 60s per 20 reps
        // e.g. 10 reps -> 1 * 60 = 60s
        // 30 reps -> 2 * 60 = 120s
        int multiplier = (_targetReps / 20).ceil();
        if (multiplier < 1) multiplier = 1;

        _totalTimeLimit = multiplier * 60;
        _secondsRemaining = _totalTimeLimit;
        // Timer starts after first rep
      }
    } else {
      // Defaults
      _targetReps = 10;
      _targetSteps = 1000;
      // Default timer for 10 reps -> 60s
      _totalTimeLimit = 60;
      _secondsRemaining = 60;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            // Timer expired
            timer.cancel();
            if (!_isTransitioning) {
              if (widget.isCalibration) {
                // In Calibration, Time Up = Success (Max Reps Done)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Time's Up! Test Complete."),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
                _nextExercise(forceFailure: false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Time's Up! Exercise Incomplete."),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
                _nextExercise(forceFailure: true);
              }
            }
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadInitialProgress() async {
    final progress = await WorkoutService().getTodayProgress();

    int firstIncomplete = -1;
    for (int i = 0; i < _exercises.length; i++) {
      // ... (existing logic)
      final name = _exercises[i];
      // Note: Progress keys in map are 'lookupName' (e.g. 'box_pushups').
      // But _exercises has Titles (e.g. 'Box Push-Ups').
      // WorkoutService.getTodayProgress returns map keyed by 'lookupName'.
      // Wait, WorkoutService keys are exercise IDs or names?
      // In WorkoutScreen, we saw:
      // 'lookupName': item.exercise.name (which is title?) -> check LevelProgressionService.
      // In WorkoutLogService:
      // 'box_pushups' vs 'Box Push-Ups'.
      // Verification needed: What are the keys in `progress` map?

      // Let's assume mismatch might exist.
      // If _plan exists, we can use `_plan[i]['lookupName']` if available.
      // Workout_Screen sets `lookupName`.

      String key = name;
      if (_plan.isNotEmpty && i < _plan.length) {
        key = _plan[i]['lookupName'] ?? name;
      }

      if (progress[key]?['isCompleted'] != true) {
        firstIncomplete = i;
        break;
      }
    }

    // ...
    // Update state
    // Update state

    if (mounted) {
      if (firstIncomplete == -1) {
        // All completed!
        // We delay slightly to let the build finish first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSummaryScreen();
        });
      } else if (firstIncomplete > 0) {
        // Skip ahead
        setState(() {
          _currentExerciseIndex = firstIncomplete;
          _exerciseStartTime = DateTime.now();
        });
        _updateCurrentTargets();
        _updateOrientation();
        if (_exercises[_currentExerciseIndex] == 'Jogging') {
          _initPedometer(); // Will call _restoreJoggingData internally
        }
      }
    }
  }

  void _updateOrientation() {
    if (_exercises[_currentExerciseIndex] == 'Jogging') {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    // Reset to Portrait only when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Log partial progress if exiting early (and not just moving to summary)
    // Note: This is a best-effort save. Async in dispose is tricky.
    // Ideally user hits a "Finish" button, but for "Back", we can try fire-and-forget.
    if (!_isTransitioning &&
        _currentExerciseIndex < _exercises.length &&
        (_reps > 0 ||
            (_steps > 0 && _exercises[_currentExerciseIndex] == 'Jogging'))) {
      final duration = DateTime.now().difference(_exerciseStartTime!).inSeconds;
      final name = _exercises[_currentExerciseIndex];
      final currentReps = _reps;
      final currentSteps = _steps;

      // Fire and forget
      double calories = 0;
      if (name == 'Jogging') {
        // Formula: (Weight * 0.001) - 0.01 per step
        // default _bodyWeight is 70 if not loaded
        double rate = (_bodyWeight * 0.001) - 0.01;
        if (rate < 0.03) rate = 0.03; // Safety floor
        calories = currentSteps * rate;
      }

      WorkoutLogService().logWorkout(
        exerciseName: name,
        repsCompleted: currentReps,
        durationSeconds: duration,
        isCompleted: false, // Partial
        caloriesOverride: name == 'Jogging' ? calories : null,
      );
    }

    TtsService().stop(); // Stop speaking on exit
    _timer?.cancel();
    super.dispose();
  }

  void _initPedometer() {
    _initialSteps = -1; // Reset baseline
    _steps = 0;

    // Restore saved steps if any
    _restoreJoggingData();

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream!.listen(_onStepCount).onError(_onStepCountError);
  }

  Future<void> _restoreJoggingData() async {
    try {
      final progress = await WorkoutService().getTodayProgress();
      if (progress.containsKey('Jogging')) {
        final data = progress['Jogging'];
        if (data != null && data['progressValue'] is int) {
          final saved = data['progressValue'] as int;
          if (mounted) {
            setState(() {
              _savedSteps = saved;
              // If we have no steps from sensor yet, show saved
              if (_initialSteps == -1) {
                _steps = saved;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error restoring jogging data: $e");
    }
  }

  void _onStepCount(StepCount event) {
    if (!mounted) return;
    if (_exercises[_currentExerciseIndex] != 'Jogging') return;

    if (_initialSteps == -1) {
      _initialSteps = event.steps;
    }

    setState(() {
      _steps = (event.steps - _initialSteps) + _savedSteps;
      if (_steps < 0) _steps = 0; // Integrity check

      if (_steps >= _targetSteps && !_isTransitioning) {
        _handleGoalMet();
      }
    });

    // Save progress safely outside setState
    if (!_isTransitioning) {
      WorkoutService()
          .saveExerciseProgress(
            exerciseName: 'Jogging',
            isCompleted: _steps >= _targetSteps,
            durationSeconds: DateTime.now()
                .difference(_exerciseStartTime!)
                .inSeconds,
            progressValue: _steps,
          )
          .catchError((e) => debugPrint("Save Error: $e"));
    }
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer Error: $error");
    setState(() {
      _steps = -1; // Indicate error in UI
    });
  }

  Future<void> _checkPermission() async {
    try {
      // Request Camera AND Activity Recognition (for Pedometer)
      final statuses = await [
        Permission.camera,
        Permission.activityRecognition,
      ].request();

      setState(() {
        _permissionGranted = statuses[Permission.camera]!.isGranted;
      });

      if (statuses[Permission.activityRecognition]!.isDenied) {
        debugPrint("Activity Recognition Denied");
        // We could show a snackbar here
      }
    } catch (e) {
      setState(() {
        _permissionGranted = true;
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
      // If model needs reload on camera switch, we might need a delay or signal
      // But typically switch is internal.
    } on PlatformException {
      // Handle camera switch error silently
    }
  }

  void _resetCounter() {
    _timer?.cancel();
    _hasStartedTimer = false;
    setState(() {
      _reps = 0;
      _repCounter.reset();
      _secondsRemaining = _totalTimeLimit;
    });
  }

  void _skipExercise() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Skip Exercise?"),
        content: const Text(
          "Skipping will mark this exercise as a failure. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        contentTextStyle: const TextStyle(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextExercise(forceFailure: true);
            },
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _nextExercise({bool forceFailure = false}) async {
    if (_isTransitioning) return; // Prevent double save

    // Check validation if manually triggered (not auto-advanced)
    // Skipped if we are forcing failure (Skip/Timeout)
    if (!forceFailure) {
      bool isGoalMet = false;
      if (_exercises[_currentExerciseIndex] == 'Jogging') {
        isGoalMet = _steps >= _targetSteps;
      } else {
        isGoalMet = _reps >= _targetReps;
      }

      // Allow if Calibration (Timer end = Success)
      if (widget.isCalibration) {
        isGoalMet = true;
      }

      if (!isGoalMet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Goal not met yet! Keep going!"),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    setState(() {
      _isTransitioning = true;
    });

    // 1. Save current exercise data
    final duration = DateTime.now().difference(_exerciseStartTime!).inSeconds;

    // Collect feedback
    String? feedbackMsg;
    if (forceFailure) {
      feedbackMsg = "Incomplete (Skipped/Timed Out)";
    } else if (_repCounter.formIssues.isNotEmpty) {
      feedbackMsg = "Fix: ${_repCounter.formIssues.join(', ')}";
    }

    try {
      await WorkoutService().saveExerciseProgress(
        exerciseName: _exercises[_currentExerciseIndex],
        isCompleted: true, // Mark done for today
        isSkipped: forceFailure, // Flag as skipped/failed
        durationSeconds: duration,
        feedback: feedbackMsg,
      );

      // LOG CALORIES
      double calories = 0;
      if (_exercises[_currentExerciseIndex] == 'Jogging') {
        // Formula: (Weight * 0.001) - 0.01 per step
        double rate = (_bodyWeight * 0.001) - 0.01;
        if (rate < 0.03) rate = 0.03; // Safety floor
        calories = _steps * rate;
      }

      await WorkoutLogService().logWorkout(
        exerciseName: _exercises[_currentExerciseIndex],
        repsCompleted: _reps,
        durationSeconds: duration,
        isCompleted: !forceFailure,
        caloriesOverride: _exercises[_currentExerciseIndex] == 'Jogging'
            ? calories
            : null,
      );
    } catch (e) {
      debugPrint("Error saving workout data: $e");
      // Continue flow even if save fails
    }

    // Store Calibration Result
    if (widget.isCalibration) {
      _calibrationResults[_exercises[_currentExerciseIndex]] = _reps;
    }

    // NOTE: We do NOT reset _isTransitioning here yet.
    // We wait until AFTER the rest timer or when the next exercise starts.

    if (_currentExerciseIndex < _exercises.length - 1) {
      // REST TIMER LOGIC
      final restSeconds = SettingsService().restTimerSeconds;
      if (restSeconds > 0 && mounted) {
        await _showRestTimer(restSeconds);
      }

      if (mounted) {
        setState(() {
          _currentExerciseIndex++;
          _reps = 0;
          _repCounter.reset();
          _exerciseStartTime = DateTime.now();
          _hasStartedTimer = false;
          _timer?.cancel();
          _secondsRemaining = _totalTimeLimit;
          // NOW we are ready for the next one
          _isTransitioning = false;
        });

        _updateCurrentTargets();
        _updateOrientation();

        if (_exercises[_currentExerciseIndex] == 'Jogging') {
          _initPedometer();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }

      if (widget.isCalibration) {
        Navigator.pop(context, _calibrationResults);
      } else {
        _showSummaryScreen();
      }
    }
  }

  Future<void> _showRestTimer(int seconds) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C313A),
          title: const Text(
            "Rest & Recover",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Colors.blueAccent, size: 40),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: seconds.toDouble(), end: 0),
                duration: Duration(seconds: seconds),
                onEnd: () {
                  if (context.mounted && Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                },
                builder: (context, value, child) {
                  return Text(
                    "${value.toInt()}s",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (_currentExerciseIndex + 1 < _exercises.length)
                Text(
                  "Next: ${_exercises[_currentExerciseIndex + 1]}",
                  style: TextStyle(color: Colors.grey[400]),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Skip Rest",
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleGoalMet() {
    if (_isTransitioning) return;
    _isTransitioning = true;

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Goal Reached! Moving to next exercise...",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Delay slightly for UX then move
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTransitioning = false; // Reset to allow _nextExercise to run
        });
        _nextExercise();
      }
    });
  }

  Future<void> _showSummaryScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(
          exercises: _exercises,
          onFinish: () {
            Navigator.of(context).pop(); // Close summary
            Navigator.of(context).pop(); // Close demo screen
          },
        ),
      ),
    );

    // Handle Retry
    if (result != null && result is String) {
      final index = _exercises.indexOf(result);
      if (index != -1) {
        setState(() {
          _currentExerciseIndex = index;
          _reps = 0;
          _repCounter.reset();
          _exerciseStartTime = DateTime.now();
          // Reset orientation if needed
          _updateOrientation();
          if (_exercises[index] == 'Jogging') _initPedometer();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentExercise = _exercises[_currentExerciseIndex];
    int targetReps = _targetReps;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              title: Text(currentExercise),
              centerTitle: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: _switchCamera,
                  tooltip: "Switch Camera",
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetCounter,
                  tooltip: "Reset Counter",
                ),
              ],
            ),
      body: isLandscape
          ? _buildLandscapeLayout(currentExercise, targetReps)
          : _buildPortraitLayout(currentExercise, targetReps),
    );
  }

  Widget _buildPortraitLayout(String currentExercise, int targetReps) {
    return Stack(
      children: [
        Column(
          children: [
            if (_permissionGranted)
              AspectRatio(
                aspectRatio: 3 / 4,
                child: _buildCameraArea(currentExercise),
              )
            else
              Expanded(child: _buildPermissionRequest()),

            ValueListenableBuilder<int>(
              valueListenable: _repNotifier,
              builder: (context, reps, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _accuracyNotifier,
                  builder: (context, accuracy, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isProperFormNotifier,
                      builder: (context, isProperForm, _) {
                        return WorkoutStatsPanel(
                          exerciseName: currentExercise,
                          reps: reps,
                          targetReps: targetReps,
                          accuracy: accuracy,
                          isProperForm: isProperForm,
                          secondsRemaining: _secondsRemaining,
                          isPortrait: true,
                          onSkip: _skipExercise,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),

        // Floating Feedback Pill (Overlay on Camera)
        ValueListenableBuilder<String>(
          valueListenable: _feedbackNotifier,
          builder: (context, feedback, _) {
            if (feedback.isEmpty) return const SizedBox.shrink();
            return Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: feedback.contains("Fix") || feedback == "GO LOWER"
                        ? Colors.redAccent.withOpacity(0.8)
                        : Colors.blueAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    feedback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(String currentExercise, int targetReps) {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: _permissionGranted
                  ? _buildCameraArea(currentExercise)
                  : _buildPermissionRequest(),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _repNotifier,
              builder: (context, reps, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _accuracyNotifier,
                  builder: (context, accuracy, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isProperFormNotifier,
                      builder: (context, isProperForm, _) {
                        return WorkoutStatsPanel(
                          exerciseName: currentExercise,
                          reps: reps,
                          targetReps: targetReps,
                          accuracy: accuracy,
                          isProperForm: isProperForm,
                          secondsRemaining: _secondsRemaining,
                          isPortrait: false,
                          onSwitchCamera: _switchCamera,
                          onReset: _resetCounter,
                          onSkip: _skipExercise,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),

        // Feedback Overlay
        ValueListenableBuilder<String>(
          valueListenable: _feedbackNotifier,
          builder: (context, feedback, _) {
            if (feedback.isEmpty) return const SizedBox.shrink();
            return Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: feedback.contains("Fix")
                      ? Colors.redAccent.withOpacity(0.8)
                      : Colors.blueAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCameraArea(String currentExercise) {
    if (currentExercise == 'Jogging') {
      return JoggingView(
        steps: _steps == -1 ? 0 : _steps,
        targetSteps: _targetSteps,
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: PoseCameraPreview(key: _cameraKey)),
        Positioned.fill(
          child: NativeDeviceOrientationReader(
            builder: (context) {
              final orientation = NativeDeviceOrientationReader.orientation(
                context,
              );
              int turns = 0; // Landmarks are now pre-rotated in stream
              if (orientation == NativeDeviceOrientation.landscapeLeft) {
                // Adjust if needed for Landscape (logic might need updates too)
                // For now, keep 0 as we primarily support Portrait
                turns = 0;
              } else if (orientation ==
                  NativeDeviceOrientation.landscapeRight) {
                turns = 0;
              }

              return ValueListenableBuilder<List<Map<String, double>>>(
                valueListenable: _skeletonNotifier,
                builder: (context, landmarks, _) {
                  if (landmarks.isEmpty) return const SizedBox();

                  return RotatedBox(
                    quarterTurns: turns,
                    child: CustomPaint(
                      painter: SettingsService().showSkeleton
                          ? SkeletonPainter(landmarks)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),

        if (MediaQuery.of(context).orientation == Orientation.landscape)
          Positioned(
            top: 10,
            left: 10,
            child: FloatingActionButton.small(
              heroTag: "back_btn",
              backgroundColor: Colors.black54,
              child: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

        // Refresh AI Button
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: "refresh_ai_btn",
            backgroundColor: Colors.black54,
            child: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Refreshing AI Model...")),
              );
              _startPoseStream(); // Re-subscribe to stream
            },
          ),
        ),
      ],
    );
  }

  // Extracted TTS and State updating logic to keep build clean
  void _handleTtsAndLogic() {
    // 1. Feedback Update
    if (_feedbackNotifier.value != _repCounter.feedback) {
      _feedbackNotifier.value = _repCounter.feedback;

      if (_feedbackNotifier.value.isNotEmpty) {
        final msg = _feedbackNotifier.value;
        bool isPostureFix = ![
          "UP",
          "DOWN",
          "GO LOWER",
          "HOLD",
          "STAND",
          "LIFT",
          "LOWER",
          "EXTEND",
          "KEEP GOING",
        ].contains(msg);

        if (isPostureFix) {
          bool isWarning = msg.contains("Unclear");
          TtsService().speakFeedback(
            msg,
            key: msg,
            debounceDuration: isWarning
                ? const Duration(seconds: 10)
                : const Duration(seconds: 4),
          );
        }
      }
    }

    // 2. Accuracy & Form Update
    if (_accuracyNotifier.value != _repCounter.accuracy) {
      _accuracyNotifier.value = _repCounter.accuracy;
    }
    if (_isProperFormNotifier.value != _repCounter.isProperForm) {
      _isProperFormNotifier.value = _repCounter.isProperForm;
    }

    // 3. Rep Count Update (State relevant for transition)
    if (_repNotifier.value != _repCounter.count) {
      _repNotifier.value = _repCounter.count;

      // We still need to update _reps for logic that depends on it (like _handleGoalMet)
      // but we do it without a full setState if possible.
      // Actually, many things use _reps. Setting it via setState might still be needed
      // for the transition logic, BUT we can reduce frequency.

      if (_repNotifier.value > _reps) {
        TtsService().speakCount(_repNotifier.value);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _reps = _repNotifier.value;
              if (!_hasStartedTimer) {
                _hasStartedTimer = true;
                _startTimer();
              }
              if (_reps >= _targetReps && !_isTransitioning) {
                _handleGoalMet();
              }
            });
          }
        });
      }
    }
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: ElevatedButton(
        onPressed: _checkPermission,
        child: const Text("Refrest Permission"),
      ),
    );
  }
}
