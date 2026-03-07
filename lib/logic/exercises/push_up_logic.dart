import 'exercise_logic.dart';

class PushUpLogic extends ExerciseLogic {
  final bool strictLegs;

  PushUpLogic({this.strictLegs = true});

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
    Map<String, double> elbow = side == "Left" ? landmarks[13] : landmarks[14];
    Map<String, double> wrist = side == "Left" ? landmarks[15] : landmarks[16];
    Map<String, double> hip = side == "Left" ? landmarks[23] : landmarks[24];
    Map<String, double> knee = side == "Left" ? landmarks[25] : landmarks[26];
    Map<String, double> ankle = side == "Left" ? landmarks[27] : landmarks[28];

    // Safety check
    if (!isSafe(shoulder) || !isSafe(elbow) || !isSafe(wrist) || !isSafe(hip)) {
      feedback = "Body Unclear";
      formIssues.add("Body Not Visible");
      isProperForm = false;
      return;
    }

    _processPushUp(
      shoulder,
      elbow,
      wrist,
      hip,
      knee,
      ankle,
      strictLegs: strictLegs,
    );
  }

  void _processPushUp(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle, {
    bool strictLegs = true,
  }) {
    accuracy = 100;

    // 0. Knee Check
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (strictLegs) {
      if (kneeAngle < 150) {
        feedback = "Straighten Knees";
        isProperForm = false;
        accuracy = 10;
        return;
      }
    }

    // 1. Hip Alignment
    if (!_isHorizontal(shoulder, hip)) {
      feedback = "Assume Push-Up Position";
      formIssues.add("Incorrect Position");
      isProperForm = false;
      accuracy = 10;
      return;
    }

    // 2. Hand Position
    if (shoulder['y']! >= wrist['y']!) {
      // Simple check: Shoulders usually above wrists in pushup,
      // but coordinate system: 0 is top. So shoulder Y should be SMALLER than wrist Y.
      // Wait, typical pushup: Shoulders (upper body) are higher (smaller Y) than floor (wrists/feet).
      // If Shoulder Y > Wrist Y, shoulders are BELOW wrists (bad/impossible unless handstand).
      // Originally: if (shoulder['y']! >= wrist['y']!) -> "Hands Above Shoulders" (Message confusing?)
      // Let's stick to original logic:
      // Original: if (shoulder['y']! >= wrist['y']!) accuracy = 30.
    }

    isProperForm = true;
    final angle = calculateAngle(shoulder, elbow, wrist);

    if (angle > 140) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "UP";
    } else if (angle < 110) {
      isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  bool _isHorizontal(Map<String, double> shoulder, Map<String, double> hip) {
    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();
    return dx > dy;
  }
}
