# Flight Status Integration Setup Guide

This guide will help you set up real-time flight status monitoring using Cirium API, Supabase, and Firebase Cloud Messaging.

## 🎯 Overview

The flight status integration provides:
- Real-time flight status updates from Cirium API
- Automatic push notifications for status changes
- Journey phase tracking (boarding, departed, landed, etc.)
- Supabase database triggers for event processing
- Edge Functions for push notification delivery

## 📋 Prerequisites

1. **Cirium API Account**: Get your API credentials from [Cirium Developer Portal](https://developer.cirium.com/)
2. **Supabase Project**: With Edge Functions enabled
3. **Firebase Project**: With Cloud Messaging enabled
4. **Flutter App**: With the required dependencies

## 🔧 Setup Steps

### 1. Cirium API Configuration

1. Sign up for a Cirium API account
2. Get your App ID and App Key
3. Update `lib/config/cirium_config.dart`:

```dart
class CiriumConfig {
  static const String appId = 'YOUR_ACTUAL_APP_ID';
  static const String appKey = 'YOUR_ACTUAL_APP_KEY';
}
```

### 2. Supabase Database Setup

Run the following SQL in your Supabase SQL Editor:

```sql
-- Run supabase_flight_status_triggers.sql
-- This creates:
-- - Notification queue table
-- - Flight status update triggers
-- - Helper functions for processing
```

### 3. Supabase Edge Functions

Deploy the Edge Functions to your Supabase project:

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy functions
supabase functions deploy send-push-notification
supabase functions deploy process-flight-status
```

### 4. Environment Variables

Set these environment variables in your Supabase project:

- `FCM_SERVER_KEY`: Your Firebase Cloud Messaging server key
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key

### 5. Firebase Configuration

1. Add your `GoogleService-Info.plist` to `ios/Runner/`
2. Update `android/app/google-services.json`
3. Configure FCM in your Firebase console

### 6. Flutter Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  supabase_flutter: ^2.0.0
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
```

## 🚀 Usage

### Initialize the Service

```dart
import 'package:your_app/services/flight_status_integration.dart';
import 'package:your_app/config/cirium_config.dart';

// Initialize in your main.dart
await FlightStatusIntegration.initialize(
  ciriumAppId: CiriumConfig.appIdFromEnv,
  ciriumAppKey: CiriumConfig.appKeyFromEnv,
);
```

### Start Monitoring a Journey

```dart
// Start monitoring a specific journey
await FlightStatusIntegration.startJourneyMonitoring(
  journeyId: 'your-journey-id',
  userId: 'your-user-id',
  checkInterval: Duration(minutes: 5), // Optional
);
```

### Subscribe to Updates

```dart
// Subscribe to real-time updates
final subscription = FlightStatusIntegration.subscribeToJourneyUpdates(
  'journey-id',
  (update) {
    print('Journey updated: $update');
    // Handle the update in your UI
  },
);

// Don't forget to cancel the subscription
subscription.cancel();
```

### Manual Status Check

```dart
// Check flight status manually
final result = await FlightStatusIntegration.checkFlightStatus(
  journeyId: 'journey-id',
  carrier: 'AA',
  flightNumber: '1234',
  departureDate: DateTime.now(),
);
```

## 📱 Push Notifications

The system automatically sends push notifications for:
- Flight boarding
- Gate closed
- Flight departed
- Flight landed
- Flight arrived
- Flight cancelled
- Flight delayed

### Test Notifications

```dart
// Send a test notification
await FlightStatusIntegration.sendTestNotification('user-id');
```

## 🔍 Monitoring and Debugging

### Check Active Monitoring

```dart
// Get number of active monitors
int count = FlightStatusIntegration.activeMonitoringCount;

// Check if specific journey is monitored
bool isMonitored = FlightStatusIntegration.isJourneyMonitored('journey-id');
```

### View Status History

```dart
// Get journey status history
final history = await FlightStatusIntegration.getJourneyStatusHistory('journey-id');
```

## 🧪 Testing

Use the `FlightStatusTestScreen` to test the integration:

```dart
// Add to your app routes
static const flightStatusTest = "/flight-status-test";

// Navigate to test screen
Navigator.pushNamed(context, AppRoutes.flightStatusTest);
```

## 📊 Database Schema

The integration uses these tables:

- `journeys`: Stores journey information with `current_phase` field
- `journey_events`: Stores status change events
- `notification_queue`: Queues push notifications for processing
- `users`: Stores FCM tokens for push notifications

## 🔄 Data Flow

1. **Cirium API** → Flight status data
2. **FlightStatusMonitor** → Processes status changes
3. **Supabase Database** → Updates journey phase
4. **Database Triggers** → Create journey events
5. **Edge Functions** → Send push notifications
6. **Firebase FCM** → Deliver to user devices

## ⚙️ Configuration Options

### Check Interval

```dart
// Check every 2 minutes
Duration(minutes: 2)

// Check every 10 minutes
Duration(minutes: 10)
```

### Phase Mapping

The system maps Cirium statuses to app phases:

- `SCHEDULED` → `pre_check_in`
- `BOARDING` → `boarding`
- `DEPARTED` → `in_flight`
- `LANDED` → `landed`
- `ARRIVED` → `arrived`
- `CANCELLED` → `cancelled`

## 🚨 Troubleshooting

### Common Issues

1. **No notifications received**
   - Check FCM token is saved in Supabase
   - Verify Firebase configuration
   - Check Edge Function logs

2. **Status not updating**
   - Verify Cirium API credentials
   - Check network connectivity
   - Review Supabase logs

3. **Monitoring not starting**
   - Ensure journey exists in database
   - Check user authentication
   - Verify service initialization

### Debug Logs

Enable debug logging:

```dart
// Add to your main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    debugPrint('Debug mode enabled');
  }
  runApp(MyApp());
}
```

## 📈 Performance Considerations

- Monitor API rate limits for Cirium
- Use appropriate check intervals
- Clean up old notification queue entries
- Monitor Supabase function execution time

## 🔒 Security

- Store API keys securely
- Use environment variables
- Implement proper RLS policies
- Validate all inputs

## 📞 Support

For issues or questions:
1. Check the logs in Supabase
2. Review Firebase console
3. Test with the provided test screen
4. Check Cirium API documentation

## 🎉 Next Steps

After setup:
1. Test with real flight data
2. Customize notification messages
3. Add analytics tracking
4. Implement user preferences
5. Add more flight data sources
