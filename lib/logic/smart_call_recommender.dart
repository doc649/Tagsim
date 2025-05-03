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
  // No need for an instance of OperatorDetector since methods are static
  // final OperatorDetector _operatorDetector;
  Map<String, dynamic>? _tariffs;

  // SmartCallRecommender() : _operatorDetector = OperatorDetector();
  SmartCallRecommender(); // Constructor without instance

  // Load tariffs if not already loaded
  Future<void> _loadTariffsIfNeeded() async {
    // Call static method
    _tariffs ??= await OperatorDetector.loadTariffs();
  }

  // Main method to get the best SIM recommendation
  Future<SimChoice> getBestSim(String destinationNumber) async {
    try {
      await _loadTariffsIfNeeded();
      if (_tariffs == null || _tariffs!.isEmpty) { // Check if tariffs are empty too
        print('Error: Tariffs could not be loaded or are empty.');
        return SimChoice.error;
      }

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

      // --- Factor in Bonuses --- //
      bool sim1BonusApplies = _isBonusApplicable(sim1BonusType, sim1BonusAmount, sim1BonusValidityStr, estimatedDuration);
      bool sim2BonusApplies = _isBonusApplicable(sim2BonusType, sim2BonusAmount, sim2BonusValidityStr, estimatedDuration);

      // --- Calculate Adjusted Costs for Estimated Duration --- //
      // If bonus applies, cost is 0. Otherwise, it's cost_per_minute * duration.
      double sim1AdjustedCost = sim1BonusApplies ? 0.0 : sim1CostPerMinute * estimatedDuration;
      double sim2AdjustedCost = sim2BonusApplies ? 0.0 : sim2CostPerMinute * estimatedDuration;

      // --- Check Credit Availability --- //
      bool sim1HasEnoughCredit = sim1Credit >= sim1AdjustedCost;
      bool sim2HasEnoughCredit = sim2Credit >= sim2AdjustedCost;

      // --- Decision Logic --- //
      if (sim1HasEnoughCredit && sim2HasEnoughCredit) {
        // Both have enough credit, choose the cheaper one (bonus prioritized)
        if (sim1AdjustedCost <= sim2AdjustedCost) {
          return SimChoice.sim1;
        } else {
          return SimChoice.sim2;
        }
      } else if (sim1HasEnoughCredit) {
        // Only SIM 1 has enough credit
        return SimChoice.sim1;
      } else if (sim2HasEnoughCredit) {
        // Only SIM 2 has enough credit
        return SimChoice.sim2;
      } else {
        // Neither has enough credit
        return SimChoice.none;
      }

    } catch (e) {
      print('Error in getBestSim: $e');
      return SimChoice.error;
    }
  }

  // Helper method to check if a configured bonus is currently active and applicable
  bool _isBonusApplicable(String? type, String? amountStr, String? validityStr, int estimatedDuration) {
    if (type == null || amountStr == null || validityStr == null || amountStr.isEmpty || validityStr.isEmpty) {
      return false; // No bonus configured or essential info missing
    }

    // Check Validity Date
    try {
      // Use a flexible date format parsing or ensure strict format upon saving
      final dateFormat = DateFormat('dd/MM/yyyy');
      final validityDate = dateFormat.parseStrict(validityStr);
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      // Bonus is valid if validity date is today or in the future
      if (validityDate.isBefore(startOfToday)) {
         return false; // Bonus expired
      }
    } catch (e) {
      print('Error parsing bonus validity date: $validityStr. Format should be DD/MM/YYYY. Error: $e');
      return false; // Invalid date format
    }

    // Check Type and Amount
    switch (type) {
      case 'Crédit Appels':
        final double? bonusAmount = double.tryParse(amountStr);
        // Basic check: Any positive call credit bonus is considered applicable for now.
        // TODO: Refine logic: Calculate the *cost* of the call and check if bonusAmount covers it.
        // This requires knowing the tariff for the specific call destination.
        return bonusAmount != null && bonusAmount > 0;

      case 'Appels Illimités':
         // Assume any entry here means unlimited calls apply (could refine based on amountStr if needed)
         // E.g., check if amountStr is 'illimité', 'unlimited', 'yes', etc.
         return true;

      case 'Volume Data':
        // Data bonus does not apply to standard calls
        return false;

      case 'Autre':
        // Cannot determine applicability for 'Other' bonus type
        return false;

      default:
        return false; // Unknown bonus type
    }
  }
}

