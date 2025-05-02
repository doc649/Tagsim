import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:tagsim/utils/operator_detector.dart'; // Import the operator detector

class ContactWithDetails {
  final Contact contact; // Original contact data from flutter_contacts
  final String? phoneNumber; // The specific phone number being displayed
  final AlgerianMobileOperator operatorInfo; // Detected operator (if Algerian)
  final String? countryCode; // ISO 3166-1 alpha-2 country code (e.g., 'DZ', 'FR')
  final String? countryFlagEmoji; // Emoji flag for the country

  ContactWithDetails({
    required this.contact,
    this.phoneNumber,
    this.operatorInfo = AlgerianMobileOperator.Unknown,
    this.countryCode,
    this.countryFlagEmoji,
  });
}

