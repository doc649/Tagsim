import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static late SharedPreferences _preferences;

  static const _keySim1Credit = 'sim1_credit';
  static const _keySim1BonusType = 'sim1_bonus_type';
  static const _keySim1BonusAmount = 'sim1_bonus_amount';
  static const _keySim1BonusValidity = 'sim1_bonus_validity';

  static const _keySim2Credit = 'sim2_credit';
  static const _keySim2BonusType = 'sim2_bonus_type';
  static const _keySim2BonusAmount = 'sim2_bonus_amount';
  static const _keySim2BonusValidity = 'sim2_bonus_validity';

  static const _keyEstimatedDuration = 'estimated_duration';

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  // --- Generic Getters/Setters (Added for flexibility) --- //
  static String? getString(String key) => _preferences.getString(key);

  static Future setString(String key, String value) async =>
      await _preferences.setString(key, value);

  // --- SIM 1 --- //
  static Future setSim1Credit(double credit) async =>
      await _preferences.setDouble(_keySim1Credit, credit);

  static double getSim1Credit() => _preferences.getDouble(_keySim1Credit) ?? 0.0;

  static Future setSim1BonusType(String? type) async {
    if (type == null) {
      await _preferences.remove(_keySim1BonusType);
    } else {
      await _preferences.setString(_keySim1BonusType, type);
    }
  }

  static String? getSim1BonusType() => _preferences.getString(_keySim1BonusType);

  static Future setSim1BonusAmount(String? amount) async {
     if (amount == null || amount.isEmpty) {
      await _preferences.remove(_keySim1BonusAmount);
    } else {
      await _preferences.setString(_keySim1BonusAmount, amount);
    }
  }

  static String? getSim1BonusAmount() => _preferences.getString(_keySim1BonusAmount);

  static Future setSim1BonusValidity(String? validity) async {
     if (validity == null || validity.isEmpty) {
      await _preferences.remove(_keySim1BonusValidity);
    } else {
      await _preferences.setString(_keySim1BonusValidity, validity);
    }
  }

  static String? getSim1BonusValidity() => _preferences.getString(_keySim1BonusValidity);

  // --- SIM 2 --- //
  static Future setSim2Credit(double credit) async =>
      await _preferences.setDouble(_keySim2Credit, credit);

  static double getSim2Credit() => _preferences.getDouble(_keySim2Credit) ?? 0.0;

  static Future setSim2BonusType(String? type) async {
     if (type == null) {
      await _preferences.remove(_keySim2BonusType);
    } else {
      await _preferences.setString(_keySim2BonusType, type);
    }
  }

  static String? getSim2BonusType() => _preferences.getString(_keySim2BonusType);

  static Future setSim2BonusAmount(String? amount) async {
    if (amount == null || amount.isEmpty) {
      await _preferences.remove(_keySim2BonusAmount);
    } else {
      await _preferences.setString(_keySim2BonusAmount, amount);
    }
  }

  static String? getSim2BonusAmount() => _preferences.getString(_keySim2BonusAmount);

  static Future setSim2BonusValidity(String? validity) async {
    if (validity == null || validity.isEmpty) {
      await _preferences.remove(_keySim2BonusValidity);
    } else {
      await _preferences.setString(_keySim2BonusValidity, validity);
    }
  }

  static String? getSim2BonusValidity() => _preferences.getString(_keySim2BonusValidity);

  // --- Estimated Duration --- //
  static Future setEstimatedDuration(int duration) async =>
      await _preferences.setInt(_keyEstimatedDuration, duration);

  static int getEstimatedDuration() => _preferences.getInt(_keyEstimatedDuration) ?? 1; // Default to 1 minute

  // --- Helper to save all config at once --- //
  static Future saveBonusConfiguration({
    required double sim1Credit,
    required String? sim1BonusType,
    required String? sim1BonusAmount,
    required String? sim1BonusValidity,
    required double sim2Credit,
    required String? sim2BonusType,
    required String? sim2BonusAmount,
    required String? sim2BonusValidity,
    required int estimatedDuration,
  }) async {
    await setSim1Credit(sim1Credit);
    await setSim1BonusType(sim1BonusType);
    await setSim1BonusAmount(sim1BonusAmount);
    await setSim1BonusValidity(sim1BonusValidity);
    await setSim2Credit(sim2Credit);
    await setSim2BonusType(sim2BonusType);
    await setSim2BonusAmount(sim2BonusAmount);
    await setSim2BonusValidity(sim2BonusValidity);
    await setEstimatedDuration(estimatedDuration);
  }
}

