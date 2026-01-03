import 'exercise_logic.dart';

class SquatLogic extends ExerciseLogic {
  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;

    // Detect Side based on Legs
    double leftScore =
        landmarks[23]['visibility']! +
        landmarks[25]['visibility']! +
        landmarks[27]['visibility']!;
    double rightScore =
        landmarks[24]['visibility']! +
        landmarks[26]['visibility']! +
        landmarks[28]['visibility']!;

    String side = leftScore > rightScore ? "Left" : "Right";

    Map<String, double> shoulder = side == "Left"
        ? landmarks[11]
        : landmarks[12];
    Map<String, double> hip = side == "Left" ? landmarks[23] : landmarks[24];
    Map<String, double> knee = side == "Left" ? landmarks[25] : landmarks[26];
    Map<String, double> ankle = side == "Left" ? landmarks[27] : landmarks[28];

    if (!isSafe(hip) || !isSafe(knee) || !isSafe(ankle)) {
      feedback = "Legs Unclear";
      formIssues.add("Legs Not Visible");
      isProperForm = false;
      return;
    }

    _processSquat(shoulder, hip, knee, ankle);
  }

  void _processSquat(
    Map<String, double> shoulder,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;

    // 1. Vertical Check
    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();

    if (dx > dy) {
      feedback = "Stand Up";
      formIssues.add("Improper Squat Form");
      isProperForm = false;
      accuracy = 10;
      return;
    }

    isProperForm = true;
    final angle = calculateAngle(hip, knee, ankle);

    if (angle > 160) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "STAND";
    } else if (angle < 100) {
      isDown = true;
      feedback = "HOLD";
    } else {
      feedback = "GO LOWER";
    }
  }
}
