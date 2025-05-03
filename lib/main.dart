import 'package:flutter/material.dart';
import 'package:tagsim/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart'; // Import dynamic_color
import 'package:tagsim/services/user_preferences.dart'; // Import UserPreferences
import 'package:tagsim/services/notification_service.dart'; // Import NotificationService

// Define default ColorSchemes (can be customized)
final _defaultLightColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
final _defaultDarkColorScheme = ColorScheme.fromSeed(
  seedColor: Colors.deepPurple,
  brightness: Brightness.dark,
);

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await UserPreferences.init(); // Initialize UserPreferences

  // Initialize Notification Service and schedule notifications
  try {
    await NotificationService.initialize();
    await NotificationService.scheduleDailyNotifications();
  } catch (e) {
    print("Error initializing or scheduling notifications: $e");
    // Handle error appropriately, maybe log it
  }

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
    // Use the public static getter from UserPreferences
    String themeModeStr = UserPreferences.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeStr,
        orElse: () => ThemeMode.system,
      );
    });
  }

  void _changeTheme(ThemeMode themeMode) async { // Make async
    setState(() {
      _themeMode = themeMode;
    });
    // Save theme preference using the public static setter
    await UserPreferences.setString("themeMode", themeMode.name); // Add await
  }

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp with DynamicColorBuilder
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // Use dynamic colors if available
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Otherwise, use fallback default schemes
          lightColorScheme = _defaultLightColorScheme;
          darkColorScheme = _defaultDarkColorScheme;
        }

        return MaterialApp(
          title: 'TagSim',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            // Keep AppBar customization consistent or adapt if needed
            appBarTheme: AppBarTheme(
              backgroundColor: lightColorScheme.primary, // Use dynamic primary color
              foregroundColor: lightColorScheme.onPrimary, // Use dynamic onPrimary color
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            // Keep AppBar customization consistent or adapt if needed
            appBarTheme: AppBarTheme(
              backgroundColor: darkColorScheme.primary, // Use dynamic primary color
              foregroundColor: darkColorScheme.onPrimary, // Use dynamic onPrimary color
            ),
          ),
          themeMode: _themeMode,
          home: HomeScreen(onThemeChanged: _changeTheme), // Pass callback
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

