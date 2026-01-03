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
    if (a['x'] == 0 && a['y'] == 0) return 0.0; // Safety check for empty points

    final radians =
        atan2(c['y']! - b['y']!, c['x']! - b['x']!) -
        atan2(a['y']! - b['y']!, a['x']! - b['x']!);
    var angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }
}
