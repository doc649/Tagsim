import 'package:flutter/material.dart';
import 'package:tagsim/screens/home_screen.dart'; // Import the HomeScreen

void main() {
  runApp(const TagSimApp());
}

class TagSimApp extends StatelessWidget {
  const TagSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TagSim',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, // Using blue as the primary seed color
          brightness: Brightness.light, // Or Brightness.dark based on preference/system
        ),
        useMaterial3: true, // Enabling Material 3
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue, // Example: Blue app bar
          foregroundColor: Colors.white, // Example: White text/icons on app bar
        ),
        // Add other theme properties as needed
      ),
      home: const HomeScreen(), // Use HomeScreen as the home page
      debugShowCheckedModeBanner: false, // Optional: Remove debug banner
    );
  }
}

