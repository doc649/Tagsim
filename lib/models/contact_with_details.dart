import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:tagsim/utils/operator_detector.dart'; // Assuming AlgerianMobileOperator enum is here
import 'package:tagsim/logic/smart_call_recommender.dart'; // Import SimChoice

class ContactWithDetails {
  final Contact contact;
  final String? phoneNumber;
  final String? countryCode;
  final String? countryFlagEmoji;
  final AlgerianMobileOperator operatorInfo;
  SimChoice? recommendedSim; // Added field for recommendation
  String? recommendationError; // Added field for error message

  ContactWithDetails({
    required this.contact,
    this.phoneNumber,
    this.countryCode,
    this.countryFlagEmoji,
    this.operatorInfo = AlgerianMobileOperator.Unknown,
    this.recommendedSim,
    this.recommendationError, // Added to constructor
  });
}

