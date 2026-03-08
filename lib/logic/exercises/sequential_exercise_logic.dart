import 'package:ai_fitness_tracker/logic/exercises/exercise_logic.dart';

class SequentialExerciseLogic extends ExerciseLogic {
  final Map<String, dynamic> definition;

  int _currentStateIndex = 0;
  DateTime? _stateStartTime;
  final Duration _stateTimeout = const Duration(seconds: 10);

  SequentialExerciseLogic({required this.definition}) {
    feedback = "Get ready!";
  }

  List<dynamic> get _states => definition['states'] ?? [];

  @override
  void reset() {
    super.reset();
    _currentStateIndex = 0;
    _stateStartTime = null;
    feedback = "Get ready!";
  }

  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    if (_states.isEmpty) return;

    // 1. Calculate standard angles for this frame
    final currentAngles = {
      'leftElbow': calculateAngle(
        getLandmark(landmarks, 11),
        getLandmark(landmarks, 13),
        getLandmark(landmarks, 15),
      ),
      'leftShoulder': calculateAngle(
        getLandmark(landmarks, 23),
        getLandmark(landmarks, 11),
        getLandmark(landmarks, 13),
      ),
      'leftHip': calculateAngle(
        getLandmark(landmarks, 11),
        getLandmark(landmarks, 23),
        getLandmark(landmarks, 25),
      ),
      'leftKnee': calculateAngle(
        getLandmark(landmarks, 23),
        getLandmark(landmarks, 25),
        getLandmark(landmarks, 27),
      ),
      'rightElbow': calculateAngle(
        getLandmark(landmarks, 12),
        getLandmark(landmarks, 14),
        getLandmark(landmarks, 16),
      ),
      'rightShoulder': calculateAngle(
        getLandmark(landmarks, 24),
        getLandmark(landmarks, 12),
        getLandmark(landmarks, 14),
      ),
      'rightHip': calculateAngle(
        getLandmark(landmarks, 12),
        getLandmark(landmarks, 24),
        getLandmark(landmarks, 26),
      ),
      'rightKnee': calculateAngle(
        getLandmark(landmarks, 24),
        getLandmark(landmarks, 26),
        getLandmark(landmarks, 28),
      ),
    };

    // 2. Evaluate current state
    final targetState = _states[_currentStateIndex];
    final Map<String, dynamic> rawTargets = targetState['targetAngles'] ?? {};
    final Map<String, double> targetAngles = rawTargets.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final tolerance = (targetState['tolerance'] ?? 15.0).toDouble();
    final holdTimeSeconds = (targetState['holdTime'] ?? 0).toInt();

    bool allMet = true;
    String? firstFailure;

    targetAngles.forEach((joint, targetValue) {
      final currentValue = currentAngles[joint] ?? 0.0;
      final diff = (currentValue - targetValue).abs();

      if (diff > tolerance) {
        allMet = false;
        firstFailure ??= joint;
      }
    });

    if (allMet) {
      _stateStartTime ??= DateTime.now();

      final elapsed = DateTime.now().difference(_stateStartTime!);
      if (elapsed.inSeconds >= holdTimeSeconds) {
        _advanceState();
      } else {
        if (holdTimeSeconds > 0) {
          feedback = "Hold for ${holdTimeSeconds - elapsed.inSeconds}s";
        } else {
          _advanceState();
        }
      }
    } else {
      if (_stateStartTime != null) {
        final elapsed = DateTime.now().difference(_stateStartTime!);
        if (elapsed > const Duration(seconds: 2)) {
          feedback = "Fix your $firstFailure";
        }
      } else {
        feedback = "Move to ${targetState['stateName']}";
      }

      _checkTimeout();
    }

    // Update accuracy based on whether any rep has been completed
    accuracy = count > 0 ? 100.0 : 0.0;
  }

  void _advanceState() {
    _stateStartTime = null;
    if (_currentStateIndex < _states.length - 1) {
      _currentStateIndex++;
      feedback = "Next: ${_states[_currentStateIndex]['stateName']}";
    } else {
      // Completed a full sequence!
      count++;
      _currentStateIndex = 0;
      feedback = "Rep $count! Restarting...";
    }
  }

  void _checkTimeout() {
    if (_stateStartTime != null) {
      final elapsed = DateTime.now().difference(_stateStartTime!);
      if (elapsed > _stateTimeout) {
        _currentStateIndex = 0;
        _stateStartTime = null;
        feedback = "Too long! Try again.";
      }
    }
  }
}
