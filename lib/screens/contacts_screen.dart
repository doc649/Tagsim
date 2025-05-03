import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tagsim/models/contact_with_details.dart';
import 'package:tagsim/utils/operator_detector.dart';
import 'package:libphonenumber_plugin/libphonenumber_plugin.dart' as phone_util;
import 'package:libphonenumber_platform_interface/libphonenumber_platform_interface.dart'; // Import RegionInfo
import 'package:emoji_flag_converter/emoji_flag_converter.dart' as emoji_converter;
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactWithDetails> _allContactsWithDetails = []; // Store all contacts
  List<ContactWithDetails> _filteredContactsWithDetails = []; // Store filtered contacts
  bool _permissionDenied = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterContacts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      try {
        List<Contact> contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);

        List<ContactWithDetails> processedContacts = [];
        for (var contact in contacts) {
          if (contact.phones.isNotEmpty) {
            for (var phone in contact.phones) {
              if (phone.number.isNotEmpty) {
                String phoneNumber = phone.number;
                String? countryCode;
                String? flagEmoji;
                AlgerianMobileOperator operator = AlgerianMobileOperator.Unknown;

                try {
                  // Use default region 'DZ' as a hint for Algerian numbers
                  RegionInfo? regionInfo = await phone_util.PhoneNumberUtil.getRegionInfo(phoneNumber, 'DZ');
                  if (regionInfo != null && regionInfo.isoCode != null) {
                    countryCode = regionInfo.isoCode;
                    flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode(countryCode!);
                    if (countryCode == 'DZ') {
                      operator = OperatorDetector.detectOperator(phoneNumber);
                    }
                  }
                } catch (e) {
                  print('Error getting region info for phone number $phoneNumber: $e');
                  // Fallback for numbers not parsable by libphonenumber but potentially Algerian
                  if (phoneNumber.startsWith('+213') || phoneNumber.startsWith('00213') || phoneNumber.startsWith('0')) {
                     operator = OperatorDetector.detectOperator(phoneNumber);
                     if (operator != AlgerianMobileOperator.Unknown) {
                       countryCode = 'DZ';
                       flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode('DZ');
                     }
                  }
                }

                processedContacts.add(ContactWithDetails(
                  contact: contact,
                  phoneNumber: phoneNumber,
                  countryCode: countryCode,
                  countryFlagEmoji: flagEmoji,
                  operatorInfo: operator,
                ));
              }
            }
          }
        }
        processedContacts.sort((a, b) => a.contact.displayName.toLowerCase().compareTo(b.contact.displayName.toLowerCase()));

        setState(() {
          _allContactsWithDetails = processedContacts;
          _filteredContactsWithDetails = processedContacts; // Initially show all
          _isLoading = false;
        });
      } catch (e) {
        print('Error fetching contacts: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
    }
  }

  void _filterContacts() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContactsWithDetails = _allContactsWithDetails.where((details) {
        final nameMatch = details.contact.displayName.toLowerCase().contains(query);
        final numberMatch = details.phoneNumber?.toLowerCase().contains(query) ?? false;
        return nameMatch || numberMatch;
      }).toList();
    });
  }

  // Helper function to get logo path
  String? _getOperatorLogoPath(AlgerianMobileOperator operator) {
    switch (operator) {
      case AlgerianMobileOperator.Djezzy:
        return 'assets/logos/djezzy_logo.png';
      case AlgerianMobileOperator.Mobilis:
        return 'assets/logos/mobilis_logo.png';
      case AlgerianMobileOperator.Ooredoo:
        return 'assets/logos/ooredoo_logo.png';
      case AlgerianMobileOperator.Unknown:
      default:
        return null;
    }
  }

  // Helper function to launch URL (call or SMS)
  Future<void> _launchUniversalLink(Uri url) async {
    try {
      final bool nativeAppLaunchSucceeded = await launchUrl(
        url,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!nativeAppLaunchSucceeded) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Could not launch $url: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer l\'action pour ${url.scheme}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher des contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
                fillColor: Theme.of(context).colorScheme.surfaceVariant, // Use theme color
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchContacts,
        tooltip: 'Rafraîchir les contacts',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Permission d\'accès aux contacts refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Ouvrir les paramètres'),
              ),
              ElevatedButton(
                onPressed: _fetchContacts,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allContactsWithDetails.isEmpty) {
      return const Center(child: Text('Aucun contact trouvé.'));
    }

    if (_filteredContactsWithDetails.isEmpty && _searchController.text.isNotEmpty) {
       return const Center(child: Text('Aucun contact ne correspond à votre recherche.'));
    }

    return ListView.builder(
      itemCount: _filteredContactsWithDetails.length,
      itemBuilder: (context, index) {
        final details = _filteredContactsWithDetails[index];
        final contact = details.contact;
        final logoPath = _getOperatorLogoPath(details.operatorInfo);
        final phoneNumber = details.phoneNumber;

        return ListTile(
          title: Text(contact.displayName.isNotEmpty ? contact.displayName : '(Sans nom)'),
          subtitle: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
            children: [
              if (details.countryFlagEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(details.countryFlagEmoji!, style: const TextStyle(fontSize: 16)), // Slightly larger flag
                ),
              Expanded(child: Text(phoneNumber ?? 'Pas de numéro')),
              if (logoPath != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Image.asset(
                    logoPath,
                    height: 24, // Adjust height as needed
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 16), // Fallback icon
                  ),
                ),
            ],
          ),
          trailing: phoneNumber != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call),
                      tooltip: 'Appeler',
                      onPressed: () {
                        final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
                        _launchUniversalLink(callUri);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.message),
                      tooltip: 'Envoyer SMS',
                      onPressed: () {
                        final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
                        _launchUniversalLink(smsUri);
                      },
                    ),
                  ],
                )
              : null,
          // TODO: Add onTap for contact details screen
        );
      },
    );
  }
}

