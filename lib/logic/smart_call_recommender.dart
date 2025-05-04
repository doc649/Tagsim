import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:tagsim/utils/operator_detector.dart'; // Updated path
import 'package:tagsim/services/user_preferences.dart';

enum SimChoice {
  sim1,
  sim2,
  none, // Neither SIM is suitable or has enough credit/bonus
  error // Error during calculation
}

class SmartCallRecommender {
  Map<String, dynamic>? _tariffs;

  SmartCallRecommender(); // Constructor

  // Public method to load tariffs if not already loaded
  Future<void> loadTariffsIfNeeded() async {
    if (_tariffs == null) { // Only load if null
      print("Tariffs are null, attempting to load...");
      _tariffs = await OperatorDetector.loadTariffs();
      if (_tariffs == null || _tariffs!.isEmpty) {
         print("Error: Tariffs loaded as null or empty after attempt.");
         // Keep _tariffs as null or empty to trigger error in getBestSim
      } else {
         print("Tariffs loaded successfully during initialization.");
      }
    } else {
       print("Tariffs already loaded, skipping reload.");
    }
  }

  // Main method to get the best SIM recommendation and potential error message
  Future<Map<SimChoice, String?>> getBestSim(String destinationNumber) async {
    print("--- Calculating best SIM for $destinationNumber ---");
    try {
      // Ensure tariffs are loaded. This might be redundant if called in initState, but safe.
      await loadTariffsIfNeeded(); // Call the public method

      if (_tariffs == null || _tariffs!.isEmpty) {
        String errorMsg = "Error: Tariffs could not be loaded or are empty.";
        print(errorMsg);
        return {SimChoice.error: errorMsg};
      }
      print("Tariffs check passed in getBestSim."); // Confirm check passed

      // --- Get User Preferences --- //
      final double sim1Credit = UserPreferences.getSim1Credit();
      final String? sim1BonusType = UserPreferences.getSim1BonusType();
      final String? sim1BonusAmount = UserPreferences.getSim1BonusAmount();
      final String? sim1BonusValidityStr = UserPreferences.getSim1BonusValidity();

      final double sim2Credit = UserPreferences.getSim2Credit();
      final String? sim2BonusType = UserPreferences.getSim2BonusType();
      final String? sim2BonusAmount = UserPreferences.getSim2BonusAmount();
      final String? sim2BonusValidityStr = UserPreferences.getSim2BonusValidity();

      final int estimatedDuration = UserPreferences.getEstimatedDuration();
      print("Preferences: SIM1(Credit: $sim1Credit, Bonus: $sim1BonusType, $sim1BonusAmount, $sim1BonusValidityStr), SIM2(Credit: $sim2Credit, Bonus: $sim2BonusType, $sim2BonusAmount, $sim2BonusValidityStr), Duration: $estimatedDuration");

      // Get SharedPreferences instance needed for calculateCallCost
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // --- Calculate Base Costs (Per Minute) using static method and named parameters --- //
      double sim1CostPerMinute = await OperatorDetector.calculateCallCost(
        tariffsData: _tariffs!,
        callingSimId: 'sim1',
        destinationNumber: destinationNumber,
        prefs: prefs,
      );
      double sim2CostPerMinute = await OperatorDetector.calculateCallCost(
        tariffsData: _tariffs!,
        callingSimId: 'sim2',
        destinationNumber: destinationNumber,
        prefs: prefs,
      );
      print("Costs per minute: SIM1=$sim1CostPerMinute, SIM2=$sim2CostPerMinute");

      // --- Factor in Bonuses --- //
      bool sim1BonusApplies = _isBonusApplicable(sim1BonusType, sim1BonusAmount, sim1BonusValidityStr, estimatedDuration);
      bool sim2BonusApplies = _isBonusApplicable(sim2BonusType, sim2BonusAmount, sim2BonusValidityStr, estimatedDuration);
      print("Bonus applicability: SIM1=$sim1BonusApplies, SIM2=$sim2BonusApplies");

      // --- Calculate Adjusted Costs for Estimated Duration --- //
      double sim1AdjustedCost = sim1BonusApplies ? 0.0 : sim1CostPerMinute * estimatedDuration;
      double sim2AdjustedCost = sim2BonusApplies ? 0.0 : sim2CostPerMinute * estimatedDuration;
      print("Adjusted costs: SIM1=$sim1AdjustedCost, SIM2=$sim2AdjustedCost");

      // --- Check Credit Availability --- //
      bool sim1HasEnoughCredit = sim1Credit >= sim1AdjustedCost;
      bool sim2HasEnoughCredit = sim2Credit >= sim2AdjustedCost;
      print("Credit check: SIM1=$sim1HasEnoughCredit, SIM2=$sim2HasEnoughCredit");

      // --- Decision Logic --- //
      SimChoice result;
      if (sim1HasEnoughCredit && sim2HasEnoughCredit) {
        if (sim1AdjustedCost <= sim2AdjustedCost) {
          result = SimChoice.sim1;
        } else {
          result = SimChoice.sim2;
        }
      } else if (sim1HasEnoughCredit) {
        result = SimChoice.sim1;
      } else if (sim2HasEnoughCredit) {
        result = SimChoice.sim2;
      } else {
        result = SimChoice.none;
      }
      print("Recommendation result: $result");
      return {result: null}; // Return null error message on success

    } catch (e, stacktrace) {
      String errorMsg = "Error calculating best SIM for $destinationNumber: $e";
      print(errorMsg);
      print("Stacktrace:\n$stacktrace");
      return {SimChoice.error: errorMsg};
    }
  }

  // Helper method to check if a configured bonus is currently active and applicable
  bool _isBonusApplicable(String? type, String? amountStr, String? validityStr, int estimatedDuration) {
    if (type == null || amountStr == null || validityStr == null || amountStr.isEmpty || validityStr.isEmpty) {
      return false;
    }

    try {
      final dateFormat = DateFormat('dd/MM/yyyy');
      final validityDate = dateFormat.parseStrict(validityStr);
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      if (validityDate.isBefore(startOfToday)) {
         return false;
      }
    } catch (e) {
      print('Error parsing bonus validity date: $validityStr. Format should be DD/MM/YYYY. Error: $e');
      return false;
    }

    switch (type) {
      case 'Crédit Appels':
        final double? bonusAmount = double.tryParse(amountStr);
        // TODO: Refine logic: Calculate the *cost* of the call and check if bonusAmount covers it.
        return bonusAmount != null && bonusAmount > 0;
      case 'Appels Illimités':
         return true;
      case 'Volume Data':
        return false;
      case 'Autre':
        return false;
      default:
        return false;
    }
  }
}

