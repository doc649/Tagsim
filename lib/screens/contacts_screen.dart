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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });
    await _recommender.loadTariffsIfNeeded();
    await _fetchContacts();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _normalizePhoneNumber(String rawNumber) async {
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

  Future<void> _fetchContacts() async {
    PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _allContactsWithDetails.clear();
          _filteredContactsWithDetails.clear();
        });
      }
      try {
        List<Contact> contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);

        List<ContactWithDetails> processedContacts = [];
        Map<String, ContactWithDetails> uniqueContactsByNumberMap = {};
        Set<String> processedNormalizedNumbersSet = {};

        for (var contact in contacts) {
          for (var phone in contact.phones) {
            if (phone.number.isNotEmpty) {
              String rawPhoneNumber = phone.number;
              String contactName = contact.displayName.isNotEmpty ? contact.displayName : "(No Name)"; // Get contact name or placeholder

              // --- Log before normalization ---
              print("DEBUG_CONTACT: Processing RawPhone='$rawPhoneNumber', ContactName='$contactName', ContactID='${contact.id}'");
              // --------------------------------

              String? normalizedNumber = await _normalizePhoneNumber(rawPhoneNumber);

              if (normalizedNumber == null) {
                 print("DEBUG_CONTACT: Skipping number due to normalization failure: Raw='$rawPhoneNumber', Contact='$contactName'");
                 continue;
              }

              // --- Explicit Duplicate Check using Set ---
              if (processedNormalizedNumbersSet.contains(normalizedNumber)) {
                print("DEBUG_CONTACT: Skipping duplicate normalized number (Set check): Norm='$normalizedNumber', Raw='$rawPhoneNumber', Contact='$contactName'");
                continue;
              }
              // -----------------------------------------

              processedNormalizedNumbersSet.add(normalizedNumber);
              print("DEBUG_CONTACT: Processing unique number: Norm='$normalizedNumber', Raw='$rawPhoneNumber', Contact='$contactName'");

              String? countryCode;
              String? flagEmoji;
              AlgerianMobileOperator operator = AlgerianMobileOperator.Unknown;

              try {
                RegionInfo? regionInfo = await phone_util.PhoneNumberUtil.getRegionInfo(normalizedNumber, 'DZ');
                if (regionInfo != null && regionInfo.isoCode != null) {
                  countryCode = regionInfo.isoCode;
                  if (countryCode != 'DZ') {
                    flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode(countryCode!);
                  }
                  if (countryCode == 'DZ') {
                    operator = OperatorDetector.detectOperator(normalizedNumber);
                  }
                }
              } catch (e) {
                print('Error getting region info for normalized number $normalizedNumber: $e');
                if (normalizedNumber.startsWith('+213')) {
                   operator = OperatorDetector.detectOperator(normalizedNumber);
                   if (operator != AlgerianMobileOperator.Unknown) {
                     countryCode = 'DZ';
                   }
                }
              }

              Map<SimChoice, String?> recommendationResult = await _recommender.getBestSim(normalizedNumber);
              SimChoice recommendation = recommendationResult.keys.first;
              String? errorMsg = recommendationResult.values.first;

              uniqueContactsByNumberMap[normalizedNumber] = ContactWithDetails(
                contact: contact,
                phoneNumber: normalizedNumber,
                countryCode: countryCode,
                countryFlagEmoji: flagEmoji,
                operatorInfo: operator,
                recommendedSim: recommendation,
                recommendationError: errorMsg,
              );

            }
          }
        }

        processedContacts = uniqueContactsByNumberMap.values.toList();
        // Sort primarily by name, then by number for contacts without names
        processedContacts.sort((a, b) {
          int nameCompare = a.contact.displayName.toLowerCase().compareTo(b.contact.displayName.toLowerCase());
          if (nameCompare == 0) {
            // If names are the same (or both empty), sort by phone number
            return (a.phoneNumber ?? '').compareTo(b.phoneNumber ?? '');
          }
          return nameCompare;
        });

        if (mounted) {
           setState(() {
            _allContactsWithDetails = processedContacts;
            _filteredContactsWithDetails = processedContacts;
          });
        }
      } catch (e) {
        print('Error fetching or processing contacts: $e');
         if (mounted) {
            setState(() {
              // Handle error state if needed
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
        // Use the detailed error message from the recommender logic
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
  }

  @override
  Widget build(BuildContext context) {
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
        tooltip: 'Rafraîchir les contacts et recommandations',
        child: const Icon(Icons.refresh_outlined),
      ),
    );
  }

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
        final phoneNumber = details.phoneNumber; // Normalized number

        // Determine display name: Use contact name if available, otherwise use the phone number
        final String displayName = contact.displayName.isNotEmpty ? contact.displayName : (phoneNumber ?? '(Numéro inconnu)');
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
              // Display normalized number in subtitle only if name is present
              if (contact.displayName.isNotEmpty)
                 Expanded(child: Text(phoneNumber ?? 'Numéro invalide')),
              // If no name, the number is already in the title, so don't repeat in subtitle (or show something else)
              if (contact.displayName.isEmpty)
                 const Expanded(child: Text('(Numéro affiché comme nom)')), // Placeholder or empty

              _buildRecommendationIndicator(details),
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

