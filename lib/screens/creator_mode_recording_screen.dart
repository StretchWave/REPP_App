import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_fitness_tracker/logic/pose_bridge.dart';
import 'package:ai_fitness_tracker/painters/skeleton_painter.dart';
import 'package:ai_fitness_tracker/widgets/camera_view.dart';
import 'package:ai_fitness_tracker/screens/creator_mode_scrubbing_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class CreatorModeRecordingScreen extends StatefulWidget {
  const CreatorModeRecordingScreen({super.key});

  @override
  State<CreatorModeRecordingScreen> createState() =>
      _CreatorModeRecordingScreenState();
}

class _CreatorModeRecordingScreenState
    extends State<CreatorModeRecordingScreen> {
  final PoseBridge _bridge = PoseBridge();
  StreamSubscription? _poseSubscription;

  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );

  bool _isRecording = false;
  // We'll store the full landmarks for visual replay
  final List<List<Map<String, double>>> _recordedFrames = [];
  // And the calculated angles per frame
  final List<Map<String, double>> _recordedAngles = [];

  List<Map<String, double>> _currentSkeleton = [];

  NativeDeviceOrientation _deviceOrientation =
      NativeDeviceOrientation.portraitUp;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;

  @override
  void initState() {
    super.initState();
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
        _currentSkeleton = normalized;
      });

      if (_isRecording) {
        _recordedFrames.add(normalized);
        _recordedAngles.add(_calculateAngles(landmarks));
      }
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

    // Calculate left side
    final leftElbow = _calculateAngle(
      landmarks[11],
      landmarks[13],
      landmarks[15],
    );
    final leftShoulder = _calculateAngle(
      landmarks[23],
      landmarks[11],
      landmarks[13],
    );
    final leftHip = _calculateAngle(
      landmarks[11],
      landmarks[23],
      landmarks[25],
    );
    final leftKnee = _calculateAngle(
      landmarks[23],
      landmarks[25],
      landmarks[27],
    );

    // Calculate right side
    final rightElbow = _calculateAngle(
      landmarks[12],
      landmarks[14],
      landmarks[16],
    );
    final rightShoulder = _calculateAngle(
      landmarks[24],
      landmarks[12],
      landmarks[14],
    );
    final rightHip = _calculateAngle(
      landmarks[12],
      landmarks[24],
      landmarks[26],
    );
    final rightKnee = _calculateAngle(
      landmarks[24],
      landmarks[26],
      landmarks[28],
    );

    return {
      'leftElbow': leftElbow,
      'leftShoulder': leftShoulder,
      'leftHip': leftHip,
      'leftKnee': leftKnee,
      'rightElbow': rightElbow,
      'rightShoulder': rightShoulder,
      'rightHip': rightHip,
      'rightKnee': rightKnee,
    };
  }

  Future<void> _pickAndProcessVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    setState(() {
      _isLoading = true;
      _recordedFrames.clear();
      _recordedAngles.clear();
    });

    try {
      // NOTE: For true video processing, we would ideally extract frames and send to ML Kit.
      // Since the current bridge is designed for live streams, we'll implement a 'Simulated Upload'
      // where we invoke the native side to process a file path if available.
      // For now, alerting user that this requires a specific native implementation update
      // or we can use a simpler approach if the bridge supports it.

      // I'll add a placeholder message and logic to show the UI intent.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video processing requires native-side file decoder. Starting live capture instead.',
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error picking video: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isLoading = false;

  @override
  void dispose() {
    _orientationSubscription?.cancel();
    _poseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
    } catch (e) {
      debugPrint("Error switching camera: $e");
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
      });
      // Go to scrubbing screen
      if (_recordedFrames.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorModeScrubbingScreen(
              frames: _recordedFrames,
              angles: _recordedAngles,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No frames recorded!')));
      }
    } else {
      // Start recording
      setState(() {
        _recordedFrames.clear();
        _recordedAngles.clear();
        _isRecording = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Record Reference',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PoseCameraPreview(),
          if (_currentSkeleton.isNotEmpty)
            CustomPaint(
              painter: SkeletonPainter(_currentSkeleton),
              size: Size.infinite,
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _pickAndProcessVideo,
                  icon: const Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording ? Colors.red : Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        height: _isRecording ? 30 : 60,
                        width: _isRecording ? 30 : 60,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.white,
                          borderRadius: _isRecording
                              ? BorderRadius.circular(4)
                              : BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(
                    Icons.flip_camera_android,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording)
            Positioned(
              top: 100,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Recording...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
