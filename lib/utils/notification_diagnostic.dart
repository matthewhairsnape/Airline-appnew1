import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Comprehensive notification diagnostic tool
class NotificationDiagnostic {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Run complete diagnostic check
  static Future<Map<String, dynamic>> runFullDiagnostic() async {
    final results = <String, dynamic>{};

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 RUNNING FULL NOTIFICATION DIAGNOSTIC');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // 1. Platform Info
      debugPrint('📱 Platform Info:');
      results['platform'] = Platform.operatingSystem;
      results['platform_version'] = Platform.operatingSystemVersion;
      debugPrint('   OS: ${results['platform']}');
      debugPrint('   Version: ${results['platform_version']}');

      // 2. FCM Permission Status
      debugPrint('\n🔔 FCM Permission Status:');
      final settings = await _messaging.getNotificationSettings();
      results['fcm_authorization'] = settings.authorizationStatus.toString();
      results['fcm_alert'] = settings.alert.toString();
      results['fcm_badge'] = settings.badge.toString();
      results['fcm_sound'] = settings.sound.toString();
      debugPrint('   Authorization: ${results['fcm_authorization']}');
      debugPrint('   Alert: ${results['fcm_alert']}');
      debugPrint('   Badge: ${results['fcm_badge']}');
      debugPrint('   Sound: ${results['fcm_sound']}');

      // 3. Android-specific checks
      if (Platform.isAndroid) {
        debugPrint('\n🤖 Android-Specific Checks:');
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          // Check if notifications are enabled
          final areEnabled = await androidImplementation.areNotificationsEnabled();
          results['android_notifications_enabled'] = areEnabled;
          debugPrint('   Notifications Enabled: $areEnabled');

          if (areEnabled == false) {
            debugPrint('   ⚠️ CRITICAL: Notifications are DISABLED!');
            debugPrint('   💡 Go to: Settings → Apps → Your App → Notifications');
          }

          // Get active notifications
          try {
            final activeNotifications =
                await androidImplementation.getActiveNotifications();
            results['android_active_notifications_count'] =
                activeNotifications.length;
            debugPrint(
                '   Active Notifications: ${activeNotifications.length}');
          } catch (e) {
            debugPrint('   Could not get active notifications: $e');
          }

          // Check notification channels
          try {
            final channels =
                await androidImplementation.getNotificationChannels();
            results['android_channels_count'] = channels?.length ?? 0;
            debugPrint('   Notification Channels: ${channels?.length ?? 0}');

            if (channels != null && channels.isNotEmpty) {
              for (final channel in channels) {
                debugPrint('      - ${channel.id}: ${channel.name}');
                debugPrint('        Importance: ${channel.importance}');
                debugPrint(
                    '        Sound: ${channel.playSound}, Vibration: ${channel.enableVibration}');
              }
            }
          } catch (e) {
            debugPrint('   Could not get notification channels: $e');
          }
        } else {
          debugPrint('   ⚠️ Could not get Android implementation');
          results['android_implementation'] = 'not_available';
        }
      }

      // 4. iOS-specific checks
      if (Platform.isIOS) {
        debugPrint('\n🍎 iOS-Specific Checks:');
        final iosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iosImplementation != null) {
          results['ios_implementation'] = 'available';
          debugPrint('   iOS Implementation: Available');

          // Check for APNS token
          final apnsToken = await _messaging.getAPNSToken();
          results['ios_apns_token'] = apnsToken != null ? 'available' : 'null';
          debugPrint('   APNS Token: ${apnsToken != null ? "Available" : "NULL"}');
        } else {
          debugPrint('   ⚠️ Could not get iOS implementation');
          results['ios_implementation'] = 'not_available';
        }
      }

      // 5. FCM Token
      debugPrint('\n🔑 FCM Token:');
      try {
        final fcmToken = await _messaging.getToken();
        results['fcm_token_available'] = fcmToken != null;
        results['fcm_token_length'] = fcmToken?.length ?? 0;
        if (fcmToken != null) {
          debugPrint('   Token Available: YES');
          debugPrint('   Token Length: ${fcmToken.length}');
          debugPrint('   Token Preview: ${fcmToken.substring(0, fcmToken.length > 30 ? 30 : fcmToken.length)}...');
        } else {
          debugPrint('   ⚠️ Token Available: NO');
        }
      } catch (e) {
        debugPrint('   ❌ Error getting FCM token: $e');
        results['fcm_token_error'] = e.toString();
      }

      // 6. Test Notification
      debugPrint('\n🧪 Testing Local Notification:');
      try {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'diagnostic_channel',
          'Diagnostic Channel',
          channelDescription: 'Channel for diagnostic notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const NotificationDetails details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _plugin.show(
          999999,
          '🔍 Diagnostic Test',
          'If you see this, local notifications are working!',
          details,
        );

        results['test_notification_sent'] = true;
        debugPrint('   ✅ Test notification sent');
        debugPrint('   💡 Check if you see a notification on your device!');
      } catch (e) {
        debugPrint('   ❌ Failed to send test notification: $e');
        results['test_notification_sent'] = false;
        results['test_notification_error'] = e.toString();
      }

      // Summary
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 DIAGNOSTIC SUMMARY');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final issues = <String>[];

      if (results['fcm_authorization'] != 'AuthorizationStatus.authorized') {
        issues.add('FCM not authorized');
      }

      if (Platform.isAndroid &&
          results['android_notifications_enabled'] == false) {
        issues.add('Android notifications disabled in system settings');
      }

      if (!results['fcm_token_available']) {
        issues.add('No FCM token available');
      }

      if (!results['test_notification_sent']) {
        issues.add('Test notification failed');
      }

      if (issues.isEmpty) {
        debugPrint('✅ No issues detected!');
        debugPrint('   Notifications should be working.');
      } else {
        debugPrint('⚠️ Issues Detected:');
        for (final issue in issues) {
          debugPrint('   - $issue');
        }
      }

      results['issues'] = issues;
      results['success'] = issues.isEmpty;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stackTrace) {
      debugPrint('❌ Diagnostic failed: $e');
      debugPrint('Stack trace: $stackTrace');
      results['diagnostic_error'] = e.toString();
      results['success'] = false;
    }

    return results;
  }

  /// Quick check for notification permissions
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
    }

    // For iOS, check FCM authorization
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Open app notification settings (Android only)
  static Future<void> openNotificationSettings() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }
}

