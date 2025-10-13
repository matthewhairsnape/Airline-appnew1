# iOS Notification Permissions Guide

This guide explains how to properly handle push notification permissions on iOS for your airline app.

## 📱 iOS Notification Permission Requirements

### 1. **User Permission Request**
iOS requires explicit user permission for push notifications. The permission request happens automatically when your app first tries to register for notifications.

### 2. **Permission Types**
- **Alert**: Shows banners, alerts, and lock screen notifications
- **Badge**: Updates the app icon badge number
- **Sound**: Plays notification sounds
- **Announcement**: Siri can announce notifications
- **CarPlay**: Notifications in CarPlay
- **Critical Alert**: High-priority notifications (requires special entitlement)
- **Provisional**: Quiet notifications that don't require permission

## 🔧 Implementation

### Current Implementation
The app already includes proper permission handling in `PushNotificationService`:

```dart
// Request permission for notifications (iOS only)
if (Platform.isIOS) {
  final settings = await _firebaseMessaging.requestPermission(
    alert: true,           // Show alerts/banners
    announcement: false,   // Siri announcements
    badge: true,           // App icon badge
    carPlay: false,        // CarPlay notifications
    criticalAlert: false,  // Critical alerts (requires special entitlement)
    provisional: false,    // Provisional notifications (quiet notifications)
    sound: true,           // Sound for notifications
  );
}
```

### Permission Status Checking
```dart
// Check current permission status
final status = await PushNotificationService.checkPermissionStatus();

// Check if notifications are enabled
final isEnabled = await PushNotificationService.areNotificationsEnabled();

// Request permissions again (if user initially denied)
final granted = await PushNotificationService.requestPermissionsAgain();
```

## 📋 iOS Configuration

### Info.plist Requirements
Your `ios/Runner/Info.plist` already includes the necessary configuration:

```xml
<!-- Background modes for push notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>

<!-- Firebase configuration -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### AppDelegate Configuration
The app uses manual Firebase configuration in `AppDelegate.swift`:

```swift
import Firebase
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Set up FCM
    Messaging.messaging().delegate = self
    
    // Request notification permission
    UNUserNotificationCenter.current().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 🎯 Permission Flow

### 1. **First Launch**
1. App initializes Firebase
2. `PushNotificationService.initialize()` is called
3. Permission request dialog appears
4. User grants/denies permission
5. FCM token is obtained (if permission granted)

### 2. **Permission States**
- **Not Determined**: User hasn't been asked yet
- **Authorized**: User granted full permission
- **Denied**: User explicitly denied permission
- **Provisional**: User granted provisional (quiet) notifications

### 3. **Handling Denied Permissions**
If user denies permission:
1. Show explanation of why notifications are important
2. Provide button to open iOS Settings
3. Allow user to retry permission request

## 🛠️ Testing Permissions

### Using the Test Screen
The `FlightStatusTestScreen` includes a `NotificationPermissionWidget` that:
- Shows current permission status
- Allows requesting permissions
- Provides visual feedback
- Handles permission state changes

### Manual Testing
1. **Reset Permissions**: Go to iOS Settings > [Your App] > Notifications
2. **Test Different States**: Deny, then grant permissions
3. **Test Foreground**: Send notifications while app is open
4. **Test Background**: Send notifications while app is closed

## 📊 Permission Status Indicators

The app provides visual indicators for permission status:

- 🟢 **Green**: Notifications enabled
- 🔴 **Red**: Notifications denied
- 🟠 **Orange**: Permission not requested
- 🔵 **Blue**: Provisional notifications

## 🔄 Best Practices

### 1. **Timing**
- Request permission at appropriate times
- Don't request immediately on app launch
- Consider user context (e.g., after they add a flight)

### 2. **Explanation**
- Explain why notifications are important
- Show benefits (flight updates, boarding alerts)
- Be transparent about notification frequency

### 3. **Fallback**
- Handle denied permissions gracefully
- Provide alternative ways to get updates
- Allow users to enable later

### 4. **User Experience**
- Don't spam permission requests
- Provide clear instructions
- Make it easy to change settings

## 🚨 Common Issues

### 1. **Permission Not Requested**
- Ensure `PushNotificationService.initialize()` is called
- Check that Firebase is properly configured
- Verify iOS deployment target is 12.0+

### 2. **Token Not Generated**
- Check permission status first
- Ensure proper Firebase configuration
- Verify network connectivity

### 3. **Notifications Not Received**
- Check permission status
- Verify FCM token is saved to Supabase
- Check notification payload format
- Test with different app states

## 📱 iOS Settings Integration

### Opening Settings
```dart
import 'package:url_launcher/url_launcher.dart';

// Open iOS Settings for your app
await launchUrl(Uri.parse('app-settings:'));
```

### Checking Settings Changes
```dart
// Listen for app lifecycle changes
WidgetsBinding.instance.addObserver(
  LifecycleObserver(
    didChangeAppLifecycleState: (state) {
      if (state == AppLifecycleState.resumed) {
        // Check permission status again
        _checkPermissionStatus();
      }
    },
  ),
);
```

## 🎉 Success Indicators

When everything is working correctly, you should see:
- ✅ Permission request dialog appears
- ✅ User can grant/deny permissions
- ✅ FCM token is generated and saved
- ✅ Notifications are received in foreground
- ✅ Notifications are received in background
- ✅ Notification taps are handled properly

## 🔧 Debugging

### Enable Debug Logging
```dart
// Add to main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    debugPrint('Debug mode enabled');
  }
  runApp(MyApp());
}
```

### Check Logs
Look for these log messages:
- `✅ User granted full permission for notifications`
- `❌ User denied permission for notifications`
- `📱 FCM Token: [token]`
- `📱 Received foreground message: [messageId]`

## 📚 Additional Resources

- [Apple Push Notifications Documentation](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging iOS Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Flutter Firebase Messaging Plugin](https://pub.dev/packages/firebase_messaging)

Your app is now properly configured for iOS push notifications! 🚀
