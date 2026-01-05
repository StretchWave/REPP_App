import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Keys
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyEmailNotifications = 'email_notifications';
  static const String _keyGoalReminders = 'goal_reminders';
  static const String _keySmsAlerts = 'sms_alerts';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keySoundEffects = 'sound_effects';
  static const String _keyCameraTracking = 'camera_tracking';
  static const String _keyVoiceGuidance = 'voice_guidance';
  static const String _keyAiRecommendations = 'ai_recommendations';
  static const String _keyRestTimer = 'rest_timer';
  static const String _keyIsMetric = 'is_metric';
  static const String _keyShowSkeleton = 'show_skeleton';

  // Getters
  bool get pushNotifications => _prefs?.getBool(_keyPushNotifications) ?? true;
  bool get emailNotifications =>
      _prefs?.getBool(_keyEmailNotifications) ?? true;
  bool get goalReminders => _prefs?.getBool(_keyGoalReminders) ?? true;
  bool get smsAlerts => _prefs?.getBool(_keySmsAlerts) ?? false;
  bool get darkMode => _prefs?.getBool(_keyDarkMode) ?? false;
  bool get soundEffects => _prefs?.getBool(_keySoundEffects) ?? true;
  bool get cameraTracking => _prefs?.getBool(_keyCameraTracking) ?? true;
  bool get voiceGuidance => _prefs?.getBool(_keyVoiceGuidance) ?? true;
  bool get aiRecommendations => _prefs?.getBool(_keyAiRecommendations) ?? true;
  int get restTimerSeconds => _prefs?.getInt(_keyRestTimer) ?? 60;
  bool get isMetric => _prefs?.getBool(_keyIsMetric) ?? true;
  bool get showSkeleton => _prefs?.getBool(_keyShowSkeleton) ?? true;

  // Setters
  Future<void> setPushNotifications(bool val) async =>
      await _prefs?.setBool(_keyPushNotifications, val);
  Future<void> setEmailNotifications(bool val) async =>
      await _prefs?.setBool(_keyEmailNotifications, val);
  Future<void> setGoalReminders(bool val) async =>
      await _prefs?.setBool(_keyGoalReminders, val);
  Future<void> setSmsAlerts(bool val) async =>
      await _prefs?.setBool(_keySmsAlerts, val);
  Future<void> setDarkMode(bool val) async =>
      await _prefs?.setBool(_keyDarkMode, val);
  Future<void> setSoundEffects(bool val) async =>
      await _prefs?.setBool(_keySoundEffects, val);
  Future<void> setCameraTracking(bool val) async =>
      await _prefs?.setBool(_keyCameraTracking, val);
  Future<void> setVoiceGuidance(bool val) async =>
      await _prefs?.setBool(_keyVoiceGuidance, val);
  Future<void> setAiRecommendations(bool val) async =>
      await _prefs?.setBool(_keyAiRecommendations, val);
  Future<void> setRestTimerSeconds(int val) async =>
      await _prefs?.setInt(_keyRestTimer, val);
  Future<void> setIsMetric(bool val) async =>
      await _prefs?.setBool(_keyIsMetric, val);
  Future<void> setShowSkeleton(bool val) async =>
      await _prefs?.setBool(_keyShowSkeleton, val);
}
