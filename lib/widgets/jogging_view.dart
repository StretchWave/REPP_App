import 'package:flutter/material.dart';

class JoggingView extends StatelessWidget {
  final int steps;
  final int targetSteps;

  const JoggingView({
    super.key,
    required this.steps,
    required this.targetSteps,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (steps / targetSteps).clamp(0.0, 1.0);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 20,
                  backgroundColor: Colors.white10,
                  color: Colors.greenAccent,
                ),
              ),
              Column(
                children: [
                  const Icon(
                    Icons.directions_run,
                    size: 50,
                    color: Colors.greenAccent,
                  ),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            "Jogging in Place",
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 10),
          const Text(
            "Keep your phone in your pocket or hand",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
