import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_fitness_tracker/logic/pose_bridge.dart';
import 'package:ai_fitness_tracker/painters/skeleton_painter.dart';
import 'package:ai_fitness_tracker/widgets/camera_view.dart';
import 'package:ai_fitness_tracker/logic/sequential_workout_controller.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class ExecuteWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> workoutDefinition;

  const ExecuteWorkoutScreen({super.key, required this.workoutDefinition});

  @override
  State<ExecuteWorkoutScreen> createState() => _ExecuteWorkoutScreenState();
}

class _ExecuteWorkoutScreenState extends State<ExecuteWorkoutScreen> {
  final PoseBridge _bridge = PoseBridge();
  StreamSubscription? _poseSubscription;
  late SequentialWorkoutController _controller;

  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );

  List<Map<String, double>> _currentSkeleton = [];
  List<Map<String, double>> _rawLandmarks = [];
  NativeDeviceOrientation _deviceOrientation =
      NativeDeviceOrientation.portraitUp;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;

  @override
  void initState() {
    super.initState();
    _controller = SequentialWorkoutController(
      definition: widget.workoutDefinition,
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
          if (mounted) {
            setState(() {
              _deviceOrientation = orientation;
            });
          }
        });
    _startPoseStream();
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
    } catch (e) {
      debugPrint("Error switching camera: $e");
    }
  }

  void _startPoseStream() {
    _poseSubscription = _bridge.poseStream.listen((landmarks) {
      if (!mounted) return;

      final List<Map<String, double>> normalized = landmarks.map((l) {
        double rawX = l['x']!;
        double rawY = l['y']!;
        double finalX = rawX;
        double finalY = rawY;

        switch (_deviceOrientation) {
          case NativeDeviceOrientation.portraitUp:
            finalX = 1.0 - rawY;
            finalY = rawX;
            break;
          case NativeDeviceOrientation.portraitDown:
            finalX = rawY;
            finalY = 1.0 - rawX;
            break;
          case NativeDeviceOrientation.landscapeLeft:
            finalX = rawX;
            finalY = rawY;
            break;
          case NativeDeviceOrientation.landscapeRight:
            finalX = 1.0 - rawX;
            finalY = 1.0 - rawY;
            break;
          default:
            finalX = 1.0 - rawY;
            finalY = rawX;
        }

        return {
          'x': finalX,
          'y': finalY,
          'z': l['z']!,
          'visibility': l['visibility']!,
        };
      }).toList();

      setState(() {
        _rawLandmarks = landmarks;
        _currentSkeleton = normalized;
      });

      // Calculate angles from RAW landmarks (ignores aspect ratio distortion)
      final currentAngles = _calculateAngles(landmarks);
      _controller.updatePose(currentAngles);
    });
  }

  double _calculateAngle(
    Map<String, double> a,
    Map<String, double> b,
    Map<String, double> c,
  ) {
    if (a['x'] == 0 && a['y'] == 0) return 0.0;
    final radians =
        atan2(c['y']! - b['y']!, c['x']! - b['x']!) -
        atan2(a['y']! - b['y']!, a['x']! - b['x']!);
    var angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }

  Map<String, double> _calculateAngles(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return {};

    final angles = {
      'leftElbow': _calculateAngle(landmarks[11], landmarks[13], landmarks[15]),
      'leftShoulder': _calculateAngle(
        landmarks[23],
        landmarks[11],
        landmarks[13],
      ),
      'leftHip': _calculateAngle(landmarks[11], landmarks[23], landmarks[25]),
      'leftKnee': _calculateAngle(landmarks[23], landmarks[25], landmarks[27]),
      'rightElbow': _calculateAngle(
        landmarks[12],
        landmarks[14],
        landmarks[16],
      ),
      'rightShoulder': _calculateAngle(
        landmarks[24],
        landmarks[12],
        landmarks[14],
      ),
      'rightHip': _calculateAngle(landmarks[12], landmarks[24], landmarks[26]),
      'rightKnee': _calculateAngle(landmarks[24], landmarks[26], landmarks[28]),
    };
    return angles;
  }

  @override
  void dispose() {
    _orientationSubscription?.cancel();
    _poseSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exerciseName = widget.workoutDefinition['exercise_name'] ?? "Workout";
    final stateCount =
        (widget.workoutDefinition['states'] as List?)?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PoseCameraPreview(),
          if (_currentSkeleton.isNotEmpty)
            CustomPaint(
              painter: SkeletonPainter(_currentSkeleton),
              size: Size.infinite,
            ),

          // HUD
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        Text(
                          exerciseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Step ${_controller.currentStateIndex + 1} of $stateCount",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_android,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _controller.feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // DEBUG PANEL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Logic Debug (Current / Target)",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_controller.states.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final state = _controller
                                .states[_controller.currentStateIndex];
                            final Map<String, dynamic> rawTargets =
                                state['targetAngles'] ?? {};
                            final targets = rawTargets.map(
                              (k, v) => MapEntry(k, (v as num).toDouble()),
                            );
                            final tol = (state['tolerance'] ?? 15.0).toDouble();
                            final currentAngles = _calculateAngles(
                              _rawLandmarks,
                            );

                            return Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: targets.keys.map((key) {
                                final tar = targets[key] ?? 0.0;
                                final cur = currentAngles[key]; // Might be null
                                final met =
                                    cur != null && (tar - cur).abs() <= tol;
                                final valStr = cur != null
                                    ? cur.toStringAsFixed(0)
                                    : "N/A";
                                return Text(
                                  "$key: $valStr/${tar.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: met
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 10,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rep counter
          Positioned(
            bottom: 60,
            right: 30,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "REPS",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "${_controller.repCount}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
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
}
