import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Need to add this dependency

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged; // Callback to change theme in main app

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Use ThemeMode.system as default if no preference is set
      _isDarkMode = (prefs.getString('themeMode') ?? 'system') == 'dark';
      // If system is default, check system brightness (optional, complex)
      // For simplicity, we just store 'light', 'dark', or 'system'.
      // Let's refine: store ThemeMode enum string directly.
      String themeModeStr = prefs.getString('themeMode') ?? 'system';
      _isDarkMode = themeModeStr == 'dark'; // Simple toggle state
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'Version ${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      print('Failed to get package info: $e');
      setState(() {
        _appVersion = 'Version inconnue';
      });
    }
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    ThemeMode newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await prefs.setString('themeMode', newMode.name); // Store 'light' or 'dark'
    setState(() {
      _isDarkMode = isDark;
    });
    widget.onThemeChanged(newMode); // Notify main app
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'TagSim',
      applicationVersion: _appVersion,
      applicationIcon: Image.asset('assets/logos/mobilis_logo.png', height: 40), // Placeholder icon
      applicationLegalese: '© 2025 Votre Nom/Société',
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 15),
          child: Text('Application de gestion SIM et codes USSD pour l\Algérie.'),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Paramètres')), // Removed to integrate with main AppBar
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.color_lens),
            title: const Text('Mode Sombre'),
            subtitle: const Text('Activer le thème sombre'),
            value: _isDarkMode,
            onChanged: _toggleTheme,
          ),
          ListTile(
            leading: const Icon(Icons.sim_card),
            title: const Text('Affichage Opérateur'),
            subtitle: Text('Gérer l\'affichage des infos opérateur'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité non implémentée.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À Propos'),
            subtitle: Text(_appVersion),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }
}

