import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/call_log_screen.dart';
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
    'Journal d\appels',
    'Codes USSD',
    'Paramètres',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize _widgetOptions here to access widget.onThemeChanged
    _widgetOptions = <Widget>[
      const ContactsScreen(),
      const CallLogScreen(),
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
        // Display the logo and the title corresponding to the selected screen
        title: Row(
          children: [
            Image.asset(
              'assets/logos/generated_app_logo.png',
              height: 30, // Adjust height to fit AppBar
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.sim_card, color: Colors.white), // Fallback icon
            ),
            const SizedBox(width: 8),
            // Text(_appBarTitles[_selectedIndex]), // Optionally show screen title too
          ],
        ),
        // Keep the blue background and white foreground defined in main.dart theme
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: 'USSD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
        currentIndex: _selectedIndex,
        // Use fixed type for more than 3 items to keep labels visible
        type: BottomNavigationBarType.fixed,
        // Use theme colors for selected/unselected items
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

