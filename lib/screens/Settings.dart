import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Toggle States
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _goalReminders = true;
  bool _smsAlerts = false;
  bool _darkMode = false;
  bool _soundEffects = true;
  bool _cameraTracking = true;
  bool _voiceGuidance = true;
  bool _aiRecommendations = true;

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
              _buildSettingItem(
                title: "Edit Profile",
                subtitle: "Update your personal information",
                icon: Icons.person,
                iconColor: Colors.blue,
              ),
              _buildSettingItem(
                title: "Change Password",
                subtitle: "Update your password",
                icon: Icons.lock,
                iconColor: Colors.amber,
              ),
              _buildSettingItem(
                title: "Connected Accounts",
                subtitle: "Manage linked accounts",
                icon: Icons.link,
                iconColor: Colors.teal,
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("NOTIFICATIONS", [
              _buildToggleItem(
                "Push Notifications",
                "Get instant reminders",
                _pushNotifications,
                Colors.amber,
                (val) => setState(() => _pushNotifications = val),
              ),
              _buildToggleItem(
                "Email Notifications",
                "Receive weekly progress reports",
                _emailNotifications,
                Colors.blue,
                (val) => setState(() => _emailNotifications = val),
              ),
              _buildToggleItem(
                "Goal Reminders",
                "Daily motivation alerts",
                _goalReminders,
                Colors.red,
                (val) => setState(() => _goalReminders = val),
              ),
              _buildToggleItem(
                "SMS Alerts",
                "Text message reminders",
                _smsAlerts,
                Colors.grey,
                (val) => setState(() => _smsAlerts = val),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("PREFERENCES", [
              _buildSettingItem(
                title: "Units",
                subtitle: "Metric or Imperial",
                icon: Icons.straighten,
                iconColor: Colors.orange,
                trailing: const Text(
                  "Metric",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              _buildSettingItem(
                title: "Language",
                subtitle: "App language",
                icon: Icons.language,
                iconColor: Colors.lightBlue,
                trailing: const Text(
                  "English",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              _buildToggleItem(
                "Dark Mode",
                "Toggle dark theme",
                _darkMode,
                Colors.purple,
                (val) => setState(() => _darkMode = val),
              ),
              _buildToggleItem(
                "Sound Effects",
                "App sounds and music",
                _soundEffects,
                Colors.deepPurple,
                (val) => setState(() => _soundEffects = val),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSection("WORKOUT", [
              _buildSettingItem(
                title: "Rest Timer",
                subtitle: "Default rest between sets",
                icon: Icons.timer,
                iconColor: Colors.grey,
                trailing: const Text(
                  "60s",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              _buildToggleItem(
                "Camera Tracking",
                "AI form correction",
                _cameraTracking,
                Colors.blueGrey,
                (val) => setState(() => _cameraTracking = val),
              ),
              _buildToggleItem(
                "Voice Guidance",
                "Audio workout instructions",
                _voiceGuidance,
                Colors.teal,
                (val) => setState(() => _voiceGuidance = val),
              ),
              _buildToggleItem(
                "AI Recommendations",
                "Smart workout suggestions",
                _aiRecommendations,
                Colors.grey,
                (val) => setState(() => _aiRecommendations = val),
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
                title: "Clear Data",
                subtitle: "Reset all local data",
                icon: Icons.delete_outline,
                iconColor: Colors.red.withOpacity(0.5),
                iconBackgroundColor: Colors.red.withOpacity(0.1),
                titleColor: Colors.redAccent,
              ),
              _buildSettingItem(
                title: "Delete Account",
                subtitle: "Permanently delete your account",
                icon: Icons.close,
                iconColor: Colors.red,
                iconBackgroundColor: Colors.red.withOpacity(0.1),
                titleColor: Colors.red,
              ),
            ]),
            const SizedBox(height: 40),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                "Fitness Trainer v1.0.0\n© 2026 All Rights Reserved",
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? iconColor.withOpacity(0.1),
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
              else
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
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ), // slightly less vertical padding for toggles
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              // Auto-determine icon helper based on title content for similar look
              _getIconForToggle(title),
              color: iconColor,
              size: 20,
            ),
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
            activeColor: Colors.white,
            activeTrackColor: const Color(
              0xFF5D6672,
            ), // Dark Slate/Blueish track
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
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
    if (title.contains("Sharing")) return Icons.visibility;
    return Icons.circle;
  }
}
