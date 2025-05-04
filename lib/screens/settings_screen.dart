import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tagsim/screens/bonus_config_screen.dart'; // Import the bonus screen

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
      String themeModeStr = prefs.getString('themeMode') ?? 'system';
      _isDarkMode = themeModeStr == 'dark';
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
    await prefs.setString('themeMode', newMode.name);
    setState(() {
      _isDarkMode = isDark;
    });
    widget.onThemeChanged(newMode);
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'TagSim',
      applicationVersion: _appVersion,
      // Use the actual app logo now
      applicationIcon: Image.asset('assets/images/app_logo_final.png', height: 40),
      applicationLegalese: '© 2025 Doctor idée',
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 15),
          child: Text('Application de gestion SIM et codes USSD pour l\'Algérie.'),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.color_lens_outlined),
            title: const Text('Mode Sombre'),
            subtitle: const Text('Activer le thème sombre'),
            value: _isDarkMode,
            onChanged: _toggleTheme,
          ),
          // Add Bonus/Credit Management Tile
          ListTile(
            leading: const Icon(Icons.card_giftcard_outlined),
            title: const Text('Bonus & Crédits'),
            subtitle: const Text('Gérer le crédit et la data restants'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BonusConfigScreen()),
              );
            },
          ),
          // Existing Tiles
          ListTile(
            leading: const Icon(Icons.sim_card_outlined),
            title: const Text('Configuration SIM'),
            subtitle: const Text('Définir l\'opérateur de chaque SIM'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { /* Feature not implemented yet */ },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À Propos'),
            subtitle: Text(_appVersion),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }
}

