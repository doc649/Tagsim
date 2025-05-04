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
    } catch (e) {
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

  // --- Reverted Display Formatting - Keep +213 for now ---
  // String _formatPhoneNumberForDisplay(String? normalizedNumber) { ... }
  // ------------------------------------------------------

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
              String contactName = contact.displayName.isNotEmpty ? contact.displayName : "(No Name)";

              print("FETCH_CONTACTS:     Normalizing '$rawPhoneNumber'...");
              String? normalizedNumber = await _normalizePhoneNumber(rawPhoneNumber);

              if (normalizedNumber == null) {
                 print("FETCH_CONTACTS:     Skipping number due to normalization failure: Raw='$rawPhoneNumber', Contact='$contactName'");
                 continue;
              }
              print("FETCH_CONTACTS:     Normalized to '$normalizedNumber'");

              if (processedNormalizedNumbersSet.contains(normalizedNumber)) {
                print("FETCH_CONTACTS:     Skipping duplicate normalized number (Set check): Norm='$normalizedNumber', Raw='$rawPhoneNumber', Contact='$contactName'");
                continue;
              }

              processedNormalizedNumbersSet.add(normalizedNumber);
              print("FETCH_CONTACTS:     Processing unique number: Norm='$normalizedNumber'");

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
              } catch (e) {
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
          int nameCompare = a.contact.displayName.toLowerCase().compareTo(b.contact.displayName.toLowerCase());
          if (nameCompare == 0) {
            return (a.phoneNumber ?? '').compareTo(b.phoneNumber ?? '');
          }
          return nameCompare;
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
        // Search in display name OR NORMALIZED phone number (reverted from formatted)
        final nameMatch = details.contact.displayName.toLowerCase().contains(query);
        final numberMatch = details.phoneNumber?.toLowerCase().contains(query) ?? false;
        return nameMatch || numberMatch;
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
          Expanded(child: _buildBodyContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeScreen,
        tooltip: 'Rafraîchir les contacts',
        child: const Icon(Icons.refresh_outlined),
      ),
    );
  }

  Widget _buildBodyContent() {
    print("ContactsScreen: _buildBodyContent called");
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
              const Icon(Icons.perm_contact_calendar_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Permission d\'accès aux contacts refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_outlined),
                onPressed: openAppSettings,
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
      print("ContactsScreen: Displaying 'Aucun contact trouvé.' message");
      return const Center(child: Text('Aucun contact trouvé.'));
    }

    if (_filteredContactsWithDetails.isEmpty && _searchController.text.isNotEmpty) {
       print("ContactsScreen: Displaying 'Aucun contact ne correspond à votre recherche.' message");
       return const Center(child: Text('Aucun contact ne correspond à votre recherche.'));
    }

    print("ContactsScreen: Displaying ListView with ${_filteredContactsWithDetails.length} items");
    return ListView.builder(
      itemCount: _filteredContactsWithDetails.length,
      itemBuilder: (context, index) {
        // print("ContactsScreen: Building item $index"); // Can be too verbose
        final details = _filteredContactsWithDetails[index];
        final contact = details.contact;
        final logoPath = _getOperatorLogoPath(details.operatorInfo);
        final phoneNumber = details.phoneNumber; // Normalized number stored internally

        // Reverted: Use normalized number directly for display for now
        final String numberToDisplay = phoneNumber ?? '(Numéro invalide)';

        // Determine display name: Use contact name if available, otherwise use the NORMALIZED phone number
        final String displayName = contact.displayName.isNotEmpty ? contact.displayName : numberToDisplay;
        final String leadingText = contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '#'; // Use '#' for contacts without name

        return ListTile(
          leading: CircleAvatar(
            child: Text(leadingText),
          ),
          title: Text(displayName),
          subtitle: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (details.countryFlagEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(details.countryFlagEmoji!, style: const TextStyle(fontSize: 16)),
                ),
              // Display NORMALIZED number in subtitle only if name is present
              if (contact.displayName.isNotEmpty)
                 Expanded(child: Text(numberToDisplay)), // Use normalized number
              // If no name, the number is already in the title, so don't repeat in subtitle
              if (contact.displayName.isEmpty)
                 const Expanded(child: SizedBox.shrink()), // Show nothing if name is empty

              _buildRecommendationIndicator(details), // This will now return SizedBox.shrink()
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
          trailing: phoneNumber != null // Use normalized number for actions
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call_outlined),
                      tooltip: 'Appeler',
                      onPressed: () {
                        if (phoneNumber != null) {
                          final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
                          _launchUniversalLink(callUri);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.message_outlined),
                      tooltip: 'Envoyer SMS',
                      onPressed: () {
                        if (phoneNumber != null) {
                          final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
                          _launchUniversalLink(smsUri);
                        }
                      },
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

