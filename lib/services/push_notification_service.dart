import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
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
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted permission for notifications');
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          debugPrint('User granted provisional permission for notifications');
        } else {
          debugPrint('User declined or has not accepted permission for notifications');
        }
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
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated
      final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
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
  static Future<void> _saveTokenToSupabase(String token, {String? userId}) async {
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
              
          debugPrint('✅ FCM token saved successfully for current user: ${user.id}');
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
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    debugPrint('Message notification: ${message.notification?.title}');
    
    // You can show a local notification or update UI here
    // For now, we'll just log the message
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    
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
