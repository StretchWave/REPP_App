import 'package:flutter/material.dart';

class WorkoutStatsPanel extends StatelessWidget {
  final String exerciseName;
  final int reps;
  final int targetReps;
  final double accuracy;
  final bool isProperForm;
  final int secondsRemaining;
  final bool isPortrait;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onReset;
  final VoidCallback? onSkip;

  const WorkoutStatsPanel({
    super.key,
    required this.exerciseName,
    required this.reps,
    required this.targetReps,
    required this.accuracy,
    required this.isProperForm,
    this.secondsRemaining = 0,
    this.isPortrait = true,
    this.onSwitchCamera,
    this.onReset,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    // Landscape Layout
    if (!isPortrait) {
      return Container(
        width: 150,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Reps", "$reps/$targetReps"),
            _buildStatItem(
              "Accuracy",
              "${accuracy.toInt()}%",
              color: isProperForm ? Colors.greenAccent : Colors.redAccent,
            ),
            _buildStatItem(
              "Time",
              _formatTime(secondsRemaining),
              color: secondsRemaining < 10 ? Colors.redAccent : Colors.white,
            ),
            const Divider(color: Colors.white24),
            if (onSwitchCamera != null)
              IconButton(
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                onPressed: onSwitchCamera,
              ),
            if (onReset != null)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: onReset,
              ),
            if (onSkip != null)
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.redAccent),
                onPressed: onSkip,
              ),
          ],
        ),
      );
    }

    // Portrait Layout (Bottom Bar)
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Reps", "$reps/$targetReps"),
          _buildStatItem(
            "Accuracy",
            "${accuracy.toInt()}%",
            color: isProperForm ? Colors.greenAccent : Colors.redAccent,
          ),
          _buildStatItem(
            "Time",
            _formatTime(secondsRemaining),
            color: secondsRemaining < 10 ? Colors.redAccent : Colors.white,
          ),

          // Skip Button
          if (onSkip != null)
            InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.skip_next, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value, {
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}
