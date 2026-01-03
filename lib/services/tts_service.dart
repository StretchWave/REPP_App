import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_fitness_tracker/services/settings_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();

  factory TtsService() => _instance;

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  DateTime? _lastSpokenTime;
  String? _lastMessage; // To prevent repeating the same message instantly

  // Helper map to track debounce times for specific messages if needed
  final Map<String, DateTime> _debounceMap = {};

  TtsService._internal() {
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  /// Speaks the count (High Priority)
  /// We usually want the count to interrupt or be immediate.
  Future<void> speakCount(int count) async {
    if (!SettingsService().voiceGuidance) return;

    // Stop any current speech (like a long tip) to say the number
    await _flutterTts.stop();
    await _flutterTts.speak(count.toString());
  }

  /// Speaks feedback with debounce logic.
  /// [key] is used to debounce specific types of feedback (e.g. "straighten_knees")
  Future<void> speakFeedback(
    String message, {
    String? key,
    Duration? debounceDuration,
  }) async {
    if (!SettingsService().voiceGuidance) return;
    if (_isSpeaking) return; // Don't interrupt unless it's a count

    final now = DateTime.now();

    // 1. Global Debounce (Don't speak too often in general)
    if (_lastSpokenTime != null &&
        now.difference(_lastSpokenTime!).inMilliseconds < 2500) {
      return;
    }

    // 2. Message Specific Debounce (Don't repeat same tip too often)
    // If we've said this exact message recently, skip it.
    if (_lastMessage == message &&
        _lastSpokenTime != null &&
        now.difference(_lastSpokenTime!).inSeconds < 5) {
      return;
    }

    // 3. Keyed Debounce (Optional strict per-issue debounce)
    if (key != null) {
      if (_debounceMap.containsKey(key)) {
        final lastTime = _debounceMap[key]!;
        final duration = debounceDuration ?? const Duration(seconds: 4);
        if (now.difference(lastTime) < duration) return;
      }
      _debounceMap[key] = now;
    }

    _lastMessage = message;
    _lastSpokenTime = now;
    await _flutterTts.speak(message);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
