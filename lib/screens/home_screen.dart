import 'package:flutter/material.dart';
import 'package:tagsim/screens/contacts_screen.dart';
import 'package:tagsim/screens/ussd_codes_screen.dart';
import 'package:tagsim/screens/settings_screen.dart';
import 'package:tagsim/screens/dashboard_screen.dart';
import 'package:tagsim/screens/offer_comparator_screen.dart';
import 'package:tagsim/services/telephony_service.dart'; // Import TelephonyService

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const ContactsScreen(),
      const UssdCodesScreen(),
      const OfferComparatorScreen(),
      const DashboardScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];
    // Check roaming status after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRoamingStatus();
    });
  }

  Future<void> _checkRoamingStatus() async {
    try {
      bool roaming = await TelephonyService.isRoaming();
      if (roaming && mounted) { // Check if mounted before showing dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Mode Voyage Détecté'),
              content: const Text(
                  'Il semble que vous soyez en itinérance (roaming). ' 
                  'Veuillez noter que les tarifs des appels et de la data peuvent être différents. '
                  'Certaines fonctionnalités de l\"application (comme les codes USSD) pourraient ne pas fonctionner correctement.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("Error checking roaming status in HomeScreen: $e");
      // Optionally show a less intrusive error message or log it
    }
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
            icon: Icon(Icons.local_offer_outlined),
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
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

