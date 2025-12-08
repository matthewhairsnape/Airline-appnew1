-- ============================================================================
-- TEST SCRIPT: Flight Status Notification Trigger
-- ============================================================================
-- This script helps you test if notifications are sent when flight status
-- is updated in the database.
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '🧪 FLIGHT STATUS NOTIFICATION TEST'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''

-- ============================================================================
-- STEP 1: Verify Setup
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '1️⃣ Checking Setup'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- Check trigger exists
SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger')
    THEN '✅ Trigger exists'
    ELSE '❌ Trigger NOT found - Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql first!'
  END as trigger_status;

-- Check function exists
SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'notify_flight_status_change')
    THEN '✅ Function exists'
    ELSE '❌ Function NOT found - Run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql first!'
  END as function_status;

\echo ''

-- ============================================================================
-- STEP 2: Find Test Journey
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '2️⃣ Finding Test Journey'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Recent journeys with FCM tokens:'

SELECT 
  j.id as journey_id,
  j.passenger_id as user_id,
  j.status as current_status,
  j.current_phase as current_phase,
  CASE WHEN u.fcm_token IS NOT NULL THEN '✅' ELSE '❌' END as has_fcm_token,
  COALESCE(f.carrier_code || f.flight_number, 'N/A') as flight_code,
  j.updated_at
FROM journeys j
LEFT JOIN users u ON u.id = j.passenger_id
LEFT JOIN flights f ON f.id = j.flight_id
WHERE j.passenger_id IS NOT NULL
ORDER BY j.updated_at DESC
LIMIT 5;

\echo ''
\echo '⚠️  IMPORTANT: Copy the journey_id and user_id from above'
\echo '⚠️  Make sure the journey has ✅ for has_fcm_token'
\echo ''

-- ============================================================================
-- STEP 3: Manual Test Query (UPDATE THIS WITH YOUR JOURNEY_ID)
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '3️⃣ Test Commands'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'REPLACE YOUR_JOURNEY_ID_HERE with the journey_id from Step 2'
\echo 'Then run ONE of these commands to test:'
\echo ''

-- Test 1: Update to boarding phase
\echo '-- Test 1: Update to boarding phase (this should trigger notification)'
\echo 'UPDATE journeys'
\echo 'SET '
\echo '  current_phase = ''boarding'','
\echo '  status = ''in_progress'','
\echo '  updated_at = NOW()'
\echo 'WHERE id = ''YOUR_JOURNEY_ID_HERE'';'
\echo ''

-- Test 2: Update to departed phase
\echo '-- Test 2: Update to departed phase'
\echo 'UPDATE journeys'
\echo 'SET '
\echo '  current_phase = ''departed'','
\echo '  status = ''in_progress'','
\echo '  updated_at = NOW()'
\echo 'WHERE id = ''YOUR_JOURNEY_ID_HERE'';'
\echo ''

-- Test 3: Update to landed phase
\echo '-- Test 3: Update to landed phase'
\echo 'UPDATE journeys'
\echo 'SET '
\echo '  current_phase = ''landed'','
\echo '  status = ''in_progress'','
\echo '  updated_at = NOW()'
\echo 'WHERE id = ''YOUR_JOURNEY_ID_HERE'';'
\echo ''

-- Test 4: Update status only
\echo '-- Test 4: Update status only'
\echo 'UPDATE journeys'
\echo 'SET '
\echo '  status = ''completed'','
\echo '  updated_at = NOW()'
\echo 'WHERE id = ''YOUR_JOURNEY_ID_HERE'';'
\echo ''

-- ============================================================================
-- STEP 4: Verify Notification Logs
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '4️⃣ Check Notification Logs'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'After running the UPDATE command, check logs with:'
\echo ''
\echo 'SELECT '
\echo '  id,'
\echo '  user_id,'
\echo '  journey_id,'
\echo '  title,'
\echo '  body,'
\echo '  type,'
\echo '  status,'
\echo '  sent_at'
\echo 'FROM notification_logs'
\echo 'WHERE journey_id = ''YOUR_JOURNEY_ID_HERE'''
\echo 'ORDER BY sent_at DESC'
\echo 'LIMIT 5;'
\echo ''

-- ============================================================================
-- STEP 5: Quick Test (Replace journey_id manually)
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '5️⃣ Quick Test (Uncomment and replace journey_id)'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Uncomment the line below and replace YOUR_JOURNEY_ID_HERE:'
\echo ''

-- Uncomment and replace YOUR_JOURNEY_ID_HERE with actual journey ID
-- UPDATE journeys
-- SET 
--   current_phase = 'boarding',
--   status = 'in_progress',
--   updated_at = NOW()
-- WHERE id = 'YOUR_JOURNEY_ID_HERE';

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ Test Setup Complete'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Next Steps:'
\echo '1. Copy a journey_id from Step 2 (one with ✅ FCM token)'
\echo '2. Run one of the UPDATE commands from Step 3'
\echo '3. Check your device for notification'
\echo '4. Check Supabase Dashboard → Edge Functions → flight-update-notification → Logs'
\echo '5. Check notification_logs table (Step 4)'
\echo ''

