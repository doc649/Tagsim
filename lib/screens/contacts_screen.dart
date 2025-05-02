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
  List<ContactWithDetails> _contactsWithDetails = [];
  bool _permissionDenied = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
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
                  // Corrected: Use RegionInfo type and access isoCode directly
                  RegionInfo? regionInfo = await phone_util.PhoneNumberUtil.getRegionInfo(phoneNumber, '');

                  if (regionInfo != null && regionInfo.isoCode != null) {
                    countryCode = regionInfo.isoCode;
                    flagEmoji = emoji_converter.EmojiConverter.fromAlpha2CountryCode(countryCode!);

                    if (countryCode == 'DZ') {
                      operator = OperatorDetector.detectOperator(phoneNumber);
                    }
                  }
                } catch (e) {
                  print('Error getting region info for phone number $phoneNumber: $e');
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
        processedContacts.sort((a, b) => a.contact.displayName.compareTo(b.contact.displayName));

        setState(() {
          _contactsWithDetails = processedContacts;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchContacts,
        tooltip: 'Refresh Contacts',
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
                'Permission to access contacts was denied.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Open App Settings'),
              ),
              ElevatedButton(
                onPressed: _fetchContacts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contactsWithDetails.isEmpty) {
      return const Center(child: Text('No contacts found.'));
    }

    return ListView.builder(
      itemCount: _contactsWithDetails.length,
      itemBuilder: (context, index) {
        final details = _contactsWithDetails[index];
        final contact = details.contact;
        final operatorName = OperatorDetector.getOperatorName(details.operatorInfo);
        final operatorColor = OperatorDetector.getOperatorColor(details.operatorInfo);

        return ListTile(
          title: Text(contact.displayName.isNotEmpty ? contact.displayName : '(No name)'),
          subtitle: Row(
            children: [
              if (details.countryFlagEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(details.countryFlagEmoji!),
                ),
              Expanded(child: Text(details.phoneNumber ?? 'No number')),
              if (details.operatorInfo != AlgerianMobileOperator.Unknown)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    operatorName,
                    style: TextStyle(color: operatorColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

