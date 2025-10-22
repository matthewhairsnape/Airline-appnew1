import 'package:flutter/foundation.dart';
import 'flight_notification_service.dart';
import 'push_notification_service.dart';

/// Production-ready notification manager for easy notification handling
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlightNotificationService _flightNotificationService =
      FlightNotificationService();

  /// Initialize notification services
  Future<void> initialize() async {
    try {
      await PushNotificationService.initialize();
      await _flightNotificationService.initialize();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing notification manager: $e');
      }
    }
  }

  /// Send a simple notification
  Future<void> sendNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    try {
      await _flightNotificationService.sendCustomNotification(
        title: title,
        message: message,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending notification: $e');
      }
    }
  }

  /// Send flight status notification
  Future<void> sendFlightStatusNotification({
    required String title,
    required String message,
    String? flightId,
  }) async {
    try {
      await _flightNotificationService.sendCustomNotification(
        title: title,
        message: message,
        payload: flightId != null ? 'flight_status|$flightId' : 'flight_status',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending flight status notification: $e');
      }
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      return await PushNotificationService.areNotificationsEnabled();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking notification status: $e');
      }
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      return await PushNotificationService.requestPermissionsAgain();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error requesting permissions: $e');
      }
      return false;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flightNotificationService.cancelAllNotifications();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error canceling notifications: $e');
      }
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _flightNotificationService.cancelNotification(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error canceling notification: $e');
      }
    }
  }
}
