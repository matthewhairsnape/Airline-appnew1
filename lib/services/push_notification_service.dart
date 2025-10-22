import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'flight_notification_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  /// Initialize Firebase and request notification permissions
  static Future<void> initialize() async {
    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // Request permission for notifications (iOS only)
      if (Platform.isIOS) {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true, // Show alerts/banners
          announcement: false, // Siri announcements
          badge: true, // App icon badge
          carPlay: false, // CarPlay notifications
          criticalAlert:
              false, // Critical alerts (requires special entitlement)
          provisional: false, // Provisional notifications (quiet notifications)
          sound: true, // Sound for notifications
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('✅ User granted full permission for notifications');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          debugPrint(
              '⚠️ User granted provisional permission for notifications');
        } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('❌ User denied permission for notifications');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.notDetermined) {
          debugPrint('❓ User has not yet responded to permission request');
        } else {
          debugPrint(
              '❌ Unknown permission status: ${settings.authorizationStatus}');
        }

        // Log detailed permission settings
        debugPrint('📱 Notification settings:');
        debugPrint('  - Alert: ${settings.alert}');
        debugPrint('  - Badge: ${settings.badge}');
        debugPrint('  - Sound: ${settings.sound}');
        debugPrint('  - Announcement: ${settings.announcement}');
        debugPrint('  - CarPlay: ${settings.carPlay}');
        debugPrint('  - Critical Alert: ${settings.criticalAlert}');
        // debugPrint('  - Provisional: ${settings.provisional}');
      }

      // Get FCM token
      await _getFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('FCM Token refreshed: $token');
        _saveTokenToSupabase(token);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated
      final RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    }
  }

  /// Get FCM token
  static Future<String?> _getFCMToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('Waiting for APNS token...');
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('APNS token not available after delay.');
            return null;
          }
        }
      }
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Supabase for the current user
  static Future<void> saveTokenForUser(String userId) async {
    debugPrint('🔔 Starting FCM token save process for user: $userId');

    if (_fcmToken == null) {
      debugPrint('🔔 FCM token not cached, getting new token...');
      await _getFCMToken();
    }

    if (_fcmToken != null) {
      debugPrint('🔔 FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
      await _saveTokenToSupabase(_fcmToken!, userId: userId);
    } else {
      debugPrint('❌ Failed to get FCM token');
    }
  }

  /// Save FCM token to Supabase
  static Future<void> _saveTokenToSupabase(String token,
      {String? userId}) async {
    try {
      debugPrint('🔔 Attempting to save FCM token to Supabase...');

      if (userId != null) {
        // Update specific user's FCM token
        final result = await _supabase
            .from('users')
            .update({
              'fcm_token': token,
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', userId)
            .select();

        debugPrint('✅ FCM token saved successfully for user: $userId');
        debugPrint('🔔 Database response: $result');
      } else {
        // Get current user and update their FCM token
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final result = await _supabase
              .from('users')
              .update({
                'fcm_token': token,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('id', user.id)
              .select();

          debugPrint(
              '✅ FCM token saved successfully for current user: ${user.id}');
          debugPrint('🔔 Database response: $result');
        } else {
          debugPrint('❌ No current user found for FCM token save');
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Supabase: $e');
      rethrow;
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Received foreground message: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
      debugPrint('Message notification: ${message.notification?.title}');
      debugPrint('Message body: ${message.notification?.body}');
    }

    // Show a local notification for foreground messages
    if (message.notification != null) {
      _showForegroundNotification(message);
    }
  }

  /// Show local notification for foreground messages
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      final flightNotificationService = FlightNotificationService();
      await flightNotificationService.initialize();

      await flightNotificationService.sendCustomNotification(
        title: notification.title ?? 'Notification',
        message: notification.body ?? '',
        payload: message.data.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error showing foreground notification: $e');
      }
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
    }

    // Handle navigation based on notification data
    // You can add navigation logic here based on the message data
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Send notification to a specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get user's FCM token from Supabase
      final userData = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();

      if (userData == null || userData['fcm_token'] == null) {
        debugPrint('❌ No FCM token found for user: $userId');
        return;
      }

      final fcmToken = userData['fcm_token'] as String;

      // Send notification via Supabase Edge Function
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': fcmToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint('✅ Push notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending push notification to user $userId: $e');
    }
  }

  /// Send notification to multiple users
  static Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get FCM tokens for all users
      final usersData = await _supabase
          .from('users')
          .select('id, fcm_token')
          .inFilter('id', userIds)
          .not('fcm_token', 'is', null);

      if (usersData.isEmpty) {
        debugPrint('❌ No FCM tokens found for any of the users');
        return;
      }

      final tokens =
          usersData.map((user) => user['fcm_token'] as String).toList();

      // Send notification via Supabase Edge Function
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'tokens': tokens,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint('✅ Push notification sent to ${tokens.length} users');
    } catch (e) {
      debugPrint('❌ Error sending push notification to users: $e');
    }
  }

  /// Send notification to all users subscribed to a topic
  static Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Send notification via Supabase Edge Function
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'topic': topic,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint('✅ Push notification sent to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error sending push notification to topic $topic: $e');
    }
  }

  /// Check current notification permission status
  static Future<AuthorizationStatus> checkPermissionStatus() async {
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus;
    }
    return AuthorizationStatus
        .authorized; // Android doesn't require explicit permission
  }

  /// Request notification permissions again (useful if user initially denied)
  static Future<bool> requestPermissionsAgain() async {
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (isGranted) {
        debugPrint('✅ User granted permission for notifications on retry');
        // Get FCM token again
        await _getFCMToken();
      } else {
        debugPrint('❌ User still denied permission for notifications');
      }

      return isGranted;
    }
    return true; // Android doesn't require explicit permission
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final status = await checkPermissionStatus();
    return status == AuthorizationStatus.authorized;
  }

  /// Clear FCM token (for logout)
  static Future<void> clearToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      debugPrint('FCM token cleared');
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}
