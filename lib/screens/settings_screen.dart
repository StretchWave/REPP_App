import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_tracker/services/settings_service.dart';
import 'package:ai_fitness_tracker/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();

  late bool _pushNotifications;
  late bool _emailNotifications;
  late bool _goalReminders;
  late bool _smsAlerts;
  late bool _darkMode;

  late bool _cameraTracking;
  late bool _voiceGuidance;
  late bool _showSkeleton;

  late bool _isMetric;
  late int _restTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _pushNotifications = _settings.pushNotifications;
      _emailNotifications = _settings.emailNotifications;
      _goalReminders = _settings.goalReminders;
      _smsAlerts = _settings.smsAlerts;
      _darkMode = _settings.darkMode;

      _cameraTracking = _settings.cameraTracking;
      _voiceGuidance = _settings.voiceGuidance;
      _showSkeleton = _settings.showSkeleton;

      _isMetric = _settings.isMetric;
      _restTimer = _settings.restTimerSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F25),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildSection("ACCOUNT", [
              // No Profile Edit yet
              // _buildSettingItem(title: "Edit Profile", ...),
              _buildSettingItem(
                title: "Sign Out",
                subtitle: "Log out of your account",
                icon: Icons.logout,
                iconColor: Colors.orangeAccent,
                onTap: _signOut,
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("NOTIFICATIONS", [
              _buildToggleItem(
                "Push Notifications",
                "Get instant reminders",
                _pushNotifications,
                Colors.amber,
                (val) {
                  _settings.setPushNotifications(val);
                  setState(() => _pushNotifications = val);
                },
              ),
              _buildToggleItem(
                "Email Notifications",
                "Receive weekly progress reports",
                _emailNotifications,
                Colors.blue,
                (val) {
                  _settings.setEmailNotifications(val);
                  setState(() => _emailNotifications = val);
                },
              ),
              _buildToggleItem(
                "Goal Reminders",
                "Daily motivation alerts",
                _goalReminders,
                Colors.red,
                (val) {
                  _settings.setGoalReminders(val);
                  setState(() => _goalReminders = val);
                },
              ),
              _buildToggleItem(
                "SMS Alerts",
                "Text message reminders",
                _smsAlerts,
                Colors.grey,
                (val) {
                  _settings.setSmsAlerts(val);
                  setState(() => _smsAlerts = val);
                },
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("PREFERENCES", [
              _buildSettingItem(
                title: "Units",
                subtitle: _isMetric ? "Metric (kg, cm)" : "Imperial (lbs, in)",
                icon: Icons.straighten,
                iconColor: Colors.orange,
                trailing: Switch(
                  value: _isMetric,
                  onChanged: (val) {
                    _settings.setIsMetric(val);
                    setState(() => _isMetric = val);
                  },
                  activeThumbColor: Colors.orange,
                  activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                ),
              ),
              _buildToggleItem(
                "Dark Mode",
                "Toggle dark theme",
                _darkMode,
                Colors.purple,
                (val) {
                  _settings.setDarkMode(val);
                  setState(() => _darkMode = val);
                },
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("WORKOUT", [
              _buildSettingItem(
                title: "Rest Timer",
                subtitle: "Rest between sets",
                icon: Icons.timer,
                iconColor: Colors.grey,
                trailing: Text(
                  "${_restTimer}s",
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: _showRestTimerDialog,
              ),
              _buildToggleItem(
                "Camera Tracking",
                "AI form correction",
                _cameraTracking,
                Colors.blueGrey,
                (val) {
                  _settings.setCameraTracking(val);
                  setState(() => _cameraTracking = val);
                },
              ),
              _buildToggleItem(
                "Voice Guidance",
                "Audio workout instructions",
                _voiceGuidance,
                Colors.teal,
                (val) {
                  _settings.setVoiceGuidance(val);
                  setState(() => _voiceGuidance = val);
                },
              ),
              _buildToggleItem(
                "Show Skeleton",
                "Visible AI skeleton overlay",
                _showSkeleton,
                Colors.green,
                (val) {
                  _settings.setShowSkeleton(val);
                  setState(() => _showSkeleton = val);
                },
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("PRIVACY & SECURITY", [
              _buildSettingItem(
                title: "Privacy Policy",
                subtitle: "Read our privacy policy",
                icon: Icons.lock_outline,
                iconColor: Colors.amber,
              ),
              _buildSettingItem(
                title: "Terms of Service",
                subtitle: "View terms and conditions",
                icon: Icons.description,
                iconColor: Colors.orange,
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("SUPPORT", [
              _buildSettingItem(
                title: "Help Center",
                subtitle: "FAQs and guides",
                icon: Icons.help_outline,
                iconColor: Colors.redAccent,
              ),
              _buildSettingItem(
                title: "Contact Support",
                subtitle: "Get help from our team",
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.blueGrey,
              ),
              _buildSettingItem(
                title: "Rate App",
                subtitle: "Share your feedback",
                icon: Icons.star,
                iconColor: Colors.amber,
              ),
              _buildSettingItem(
                title: "Share App",
                subtitle: "Invite friends to join",
                icon: Icons.ios_share,
                iconColor: Colors.orange,
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("DANGER ZONE", [
              _buildSettingItem(
                title: "Delete Account",
                subtitle: "Permanently delete your account",
                icon: Icons.delete_forever,
                iconColor: Colors.red,
                iconBackgroundColor: Colors.red.withValues(alpha: 0.1),
                titleColor: Colors.red,
                onTap: _deleteAccount,
              ),
            ]),
            const SizedBox(height: 40),

            const Center(
              child: Text(
                "Fitness Trainer v1.1.0\n© 2026",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helpers
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (c) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action cannot be undone. All your data will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deletion request submitted.")),
        );
        await _signOut();
      }
    }
  }

  Future<void> _showRestTimerDialog() async {
    int temp = _restTimer;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Rest Timer"),
        content: StatefulBuilder(
          builder: (context, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$temp seconds",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: temp.toDouble(),
                min: 15,
                max: 180,
                divisions: 11,
                label: "$temp s",
                onChanged: (val) => setSt(() => temp = val.toInt()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _settings.setRestTimerSeconds(temp);
              setState(() => _restTimer = temp);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? iconBackgroundColor,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    String subtitle,
    bool value,
    Color iconColor,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getIconForToggle(title), color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF5D6672),
          ),
        ],
      ),
    );
  }

  IconData _getIconForToggle(String title) {
    if (title.contains("Push")) return Icons.notifications_active;
    if (title.contains("Email")) return Icons.email;
    if (title.contains("Goal")) return Icons.track_changes;
    if (title.contains("SMS")) return Icons.sms;
    if (title.contains("Dark")) return Icons.dark_mode;
    if (title.contains("Sound")) return Icons.music_note;
    if (title.contains("Camera")) return Icons.camera_alt;
    if (title.contains("Voice")) return Icons.record_voice_over;
    if (title.contains("AI")) return Icons.smart_toy;
    return Icons.circle;
  }
}
