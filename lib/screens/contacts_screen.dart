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
  // final SmartCallRecommender _recommender = SmartCallRecommender(); // Instantiate the recommender - Temporarily disabled

  @override
  void initState() {
    super.initState();
    print("ContactsScreen: initState called");
    _initializeScreen();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    print("ContactsScreen: dispose called");
    _searchController.removeListener(_filterContacts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    print("ContactsScreen: _initializeScreen started");
    if (!mounted) {
      print("ContactsScreen: _initializeScreen aborted (not mounted)");
      return;
    }
    setState(() {
      print("ContactsScreen: Setting _isLoading = true");
      _isLoading = true;
      _permissionDenied = false;
    });
    try {
      // print("ContactsScreen: Loading tariffs...");
      // await _recommender.loadTariffsIfNeeded(); // Temporarily disabled
      // print("ContactsScreen: Tariffs loaded (or skipped if already loaded)");
      print("ContactsScreen: Fetching contacts...");
      await _fetchContacts();
      print("ContactsScreen: Contacts fetched");
    } catch (e, stacktrace) {
      print("ContactsScreen: Error during _initializeScreen (contact fetch): $e\n$stacktrace");
    }
    if (mounted) {
      setState(() {
        print("ContactsScreen: Setting _isLoading = false");
        _isLoading = false;
      });
    } else {
      print("ContactsScreen: _initializeScreen finished but not mounted after async operations");
    }
    print("ContactsScreen: _initializeScreen finished");
  }

  Future<String?> _normalizePhoneNumber(String rawNumber) async {
    // ... (keep existing normalization logic with its logs)
    if (rawNumber.isEmpty) return null;
    try {
      String? normalized = await phone_util.PhoneNumberUtil.normalizePhoneNumber(rawNumber, 'DZ');
      if (normalized != null) {
        return normalized;
      }
    } catch (e, stacktrace) {
      print("Could not normalize number '$rawNumber' using libphonenumber: $e. Using basic cleanup.");
      String cleaned = rawNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
      if (cleaned.startsWith('0') && cleaned.length == 10) {
         cleaned = '+213${cleaned.substring(1)}';
         print("Fallback normalized '$rawNumber' to '$cleaned'");
         return cleaned;
      }
      print("Fallback normalization failed for '$rawNumber'. Skipping number.");
      return null;
    }
    print("Normalization resulted in null for '$rawNumber'. Skipping number.");
    return null;
  }

  // Helper function to format number for display
  String _formatPhoneNumberForDisplay(String? normalizedNumber) {
    if (normalizedNumber == null) {
      return '(Numéro invalide)';
    }
    if (normalizedNumber.startsWith('+213') && normalizedNumber.length == 13) {
      // Algerian number, format to local 0...
      return '0${normalizedNumber.substring(4)}';
    }
    // For other numbers, return the normalized format
    return normalizedNumber;
  }

  Future<void> _fetchContacts() async {
    print("FETCH_CONTACTS: Starting _fetchContacts");
    PermissionStatus status = await Permission.contacts.request();
    print("FETCH_CONTACTS: Permission status: $status");

    if (status.isGranted) {
      print("FETCH_CONTACTS: Permission granted");
      if (mounted) {
        print("FETCH_CONTACTS: Clearing existing contact lists (setState)");
        setState(() {
          _allContactsWithDetails.clear();
          _filteredContactsWithDetails.clear();
        });
      }
      try {
        print("FETCH_CONTACTS: Calling FlutterContacts.getContacts...");
        List<Contact> contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);
        print("FETCH_CONTACTS: Got ${contacts.length} contacts from plugin");

        List<ContactWithDetails> processedContacts = [];
        Map<String, ContactWithDetails> uniqueContactsByNumberMap = {};
        Set<String> processedNormalizedNumbersSet = {};
        int contactIndex = 0;

        for (var contact in contacts) {
          contactIndex++;
          print("FETCH_CONTACTS: Processing contact ${contactIndex}/${contacts.length}, ID: ${contact.id}, Name: ${contact.displayName}");
          int phoneIndex = 0;
          for (var phone in contact.phones) {
            phoneIndex++;
            print("FETCH_CONTACTS:   Phone ${phoneIndex}/${contact.phones.length}: ${phone.number}");
            if (phone.number.isNotEmpty) {
              String rawPhoneNumber = phone.number;
              // Use displayName directly, check for emptiness later during display
              // String contactName = contact.displayName.isNotEmpty ? contact.displayName : "(No Name)";

              print("FETCH_CONTACTS:     Normalizing '$rawPhoneNumber'...");
              String? normalizedNumber = await _normalizePhoneNumber(rawPhoneNumber);

              if (normalizedNumber == null) {
                 print("FETCH_CONTACTS:     Skipping number due to normalization failure: Raw='$rawPhoneNumber', Contact='${contact.displayName}'");
                 continue;
              }
              print("FETCH_CONTACTS:     Normalized to '$normalizedNumber'");

              // Vérifier si une entrée existe déjà et si on doit la mettre à jour
              ContactWithDetails? existingDetails = uniqueContactsByNumberMap[normalizedNumber];
              bool shouldProcessThisContact = true; // On traite sauf si on saute explicitement

              if (existingDetails != null) {
                // Numéro dupliqué trouvé
                bool contactHasName = contact.displayName.isNotEmpty;
                bool existingHasName = existingDetails.contact.displayName.isNotEmpty;

                if (contactHasName && !existingHasName) {
                  // Le contact actuel a un nom, l'existant n'en avait pas. On priorise celui avec nom.
                  print("FETCH_CONTACTS:     Prioritizing contact with name for '$normalizedNumber'. Replacing previous entry (Name: '${contact.displayName}', Prev Name: '${existingDetails.contact.displayName}')");
                  // On laisse shouldProcessThisContact à true pour écraser l'entrée plus bas
                } else {
                  // On garde l'entrée existante (soit elle avait déjà un nom, soit le nouveau n'en a pas)
                  print("FETCH_CONTACTS:     Skipping duplicate '$normalizedNumber'. Existing entry is preferred (Existing Name: '${existingDetails.contact.displayName}', Current Name: '${contact.displayName}')");
                  shouldProcessThisContact = false; // On saute le traitement de ce contact
                }
              } else {
                 print("FETCH_CONTACTS:     Processing unique number: Norm='$normalizedNumber'");
                 // On laisse shouldProcessThisContact à true
              }

              // On continue seulement si c'est un nouveau numéro ou si une mise à jour est nécessaire
              if (shouldProcessThisContact) {
                  String? countryCode;
                  String? flagEmoji;
                  AlgerianMobileOperator operator = AlgerianMobileOperator.Unknown;

              try {
                print("FETCH_CONTACTS:       Getting region info for '$normalizedNumber'...");
                RegionInfo? regionInfo = await phone_util.PhoneNumberUtil.getRegionInfo(normalizedNumber, 'DZ');
                if (regionInfo != null && regionInfo.isoCode != null) {
                  countryCode = regionInfo.isoCode;
                  print("FETCH_CONTACTS:       Region info: Code=$countryCode");
                  if (countryCode != 'DZ') {
                    flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode(countryCode!);
                  }
                  if (countryCode == 'DZ') {
                    operator = OperatorDetector.detectOperator(normalizedNumber);
                    print("FETCH_CONTACTS:       Detected operator (DZ): $operator");
                  }
                } else {
                  print("FETCH_CONTACTS:       Region info was null or had no isoCode");
                }
              } catch (e, stacktrace) {
                print('FETCH_CONTACTS:       Error getting region info for normalized number $normalizedNumber: $e');
                if (normalizedNumber.startsWith('+213')) {
                   operator = OperatorDetector.detectOperator(normalizedNumber);
                   print("FETCH_CONTACTS:       Detected operator (DZ fallback): $operator");
                   if (operator != AlgerianMobileOperator.Unknown) {
                     countryCode = 'DZ';
                   }
                }
              }

              // --- Temporarily Disable Recommendation --- //
              // print("FETCH_CONTACTS:       Getting recommendation for '$normalizedNumber'...");
              // Map<SimChoice, String?> recommendationResult = await _recommender.getBestSim(normalizedNumber);
              // SimChoice recommendation = recommendationResult.keys.first;
              // String? errorMsg = recommendationResult.values.first;
              // print("FETCH_CONTACTS:       Recommendation: $recommendation, Error: $errorMsg");
              SimChoice recommendation = SimChoice.none; // Default to none
              String? errorMsg = null;
              // ------------------------------------------ //

              print("FETCH_CONTACTS:       Adding to uniqueContactsByNumberMap: Key='$normalizedNumber'");
              uniqueContactsByNumberMap[normalizedNumber] = ContactWithDetails(
                contact: contact,
                phoneNumber: normalizedNumber, // Store normalized number internally
                countryCode: countryCode,
                countryFlagEmoji: flagEmoji,
                operatorInfo: operator,
                recommendedSim: recommendation, // Use default value
                recommendationError: errorMsg, // Use default value
              );
              print("FETCH_CONTACTS:       Added successfully.");

            } else {
              print("FETCH_CONTACTS:   Skipping empty phone number.");
            }
          }
          print("FETCH_CONTACTS: Finished processing phones for contact ${contactIndex}");
        }
        print("FETCH_CONTACTS: Finished processing all contacts. Found ${uniqueContactsByNumberMap.length} unique numbers.");

        processedContacts = uniqueContactsByNumberMap.values.toList();
        print("FETCH_CONTACTS: Sorting ${processedContacts.length} processed contacts...");
        processedContacts.sort((a, b) {
          // Sort primarily by display name, treating empty names consistently
          bool aHasName = a.contact.displayName.isNotEmpty;
          bool bHasName = b.contact.displayName.isNotEmpty;
          if (aHasName && !bHasName) return -1; // Contacts with names first
          if (!aHasName && bHasName) return 1;  // Contacts without names last
          if (aHasName && bHasName) { // Both have names, sort alphabetically
            int nameCompare = a.contact.displayName.toLowerCase().compareTo(b.contact.displayName.toLowerCase());
            if (nameCompare != 0) return nameCompare;
          }
          // If names are the same or both are empty, sort by phone number
          return (a.phoneNumber ?? '').compareTo(b.phoneNumber ?? '');
        });
        print("FETCH_CONTACTS: Sorting complete.");

        if (mounted) {
           print("FETCH_CONTACTS: Updating state with ${processedContacts.length} contacts (setState)");
           setState(() {
            _allContactsWithDetails = processedContacts;
            _filteredContactsWithDetails = processedContacts;
          });
           print("FETCH_CONTACTS: setState completed.");
        } else {
           print("FETCH_CONTACTS: Not mounted after processing contacts, cannot update state.");
        }
      } catch (e, stacktrace) {
        print('FETCH_CONTACTS: CRITICAL ERROR fetching or processing contacts: $e\n$stacktrace');
         if (mounted) {
            print("FETCH_CONTACTS: Setting state to show error (optional)");
            setState(() {
              // Optionally set an error state here to display a message
              // e.g., _showError = true; _errorMessage = e.toString();
            });
         }
      }
    } else {
       print("FETCH_CONTACTS: Permission denied");
       if (mounted) {
          print("FETCH_CONTACTS: Setting _permissionDenied = true (setState)");
          setState(() {
            _permissionDenied = true;
          });
       }
    }
    print("FETCH_CONTACTS: Finished _fetchContacts");
  }

  void _filterContacts() {
    if (!mounted) return;
    String query = _searchController.text.toLowerCase();
    print("ContactsScreen: Filtering contacts with query: '$query'");
    setState(() {
      _filteredContactsWithDetails = _allContactsWithDetails.where((details) {
        // Determine the primary display text (name or formatted number)
        final bool hasName = details.contact.displayName.isNotEmpty;
        final String formattedNumber = _formatPhoneNumberForDisplay(details.phoneNumber);
        final String primaryText = hasName ? details.contact.displayName : formattedNumber;

        // Search in primary display text OR the secondary number if a name exists
        final primaryMatch = primaryText.toLowerCase().contains(query);
        final secondaryNumberMatch = hasName ? formattedNumber.toLowerCase().contains(query) : false;

        return primaryMatch || secondaryNumberMatch;
      }).toList();
    });
    print("ContactsScreen: Filtering complete, ${_filteredContactsWithDetails.length} results.");
  }

  String? _getOperatorLogoPath(AlgerianMobileOperator operator) {
    // ... (keep existing logo logic)
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
    // ... (keep existing launch logic)
    print("Attempting to launch URL: $url");
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
    } catch (e, stacktrace) {
      print("Could not launch $url: $e\n$stacktrace");
      if (mounted) {
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
    // --- Temporarily Disable Recommendation Display --- //
    return const SizedBox.shrink(); // Return empty widget
    // ------------------------------------------------ //

    /* // Original logic kept for reference
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
        tooltip = errorMsg ?? 'Erreur inconnue de recommandation';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
    );
    */
  }

  Widget _buildBodyContent() {
    print("ContactsScreen: _buildBodyContent called (_isLoading: $_isLoading, _permissionDenied: $_permissionDenied, _filteredContacts: ${_filteredContactsWithDetails.length})");
    if (_isLoading) {
      print("ContactsScreen: Displaying loading indicator");
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      print("ContactsScreen: Displaying permission denied message");
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
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  print("ContactsScreen: Opening app settings...");
                  openAppSettings();
                },
                child: const Text('Ouvrir les paramètres'),
              ),
            ],
          ),
        ),
      );
    }
    if (_filteredContactsWithDetails.isEmpty && _searchController.text.isEmpty) {
      print("ContactsScreen: Displaying 'Aucun contact trouvé' message");
      return const Center(child: Text('Aucun contact trouvé.'));
    }
    if (_filteredContactsWithDetails.isEmpty && _searchController.text.isNotEmpty) {
      print("ContactsScreen: Displaying 'Aucun résultat' message for search");
      return const Center(child: Text('Aucun résultat pour votre recherche.'));
    }

    print("ContactsScreen: Building contact list with ${_filteredContactsWithDetails.length} items");
    return ListView.builder(
      itemCount: _filteredContactsWithDetails.length,
      itemBuilder: (context, index) {
        final details = _filteredContactsWithDetails[index];
        final contact = details.contact;
        final formattedNumber = _formatPhoneNumberForDisplay(details.phoneNumber);
        final bool hasName = contact.displayName.isNotEmpty;

        // Determine title and subtitle based on whether the contact has a name
        final String titleText = hasName ? contact.displayName : formattedNumber;
        final String? subtitleText = hasName ? formattedNumber : null; // Subtitle is null if no name

        final logoPath = _getOperatorLogoPath(details.operatorInfo);

        return ListTile(
          leading: CircleAvatar(
            // Placeholder for contact photo or initials
            child: Text(hasName ? contact.displayName[0].toUpperCase() : '#'),
          ),
          title: Row(
            children: [
              Expanded(child: Text(titleText)),
              if (details.countryFlagEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(details.countryFlagEmoji!),
                ),
              if (logoPath != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Image.asset(logoPath, height: 16),
                ),
              // _buildRecommendationIndicator(details), // Recommendation disabled
            ],
          ),
          subtitle: subtitleText != null ? Text(subtitleText) : null, // Only show subtitle if it's not null
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.call_outlined),
                onPressed: () {
                  if (details.phoneNumber != null) {
                    _launchUniversalLink(Uri(scheme: 'tel', path: details.phoneNumber));
                  }
                },
                tooltip: 'Appeler',
              ),
              IconButton(
                icon: const Icon(Icons.message_outlined),
                onPressed: () {
                  if (details.phoneNumber != null) {
                    _launchUniversalLink(Uri(scheme: 'sms', path: details.phoneNumber));
                  }
                },
                tooltip: 'Envoyer SMS',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("ContactsScreen: build called (_isLoading: $_isLoading, _permissionDenied: $_permissionDenied, _filteredContacts: ${_filteredContactsWithDetails.length})");
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher des contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _initializeScreen,
              child: _buildBodyContent(),
            ),
          ),
        ],
      ),
    );
  }
}

