# Airline App - Complete Setup Guide

This guide covers the setup and deployment of all remaining features for your airline app.

## 🚀 What's Been Implemented

### ✅ Push Notifications with Supabase Edge Functions
- **Edge Functions**: 3 functions for push notifications
- **Expo Integration**: Cross-platform push notifications
- **Real-time Updates**: Flight phase change notifications
- **Batch Notifications**: Send to multiple users

### ✅ Enhanced Cirium Integration
- **Retry Logic**: Automatic retry with exponential backoff
- **Rate Limiting**: Handles API rate limits gracefully
- **Error Handling**: Comprehensive error management
- **Historical Data**: Support for past flights

### ✅ Data Flow to Supabase
- **Journey Tracking**: Complete flight journey data
- **Stage Feedback**: Real-time feedback collection
- **User Analytics**: Push token management
- **Event Logging**: Comprehensive event tracking

### ✅ Admin Dashboard
- **Real-time Monitoring**: Live data updates
- **Flight Analytics**: Phase distribution and trends
- **User Management**: Journey and review tracking
- **Responsive Design**: Works on all devices

## 📱 Mobile App Setup

### 1. Environment Variables
Create a `.env` file in your Flutter project root:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Update Dependencies
The following new dependency has been added:
- `expo_notifications: ^0.1.0`

### 4. Initialize Push Notifications
The push notification service is automatically initialized in `main.dart`. Make sure to call `updateUserId()` when users log in:

```dart
// In your login success handler
await PushNotificationService().updateUserId(userId);
```

## 🗄️ Supabase Setup

### 1. Deploy Edge Functions
```bash
# Make sure you have Supabase CLI installed
npm install -g supabase

# Login to Supabase
supabase login

# Deploy functions
./deploy-functions.sh
```

### 2. Update Database Schema
Run the updated schema in your Supabase SQL Editor:

```sql
-- Add push token columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
```

### 3. Configure RLS Policies
The schema includes Row Level Security policies. Make sure they're applied:

```sql
-- Users can update their own push tokens
CREATE POLICY "Users can update their own push tokens" ON users
  FOR UPDATE USING (auth.uid() = id);
```

## 📊 Dashboard Setup

### 1. Install Dependencies
```bash
cd dashboard
npm install
```

### 2. Environment Variables
Create `dashboard/.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
```

### 3. Run Development Server
```bash
npm run dev
```

### 4. Deploy Dashboard
The dashboard is ready for deployment to Vercel, Netlify, or any Next.js hosting platform.

## 🔧 Configuration

### Push Notification Setup

1. **Expo Setup**:
   - Create an Expo account
   - Configure push notification certificates
   - Update Expo configuration in your app

2. **Firebase Setup** (for Android):
   - Create Firebase project
   - Add `google-services.json` to `android/app/`
   - Configure FCM in your app

3. **iOS Setup**:
   - Configure push notification capabilities
   - Add APNs certificates to Expo

### Cirium API Configuration

The Cirium API is already configured with your credentials in `lib/utils/global_variable.dart`:

```dart
const String ciriumAppId = "7f155a19";
const String ciriumAppKey = "6c5f44eeeb23a68f311a6321a96fcbdf";
```

## 🧪 Testing

### 1. Test Push Notifications
```dart
// Send a test notification
await PushNotificationService().sendTestNotification();
```

### 2. Test Flight Tracking
- Scan a boarding pass
- Check that journey is created in Supabase
- Verify real-time phase updates
- Confirm push notifications are sent

### 3. Test Dashboard
- Open dashboard in browser
- Verify real-time data updates
- Check all metrics are displaying correctly

## 📈 Monitoring

### Real-time Monitoring
- **Dashboard**: Live data visualization
- **Supabase Logs**: Function execution logs
- **App Logs**: Flutter debug console

### Key Metrics to Monitor
- Journey creation rate
- Push notification delivery rate
- Flight phase transition accuracy
- API error rates

## 🚨 Troubleshooting

### Common Issues

1. **Push Notifications Not Working**:
   - Check Expo configuration
   - Verify push tokens are being saved
   - Check Supabase function logs

2. **Cirium API Errors**:
   - Check API credentials
   - Verify rate limits
   - Check network connectivity

3. **Dashboard Not Loading**:
   - Verify environment variables
   - Check Supabase connection
   - Ensure RLS policies allow access

4. **Data Not Flowing to Supabase**:
   - Check Supabase initialization
   - Verify user authentication
   - Check database schema

### Debug Commands

```bash
# Check Supabase connection
flutter logs | grep "Supabase"

# Check push notifications
flutter logs | grep "Push"

# Check Cirium API
flutter logs | grep "Cirium"
```

## 📱 Production Deployment

### 1. Mobile App
- Build release version
- Test on real devices
- Submit to app stores

### 2. Supabase Functions
- Deploy to production
- Configure monitoring
- Set up alerts

### 3. Dashboard
- Deploy to production
- Configure custom domain
- Set up SSL certificates

## 🔐 Security Considerations

1. **API Keys**: Store securely, never commit to version control
2. **RLS Policies**: Ensure proper data access controls
3. **Push Tokens**: Encrypt sensitive user data
4. **Rate Limiting**: Implement proper API rate limiting

## 📞 Support

For issues with:
- **Flutter App**: Check Flutter documentation
- **Supabase**: Check Supabase documentation
- **Cirium API**: Check Cirium documentation
- **Dashboard**: Check Next.js documentation

## 🎉 Next Steps

1. **Deploy Edge Functions**: Run the deployment script
2. **Test Push Notifications**: Verify on real devices
3. **Deploy Dashboard**: Set up production monitoring
4. **Monitor Performance**: Track key metrics
5. **Gather Feedback**: Collect user feedback and iterate

Your airline app is now ready for production with all the requested features implemented!
