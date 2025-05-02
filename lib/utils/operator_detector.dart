import 'package:flutter/material.dart';

// Enum to represent the mobile operators
enum AlgerianMobileOperator {
  Djezzy,
  Mobilis,
  Ooredoo,
  Unknown
}

class OperatorDetector {
  // Function to detect the operator based on the phone number prefix
  static AlgerianMobileOperator detectOperator(String phoneNumber) {
    // Normalize the phone number: remove spaces, hyphens
    String normalizedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-'), '');

    // Remove international prefix if present (+213 or 00213)
    if (normalizedNumber.startsWith('+213')) {
      normalizedNumber = '0${normalizedNumber.substring(4)}';
    } else if (normalizedNumber.startsWith('00213')) {
      normalizedNumber = '0${normalizedNumber.substring(5)}';
    }

    // Ensure the number starts with '0' and has at least 3 digits (0 + prefix + number)
    if (!normalizedNumber.startsWith('0') || normalizedNumber.length < 3) {
      return AlgerianMobileOperator.Unknown;
    }

    // Extract the prefix (the digit after the initial '0')
    String prefix = normalizedNumber.substring(1, 2);

    // Determine the operator based on the prefix
    switch (prefix) {
      case '5':
        return AlgerianMobileOperator.Ooredoo;
      case '6':
        return AlgerianMobileOperator.Mobilis;
      case '7':
        return AlgerianMobileOperator.Djezzy;
      default:
        return AlgerianMobileOperator.Unknown;
    }
  }

  // Helper function to get the operator name as a string
  static String getOperatorName(AlgerianMobileOperator operator) {
    switch (operator) {
      case AlgerianMobileOperator.Djezzy:
        return 'Djezzy';
      case AlgerianMobileOperator.Mobilis:
        return 'Mobilis';
      case AlgerianMobileOperator.Ooredoo:
        return 'Ooredoo';
      default:
        return 'Unknown';
    }
  }

  // Optional: Helper function to get a color associated with the operator
  static Color getOperatorColor(AlgerianMobileOperator operator) {
    switch (operator) {
      case AlgerianMobileOperator.Djezzy:
        return Colors.red; // Example color
      case AlgerianMobileOperator.Mobilis:
        return Colors.blue; // Example color
      case AlgerianMobileOperator.Ooredoo:
        return Colors.orange; // Example color
      default:
        return Colors.grey;
    }
  }
}

