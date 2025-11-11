-- ============================================================================
-- DIAGNOSTIC SCRIPT: Why trigger didn't fire
-- ============================================================================
-- Run this to find out why your notification didn't work
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '🔍 DIAGNOSING TRIGGER ISSUE'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''

-- ============================================================================
-- CHECK 1: Is trigger set up?
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '1️⃣ Checking Trigger Setup'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  CASE tgenabled
    WHEN 'O' THEN '✅ Enabled'
    WHEN 'D' THEN '❌ Disabled'
    ELSE '⚠️ Unknown'
  END as status
FROM pg_trigger 
WHERE tgname = 'journey_status_notification_trigger';

-- If empty, trigger doesn't exist
SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger')
    THEN '✅ Trigger exists'
    ELSE '❌ TRIGGER NOT FOUND - Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql first!'
  END as trigger_check;

\echo ''

-- ============================================================================
-- CHECK 2: Is function set up?
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '2️⃣ Checking Function Setup'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  proname as function_name,
  CASE 
    WHEN proname = 'notify_flight_status_change' THEN '✅ Function exists'
    ELSE '❌ Function not found'
  END as status
FROM pg_proc 
WHERE proname = 'notify_flight_status_change';

SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'notify_flight_status_change')
    THEN '✅ Function exists'
    ELSE '❌ FUNCTION NOT FOUND - Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql first!'
  END as function_check;

\echo ''

-- ============================================================================
-- CHECK 3: Check pg_net extension (needed for trigger)
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '3️⃣ Checking pg_net Extension'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  extname as extension_name,
  extversion as version
FROM pg_extension 
WHERE extname = 'pg_net';

SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
    THEN '✅ pg_net extension installed'
    ELSE '❌ pg_net NOT INSTALLED - Add this: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END as pg_net_check;

\echo ''

-- ============================================================================
-- CHECK 4: Check your journey and user
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '4️⃣ Checking Journey and User'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  j.id as journey_id,
  j.passenger_id as user_id,
  j.status,
  j.current_phase,
  CASE 
    WHEN j.passenger_id IS NULL THEN '❌ NO USER ID'
    ELSE '✅ Has user ID'
  END as user_check,
  CASE 
    WHEN u.fcm_token IS NOT NULL THEN '✅ Has FCM token'
    ELSE '❌ NO FCM TOKEN'
  END as fcm_check,
  u.fcm_token IS NOT NULL as has_fcm_token,
  u.email as user_email
FROM journeys j
LEFT JOIN users u ON u.id = j.passenger_id
WHERE j.id = '974ebeb1-29f8-4876-817f-ab098ddaa54e';

\echo ''

-- ============================================================================
-- CHECK 5: Check if phase/status actually changed
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '5️⃣ Important: Trigger only fires on CHANGE'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo '⚠️  The trigger ONLY fires if the phase/status ACTUALLY CHANGES'
\echo '⚠️  If you update to the same value, it won''t fire!'
\echo ''
\echo 'Try this: Update to a DIFFERENT phase first, then back to boarding'
\echo ''
\echo '-- Step 1: Update to a different phase'
\echo 'UPDATE journeys'
\echo 'SET current_phase = ''pre_check_in'','
\echo '    status = ''scheduled'','
\echo '    updated_at = NOW()'
\echo 'WHERE id = ''974ebeb1-29f8-4876-817f-ab098ddaa54e'';'
\echo ''
\echo '-- Step 2: Wait 2 seconds, then update to boarding (THIS will trigger)'
\echo 'UPDATE journeys'
\echo 'SET current_phase = ''boarding'','
\echo '    status = ''in_progress'','
\echo '    updated_at = NOW()'
\echo 'WHERE id = ''974ebeb1-29f8-4876-817f-ab098ddaa54e'';'
\echo ''

-- ============================================================================
-- CHECK 6: Check notification logs
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '6️⃣ Checking Notification Logs'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  COUNT(*) as total_logs,
  MAX(sent_at) as last_notification
FROM notification_logs
WHERE journey_id = '974ebeb1-29f8-4876-817f-ab098ddaa54e';

SELECT * FROM notification_logs
WHERE journey_id = '974ebeb1-29f8-4876-817f-ab098ddaa54e'
ORDER BY sent_at DESC
LIMIT 5;

\echo ''

-- ============================================================================
-- CHECK 7: Manual test (direct function call)
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '7️⃣ Manual Test: Call Edge Function Directly'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'If trigger doesn''t work, test the Edge Function directly:'
\echo ''
\echo 'Go to: Supabase Dashboard → Edge Functions → flight-update-notification'
\echo 'Or use curl:'
\echo ''
\echo 'curl --location ''https://otidfywfqxyxteixpqre.supabase.co/functions/v1/flight-update-notification'' \'
\echo '  --header ''Authorization: Bearer YOUR_SERVICE_ROLE_KEY'' \'
\echo '  --header ''apikey: YOUR_SERVICE_ROLE_KEY'' \'
\echo '  --header ''Content-Type: application/json'' \'
\echo '  --data ''{'
\echo '    "journeyId": "974ebeb1-29f8-4876-817f-ab098ddaa54e",'
\echo '    "status": "in_progress",'
\echo '    "phase": "boarding"'
\echo '  }'''
\echo ''

-- ============================================================================
-- SUMMARY
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '📋 SUMMARY'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Common issues:'
\echo '1. ❌ Trigger not set up → Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql'
\echo '2. ❌ pg_net extension missing → Add: CREATE EXTENSION IF NOT EXISTS pg_net;'
\echo '3. ❌ User has no FCM token → User needs to open app and grant permissions'
\echo '4. ❌ Edge Function not deployed → Deploy: supabase functions deploy flight-update-notification'
\echo '5. ❌ Phase didn''t actually change → Update to different value first'
\echo ''
\echo 'Next steps:'
\echo '1. Run all checks above'
\echo '2. Check Supabase Dashboard → Edge Functions → flight-update-notification → Logs'
\echo '3. Check Supabase Dashboard → Logs → Database (for trigger errors)'
\echo ''

