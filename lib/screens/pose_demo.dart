import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';
import 'package:ai_fitness_tracker/services/workout_log_service.dart';
import 'package:ai_fitness_tracker/screens/workout_summary_screen.dart';
import 'package:ai_fitness_tracker/widgets/camera_view.dart';
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

  const PoseDemoScreen({super.key, this.workoutPlan});

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

  // Timer for Rep-based exercises
  Timer? _timer;
  int _secondsRemaining = 0;
  int _totalTimeLimit = 0;
  double _bodyWeight = 70.0;
  bool _hasStartedTimer = false;

  @override
  void initState() {
    super.initState();
    TtsService(); // Warm up TTS engine
    _checkPermission();
    _loadUserProfile();

    // Initialize Workout Data
    if (widget.workoutPlan != null && widget.workoutPlan!.isNotEmpty) {
      _plan = widget.workoutPlan!;
      _exercises = _plan.map((e) => e['title'] as String).toList();
    } else {
      _exercises = List.from(_defaultExercises);
    }

    _updateCurrentTargets();

    // Default orientation until loaded
    _updateOrientation();
    _exerciseStartTime = DateTime.now();

    // Check for already completed exercises
    _loadInitialProgress();
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

    if (mounted) {
      setState(() {
        _isTransitioning = false;
      });
    }

    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _reps = 0;
        _repCounter.reset();
        _exerciseStartTime = DateTime.now(); // Reset timer for next
      });

      _updateCurrentTargets(); // Update Reps/Steps target for new exercise
      _updateOrientation();

      if (_exercises[_currentExerciseIndex] == 'Jogging') {
        _initPedometer();
      }
    } else {
      _showSummaryScreen();
    }
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
                // Skip to Summary
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                  onPressed: () {
                    // Just skip entire workout to summary
                    _showSummaryScreen();
                  },
                  tooltip: "Finish & View Summary",
                ),
              ],
            ),
      body: isLandscape
          ? _buildLandscapeLayout(currentExercise, targetReps)
          : _buildPortraitLayout(currentExercise, targetReps),
    );
  }

  Widget _buildPortraitLayout(String currentExercise, int targetReps) {
    return Column(
      children: [
        if (_permissionGranted)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _buildCameraArea(currentExercise),
          )
        else
          Expanded(child: _buildPermissionRequest()),

        Expanded(child: _buildStatsPanel(currentExercise, targetReps)),
      ],
    );
  }

  Widget _buildLandscapeLayout(String currentExercise, int targetReps) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _permissionGranted
              ? _buildCameraArea(currentExercise)
              : _buildPermissionRequest(),
        ),

        Container(
          width: 150,
          color: Colors.black,
          child: _buildStatsPanel(
            currentExercise,
            targetReps,
            isLandscape: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraArea(String currentExercise) {
    if (currentExercise == 'Jogging') {
      return _buildJoggingUI();
    }

    return Stack(
      children: [
        // 1. Native Camera View with GlobalKey to persist across rotation
        Positioned.fill(child: PoseCameraPreview(key: _cameraKey)),

        // 2. Overlay Data & Skeleton
        Positioned.fill(
          child: NativeDeviceOrientationReader(
            builder: (context) {
              final orientation = NativeDeviceOrientationReader.orientation(
                context,
              );
              int turns = 0;
              if (orientation == NativeDeviceOrientation.landscapeLeft) {
                turns = 3; // 270 degrees
              } else if (orientation ==
                  NativeDeviceOrientation.landscapeRight) {
                turns = 1; // 90 degrees (Flip of Left)
              }

              return StreamBuilder<List<Map<String, double>>>(
                stream: _bridge.poseStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.greenAccent,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox();
                  }

                  if (currentExercise == 'Push-Ups' ||
                      currentExercise == 'Box Push-Ups' ||
                      currentExercise == 'Pike Push-Ups' ||
                      currentExercise == 'Chair Dips' ||
                      currentExercise == 'Floor Dips' ||
                      currentExercise == 'Bird Dog' ||
                      currentExercise == 'Leg Raises' ||
                      currentExercise == 'Squats' ||
                      currentExercise == 'Sit-Ups') {
                    _repCounter.processLandmarks(
                      snapshot.data!,
                      currentExercise,
                    );

                    // TTS FEEDBACK INTEGRATION
                    if (_repCounter.feedback.isNotEmpty) {
                      // Only speak meaningful feedback (ignore "UP", "DOWN" unless we want them)
                      // "UP"/"DOWN"/ "GO LOWER" might be spammy or helpful?
                      // User requested specific posture fixes.
                      // Let's filter:
                      final msg = _repCounter.feedback;
                      bool isPostureFix =
                          msg != "UP" &&
                          msg != "DOWN" &&
                          msg != "GO LOWER" &&
                          msg != "HOLD" &&
                          msg != "STAND" &&
                          msg != "LIFT" &&
                          msg != "LOWER" &&
                          msg != "EXTEND" &&
                          msg != "KEEP GOING";

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

                  if (_reps != _repCounter.count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        // Speak if incremented
                        if (_repCounter.count > _reps) {
                          TtsService().speakCount(_repCounter.count);
                        }

                        setState(() => _reps = _repCounter.count);

                        // Start Timer on First Rep
                        if (_reps > 0 && !_hasStartedTimer) {
                          _hasStartedTimer = true;
                          _startTimer();
                        }

                        if (_reps >= _targetReps && !_isTransitioning) {
                          _handleGoalMet();
                        }
                      }
                    });
                  }

                  return RotatedBox(
                    quarterTurns: turns,
                    child: CustomPaint(
                      painter: SkeletonPainter(snapshot.data!),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Back Button Overlay for Landscape
        if (MediaQuery.of(context).orientation == Orientation.landscape)
          Positioned(
            top: 20,
            left: 20,
            child: FloatingActionButton.small(
              heroTag: "back_btn", // Unique tag
              backgroundColor: Colors.black54,
              child: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );
  }

  Widget _buildJoggingUI() {
    if (_steps == -1) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            "Step Sensor Not Available\n(Try walking to wake it up)",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 18),
          ),
        ),
      );
    }

    double progress = _steps / _targetSteps;
    if (progress > 1.0) progress = 1.0;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_run,
              size: 80,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 30),
            const Text(
              "Jog in Place",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Goal: $_targetSteps Steps",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                color: Colors.greenAccent,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "$_steps / $_targetSteps",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: ElevatedButton(
        onPressed: _checkPermission,
        child: const Text("Refrest Permission"),
      ),
    );
  }

  Widget _buildStatsPanel(
    String currentExercise,
    int targetReps, {
    bool isLandscape = false,
  }) {
    // Buttons for Landscape Control
    Widget landscapeControls = Column(
      children: [
        const Divider(color: Colors.white24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              onPressed: _switchCamera,
              tooltip: "Switch Camera",
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetCounter,
              tooltip: "Reset Counter",
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.redAccent),
              onPressed: _skipExercise,
              tooltip: "Skip Exercise",
            ),
          ],
        ),
      ],
    );

    List<Widget> children = [
      if (currentExercise == 'Push-Ups' ||
          currentExercise == 'Box Push-Ups' ||
          currentExercise == 'Pike Push-Ups' ||
          currentExercise == 'Chair Dips' ||
          currentExercise == 'Floor Dips' ||
          currentExercise == 'Bird Dog' ||
          currentExercise == 'Leg Raises' ||
          currentExercise == 'Squats' ||
          currentExercise == 'Sit-Ups') ...[
        // Reps
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isLandscape
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              "Reps",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              "$_reps/$targetReps",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // Accuracy
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isLandscape
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              "Accuracy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              "${_repCounter.accuracy.toStringAsFixed(0)}%",
              style: TextStyle(
                color: _repCounter.isProperForm
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // Timer
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isLandscape
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              "Time",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              _formatTime(_secondsRemaining),
              style: TextStyle(
                color: _secondsRemaining < 10 ? Colors.redAccent : Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ] else ...[
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, color: Colors.white54),
            const SizedBox(height: 5),
            Text(
              currentExercise,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ],

      // Skip Button
      Material(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _skipExercise,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.skip_next,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
        ),
      ),

      if (isLandscape) landscapeControls,
    ];

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: isLandscape
          ? Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            ),
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}
