import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

// Enum to represent the mobile operators
enum AlgerianMobileOperator {
  Djezzy,
  Mobilis,
  Ooredoo,
  Unknown
}

class OperatorDetector {

  // --- Operator Detection Logic ---

  /// Detects the operator based on the phone number prefix.
  static AlgerianMobileOperator detectOperator(String phoneNumber) {
    // Normalize the phone number: remove spaces, hyphens
    String normalizedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-\s*'), ''); // Improved regex

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

  // --- Tariff Loading and Cost Calculation Logic ---

  /// Loads the tariff data from the 'assets/data/tarifs.json' file.
  ///
  /// Returns a Map representing the parsed JSON data.
  /// Returns an empty map if loading or parsing fails.
  static Future<Map<String, dynamic>> loadTariffs() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/tarifs.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      return data;
    } catch (e) {
      print('Error loading or parsing tariffs.json: $e');
      return {};
    }
  }

  /// Calculates the estimated cost per minute for a call, considering bonuses.
  ///
  /// Uses the loaded tariff data, the selected calling SIM ('sim1' or 'sim2'),
  /// the destination phone number, and SharedPreferences to check for bonuses.
  /// Returns the cost as a double (0.0 if a relevant bonus applies), or a default high cost (e.g., 999.0) if tariffs are missing.
  static Future<double> calculateCallCost({
    required Map<String, dynamic> tariffsData,
    required String callingSimId, // 'sim1' or 'sim2'
    required String destinationNumber,
    required SharedPreferences prefs, // Pass SharedPreferences instance
  }) async {

    // --- Bonus Check --- 
    // Check for bonus credit on the calling SIM
    String? bonusCredit = prefs.getString('${callingSimId}_credit');
    // TODO: Add more sophisticated bonus logic:
    // - Check validity (prefs.getString('${callingSimId}_validity'))
    // - Differentiate bonus types (e.g., bonus towards specific networks)
    // - Consider data bonus for potential VoIP calls (complex)
    if (bonusCredit != null && bonusCredit.isNotEmpty) {
      // Simple check: If bonus is 'Illimité' or a positive number (assuming format like '500 DA')
      if (bonusCredit.toLowerCase() == 'illimité' || (double.tryParse(bonusCredit.split(' ')[0]) ?? 0) > 0) {
         print('Bonus credit found for $callingSimId, applying 0 cost.');
         return 0.0; // Bonus applies, call is considered free
      }
    }
    // --- End Bonus Check ---

    // --- Standard Tariff Calculation --- 
    final AlgerianMobileOperator destinationOperatorEnum = detectOperator(destinationNumber);
    final String destinationOperatorName = getOperatorName(destinationOperatorEnum);

    // Get the operator of the calling SIM (needed for operator_tariffs)
    final String callingSimOperator = tariffsData[callingSimId]?['operator'] ?? 'Unknown';

    // Get the standard tariffs based on the calling operator
    final Map<String, dynamic>? operatorTariffs = tariffsData['operator_tariffs']?[callingSimOperator];

    if (operatorTariffs == null) {
       print('Error: Standard tariff data not found for operator $callingSimOperator');
       // Fallback to SIM-specific tariffs if operator tariffs are missing
       final Map<String, dynamic>? simTariffs = tariffsData[callingSimId]?['tariffs_per_minute'];
       if (simTariffs == null) {
          print('Error: Tariff data not found for $callingSimId');
          return 999.0; // High cost indicating error
       }
       final String costKey = (destinationOperatorName == 'Unknown') ? 'Unknown' : destinationOperatorName;
       final double cost = (simTariffs[costKey] ?? simTariffs['Unknown'] ?? 999.0).toDouble();
       return cost;
    }

    // Get the cost for the destination operator from the standard operator tariffs
    final String costKey = (destinationOperatorName == 'Unknown') ? 'Unknown' : destinationOperatorName;
    final double cost = (operatorTariffs[costKey] ?? operatorTariffs['Unknown'] ?? 999.0).toDouble();

    return cost;
  }


  // --- Helper Functions ---

  /// Helper function to get the operator name as a string.
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

  /// Optional: Helper function to get a color associated with the operator.
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

