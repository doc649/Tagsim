import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/call_log_screen.dart';
import 'package:tagsim/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    ContactsScreen(), // Placeholder for Contacts Screen
    CallLogScreen(),   // Placeholder for Call Log Screen
    SettingsScreen(), // Placeholder for Settings Screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine the title based on the selected index
    String appBarTitle;
    switch (_selectedIndex) {
      case 0:
        appBarTitle = 'Contacts';
        break;
      case 1:
        appBarTitle = 'Call Log';
        break;
      case 2:
        appBarTitle = 'Settings';
        break;
      default:
        appBarTitle = 'TagSim';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        // Potentially add actions like search here later
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
            label: 'Call Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary, // Use primary blue color
        unselectedItemColor: Colors.grey, // Or another suitable color
        onTap: _onItemTapped,
      ),
    );
  }
}

