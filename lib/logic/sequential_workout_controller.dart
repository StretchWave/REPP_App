import 'package:flutter/foundation.dart';

class SequentialWorkoutController extends ChangeNotifier {
  final Map<String, dynamic> definition;

  int _currentStateIndex = 0;
  int _repCount = 0;
  String _feedback = "Get ready!";
  bool _isComplete = false;

  DateTime? _stateStartTime;
  final Duration _stateTimeout = const Duration(
    seconds: 10,
  ); // Standard timeout for a state

  SequentialWorkoutController({required this.definition});

  int get currentStateIndex => _currentStateIndex;
  int get repCount => _repCount;
  String get feedback => _feedback;
  bool get isComplete => _isComplete;

  List<dynamic> get states => definition['states'] ?? [];

  void updatePose(Map<String, double> currentAngles) {
    if (_isComplete || states.isEmpty) return;

    final targetState = states[_currentStateIndex];
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
          _feedback = "Hold for ${holdTimeSeconds - elapsed.inSeconds}s";
          notifyListeners();
        } else {
          // Double safety: if holdTime is 0, just advance
          _advanceState();
        }
      }
    } else {
      // Check for timeout or major form break
      if (_stateStartTime != null) {
        final elapsed = DateTime.now().difference(_stateStartTime!);
        if (elapsed > const Duration(seconds: 2)) {
          // If we were holding but then broke form for > 2s, reset?
          // Or just show feedback.
          _feedback = "Fix your $firstFailure";
          notifyListeners();
        }
      } else {
        _feedback = "Move to ${targetState['stateName']}";
        notifyListeners();
      }

      _checkTimeout();
    }
  }

  void _advanceState() {
    _stateStartTime = null;
    if (_currentStateIndex < states.length - 1) {
      _currentStateIndex++;
      _feedback = "Next: ${states[_currentStateIndex]['stateName']}";
    } else {
      // Completed a full sequence!
      _repCount++;
      _currentStateIndex = 0;
      _feedback = "Rep $_repCount! Restarting...";
    }
    notifyListeners();
  }

  void _checkTimeout() {
    if (_stateStartTime != null) {
      final elapsed = DateTime.now().difference(_stateStartTime!);
      if (elapsed > _stateTimeout) {
        _resetSequence("Too long! Try again.");
      }
    }
  }

  void _resetSequence(String reason) {
    _currentStateIndex = 0;
    _stateStartTime = null;
    _feedback = reason;
    notifyListeners();
  }
}
