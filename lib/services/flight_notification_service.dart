import 'dart:io';
import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/models/stage_feedback_model.dart';
import 'package:airline_app/services/stage_question_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to handle flight-related push notifications
class FlightNotificationService {
  static final FlightNotificationService _instance =
      FlightNotificationService._internal();
  factory FlightNotificationService() => _instance;
  FlightNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS initialization
      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
    } catch (e) {
      // Log error but don't crash the app
      if (kDebugMode) {
        debugPrint('Error initializing notifications: $e');
      }
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'flight_tracking',
        'Flight Tracking',
        description: 'Notifications for flight status and feedback requests',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating notification channel: $e');
      }
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Handle notification tap (background/terminated)
  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${notificationResponse.payload}');
    }
    // Handle navigation to stage-specific feedback screen
    // This will be handled by the app's navigation system
  }

  /// Send notification for flight phase change
  Future<void> notifyFlightPhaseChange(FlightTrackingModel flight) async {
    if (!_isInitialized) {
      await initialize();
    }

    final FlightPhase phase = flight.currentPhase;
    final FeedbackStage stage =
        StageQuestionService.getStageFromFlightPhase(phase);

    // Only notify for specific stages
    if (!StageQuestionService.shouldNotifyForStage(stage)) {
      return;
    }

    final String title = StageQuestionService.getNotificationTitle(stage);
    final String message = StageQuestionService.getNotificationMessage(stage);

    await _showNotification(
      id: flight.pnr.hashCode,
      title: title,
      body: message,
      payload: '${flight.pnr}|${stage.toString()}',
    );
  }

  /// Show a notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'flight_tracking',
      'Flight Tracking',
      channelDescription:
          'Notifications for flight status and feedback requests',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error showing local notification: $e');
      }
      // Don't rethrow in production to avoid crashing the app
    }
  }

  /// Send a custom notification
  Future<void> sendCustomNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}
