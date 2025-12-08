import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'flight_notification_service.dart';
import '../utils/app_routes.dart';
import '../utils/navigation_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  /// Initialize Firebase and request notification permissions
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing PushNotificationService...');
      
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized');
      } else {
        debugPrint('✅ Firebase already initialized');
      }

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle local notification tap
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('👆 LOCAL NOTIFICATION TAPPED');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('Payload: ${response.payload}');
          debugPrint('Action ID: ${response.actionId}');
          debugPrint('Input: ${response.input}');
          
          // Navigate to My Journey screen
          _navigateToMyJourney();
        },
      );
      
      // CRITICAL FOR iOS: Request permission to display notifications while app is in foreground
      if (Platform.isIOS) {
        debugPrint('🍎 Requesting iOS foreground notification permissions...');
        final iosImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        
        if (iosImplementation != null) {
          // Request standard permissions
          await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          
          // CRITICAL for iOS 15+: Request time-sensitive notification permission
          // This prevents notifications from auto-dismissing
          // Note: This is handled in AppDelegate.swift, but we can also request here if needed
          debugPrint('✅ iOS notification permissions requested');
        }
      }

      // Create notification channel for Android
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
          playSound: true,
        );

        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // Request notification permissions
      NotificationSettings settings;
      if (Platform.isIOS) {
        settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      } else {
        settings = await _firebaseMessaging.getNotificationSettings();
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ Notification permission granted');

        // Get FCM token
        await _getFCMToken();

        // Save token if user is logged in
        final user = _supabase.auth.currentUser;
        if (user != null && _fcmToken != null) {
          await _saveTokenToSupabase(_fcmToken!, userId: user.id);
          debugPrint('✅ FCM token saved for user: ${user.id}');
        }

        // Listen to token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            await _saveTokenToSupabase(_fcmToken!, userId: currentUser.id);
          }
        });

        // NOTE: Background message handler is registered in main.dart at app startup
        // This ensures it works when app is fully terminated

        // ====================================================================
        // NOTIFICATION HANDLERS FOR ALL APP STATES
        // ====================================================================
        // These handlers ensure navigation to My Journey screen works in ALL states:
        // 1. TERMINATED: App is fully closed → getInitialMessage() handles it
        // 2. BACKGROUND: App is minimized → onMessageOpenedApp handles it
        // 3. FOREGROUND: App is open → Local notification tap + in-app banner tap
        // ====================================================================

        // Handle foreground messages (app is open)
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps when app is opened from TERMINATED state
        // This is called when user taps notification while app is fully closed
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            debugPrint('📱 APP OPENED FROM NOTIFICATION (TERMINATED STATE)');
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            debugPrint('Title: ${message.notification?.title}');
            debugPrint('Body: ${message.notification?.body}');
            debugPrint('Data: ${message.data}');
            debugPrint('Journey ID: ${message.data['journey_id']}');
            
            // Add delay to ensure app is fully initialized before navigation
            // Increased delay to ensure navigator is ready
            Future.delayed(const Duration(milliseconds: 2000), () {
              debugPrint('🔄 Attempting navigation after delay...');
              _handleNotificationTap(message);
            });
          }
        });

        // Handle notification taps when app is in BACKGROUND state
        // This is called when user taps notification while app is minimized
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('📱 NOTIFICATION TAPPED (BACKGROUND STATE)');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('Title: ${message.notification?.title}');
          debugPrint('Body: ${message.notification?.body}');
          debugPrint('Journey ID: ${message.data['journey_id']}');
          _handleNotificationTap(message);
        });

        debugPrint('✅ Push notification service initialized successfully');
      } else {
        debugPrint('❌ Notification permission denied');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing push notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  /// Get FCM token
  static Future<String?> _getFCMToken() async {
    try {
      debugPrint('🔑 Attempting to get FCM token...');
      
      if (Platform.isIOS) {
        debugPrint('🍎 iOS detected - checking APNS token...');
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⏳ APNS token not ready, waiting...');
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('⚠️ APNS token not available after delay.');
            return null;
          } else {
            debugPrint('✅ APNS token obtained');
          }
        } else {
          debugPrint('✅ APNS token already available');
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        final tokenPreview = _fcmToken!.length > 30 ? _fcmToken!.substring(0, 30) : _fcmToken!;
        debugPrint('✅ FCM Token obtained: $tokenPreview...');
        debugPrint('📋 Full FCM Token length: ${_fcmToken!.length}');
      } else {
        debugPrint('❌ FCM Token is null');
      }
      return _fcmToken;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
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

  /// Callback for in-app notification banner display
  static Function(String title, String body, Map<String, dynamic> data)? onForegroundNotification;

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📬 FOREGROUND NOTIFICATION RECEIVED');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Message Type: ${message.messageType}');
    debugPrint('Sent Time: ${message.sentTime}');
    debugPrint('From: ${message.from}');
    debugPrint('Collapse Key: ${message.collapseKey}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    debugPrint('Has Notification: ${message.notification != null}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Show a local notification for foreground messages
    if (message.notification != null) {
      debugPrint('📤 Showing local notification for foreground message');
      _showForegroundNotification(message);
      
      // Trigger in-app notification callback if set
      if (onForegroundNotification != null) {
        onForegroundNotification!(
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
          message.data,
        );
      }
    } else {
      debugPrint('⚠️ Message has no notification payload, only data: ${message.data}');
      // If no notification payload, create one from data
      if (message.data['title'] != null && message.data['body'] != null) {
        debugPrint('📤 Creating notification from data payload');
        final notification = RemoteNotification(
          title: message.data['title'],
          body: message.data['body'],
        );
        final messageWithNotification = RemoteMessage(
          messageId: message.messageId,
          data: message.data,
          notification: notification,
        );
        _showForegroundNotification(messageWithNotification);
        
        // Trigger in-app notification callback if set
        if (onForegroundNotification != null) {
          onForegroundNotification!(
            message.data['title'],
            message.data['body'],
            message.data,
          );
        }
      }
    }
  }

  /// Show local notification for foreground messages
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) {
        debugPrint('⚠️ Notification payload is null, cannot show foreground notification');
        return;
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📲 SHOWING FOREGROUND NOTIFICATION');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Title: ${notification.title}');
      debugPrint('Body: ${notification.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Create notification details
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: false, // CRITICAL: Don't auto-dismiss notifications
        ongoing: false, // Allow user to dismiss manually
        styleInformation: BigTextStyleInformation(
          notification.body ?? '',
          htmlFormatBigText: false,
          contentTitle: notification.title,
          htmlFormatContentTitle: false,
        ),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,  // CRITICAL for foreground display
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        subtitle: notification.body,
        badgeNumber: 1,
        // CRITICAL for iOS: Use timeSensitive to prevent auto-dismiss
        // This ensures notifications persist until user dismisses them
        interruptionLevel: InterruptionLevel.timeSensitive,  // iOS 15+ - prevents auto-dismiss
        threadIdentifier: 'flight_notifications',  // Prevent notification grouping
        categoryIdentifier: 'FLIGHT_NOTIFICATION',  // Custom category for better control
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate a unique notification ID using hash of title+body+timestamp
      // This ensures each notification gets a unique ID and won't replace others
      final notificationId = ((notification.title ?? '').hashCode.abs() + 
          (notification.body ?? '').hashCode.abs() + 
          DateTime.now().millisecondsSinceEpoch);

      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        notification.title ?? 'Notification',
        notification.body ?? '',
        platformDetails,
        payload: message.data.toString(),
      );

      debugPrint('✅ Foreground notification shown with ID: $notificationId');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing foreground notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('👆 NOTIFICATION TAPPED');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    debugPrint('Journey ID: ${message.data['journey_id']}');
    debugPrint('Type: ${message.data['type']}');
    debugPrint('Phase: ${message.data['phase']}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Navigate to My Journey screen
    _navigateToMyJourney();
  }

  /// Navigate to My Journey screen
  static void _navigateToMyJourney() {
    debugPrint('🔄 Calling NavigationService.navigateToMyJourney()...');
    NavigationService.navigateToMyJourney();
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
    String? journeyId,
    String? stage,
  }) async {
    try {
      // Send notification via Supabase Edge Function
      // The deployed function expects userId and looks up the token itself
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
          if (journeyId != null) 'journeyId': journeyId,
          if (stage != null) 'stage': stage,
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

  /// Get notification permission status (returns true if granted, false otherwise)
  static Future<bool> getNotificationPermissionStatus() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ Error getting notification permission status: $e');
      return false;
    }
  }

  /// Request notification permission (returns true if granted, false otherwise)
  static Future<bool> requestNotificationPermission() async {
    try {
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

        final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        if (isGranted) {
          debugPrint('✅ Notification permission granted');
          // Get FCM token and save it
          await _getFCMToken();
          final user = _supabase.auth.currentUser;
          if (user != null && _fcmToken != null) {
            await _saveTokenToSupabase(_fcmToken!, userId: user.id);
          }
        } else {
          debugPrint('❌ Notification permission denied');
        }

        return isGranted;
      } else {
        // Android doesn't require explicit permission (it's granted by default)
        // Just get the token and save it
        await _getFCMToken();
        final user = _supabase.auth.currentUser;
        if (user != null && _fcmToken != null) {
          await _saveTokenToSupabase(_fcmToken!, userId: user.id);
        }
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
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

  /// Diagnostic function - checks notification setup
  static Future<Map<String, dynamic>> diagnosticCheck() async {
    final results = <String, dynamic>{
      'firebaseInitialized': Firebase.apps.isNotEmpty,
      'hasFCMToken': _fcmToken != null,
      'notificationPermission': 'unknown',
    };

    try {
      // Check notification permission
      final settings = await _firebaseMessaging.getNotificationSettings();
      results['notificationPermission'] = settings.authorizationStatus.toString();

      // Check FCM token
      if (_fcmToken == null) {
        await _getFCMToken();
      }
      results['fcmToken'] = _fcmToken != null ? '${_fcmToken!.substring(0, 20)}...' : null;
      results['fcmTokenLength'] = _fcmToken?.length ?? 0;

      // Check if user is logged in
      final user = _supabase.auth.currentUser;
      results['userLoggedIn'] = user != null;
      results['userId'] = user?.id;

      // Check if token is saved in database
      if (user != null && _fcmToken != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select('fcm_token')
              .eq('id', user.id)
              .maybeSingle();
          results['tokenInDatabase'] = userData?['fcm_token'] != null;
          results['databaseTokenMatch'] = userData?['fcm_token'] == _fcmToken;
        } catch (e) {
          results['tokenInDatabase'] = false;
          results['databaseCheckError'] = e.toString();
        }
      }

      results['success'] = true;
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
    }

    // Print diagnostic results
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 NOTIFICATION DIAGNOSTIC CHECK');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    results.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return results;
  }

  /// Force refresh and save FCM token to database
  static Future<void> refreshAndSaveToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in to refresh token');
        return;
      }

      debugPrint('🔄 Force refreshing FCM token...');
      
      // Delete old token first (optional, but ensures fresh token)
      try {
        await _firebaseMessaging.deleteToken();
        debugPrint('🗑️ Old token deleted');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('⚠️ Error deleting old token (continuing anyway): $e');
      }

      // Get new token
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⏳ Waiting for APNS token...');
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }
        if (apnsToken != null) {
          debugPrint('✅ APNS token ready');
        }
      }

      // Get fresh FCM token
      final newToken = await _firebaseMessaging.getToken();
      
      if (newToken == null) {
        debugPrint('❌ Failed to get new FCM token');
        return;
      }

      _fcmToken = newToken;
      debugPrint('✅ New FCM Token obtained: ${newToken.substring(0, 30)}...');
      debugPrint('📋 Token length: ${newToken.length}');

      // Save to database
      await _saveTokenToSupabase(newToken, userId: user.id);
      debugPrint('✅ FCM token refreshed and saved to database');
    } catch (e, stackTrace) {
      debugPrint('❌ Error refreshing FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// PUBLIC METHOD: Manually show a foreground notification
  /// This can be called from anywhere in your app to display a notification
  static Future<void> showForegroundNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📲 MANUALLY SHOWING FOREGROUND NOTIFICATION');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Title: $title');
      debugPrint('Body: $body');
      debugPrint('Data: $data');
      
      // First, ensure the channel is created
      if (Platform.isAndroid) {
        debugPrint('🔧 Creating/Verifying Android notification channel...');
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        final androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(channel);
          debugPrint('✅ Notification channel created/verified');
          
          // Check if notifications are enabled
          final areEnabled = await androidImplementation.areNotificationsEnabled();
          debugPrint('📱 Notifications enabled: $areEnabled');
          
          if (areEnabled == false) {
            debugPrint('⚠️ WARNING: Notifications are DISABLED in system settings!');
            debugPrint('💡 Go to: Settings → Apps → airline_app → Notifications → Allow');
          }
        } else {
          debugPrint('⚠️ Could not get Android implementation');
        }
      }
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Create notification details
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: false, // CRITICAL: Don't auto-dismiss notifications
        ongoing: false, // Allow user to dismiss manually
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
        ),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,  // Show alert when app is in foreground
        presentBadge: true,  // Update badge
        presentSound: true,  // Play sound
        sound: 'default',    // Use default sound
        subtitle: body,
        badgeNumber: 1,
        // CRITICAL for iOS: Use timeSensitive to prevent auto-dismiss
        // This ensures notifications persist until user dismisses them
        interruptionLevel: InterruptionLevel.timeSensitive,  // iOS 15+ - prevents auto-dismiss
        threadIdentifier: 'flight_notifications',  // Prevent notification grouping
        categoryIdentifier: 'FLIGHT_NOTIFICATION',  // Custom category for better control
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate a unique notification ID using hash of title+body+timestamp
      // This ensures each notification gets a unique ID and won't replace others
      final notificationId = title.hashCode.abs() + 
          body.hashCode.abs() + 
          DateTime.now().millisecondsSinceEpoch;

      debugPrint('📤 Calling flutter_local_notifications.show()...');
      debugPrint('   ID: $notificationId');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');
      
      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: data?.toString(),
      );

      debugPrint('✅ flutter_local_notifications.show() completed successfully');
      debugPrint('✅ Foreground notification shown with ID: $notificationId');
      
      // Trigger in-app notification callback if set
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 CHECKING FOR IN-APP BANNER CALLBACK');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Callback is null: ${onForegroundNotification == null}');
      
      if (onForegroundNotification != null) {
        debugPrint('✅ In-app banner callback EXISTS, triggering now...');
        try {
          onForegroundNotification!(title, body, data ?? {});
          debugPrint('✅ In-app banner callback CALLED successfully');
        } catch (e) {
          debugPrint('❌ Error calling in-app banner callback: $e');
        }
      } else {
        debugPrint('❌ WARNING: No in-app banner callback set!');
        debugPrint('💡 The callback should be set in main.dart MaterialApp.builder');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 NOTIFICATION SENT SUCCESSFULLY');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing manual foreground notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Test push notification - sends a test notification to the current user
  static Future<void> testPushNotification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in to send test notification');
        return;
      }

      // Get user's FCM token from database (more reliable)
      final userData = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', user.id)
          .maybeSingle();

      String? fcmToken;
      if (userData != null && userData['fcm_token'] != null) {
        fcmToken = userData['fcm_token'] as String;
        debugPrint('✅ FCM token retrieved from database');
      } else {
        // Try to get from cache or generate new token
        if (_fcmToken == null) {
          await _getFCMToken();
        }
        fcmToken = _fcmToken;
        
        if (fcmToken != null) {
          // Save the token to database
          await _saveTokenToSupabase(fcmToken, userId: user.id);
        }
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('❌ FCM token not available for test notification');
        return;
      }

      debugPrint('🧪 Sending test push notification to user: ${user.id}');
      if (fcmToken != null) {
        debugPrint('📱 FCM Token (first 20 chars): ${fcmToken.substring(0, fcmToken.length > 20 ? 20 : fcmToken.length)}...');
      }

      // Prepare the request body - deployed function expects userId and looks up the token itself
      final requestBody = {
        'userId': user.id,
        'title': '✈️ Flight Status Test',
        'body': 'This is a test notification! Your push notifications are working correctly.',
        'data': {
          'type': 'test_notification',
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      debugPrint('📤 Request body keys: ${requestBody.keys}');

      // Send test notification via Supabase Edge Function
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: requestBody,
      );

      debugPrint('📥 Response: $response');
      debugPrint('✅ Test push notification sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending test push notification: $e');
      if (e is FunctionException) {
        debugPrint('📋 FunctionException status: ${e.status}');
        debugPrint('📋 FunctionException details: ${e.details}');
        debugPrint('📋 FunctionException reason: ${e.reasonPhrase}');
      }
      rethrow;
    }
  }
}

// NOTE: Background message handler moved to main.dart
// The handler MUST be registered at the top level before app initialization
// to ensure notifications work when the app is fully terminated
