import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/flight_tracking_model.dart';

class JourneyNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final SupabaseClient _client = SupabaseService.client;

  /// Initialize push notifications for journey updates
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing journey notification service...');

      // Check existing permission status (don't request again)
      // PushNotificationService already requests permission in main.dart
      final settings = await _messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission already granted (checked by journey service)');

        // Get FCM token
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          await _saveTokenToDatabase(token);
        }

        // Listen to token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          await _saveTokenToDatabase(newToken);
        });

        // NOTE: Background message handler is registered in main.dart at app startup
        // to ensure it works when app is fully terminated

        // Listen to foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Listen to notification taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        debugPrint('✅ Journey notification service initialized');
      } else {
        debugPrint('⚠️ Notification permission not granted yet. Waiting for PushNotificationService to request permission.');
        // PushNotificationService will request permission and this service can be re-initialized after
      }
    } catch (e) {
      debugPrint('❌ Error initializing journey notification service: $e');
    }
  }

  /// Save FCM token to database
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final session = _client.auth.currentSession;
      if (session?.user.id == null) return;

      await _client.from('user_tokens').upsert({
        'user_id': session!.user.id,
        'fcm_token': token,
        'platform': 'mobile',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM token saved to database');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Send journey update notification
  static Future<void> sendJourneyUpdateNotification({
    required String userId,
    required String journeyId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📤 Sending journey update notification: $title');

      // Get user's FCM token
      final response = await _client
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['fcm_token'] == null) {
        debugPrint('❌ No FCM token found for user: $userId');
        return;
      }

      final fcmToken = response['fcm_token'] as String;

      // Send notification via Supabase Edge Function
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'token': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': type,
            'journey_id': journeyId,
            ...?data,
          },
        },
      );

      debugPrint('✅ Journey update notification sent');
    } catch (e) {
      debugPrint('❌ Error sending journey update notification: $e');
    }
  }

  /// Send flight phase update notification
  static Future<void> sendFlightPhaseNotification({
    required String userId,
    required String journeyId,
    required FlightPhase phase,
    required String flightInfo,
    Map<String, dynamic>? additionalData,
  }) async {
    String title;
    String body;
    String type;

    switch (phase) {
      case FlightPhase.boarding:
        title = 'Boarding Started';
        body = 'Boarding has begun for $flightInfo';
        type = 'boarding_started';
        break;
      case FlightPhase.inFlight:
        title = 'Flight Departed';
        body = 'Your flight $flightInfo has departed';
        type = 'flight_departed';
        break;
      case FlightPhase.landed:
        title = 'Flight Landed';
        body = 'Your flight $flightInfo has landed';
        type = 'flight_landed';
        break;
      case FlightPhase.completed:
        title = 'Journey Complete';
        body = 'Your journey $flightInfo is complete. Rate your experience!';
        type = 'journey_complete';
        break;
      default:
        title = 'Flight Update';
        body = 'Update for $flightInfo';
        type = 'flight_update';
    }

    await sendJourneyUpdateNotification(
      userId: userId,
      journeyId: journeyId,
      title: title,
      body: body,
      type: type,
      data: {
        'phase': phase.name,
        'flight_info': flightInfo,
        ...?additionalData,
      },
    );
  }

  /// Send gate change notification
  static Future<void> sendGateChangeNotification({
    required String userId,
    required String journeyId,
    required String oldGate,
    required String newGate,
    required String flightInfo,
  }) async {
    await sendJourneyUpdateNotification(
      userId: userId,
      journeyId: journeyId,
      title: 'Gate Change',
      body: 'Gate changed from $oldGate to $newGate for $flightInfo',
      type: 'gate_change',
      data: {
        'old_gate': oldGate,
        'new_gate': newGate,
        'flight_info': flightInfo,
      },
    );
  }

  /// Send delay notification
  static Future<void> sendDelayNotification({
    required String userId,
    required String journeyId,
    required String delayReason,
    required String newTime,
    required String flightInfo,
  }) async {
    await sendJourneyUpdateNotification(
      userId: userId,
      journeyId: journeyId,
      title: 'Flight Delay',
      body: '$flightInfo delayed. New time: $newTime. Reason: $delayReason',
      type: 'flight_delay',
      data: {
        'delay_reason': delayReason,
        'new_time': newTime,
        'flight_info': flightInfo,
      },
    );
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        '📱 Received foreground message: ${message.notification?.title}');

    // Show local notification or update UI
    // This could trigger a UI update or show an in-app notification
  }

  /// Handle notification taps
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.notification?.title}');

    final data = message.data;
    final type = data['type'];
    final journeyId = data['journey_id'];

    // Navigate to appropriate screen based on notification type
    switch (type) {
      case 'journey_complete':
        // Navigate to feedback screen
        break;
      case 'boarding_started':
      case 'flight_departed':
      case 'flight_landed':
        // Navigate to journey timeline
        break;
      case 'gate_change':
        // Navigate to journey details
        break;
      default:
        // Navigate to journey screen
        break;
    }
  }

  /// Clear all notifications for a user
  static Future<void> clearUserNotifications(String userId) async {
    try {
      await _client.from('user_tokens').delete().eq('user_id', userId);

      debugPrint('✅ Cleared notifications for user: $userId');
    } catch (e) {
      debugPrint('❌ Error clearing user notifications: $e');
    }
  }
}

/// Background message handler
// NOTE: Background message handler moved to main.dart
// The handler MUST be registered at the top level before app initialization
// to ensure notifications work when the app is fully terminated
