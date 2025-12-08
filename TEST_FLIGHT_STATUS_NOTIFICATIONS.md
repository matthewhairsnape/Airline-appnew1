# Test Flight Status Notification System

This guide will help you test whether notifications are automatically sent when flight status is updated in the database.

## Prerequisites

1. ✅ Database trigger is set up (run `SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql` in Supabase SQL Editor)
2. ✅ Edge Functions deployed:
   - `send-push-notification`
   - `flight-update-notification`
3. ✅ User has FCM token saved in `users.fcm_token`
4. ✅ FCM Server Key is configured in Supabase Secrets

## Test Steps

### Step 1: Verify Setup

Run this SQL in Supabase SQL Editor to verify setup:

```sql
-- Check if trigger exists
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled
FROM pg_trigger 
WHERE tgname = 'journey_status_notification_trigger';

-- Check if function exists
SELECT 
  proname as function_name,
  prosrc as function_source
FROM pg_proc 
WHERE proname = 'notify_flight_status_change';

-- Check recent journeys with user info
SELECT 
  j.id as journey_id,
  j.passenger_id as user_id,
  j.status,
  j.current_phase,
  u.fcm_token IS NOT NULL as has_fcm_token,
  f.carrier_code,
  f.flight_number,
  j.updated_at
FROM journeys j
LEFT JOIN users u ON u.id = j.passenger_id
LEFT JOIN flights f ON f.id = j.flight_id
WHERE j.passenger_id IS NOT NULL
ORDER BY j.updated_at DESC
LIMIT 5;
```

**Expected Result**: You should see:
- ✅ Trigger exists and is enabled
- ✅ Function exists
- ✅ At least one journey with a user that has an FCM token

### Step 2: Find a Test Journey

Get a journey ID and user ID for testing:

```sql
SELECT 
  j.id as journey_id,
  j.passenger_id as user_id,
  j.status as current_status,
  j.current_phase as current_phase,
  u.fcm_token IS NOT NULL as has_fcm_token,
  f.carrier_code || f.flight_number as flight_code
FROM journeys j
LEFT JOIN users u ON u.id = j.passenger_id
LEFT JOIN flights f ON f.id = j.flight_id
WHERE j.passenger_id IS NOT NULL
  AND u.fcm_token IS NOT NULL
  AND j.status != 'completed'
  AND j.current_phase != 'arrived'
ORDER BY j.created_at DESC
LIMIT 1;
```

**Save these values:**
- `journey_id`: ____________________
- `user_id`: ____________________
- `current_status`: ____________________
- `current_phase`: ____________________

### Step 3: Test Status Update (Phase Change)

Update the journey's phase to trigger a notification:

```sql
-- Update journey phase (this will trigger the notification)
UPDATE journeys
SET 
  current_phase = 'boarding',
  status = 'in_progress',
  updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';
```

**Expected Result:**
1. ✅ SQL update succeeds
2. ✅ Check Supabase Dashboard → Logs → Database → Look for trigger execution logs
3. ✅ Check Supabase Dashboard → Edge Functions → `flight-update-notification` → Look for execution logs
4. ✅ Check Supabase Dashboard → Edge Functions → `send-push-notification` → Look for execution logs
5. ✅ Notification should appear on your device

### Step 4: Test Status Update (Status Change)

Update the journey's status:

```sql
-- Update journey status (this will trigger the notification)
UPDATE journeys
SET 
  status = 'completed',
  current_phase = 'arrived',
  updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';
```

**Expected Result:**
1. ✅ SQL update succeeds
2. ✅ Check logs for trigger and function execution
3. ✅ Notification should appear on your device

### Step 5: Test Different Phases

Test different phases to see different notification messages:

```sql
-- Test: Pre-check-in
UPDATE journeys
SET current_phase = 'pre_check_in', updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';

-- Test: Boarding
UPDATE journeys
SET current_phase = 'boarding', updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';

-- Test: Departed
UPDATE journeys
SET current_phase = 'departed', updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';

-- Test: Landed
UPDATE journeys
SET current_phase = 'landed', updated_at = NOW()
WHERE id = 'YOUR_JOURNEY_ID_HERE';
```

### Step 6: Verify Notification Logs

Check if notifications are being logged:

```sql
-- Check notification logs
SELECT 
  id,
  user_id,
  journey_id,
  title,
  body,
  type,
  status,
  sent_at
FROM notification_logs
WHERE journey_id = 'YOUR_JOURNEY_ID_HERE'
ORDER BY sent_at DESC
LIMIT 10;
```

### Step 7: Test via API (Alternative Method)

You can also test by calling the Edge Function directly via API:

```bash
curl --location 'https://otidfywfqxyxteixpqre.supabase.co/functions/v1/flight-update-notification' \
  --header 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  --header 'apikey: YOUR_SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "journeyId": "YOUR_JOURNEY_ID_HERE",
    "status": "in_progress",
    "phase": "boarding",
    "notificationType": "boarding"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "journeyId": "...",
  "userId": "...",
  "notificationSent": true,
  "message": "Notification sent successfully"
}
```

## Troubleshooting

### Issue: No notification received

1. **Check FCM Token:**
   ```sql
   SELECT id, email, fcm_token IS NOT NULL as has_token
   FROM users
   WHERE id = 'YOUR_USER_ID';
   ```
   If `has_token` is false, the user needs to open the app and refresh their FCM token.

2. **Check Trigger Logs:**
   - Go to Supabase Dashboard → Logs → Database
   - Look for errors or warnings from `notify_flight_status_change`

3. **Check Edge Function Logs:**
   - Go to Supabase Dashboard → Edge Functions → `flight-update-notification`
   - Check the latest execution logs for errors

4. **Check FCM Server Key:**
   - Verify `FCM_SERVER_KEY` is set in Supabase Secrets
   - Ensure it's the Legacy Server Key (starts with `AAAA...`)

### Issue: Trigger not firing

1. **Verify trigger is enabled:**
   ```sql
   SELECT tgname, tgenabled 
   FROM pg_trigger 
   WHERE tgname = 'journey_status_notification_trigger';
   ```
   `tgenabled` should be `O` (enabled).

2. **Check if phase/status actually changed:**
   - The trigger only fires if `status` or `current_phase` actually changes
   - Try updating with a different value than the current one

### Issue: Function returns 404

- Ensure `flight-update-notification` is deployed:
  ```bash
  supabase functions deploy flight-update-notification --project-ref otidfywfqxyxteixpqre
  ```

### Issue: Function returns 500

- Check Supabase Dashboard → Edge Functions → `flight-update-notification` → Logs
- Look for the specific error message

## Expected Notification Messages

- **pre_check_in**: "Check-in Available - Check-in is now available for [FLIGHT_CODE]."
- **boarding**: "Flight Boarding - [FLIGHT_CODE] is now boarding! Please proceed to the gate."
- **departed**: "Flight Departed - [FLIGHT_CODE] has departed. Enjoy your journey!"
- **landed**: "Flight Landed - [FLIGHT_CODE] has landed."
- **arrived**: "Flight Arrived - [FLIGHT_CODE] has arrived. Thank you for flying with us!"

## Notes

- The trigger fires automatically when `status` or `current_phase` is updated in the `journeys` table
- Notifications are only sent if the user has an FCM token
- Completed journeys (status: `completed`, phase: `arrived`) won't trigger notifications
- The trigger uses `passenger_id` from the journeys table to identify the user

