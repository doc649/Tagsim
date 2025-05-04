import 'dart:convert';
import 'dart:io'; // Import for FileSystemException

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, PlatformException;
import 'package:shared_preferences/shared_preferences.dart';

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
    String normalizedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-\s*'), '');

    if (normalizedNumber.startsWith('+213')) {
      normalizedNumber = '0${normalizedNumber.substring(4)}';
    } else if (normalizedNumber.startsWith('00213')) {
      normalizedNumber = '0${normalizedNumber.substring(5)}';
    }

    if (!normalizedNumber.startsWith('0') || normalizedNumber.length < 3) {
      return AlgerianMobileOperator.Unknown;
    }

    String prefix = normalizedNumber.substring(1, 2);

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
  /// Returns a Map containing the parsed JSON data.
  /// Throws a detailed exception if loading or parsing fails.
  static Future<Map<String, dynamic>> loadTariffs() async {
    const String assetPath = 'assets/data/tarifs.json';
    print("Attempting to load tariffs from: $assetPath"); // Log start
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      print("Successfully loaded tariff file content."); // Log success load
      if (jsonString.isEmpty) {
        print("Error: Tariff file '$assetPath' is empty.");
        throw Exception("Tariff file is empty");
      }
      try {
        final Map<String, dynamic> data = json.decode(jsonString);
        print("Successfully parsed tariff JSON data."); // Log success parse
        if (data.isEmpty) {
           print("Warning: Parsed tariff data is an empty map.");
           // Decide if this is an error or acceptable
           // throw Exception("Parsed tariff data is empty");
        }
        return data;
      } on FormatException catch (e) {
        print("Error parsing tariff JSON from '$assetPath': $e");
        throw Exception("Invalid JSON format in tariff file: ${e.message}");
      }
    } on FlutterError catch (e) { // More specific catch for asset loading errors
       print("Error loading asset '$assetPath': $e");
       if (e.message.contains("Unable to load asset")) {
         throw Exception("Tariff file not found at '$assetPath'");
       } else {
         throw Exception("Asset loading error: ${e.message}");
       }
    } catch (e) {
      print("Unexpected error loading or parsing '$assetPath': $e");
      throw Exception("Unexpected error loading tariffs: ${e.toString()}");
    }
  }

  /// Calculates the estimated cost per minute for a call, considering bonuses.
  ///
  /// Returns the cost as a double (0.0 if a relevant bonus applies), or a default high cost (e.g., 999.0) if tariffs are missing.
  static Future<double> calculateCallCost({
    required Map<String, dynamic> tariffsData,
    required String callingSimId, // 'sim1' or 'sim2'
    required String destinationNumber,
    required SharedPreferences prefs,
  }) async {

    // --- Bonus Check --- 
    String? bonusCredit = prefs.getString('${callingSimId}_credit');
    if (bonusCredit != null && bonusCredit.isNotEmpty) {
      if (bonusCredit.toLowerCase() == 'illimité' || (double.tryParse(bonusCredit.split(' ')[0]) ?? 0) > 0) {
         print('Bonus credit found for $callingSimId, applying 0 cost.');
         return 0.0;
      }
    }
    // --- End Bonus Check ---

    // --- Standard Tariff Calculation --- 
    if (tariffsData.isEmpty) {
      print('Error: Cannot calculate cost, tariffsData is empty.');
      return 999.0; // Indicate error due to missing tariffs
    }

    final AlgerianMobileOperator destinationOperatorEnum = detectOperator(destinationNumber);
    final String destinationOperatorName = getOperatorName(destinationOperatorEnum);
    final String callingSimOperator = tariffsData[callingSimId]?['operator'] ?? 'Unknown';

    if (callingSimOperator == 'Unknown') {
       print('Error: Calling SIM operator is Unknown for $callingSimId.');
       // Maybe fallback to SIM-specific tariffs directly?
    }

    final Map<String, dynamic>? operatorTariffs = tariffsData['operator_tariffs']?[callingSimOperator];

    if (operatorTariffs == null) {
       print('Error: Standard tariff data not found for operator $callingSimOperator. Falling back to SIM tariffs.');
       final Map<String, dynamic>? simTariffs = tariffsData[callingSimId]?['tariffs_per_minute'];
       if (simTariffs == null) {
          print('Error: Tariff data not found for $callingSimId either.');
          return 999.0;
       }
       final String costKey = (destinationOperatorName == 'Unknown') ? 'Unknown' : destinationOperatorName;
       final double cost = (simTariffs[costKey] ?? simTariffs['Unknown'] ?? 999.0).toDouble();
       print('Calculated cost (SIM fallback): $cost for $callingSimId to $destinationOperatorName ($destinationNumber)');
       return cost;
    }

    final String costKey = (destinationOperatorName == 'Unknown') ? 'Unknown' : destinationOperatorName;
    final double cost = (operatorTariffs[costKey] ?? operatorTariffs['Unknown'] ?? 999.0).toDouble();
    print('Calculated cost (Operator): $cost for $callingSimId ($callingSimOperator) to $destinationOperatorName ($destinationNumber)');
    return cost;
  }


  // --- Helper Functions ---

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

  static Color getOperatorColor(AlgerianMobileOperator operator) {
    switch (operator) {
      case AlgerianMobileOperator.Djezzy:
        return Colors.red;
      case AlgerianMobileOperator.Mobilis:
        return Colors.blue;
      case AlgerianMobileOperator.Ooredoo:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

