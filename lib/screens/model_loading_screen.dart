import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModelLoadingScreen extends StatefulWidget {
  final Widget nextScreen;

  const ModelLoadingScreen({super.key, required this.nextScreen});

  @override
  State<ModelLoadingScreen> createState() => _ModelLoadingScreenState();
}

class _ModelLoadingScreenState extends State<ModelLoadingScreen> {
  static const MethodChannel _appControl = MethodChannel(
    'com.workout/app_control',
  );
  String _statusMessage = "Initializing AI...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      setState(() => _statusMessage = "Loading Pose Detection Model...");

      // Trigger preload
      final bool result =
          await _appControl.invokeMethod('preloadModel') ?? false;

      if (mounted) {
        if (result) {
          setState(() => _statusMessage = "Ready!");
          // Brief delay for user to see "Ready"
          // await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // Navigate to the next screen (replace this loading screen)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => widget.nextScreen),
            );
          }
        } else {
          setState(() {
            _hasError = true;
            _statusMessage = "Failed to load AI Model.";
          });
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Model Load Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = "Error: ${e.message}";
        });
      }
    } catch (e) {
      debugPrint("Unknown Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = "An unexpected error occurred.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2126), // Dark background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasError)
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64)
            else
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 4,
                ),
              ),
            const SizedBox(height: 30),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_hasError) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _loadModel, child: const Text("Retry")),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
