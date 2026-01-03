import 'exercise_logic.dart';

class SitUpLogic extends ExerciseLogic {
  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;

    // Detect Side
    double leftScore =
        landmarks[11]['visibility']! +
        landmarks[13]['visibility']! +
        landmarks[15]['visibility']!;
    double rightScore =
        landmarks[12]['visibility']! +
        landmarks[14]['visibility']! +
        landmarks[16]['visibility']!;

    String side = leftScore > rightScore ? "Left" : "Right";

    Map<String, double> shoulder = side == "Left"
        ? landmarks[11]
        : landmarks[12];
    Map<String, double> hip = side == "Left" ? landmarks[23] : landmarks[24];
    Map<String, double> knee = side == "Left" ? landmarks[25] : landmarks[26];

    if (!isSafe(shoulder) || !isSafe(hip) || !isSafe(knee)) {
      feedback = "Body Unclear";
      formIssues.add("Body Not Visible");
      isProperForm = false;
      return;
    }

    _processSitUp(shoulder, hip, knee);
  }

  void _processSitUp(
    Map<String, double> shoulder,
    Map<String, double> hip,
    Map<String, double> knee,
  ) {
    accuracy = 100;
    isProperForm = true;

    final angle = calculateAngle(shoulder, hip, knee);

    // Down (Lying): > 110
    // Up (Sitting): < 80

    if (angle > 110) {
      isDown = true;
      feedback = "UP";
    } else if (angle < 80) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "DOWN";
    } else {
      feedback = "KEEP GOING";
    }
  }
}
