import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tagsim/models/contact_with_details.dart';
import 'package:tagsim/utils/operator_detector.dart';
import 'package:tagsim/logic/smart_call_recommender.dart'; // Import the recommender
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
  final SmartCallRecommender _recommender = SmartCallRecommender(); // Instantiate the recommender

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterContacts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    if (!mounted) return; // Check if the state is still mounted
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });
    await _fetchContacts();
    if (mounted) { // Check again if mounted after async operation
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchContacts() async {
    PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      // Clear lists before fetching to prevent duplicates on refresh
      if (mounted) {
        setState(() {
          _allContactsWithDetails.clear();
          _filteredContactsWithDetails.clear();
        });
      }
      try {
        List<Contact> contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);

        // Use local variables within the try block scope
        List<ContactWithDetails> processedContacts = [];
        Map<String, ContactWithDetails> uniqueContacts = {}; // Use Map to handle duplicates by contact ID

        for (var contact in contacts) {
          // Find the first non-empty phone number for this contact
          Phone? firstValidPhone;
          for (var phone in contact.phones) {
            if (phone.number.isNotEmpty) {
              firstValidPhone = phone;
              break; // Found the first valid one, exit the inner loop
            }
          }

          // Only process if a valid phone was found and the contact is not already processed
          if (firstValidPhone != null && !uniqueContacts.containsKey(contact.id)) {
            String phoneNumber = firstValidPhone.number;
            String? countryCode;
            String? flagEmoji;
            AlgerianMobileOperator operator = AlgerianMobileOperator.Unknown;

            try {
              RegionInfo? regionInfo = await phone_util.PhoneNumberUtil.getRegionInfo(phoneNumber, 'DZ');
              if (regionInfo != null && regionInfo.isoCode != null) {
                countryCode = regionInfo.isoCode;
                // Only set flag if country code is NOT DZ
                if (countryCode != 'DZ') {
                  flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode(countryCode!);
                }
                if (countryCode == 'DZ') {
                  operator = OperatorDetector.detectOperator(phoneNumber);
                }
              }
            } catch (e) {
              print('Error getting region info for phone number $phoneNumber: $e');
              // Fallback for Algerian numbers if region info fails
              if (phoneNumber.startsWith('+213') || phoneNumber.startsWith('00213') || phoneNumber.startsWith('0')) {
                 operator = OperatorDetector.detectOperator(phoneNumber);
                 if (operator != AlgerianMobileOperator.Unknown) {
                   countryCode = 'DZ'; // Assume DZ if operator detected
                   // Do not set flag for DZ
                 }
              }
            }

            print("Processing contact: ID=${contact.id}, Name=${contact.displayName}, Phone=$phoneNumber"); // Log processing

            // Get recommendation and potential error message
            Map<SimChoice, String?> recommendationResult = await _recommender.getBestSim(phoneNumber);
            SimChoice recommendation = recommendationResult.keys.first;
            String? errorMsg = recommendationResult.values.first;

            uniqueContacts[contact.id] = ContactWithDetails(
              contact: contact,
              phoneNumber: phoneNumber, // Store only the first number
              countryCode: countryCode,
              countryFlagEmoji: flagEmoji,
              operatorInfo: operator,
              recommendedSim: recommendation,
              recommendationError: errorMsg, // Store the error message
            );
            print("Added contact to map: ID=${contact.id}"); // Log addition
          } else {
            // Optionally log skipped contacts (already processed or no valid phone)
            if (firstValidPhone == null) {
              // print("Skipping contact with no valid phone: ID=${contact.id}, Name=${contact.displayName}");
            } else {
              // print("Skipping duplicate contact ID: ${contact.id}, Name=${contact.displayName}"); // Already logged if needed
            }
          }
        } // End of for loop

        processedContacts = uniqueContacts.values.toList(); // Convert map values back to list
        processedContacts.sort((a, b) => a.contact.displayName.toLowerCase().compareTo(b.contact.displayName.toLowerCase()));

        if (mounted) {
           setState(() {
            _allContactsWithDetails = processedContacts;
            _filteredContactsWithDetails = processedContacts;
          });
        }
      } catch (e) { // Correct catch block
        print('Error fetching contacts: $e');
         if (mounted) {
            setState(() {
              // Handle error state if needed, e.g., show a message
            });
         }
      }
    } else {
       if (mounted) {
          setState(() {
            _permissionDenied = true;
          });
       }
    }
  }

  void _filterContacts() {
    if (!mounted) return;
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContactsWithDetails = _allContactsWithDetails.where((details) {
        final nameMatch = details.contact.displayName.toLowerCase().contains(query);
        final numberMatch = details.phoneNumber?.toLowerCase().contains(query) ?? false;
        return nameMatch || numberMatch;
      }).toList();
    });
  }

  String? _getOperatorLogoPath(AlgerianMobileOperator operator) {
    switch (operator) {
      case AlgerianMobileOperator.Djezzy:
        return 'assets/images/djezzy_logo.png';
      case AlgerianMobileOperator.Mobilis:
        return 'assets/images/mobilis_logo.png';
      case AlgerianMobileOperator.Ooredoo:
        return 'assets/images/ooredoo_logo.png';
      case AlgerianMobileOperator.Unknown:
      default:
        return null;
    }
  }

   Future<void> _launchUniversalLink(Uri url) async {
    print("Attempting to launch URL: $url"); // Log start
    try {
      print("Trying to launch in external non-browser app..."); // Log native attempt
      final bool nativeAppLaunchSucceeded = await launchUrl(
        url,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!nativeAppLaunchSucceeded) {
        print("Native app launch failed, trying external application..."); // Log fallback attempt
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        print("Launched in external application."); // Log success fallback
      } else {
        print("Launched successfully in native app."); // Log success native
      }
    } catch (e, stacktrace) { // Added stacktrace
      print("Could not launch $url: $e\n$stacktrace"); // Log error with stacktrace
      if (mounted) {
        // Use ScaffoldMessenger safely
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text("Impossible de lancer l'action pour ${url.scheme}")),
          );
        }
      }
    }
  }

  Widget _buildRecommendationIndicator(ContactWithDetails details) {
    SimChoice recommendation = details.recommendedSim ?? SimChoice.none;
    String? errorMsg = details.recommendationError;
    IconData iconData;
    Color iconColor;
    String tooltip;

    switch (recommendation) {
      case SimChoice.sim1:
        iconData = Icons.looks_one_outlined;
        iconColor = Colors.green;
        tooltip = 'SIM 1 recommandée (coût/bonus)';
        break;
      case SimChoice.sim2:
        iconData = Icons.looks_two_outlined;
        iconColor = Colors.blue;
        tooltip = 'SIM 2 recommandée (coût/bonus)';
        break;
      case SimChoice.none:
        iconData = Icons.money_off_outlined;
        iconColor = Colors.red;
        tooltip = 'Aucune SIM recommandée (crédit insuffisant?)';
        break;
      case SimChoice.error:
        iconData = Icons.error_outline;
        iconColor = Colors.orange;
        tooltip = errorMsg ?? 'Erreur lors du calcul de la recommandation'; // Use specific error message
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
    );
  }

  // This is the main build method for the State
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar as it's likely handled by the main navigation structure
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher des contacts...',
                prefixIcon: const Icon(Icons.search_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Expanded(child: _buildBodyContent()), // Delegate body to separate method
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeScreen, // Refresh action
        tooltip: 'Rafraîchir les contacts et recommandations',
        child: const Icon(Icons.refresh_outlined),
      ),
    );
  }

  // Helper method to build the main content area (list or messages)
  Widget _buildBodyContent() {
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
              const Icon(Icons.perm_contact_calendar_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Permission d\'accès aux contacts refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_outlined),
                onPressed: openAppSettings, // Function from permission_handler
                label: const Text('Ouvrir les paramètres'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_outlined),
                onPressed: _initializeScreen,
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allContactsWithDetails.isEmpty && !_isLoading) {
      return const Center(child: Text('Aucun contact trouvé.'));
    }

    if (_filteredContactsWithDetails.isEmpty && _searchController.text.isNotEmpty) {
       return const Center(child: Text('Aucun contact ne correspond à votre recherche.'));
    }

    // Display the list using filtered contacts
    return ListView.builder(
      itemCount: _filteredContactsWithDetails.length,
      itemBuilder: (context, index) {
        final details = _filteredContactsWithDetails[index];
        final contact = details.contact;
        final logoPath = _getOperatorLogoPath(details.operatorInfo);
        final phoneNumber = details.phoneNumber;

        return ListTile(
          leading: CircleAvatar(
            child: Text(contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?'),
          ),
          title: Text(contact.displayName.isNotEmpty ? contact.displayName : '(Sans nom)'),
          subtitle: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Flag (only if not DZ)
              if (details.countryFlagEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(details.countryFlagEmoji!, style: const TextStyle(fontSize: 16)),
                ),
              // Phone Number (Expanded)
              Expanded(child: Text(phoneNumber ?? 'Pas de numéro')), // Handle null phone number
              // Recommendation Indicator
              _buildRecommendationIndicator(details),
              // Operator Logo
              if (logoPath != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Image.asset(
                    logoPath,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, size: 16),
                  ),
                ),
            ],
          ),
          trailing: phoneNumber != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Call Button
                    IconButton(
                      icon: const Icon(Icons.call_outlined),
                      tooltip: 'Appeler',
                      onPressed: () {
                        // Ensure phone number is not null before attempting call
                        if (phoneNumber != null) {
                          final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
                          _launchUniversalLink(callUri);
                        }
                      },
                    ),
                    // SMS Button
                    IconButton(
                      icon: const Icon(Icons.message_outlined),
                      tooltip: 'Envoyer SMS',
                      onPressed: () {
                        // Ensure phone number is not null before attempting SMS
                        if (phoneNumber != null) {
                          final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
                          _launchUniversalLink(smsUri);
                        }
                      },
                    ),
                  ],
                )
              : null, // No trailing icons if phone number is null
        );
      },
    );
  }
}

