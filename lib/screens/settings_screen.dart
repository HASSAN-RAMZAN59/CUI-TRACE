import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'edit_profile_screen.dart';
import '../services/app_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppService _appService = AppService();
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _locationServices = true;
  bool _requireVerification = true;
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = await _appService.getCurrentUser();
      setState(() {
        _pushNotifications = prefs.getBool('settings_push_notifications') ?? true;
        _darkMode = prefs.getBool('settings_dark_mode') ?? false;
        _locationServices = prefs.getBool('settings_location_services') ?? true;
        _requireVerification = prefs.getBool('settings_require_verification') ?? true;
        _userName = user?.displayName ?? prefs.getString('current_user_name') ?? 'User';
        _userEmail = user?.email ?? prefs.getString('current_user_email') ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSetting(String key, bool value, Function(bool) updateState) async {
    setState(() => updateState(value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    if (key == 'settings_dark_mode') {
      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    }

    if (mounted) {
      String label;
      switch (key) {
        case 'settings_dark_mode':
          label = value ? '🌙 Dark Mode Enabled' : '☀️ Light Mode Enabled';
          break;
        case 'settings_push_notifications':
          label = value ? '🔔 Push Notifications Enabled' : '🔕 Push Notifications Disabled';
          break;
        case 'settings_location_services':
          label = value ? '📍 Campus Location Auto-fill Enabled' : '📍 Location Auto-fill Disabled';
          break;
        case 'settings_require_verification':
          label = value ? '🔒 Security Question Verification Mandatory' : '🔓 Verification Optional';
          break;
        default:
          label = 'Setting updated!';
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cui_trace_user_items_v3');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App local cache cleared successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Section Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    title: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_userEmail.isNotEmpty ? _userEmail : 'COMSATS Student/Faculty'),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              currentName: _userName,
                              currentEmail: _userEmail,
                            ),
                          ),
                        ).then((_) => _loadSettings());
                      },
                      child: const Text('Edit Profile'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Notifications & Preferences Section
                _buildSectionHeader('Preferences & Notifications'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active, color: Colors.blue),
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive immediate alerts for lost/found items'),
                        value: _pushNotifications,
                        onChanged: (val) => _toggleSetting(
                          'settings_push_notifications',
                          val,
                          (v) => _pushNotifications = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode, color: Colors.indigo),
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Switch app theme appearance'),
                        value: _darkMode,
                        onChanged: (val) => _toggleSetting(
                          'settings_dark_mode',
                          val,
                          (v) => _darkMode = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.location_on, color: Colors.red),
                        title: const Text('Campus Location Auto-fill'),
                        subtitle: const Text('Automatically suggest COMSATS Sahiwal spots'),
                        value: _locationServices,
                        onChanged: (val) => _toggleSetting(
                          'settings_location_services',
                          val,
                          (v) => _locationServices = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Privacy & Security Section
                _buildSectionHeader('Privacy & Security'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.verified_user, color: Colors.green),
                        title: const Text('Require Question Verification'),
                        subtitle: const Text('Mandatory security question before contacting'),
                        value: _requireVerification,
                        onChanged: (val) => _toggleSetting(
                          'settings_require_verification',
                          val,
                          (v) => _requireVerification = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Data & Storage Section
                _buildSectionHeader('Data & Storage'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                    title: const Text('Clear Temporary Cache'),
                    subtitle: const Text('Free local storage and reload fresh data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _clearCache,
                  ),
                ),
                const SizedBox(height: 25),

                // App Info Header
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.shield, size: 36, color: Colors.blue),
                      const SizedBox(height: 6),
                      const Text(
                        'CUI Trace - Campus Lost & Found',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.2.0 (Build 2026.07)\nCOMSATS University Sahiwal Campus',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
