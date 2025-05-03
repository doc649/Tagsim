import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'promo_notifications';
  static const String _channelName = 'Notifications des Promotions';
  static const String _channelDescription = 'Notifications sur les nouvelles offres et promotions';
  static const String _lastNotifiedOffersKey = 'lastNotifiedOffers';

  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    // Set the local location (adjust if needed, e.g., based on device timezone)
    // For Algeria, Africa/Algiers is appropriate
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
    } catch (e) {
      print('Could not set local location for timezone: $e');
      // Fallback or default location might be needed
    }

    // Initialization settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use app icon

    // Initialization settings for iOS (requesting permissions)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(initializationSettings);

    // Request notification permissions on Android 13+
    if (await _needsPermissionRequest()) {
      await _requestPermissions();
    }

    print('Notification Service Initialized');
  }

  static Future<bool> _needsPermissionRequest() async {
    if (await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      return true;
    }
    // Add checks for iOS if needed, though permissions are requested at init
    return false;
  }

  static Future<void> _requestPermissions() async {
    // Request permission for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request permission for iOS (older versions might need this explicitly)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<List<Map<String, dynamic>>> _loadPromotions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/promotions.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading promotions.json: $e');
      return [];
    }
  }

  static Future<Set<String>> _getLastNotifiedOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notified = prefs.getStringList(_lastNotifiedOffersKey) ?? [];
    return notified.toSet();
  }

  static Future<void> _saveLastNotifiedOffers(Set<String> currentOfferIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lastNotifiedOffersKey, currentOfferIds.toList());
  }

  // Simple way to generate a unique ID for each offer based on its content
  static String _generateOfferId(Map<String, dynamic> offer) {
    // Use operator, name, and price as a basic unique identifier
    return '${offer['operator']}_${offer['name']}_${offer['price']}'.replaceAll(' ', '_');
  }

  // Basic intelligence: find new offers or offers with significantly more data
  static List<Map<String, dynamic>> _findSmartOffers(
      List<Map<String, dynamic>> currentPromos,
      Set<String> lastNotifiedIds) {
    List<Map<String, dynamic>> smartOffers = [];
    Set<String> currentOfferIds = {};

    for (var offer in currentPromos) {
      String offerId = _generateOfferId(offer);
      currentOfferIds.add(offerId);

      if (!lastNotifiedIds.contains(offerId)) {
        // It's a new offer (based on our simple ID)
        smartOffers.add(offer);
      } else {
        // Could add logic here to detect 'more data' if we stored previous data amounts
        // For now, just focusing on new offers
      }
    }

    // Update the stored list of notified offers for next time
    _saveLastNotifiedOffers(currentOfferIds);

    return smartOffers;
  }

  static Future<void> scheduleDailyNotifications() async {
    print('Scheduling daily notifications...');
    final List<Map<String, dynamic>> allPromos = await _loadPromotions();
    if (allPromos.isEmpty) {
      print('No promotions loaded, cannot schedule notifications.');
      return;
    }

    final Set<String> lastNotified = await _getLastNotifiedOffers();
    final List<Map<String, dynamic>> offersToNotify = _findSmartOffers(allPromos, lastNotified);

    if (offersToNotify.isEmpty) {
      print('No new smart offers to notify about today.');
      return;
    }

    // Schedule one notification summarizing the new offers, or individual ones?
    // Let's schedule one summary notification for simplicity.

    String notificationBody;
    if (offersToNotify.length == 1) {
      final offer = offersToNotify.first;
      notificationBody = 'Nouvelle offre ${offer['operator']}: ${offer['name']} (${offer['price']})';
    } else {
      notificationBody = '${offersToNotify.length} nouvelles offres disponibles ! Découvrez les dernières promotions.';
    }

    // Define notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for tomorrow at a specific time (e.g., 9 AM)
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9); // 9 AM today
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1)); // If 9 AM passed, schedule for tomorrow
    }

    print("Scheduling notification for: $scheduledDate");

    try {
      await _notificationsPlugin.zonedSchedule(
        0, // Notification ID
        'Nouvelles Promotions TagSim',
        notificationBody,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Match time daily
      );
      print('Daily notification scheduled successfully.');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  // Optional: Method to cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('All scheduled notifications cancelled.');
  }
}

