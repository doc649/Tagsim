import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/ussd_codes_screen.dart';
import 'package:tagsim/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged; // Add callback parameter

  const HomeScreen({super.key, required this.onThemeChanged}); // Require callback

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Define the screens for each tab - must be initialized dynamically if passing parameters
  late final List<Widget> _widgetOptions;

  // Define titles for each screen
  static const List<String> _appBarTitles = <String>[
    'Contacts',
    'Codes USSD',
    'Paramètres',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize _widgetOptions here to access widget.onThemeChanged
    _widgetOptions = <Widget>[
      const ContactsScreen(),
      const UssdCodesScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged), // Pass callback here
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Display the logo
        title: Row(
          children: [
            Image.asset(
              'assets/logos/generated_app_logo.png',
              height: 30, // Adjust height to fit AppBar
              errorBuilder: (context, error, stackTrace) => Icon(Icons.sim_card_outlined, color: Theme.of(context).colorScheme.onPrimary), // Fallback icon (modernized)
            ),
            // const SizedBox(width: 8),
            // Text(_appBarTitles[_selectedIndex]), // Optionally show screen title too
          ],
        ),
        // AppBar theme is handled by the main theme
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined), // Modernized icon
            activeIcon: Icon(Icons.contacts), // Optional: Filled icon when active
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad_outlined), // Modernized icon
            activeIcon: Icon(Icons.dialpad),
            label: 'USSD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), // Modernized icon
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        // Let the theme handle colors
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        onTap: _onItemTapped,
      ),
    );
  }
}

