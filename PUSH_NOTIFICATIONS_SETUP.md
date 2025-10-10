# Push Notifications Setup Guide

This guide explains how to set up push notifications for your Flutter airline app using Firebase Cloud Messaging (FCM) and Supabase.

## Overview

The push notification system has been implemented with the following components:

1. **Firebase Cloud Messaging (FCM)** - For sending push notifications
2. **Supabase** - For storing FCM tokens in the database
3. **iOS-specific configuration** - For handling iOS push notifications
4. **Automatic token management** - Tokens are saved during login/signup

## Files Added/Modified

### New Files
- `lib/services/push_notification_service.dart` - Core push notification service
- `lib/firebase_options.dart` - Firebase configuration
- `lib/screen/test/push_notification_test.dart` - Test screen for debugging
- `PUSH_NOTIFICATIONS_SETUP.md` - This documentation

### Modified Files
- `pubspec.yaml` - Added Firebase dependencies
- `ios/Runner/Info.plist` - Added iOS push notification capabilities
- `lib/main.dart` - Initialize Firebase and push notifications
- `lib/provider/auth_provider.dart` - Integrated FCM token saving
- `lib/utils/app_routes.dart` - Added test route

## Dependencies Added

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  firebase_auth: ^5.3.1
```

## iOS Configuration

### 1. Info.plist Updates
The following capabilities have been added to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### 2. Firebase Configuration
You need to update `lib/firebase_options.dart` with your actual Firebase project credentials:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Add iOS app to your project
4. Download `GoogleService-Info.plist` and place it in `ios/Runner/`
5. Update the `firebase_options.dart` file with your project details

### 3. iOS Push Notification Certificates
1. In Firebase Console, go to Project Settings > Cloud Messaging
2. Upload your iOS APNs certificate or key
3. Configure your app's bundle identifier

## Database Schema

The system uses the existing `users` table with the following FCM-related fields:

```sql
-- FCM token fields in users table
push_token text,        -- Legacy field (can be removed)
fcm_token text,         -- Current FCM token
```

## How It Works

### 1. Initialization
- Firebase is initialized in `main.dart`
- Push notification service is initialized
- iOS permission is requested automatically

### 2. Token Management
- FCM token is obtained when the app starts
- Token is automatically saved to Supabase when user logs in/signs up
- Token is refreshed automatically when it changes
- Token is cleared when user logs out

### 3. Authentication Integration
- `AuthProvider` automatically saves FCM tokens during authentication
- Tokens are associated with user accounts in the database
- No manual token management required

## Testing

### 1. Test Screen
Navigate to `/push-notification-test` to access the test screen where you can:
- View current FCM token
- Check authentication status
- Save token for current user
- Subscribe/unsubscribe from topics

### 2. Manual Testing
1. Run the app on a physical iOS device
2. Sign in or create an account
3. Check the test screen to verify token is generated
4. Verify token is saved in your Supabase database

### 3. Sending Test Notifications
You can send test notifications from:
1. Firebase Console > Cloud Messaging
2. Your backend server using FCM API
3. Third-party services like Postman

## Usage Examples

### Sending Notifications from Backend

```javascript
// Example using Firebase Admin SDK
const admin = require('firebase-admin');

// Send to specific user
const userTokens = await getFCMTokensForUser(userId);
const message = {
  notification: {
    title: 'Flight Update',
    body: 'Your flight has been delayed by 30 minutes'
  },
  data: {
    journey_id: '123',
    type: 'flight_delay'
  },
  tokens: userTokens
};

await admin.messaging().sendMulticast(message);
```

### Sending to Topics

```javascript
const message = {
  notification: {
    title: 'Airline News',
    body: 'New routes available for booking'
  },
  topic: 'airline_updates'
};

await admin.messaging().send(message);
```

## Troubleshooting

### Common Issues

1. **No FCM token generated**
   - Ensure you're testing on a physical device
   - Check iOS permissions are granted
   - Verify Firebase configuration

2. **Token not saved to database**
   - Check Supabase connection
   - Verify user is authenticated
   - Check database permissions

3. **Notifications not received**
   - Verify APNs certificate is uploaded to Firebase
   - Check device notification settings
   - Ensure app is properly configured for background notifications

### Debug Steps

1. Check the test screen for token status
2. Verify token in Supabase database
3. Test with Firebase Console notifications
4. Check iOS device logs for errors

## Security Considerations

1. **Token Storage**: FCM tokens are stored securely in Supabase
2. **User Association**: Tokens are only associated with authenticated users
3. **Token Cleanup**: Tokens are cleared on logout
4. **Permission Handling**: iOS permissions are properly requested

## Next Steps

1. **Configure Firebase Project**: Update `firebase_options.dart` with your credentials
2. **Upload APNs Certificate**: Configure iOS push notifications in Firebase Console
3. **Test Implementation**: Use the test screen to verify everything works
4. **Backend Integration**: Implement notification sending from your backend
5. **Production Setup**: Configure production APNs certificates

## Support

For issues or questions:
1. Check the test screen for debugging information
2. Review Firebase Console logs
3. Check iOS device logs
4. Verify Supabase database entries

The push notification system is now fully integrated and ready for use!
