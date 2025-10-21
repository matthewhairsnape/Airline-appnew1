# Push Notification Testing Guide

This guide provides comprehensive instructions for testing push notifications in your Flutter airline app.

## 🚀 Quick Start

1. **Navigate to Test Screen**: Go to `/push-notification-test` in your app
2. **Check Token Status**: Verify FCM token is generated
3. **Test Database**: Ensure token is saved to Supabase
4. **Send Test Notification**: Use Firebase Console or the built-in simulator

## 📱 Testing Methods

### 1. Built-in Test Screen

The enhanced test screen (`/push-notification-test`) provides:

#### **FCM Token Status**
- ✅ View current FCM token
- ✅ Check token length and validity
- ✅ Refresh token if needed

#### **User Authentication Status**
- ✅ Verify user is logged in
- ✅ Display user ID and email
- ✅ Check authentication state

#### **Database Token Verification**
- ✅ Check if token is saved in Supabase
- ✅ Compare current token with saved token
- ✅ Verify token consistency

#### **Testing Actions**
- 🔔 **Save Token for Current User**: Manually save FCM token
- 🔔 **Check Notification Permissions**: Verify iOS permissions
- 🔔 **Simulate Local Notification**: Test notification handling
- 🔔 **Firebase Console Instructions**: Get step-by-step guide

#### **Topic Management**
- 📢 Subscribe to `airline_updates` topic
- 📢 Unsubscribe from topics
- 📢 Test topic-based notifications

#### **Real-time Test Results**
- 📊 Live notification counter
- 📊 Detailed test logs
- 📊 Foreground/background message tracking
- 📊 Notification tap handling

### 2. Firebase Console Testing

#### **Step-by-Step Instructions**

1. **Access Firebase Console**
   - Go to [console.firebase.google.com](https://console.firebase.google.com)
   - Select your project

2. **Navigate to Cloud Messaging**
   - Click "Cloud Messaging" in the left sidebar
   - Click "Send your first message"

3. **Configure Test Message**
   ```
   Title: Test Notification
   Body: Testing push notifications from Firebase Console
   Target: Single device
   FCM registration token: [Your token from test screen]
   ```

4. **Send Test Message**
   - Click "Send test message"
   - Check your device for the notification

#### **Important Notes**
- ⚠️ **Physical Device Required**: Push notifications don't work on simulators
- ⚠️ **iOS Certificate**: Ensure APNs certificate is uploaded to Firebase
- ⚠️ **App State**: Test both foreground and background states

### 3. Backend API Testing

#### **Using Postman or cURL**

```bash
# Send notification via FCM API
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_FROM_TEST_SCREEN",
    "notification": {
      "title": "Test Notification",
      "body": "Testing from backend API"
    },
    "data": {
      "journey_id": "123",
      "type": "test"
    }
  }'
```

#### **Using Firebase Admin SDK**

```javascript
const admin = require('firebase-admin');

const message = {
  notification: {
    title: 'Flight Update',
    body: 'Your flight has been delayed by 30 minutes'
  },
  data: {
    journey_id: '123',
    type: 'flight_delay'
  },
  token: 'FCM_TOKEN_FROM_TEST_SCREEN'
};

admin.messaging().send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.log('Error sending message:', error);
  });
```

## 🔍 Testing Scenarios

### 1. Basic Functionality Test

**Steps:**
1. Open test screen
2. Verify FCM token is generated
3. Check user authentication
4. Save token to database
5. Verify database token matches

**Expected Results:**
- ✅ FCM token displayed
- ✅ User logged in
- ✅ Token saved to database
- ✅ Tokens match

### 2. Permission Test

**Steps:**
1. Click "Check Notification Permissions"
2. Review permission status
3. If denied, go to iOS Settings > Notifications > Your App
4. Enable notifications

**Expected Results:**
- ✅ Authorization Status: authorized
- ✅ Alert: enabled
- ✅ Badge: enabled
- ✅ Sound: enabled

### 3. Foreground Notification Test

**Steps:**
1. Keep app open in foreground
2. Send test notification from Firebase Console
3. Check test results section
4. Verify notification data is captured

**Expected Results:**
- ✅ Notification appears in test results
- ✅ Title and body are captured
- ✅ Data payload is logged
- ✅ Timestamp is recorded

### 4. Background Notification Test

**Steps:**
1. Minimize app to background
2. Send test notification from Firebase Console
3. Tap the notification
4. Check test results section

**Expected Results:**
- ✅ Notification appears in system tray
- ✅ Tapping notification opens app
- ✅ Notification tap is logged in test results

### 5. Topic Subscription Test

**Steps:**
1. Subscribe to `airline_updates` topic
2. Send topic-based notification from Firebase Console
3. Check if notification is received
4. Unsubscribe from topic
5. Send another notification (should not be received)

**Expected Results:**
- ✅ Subscription successful
- ✅ Topic notifications received
- ✅ Unsubscription successful
- ✅ No notifications after unsubscribing

## 🐛 Troubleshooting

### Common Issues

#### **No FCM Token Generated**
- **Cause**: iOS simulator or missing APNs certificate
- **Solution**: Use physical device and ensure APNs certificate is uploaded

#### **Token Not Saved to Database**
- **Cause**: User not authenticated or database connection issue
- **Solution**: Check authentication status and Supabase connection

#### **Notifications Not Received**
- **Cause**: Missing permissions or incorrect configuration
- **Solution**: Check iOS notification settings and Firebase configuration

#### **Token Mismatch**
- **Cause**: Token refresh or multiple app instances
- **Solution**: Refresh token and save again

### Debug Steps

1. **Check Test Screen**: Review all status indicators
2. **Verify Database**: Check Supabase for saved tokens
3. **Test Permissions**: Ensure iOS notifications are enabled
4. **Check Logs**: Review test results for error messages
5. **Firebase Console**: Verify project configuration

## 📊 Monitoring and Analytics

### Test Results Tracking

The test screen automatically tracks:
- 📈 Notification count
- 📈 Permission status
- 📈 Token generation success
- 📈 Database save operations
- 📈 Foreground/background message handling

### Real-time Monitoring

- 🔄 Live notification counter
- 🔄 Automatic test result logging
- 🔄 Error tracking and reporting
- 🔄 Performance metrics

## 🚀 Production Testing

### Pre-Production Checklist

- [ ] FCM token generation working
- [ ] Database token storage working
- [ ] iOS permissions properly requested
- [ ] Foreground notifications working
- [ ] Background notifications working
- [ ] Notification tap handling working
- [ ] Topic subscriptions working
- [ ] Error handling implemented
- [ ] APNs certificate uploaded
- [ ] Firebase project configured

### Load Testing

1. **Multiple Users**: Test with multiple user accounts
2. **High Volume**: Send notifications to many users
3. **Concurrent**: Test simultaneous notifications
4. **Performance**: Monitor app performance during notifications

## 📝 Best Practices

### Development
- Always test on physical devices
- Use the test screen for debugging
- Monitor test results regularly
- Keep tokens secure and private

### Production
- Implement proper error handling
- Monitor notification delivery rates
- Use topics for broad notifications
- Implement user preference management

## 🆘 Support

If you encounter issues:

1. **Check Test Screen**: Review all status indicators
2. **Review Logs**: Check test results for error messages
3. **Verify Configuration**: Ensure Firebase and Supabase are properly configured
4. **Test Permissions**: Verify iOS notification permissions
5. **Check Documentation**: Review Firebase and Supabase documentation

## 📚 Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Firebase Messaging Plugin](https://pub.dev/packages/firebase_messaging)
- [iOS Push Notifications Guide](https://developer.apple.com/documentation/usernotifications)

---

**Happy Testing! 🎉**

The push notification system is now fully equipped with comprehensive testing capabilities. Use the test screen to verify everything is working correctly before deploying to production.
