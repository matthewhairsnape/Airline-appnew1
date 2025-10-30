# 🔧 Flight Notification Troubleshooting Guide

## 🐛 Issue: Notifications Not Working

The `pg_net` extension error you're seeing is common. Here's how to fix it:

---

## ✅ Quick Fix Steps

### Step 1: Fix pg_net Setup

Run this in **Supabase SQL Editor**:

```sql
-- Copy contents of FIX_PG_NET.sql and run it
```

Or manually:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role;
```

### Step 2: Update the Trigger Function

Run **SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql** again. I've updated it to use `net.http_post` instead of `extensions.net.http_post`.

### Step 3: Test Without pg_net (Bypass the Issue)

While debugging pg_net, test the Edge Function directly:

#### Option A: Using the Shell Script

```bash
# 1. Edit the script and add your SERVICE_ROLE_KEY
nano test-notification.sh

# 2. Run it
./test-notification.sh
```

#### Option B: Using curl directly

```bash
curl -X POST https://otidfywfqxyxteixpqre.supabase.co/functions/v1/flight-status-notification \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "journeyId": "974ebeb1-29f8-4876-817f-ab098ddaa54e",
    "userId": "0da7f390-aa01-4286-a847-265185d8e8ce",
    "oldStatus": "active",
    "newStatus": "active",
    "oldPhase": "at_airport",
    "newPhase": "boarding",
    "flightNumber": "912",
    "carrier": "VA"
  }'
```

**Replace:**
- `YOUR_SERVICE_ROLE_KEY` - Get from Supabase Dashboard → Settings → API → service_role key
- Journey ID and User ID with your actual values

---

## 🔍 Diagnosis Checklist

Run **TEST_NOTIFICATION_SIMPLE.sql** in Supabase SQL Editor to check:

1. ✅ **pg_net installed?**
   - If not: Contact Supabase support or use manual testing

2. ✅ **Edge Function deployed?**
   ```bash
   supabase functions deploy flight-status-notification --no-verify-jwt
   ```

3. ✅ **Firebase secrets configured?**
   - Go to: Supabase Dashboard → Settings → Edge Functions → Secrets
   - Add:
     - `FIREBASE_PROJECT_ID`
     - `FIREBASE_CLIENT_EMAIL`
     - `FIREBASE_PRIVATE_KEY`
   - Get these from your Firebase project settings → Service Accounts

4. ✅ **User has FCM token?**
   ```sql
   SELECT id, fcm_token FROM users WHERE id = 'YOUR_USER_ID';
   ```
   - If NULL: User needs to log into the app and grant notification permissions

5. ✅ **Trigger installed?**
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger';
   ```
   - If empty: Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql

---

## 🧪 Testing Methods

### Method 1: Update a Journey (Automatic Trigger)

```sql
UPDATE journeys
SET current_phase = 'boarding',
    updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID';
```

This should automatically trigger the notification via the database trigger.

### Method 2: Direct Edge Function Call (Manual)

Use the `test-notification.sh` script or curl (see above).

### Method 3: Check Logs

After any test:

1. **Edge Function Logs:**
   - https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/functions/flight-status-notification/logs

2. **Database Notification Logs:**
   ```sql
   SELECT * FROM notification_logs ORDER BY sent_at DESC LIMIT 10;
   ```

3. **Device Logs:**
   - iOS: Xcode Console
   - Android: Logcat

---

## ❌ Common Errors & Solutions

### Error: "cross-database references are not implemented"

**Cause:** pg_net extension issue or incorrect function call

**Solution:**
1. Run FIX_PG_NET.sql
2. Update trigger with SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql (now uses `net.http_post`)
3. If still fails: Use manual testing (curl) to verify Edge Function works

### Error: "No FCM token found for user"

**Cause:** User hasn't logged into app or notifications not enabled

**Solution:**
1. User must log into the app
2. Grant notification permissions when prompted
3. Check: `SELECT fcm_token FROM users WHERE id = 'USER_ID';`

### Error: "Firebase credentials not configured"

**Cause:** Missing Firebase secrets

**Solution:**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key (downloads JSON)
3. Add to Supabase: Dashboard → Settings → Edge Functions → Secrets:
   - `FIREBASE_PROJECT_ID`: From JSON `project_id`
   - `FIREBASE_CLIENT_EMAIL`: From JSON `client_email`
   - `FIREBASE_PRIVATE_KEY`: From JSON `private_key` (include `-----BEGIN/END-----`)

### Error: 404 Not Found

**Cause:** Edge Function not deployed

**Solution:**
```bash
supabase functions deploy flight-status-notification --no-verify-jwt
```

---

## 🎯 Expected Behavior

When working correctly:

1. **User updates journey** → Trigger fires
2. **Trigger calls** → Edge Function via pg_net
3. **Edge Function:**
   - Gets user's FCM token from database
   - Generates notification message based on phase/status
   - Sends to Firebase Cloud Messaging
   - Logs in `notification_logs` table
4. **User receives** → Push notification on device

---

## 📱 Notification Types

| Phase/Status | Title | Body |
|-------------|-------|------|
| `at_airport` | 🏢 At the Airport | Welcome! VA912 - Check-in and prepare for boarding. |
| `boarding` | 🎫 Boarding Started | VA912 is now boarding. Please proceed to your gate. |
| `in_flight` | ✈️ Flight Departed | VA912 is now in the air. Enjoy your flight! |
| `landed` | 🛬 Flight Landed | VA912 has landed safely. Welcome to your destination! |
| `completed` | 🎉 Journey Completed | Your journey for VA912 is complete. Please share your feedback! |
| `delayed` | ⏰ Flight Delayed | VA912 has been delayed. Check the app for updates. |
| `cancelled` | ❌ Flight Cancelled | VA912 has been cancelled. Please contact your airline. |

---

## 🆘 Still Not Working?

1. **Run diagnostics:**
   ```sql
   -- In Supabase SQL Editor
   \i TEST_NOTIFICATION_SIMPLE.sql
   ```

2. **Check all logs:**
   - Edge Function logs (Supabase Dashboard)
   - Database `notification_logs` table
   - Device logs (Xcode/Logcat)

3. **Test each component separately:**
   - Test Edge Function with curl ✅
   - Test FCM token is valid ✅
   - Test trigger fires ✅
   - Test pg_net works ✅

4. **If pg_net doesn't work:**
   - This is a Supabase platform limitation
   - Contact Supabase support
   - Notifications will work via manual testing
   - Consider alternative: Call Edge Function from Flutter app after status updates

---

## 🔗 Resources

- **Supabase Dashboard:** https://supabase.com/dashboard/project/otidfywfqxyxteixpqre
- **Edge Functions:** https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/functions
- **Firebase Console:** https://console.firebase.google.com/

---

## 📝 Files Reference

- `SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql` - Initial setup (trigger, function, table)
- `TEST_NOTIFICATION_SIMPLE.sql` - Simple diagnostic queries
- `DEBUG_NOTIFICATIONS.sql` - Comprehensive diagnostic
- `FIX_PG_NET.sql` - Fix pg_net permissions
- `test-notification.sh` - Manual test script
- `TEST_FLIGHT_NOTIFICATIONS.sql` - Detailed test queries

---

**Created:** October 30, 2025
**Last Updated:** October 30, 2025

