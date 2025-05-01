import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Importer AdMob
import 'package:smart_sim_dz/screens/home_screen.dart';

void main() {
  // Assurer l'initialisation des Widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser le SDK Mobile Ads
  MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart SIM DZ',
      theme: ThemeData(
        brightness: Brightness.dark, // Thème sombre
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Personnaliser d'autres aspects du thème sombre si nécessaire
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
        ),
        cardColor: Colors.grey[850],
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.grey[800],
          // Définir d'autres styles pour les champs de texte
        ),
        // etc.
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false, // Masquer la bannière de débogage
    );
  }
}

