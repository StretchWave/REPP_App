import 'exercise_logic.dart';

// Pike PushUps
class PikePushUpLogic extends ExerciseLogic {
  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    // Basic implementation similar to PushUp but with pike checks
    // ... (Due to space, simplified migration of logic from RepCounter)
    // Copying logic exactly as it was
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

    if (!isSafe(shoulder) ||
        !isSafe(elbow) ||
        !isSafe(wrist) ||
        !isSafe(hip) ||
        !isSafe(knee) ||
        !isSafe(ankle)) {
      feedback = "Body Unclear";
      isProperForm = false;
      return;
    }

    _processPikePushUp(shoulder, elbow, wrist, hip, knee, ankle);
  }

  void _processPikePushUp(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (kneeAngle < 150) {
      feedback = "Straighten Knees";
      isProperForm = false;
      accuracy = 10;
      return;
    }
    final hipAngle = calculateAngle(shoulder, hip, knee);
    if (hipAngle > 130) {
      feedback = "Raise Hips";
      isProperForm = false;
      accuracy = 30;
      return;
    }
    isProperForm = true;
    final armAngle = calculateAngle(shoulder, elbow, wrist);
    if (armAngle > 140) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "UP";
    } else if (armAngle < 100) {
      isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }
}

// Chair Dips
class ChairDipLogic extends ExerciseLogic {
  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;
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
    Map<String, double> ankle = side == "Left"
        ? landmarks[27]
        : landmarks[28]; // Needed for elevation check

    if (!isSafe(shoulder) || !isSafe(elbow) || !isSafe(wrist)) {
      feedback = "Arm Unclear";
      isProperForm = false;
      return;
    }

    // Elevation Check
    if (wrist['y']! > ankle['y']! - 0.05) {
      feedback = "Use a Chair";
      isProperForm = false;
      accuracy = 10;
      return;
    }

    isProperForm = true;
    accuracy = 100;
    final angle = calculateAngle(shoulder, elbow, wrist);
    if (angle > 160) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "UP";
    } else if (angle < 100) {
      isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }
}

// Leg Raises
class LegRaiseLogic extends ExerciseLogic {
  @override
  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;
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

    if (!isSafe(shoulder) || !isSafe(hip) || !isSafe(knee)) {
      feedback = "Legs Unclear";
      isProperForm = false;
      return;
    }

    accuracy = 100;
    // 1. Straight Legs Check
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (kneeAngle < 140) {
      feedback = "Straighten Legs";
      isProperForm = false;
      return;
    }
    isProperForm = true;
    // 2. Hip Angle
    final hipAngle = calculateAngle(shoulder, hip, knee);
    if (hipAngle < 110) {
      if (isDown) {
        count++;
        isDown = false;
      }
      feedback = "LOWER";
    } else if (hipAngle > 150) {
      isDown = true;
      feedback = "LIFT";
    } else {
      feedback = isDown ? "LIFT" : "LOWER";
    }
  }
}
