import 'dart:io';
import 'package:airline_app/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to handle push notifications using Supabase Edge Functions
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _isInitialized = false;
  String? _deviceToken;
  String? _userId;

  /// Initialize push notification service
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    try {
      _userId = userId;
      
      // Generate a simple device token (in production, you'd get this from FCM/APNs)
      await _generateDeviceToken();

      // Register for push notifications
      await _registerForPushNotifications();

      _isInitialized = true;
      debugPrint('✅ Push notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing push notifications: $e');
    }
  }

  /// Generate a simple device token for testing
  Future<void> _generateDeviceToken() async {
    try {
      // Check if we have a cached token
      final prefs = await SharedPreferences.getInstance();
      _deviceToken = prefs.getString('device_token');

      if (_deviceToken == null) {
        // Generate a simple device token (in production, get from FCM/APNs)
        _deviceToken = 'device_${DateTime.now().millisecondsSinceEpoch}_${Platform.isIOS ? 'ios' : 'android'}';
        
        // Cache the token
        await prefs.setString('device_token', _deviceToken!);
        debugPrint('📱 Generated device token: $_deviceToken');
      } else {
        debugPrint('📱 Using cached device token: $_deviceToken');
      }
    } catch (e) {
      debugPrint('❌ Error generating device token: $e');
    }
  }

  /// Register for push notifications with Supabase
  Future<void> _registerForPushNotifications() async {
    if (_deviceToken == null || _userId == null) {
      debugPrint('⚠️ Cannot register for push notifications: missing token or user ID');
      return;
    }

    try {
      // Update user's push token in Supabase
      await SupabaseService.updateUserPushToken(
        userId: _userId!,
        pushToken: _deviceToken!,
      );

      debugPrint('✅ Push token registered with Supabase');
    } catch (e) {
      debugPrint('❌ Error registering push token: $e');
    }
  }

  /// Send a test notification
  Future<void> sendTestNotification() async {
    if (!_isInitialized || _userId == null) {
      debugPrint('⚠️ Push notification service not initialized');
      return;
    }

    try {
      await SupabaseService.sendPushNotification(
        userId: _userId!,
        title: 'Test Notification',
        body: 'This is a test notification from your airline app!',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('✅ Test notification sent');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// Send a custom notification
  Future<void> sendCustomNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? journeyId,
    String? stage,
  }) async {
    if (!_isInitialized || _userId == null) {
      debugPrint('⚠️ Push notification service not initialized');
      return;
    }

    try {
      await SupabaseService.sendPushNotification(
        userId: _userId!,
        title: title,
        body: body,
        data: data,
        journeyId: journeyId,
        stage: stage,
      );

      debugPrint('✅ Custom notification sent: $title');
    } catch (e) {
      debugPrint('❌ Error sending custom notification: $e');
    }
  }

  /// Send batch notifications to multiple users
  Future<void> sendBatchNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? journeyId,
    String? stage,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Push notification service not initialized');
      return;
    }

    try {
      await SupabaseService.sendBatchNotifications(
        userIds: userIds,
        title: title,
        body: body,
        data: data,
        journeyId: journeyId,
        stage: stage,
      );

      debugPrint('✅ Batch notifications sent to ${userIds.length} users');
    } catch (e) {
      debugPrint('❌ Error sending batch notifications: $e');
    }
  }

  /// Update user ID (useful when user logs in)
  Future<void> updateUserId(String userId) async {
    _userId = userId;
    
    if (_isInitialized && _deviceToken != null) {
      await _registerForPushNotifications();
    }
  }

  /// Get current push token
  String? get pushToken => _deviceToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Clear push token (useful when user logs out)
  Future<void> clearPushToken() async {
    if (_userId != null) {
      try {
        await SupabaseService.updateUserPushToken(
          userId: _userId!,
          pushToken: '',
        );
        debugPrint('✅ Push token cleared for user');
      } catch (e) {
        debugPrint('❌ Error clearing push token: $e');
      }
    }

    _userId = null;
    _deviceToken = null;
    _isInitialized = false;

    // Clear cached token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_token');
  }
}
