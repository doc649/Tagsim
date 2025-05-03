import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/ussd_codes_screen.dart';
import 'package:tagsim/screens/settings_screen.dart';
import 'package:tagsim/screens/dashboard_screen.dart';
import 'package:tagsim/screens/offer_comparator_screen.dart'; // Import the offer comparator screen

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  // Define titles for each screen (optional)
  // static const List<String> _appBarTitles = <String>[
  //   'Contacts',
  //   'Codes USSD',
  //   'Offres',
  //   'Dashboard',
  //   'Paramètres',
  // ];

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const ContactsScreen(),
      const UssdCodesScreen(),
      const OfferComparatorScreen(), // Add OfferComparatorScreen here
      const DashboardScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
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
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_logo_final.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.sim_card_outlined, color: Theme.of(context).colorScheme.onPrimary),
            ),
            // const SizedBox(width: 8),
            // Text(_appBarTitles[_selectedIndex]), // Optionally show screen title
          ],
        ),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad_outlined),
            activeIcon: Icon(Icons.dialpad),
            label: 'USSD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined), // Add Offer Comparator icon
            activeIcon: Icon(Icons.local_offer),
            label: 'Offres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Use fixed type for 5 items
        onTap: _onItemTapped,
      ),
    );
  }
}

