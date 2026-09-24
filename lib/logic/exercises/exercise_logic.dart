import 'dart:math';

abstract class ExerciseLogic {
  int count = 0;
  bool isDown = false;
  String feedback = "";
  double accuracy = 0.0;
  bool isProperForm = true;
  final Set<String> formIssues = {};

  void reset() {
    count = 0;
    isDown = false;
    feedback = "";
    accuracy = 0.0;
    isProperForm = true;
    formIssues.clear();
  }

  void processLandmarks(List<Map<String, double>> landmarks);

  // Helper Methods shared across exercises

  Map<String, double> getLandmark(
    List<Map<String, double>> landmarks,
    int index,
  ) {
    if (index >= landmarks.length) return {'x': 0, 'y': 0, 'visibility': 0};
    return landmarks[index];
  }

  bool isSafe(Map<String, double> point) {
    if ((point['visibility'] ?? 0) < 0.5) return false;
    double x = point['x']!;
    double y = point['y']!;
    if (x < 0.05 || x > 0.95) return false;
    if (y < 0.05 || y > 0.95) return false;
    return true;
  }

  double calculateAngle(
    Map<String, double> a,
    Map<String, double> b,
    Map<String, double> c,
  ) {
    // Safety check for empty/zero points on all three landmarks
    if ((a['x'] == 0 && a['y'] == 0) ||
        (b['x'] == 0 && b['y'] == 0) ||
        (c['x'] == 0 && c['y'] == 0)) {
      return 0.0;
    }

    final radians =
        atan2(c['y']! - b['y']!, c['x']! - b['x']!) -
        atan2(a['y']! - b['y']!, a['x']! - b['x']!);
    var angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }

  /// Detects which side of the body is more visible, based on landmark
  /// visibility scores for the given indices.
  ///
  /// [landmarks] - Full list of pose landmarks.
  /// [leftIndices] - Landmark indices for the left side (e.g. [11, 13, 15]).
  /// [rightIndices] - Landmark indices for the right side (e.g. [12, 14, 16]).
  ///
  /// Returns "Left" or "Right".
  String detectSide(
    List<Map<String, double>> landmarks,
    List<int> leftIndices,
    List<int> rightIndices,
  ) {
    double leftScore = 0;
    for (final i in leftIndices) {
      leftScore += landmarks[i]['visibility']!;
    }
    double rightScore = 0;
    for (final i in rightIndices) {
      rightScore += landmarks[i]['visibility']!;
    }
    return leftScore > rightScore ? "Left" : "Right";
  }

  /// Clears per-frame state before processing new landmarks.
  /// Subclasses should call this at the start of [processLandmarks].
  void clearFrameState() {
    formIssues.clear();
  }
}

