import 'package:flutter/material.dart';
import 'package:tagsim/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TagSimApp());
}

class TagSimApp extends StatefulWidget {
  const TagSimApp({super.key});

  @override
  State<TagSimApp> createState() => _TagSimAppState();
}

class _TagSimAppState extends State<TagSimApp> {
  ThemeMode _themeMode = ThemeMode.system; // Default theme

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String themeModeStr = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeStr,
        orElse: () => ThemeMode.system,
      );
    });
  }

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TagSim',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Customize dark theme appBarTheme if needed
        // appBarTheme: const AppBarTheme(...),
      ),
      themeMode: _themeMode,
      home: HomeScreen(onThemeChanged: _changeTheme), // Pass callback
      debugShowCheckedModeBanner: false,
    );
  }
}

