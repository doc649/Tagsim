import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class TelephonyService {
  static const _platform = MethodChannel('com.example.tagsim/telephony');

  static Future<bool> isRoaming() async {
    // 1. Check and request permission
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
      if (!status.isGranted) {
        // Handle the case where permission is denied
        print('Phone permission denied. Cannot check roaming status.');
        // Return false or throw an exception, depending on desired behavior
        return false; // Or throw Exception('Permission denied');
      }
    }

    // 2. Call the native method
    try {
      final bool? isRoaming = await _platform.invokeMethod<bool>('isRoaming');
      return isRoaming ?? false; // Return false if null is returned
    } on PlatformException catch (e) {
      print("Failed to check roaming status: '${e.message}'.");
      return false; // Or handle the error appropriately
    } catch (e) {
      print("An unexpected error occurred: $e");
      return false;
    }
  }
}

