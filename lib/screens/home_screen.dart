import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/call_log_screen.dart'; // To be created
import 'package:tagsim/screens/ussd_codes_screen.dart'; // To be created
import 'package:tagsim/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Define the screens for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    ContactsScreen(),
    CallLogScreen(), // Placeholder for Call Log
    UssdCodesScreen(), // Placeholder for USSD Codes
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar might be removed or adapted depending on screen content
      // appBar: AppBar(
      //   title: const Text('TagSim'),
      // ),
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

