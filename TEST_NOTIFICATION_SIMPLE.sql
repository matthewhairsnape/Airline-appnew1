-- ============================================================================
-- SIMPLE NOTIFICATION TEST
-- ============================================================================
-- This provides a simpler way to test flight status notifications
-- ============================================================================

-- ============================================================================
-- STEP 1: Check if pg_net is installed
-- ============================================================================

\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '1️⃣ Checking pg_net Extension'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  extname,
  extversion,
  CASE 
    WHEN nspname = 'extensions' THEN '✅ Installed in extensions schema'
    ELSE '⚠️ Installed in ' || nspname || ' schema'
  END as status
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE extname = 'pg_net';

-- If nothing shows up, pg_net is not installed

-- ============================================================================
-- STEP 2: Find a test journey with user
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '2️⃣ Finding Test Journey'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- First, let's check the flights table structure to see where user_id is
\echo ''
\echo 'Checking flights table structure...'

SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'flights'
  AND column_name IN ('id', 'user_id', 'carrier_code', 'flight_number')
ORDER BY ordinal_position;

\echo ''
\echo 'Checking journeys table structure...'

SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'journeys'
  AND column_name IN ('id', 'flight_id', 'status', 'current_phase', 'user_id')
ORDER BY ordinal_position;

-- Now let's find a test journey
\echo ''
\echo 'Recent journeys for testing:'

-- Check if journeys has user_id column
DO $$
DECLARE
  has_user_id_in_journeys BOOLEAN;
  has_user_id_in_flights BOOLEAN;
BEGIN
  -- Check journeys table
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journeys' AND column_name = 'user_id'
  ) INTO has_user_id_in_journeys;
  
  -- Check flights table
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'flights' AND column_name = 'user_id'
  ) INTO has_user_id_in_flights;
  
  RAISE NOTICE 'user_id in journeys table: %', CASE WHEN has_user_id_in_journeys THEN '✅ YES' ELSE '❌ NO' END;
  RAISE NOTICE 'user_id in flights table: %', CASE WHEN has_user_id_in_flights THEN '✅ YES' ELSE '❌ NO' END;
END $$;

-- Show recent journeys (adapt based on schema)
SELECT 
  j.id as journey_id,
  j.status,
  j.current_phase,
  f.carrier_code,
  f.flight_number,
  f.id as flight_id,
  j.created_at,
  j.updated_at
FROM journeys j
LEFT JOIN flights f ON f.id = j.flight_id
ORDER BY j.updated_at DESC
LIMIT 5;

-- ============================================================================
-- STEP 3: Check user has FCM token
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '3️⃣ Checking FCM Tokens'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  id as user_id,
  CASE 
    WHEN fcm_token IS NOT NULL 
    THEN '✅ Has token: ' || SUBSTRING(fcm_token, 1, 30) || '...'
    ELSE '❌ NO TOKEN'
  END as token_status,
  updated_at
FROM users
ORDER BY updated_at DESC
LIMIT 5;

-- ============================================================================
-- STEP 4: Manual trigger test (Update a journey)
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '4️⃣ Manual Trigger Test'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo '📝 Copy a journey_id from above and run this:'
\echo ''
\echo '   UPDATE journeys'
\echo '   SET current_phase = ''boarding'','
\echo '       updated_at = NOW()'
\echo '   WHERE id = ''YOUR_JOURNEY_ID_HERE'';'
\echo ''
\echo '⚠️  IMPORTANT: The trigger will only fire if:'
\echo '   1. The trigger is installed (run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql)'
\echo '   2. The Edge Function is deployed'
\echo '   3. The user has an FCM token'
\echo '   4. Firebase secrets are configured in Supabase'
\echo ''

-- ============================================================================
-- STEP 5: Check if notification was logged
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '5️⃣ Check Notification Logs'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_logs')
    THEN '✅ notification_logs table exists'
    ELSE '❌ notification_logs table NOT found'
  END as table_status;

-- Show recent notification logs (if table exists)
SELECT 
  nl.id,
  nl.user_id,
  nl.journey_id,
  nl.title,
  nl.body,
  nl.type,
  nl.status,
  nl.sent_at
FROM notification_logs nl
ORDER BY nl.sent_at DESC
LIMIT 10;

-- If no rows show up, notifications haven't been sent yet

-- ============================================================================
-- STEP 6: Alternative test using Supabase REST API
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '6️⃣ Alternative: Test via curl (run in terminal)'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'If pg_net is not working, test the Edge Function directly with curl:'
\echo ''
\echo 'curl -X POST https://otidfywfqxyxteixpqre.supabase.co/functions/v1/flight-status-notification \'
\echo '  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \'
\echo '  -H "Content-Type: application/json" \'
\echo '  -d ''{'
\echo '    "journeyId": "YOUR_JOURNEY_ID",'
\echo '    "userId": "YOUR_USER_ID",'
\echo '    "oldStatus": "active",'
\echo '    "newStatus": "active",'
\echo '    "oldPhase": "at_airport",'
\echo '    "newPhase": "boarding",'
\echo '    "flightNumber": "912",'
\echo '    "carrier": "VA"'
\echo '  }'''
\echo ''

-- ============================================================================
-- CHECKLIST
-- ============================================================================

\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ CHECKLIST'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo '1. ☐ pg_net extension installed?'
\echo '2. ☐ Trigger created? (run SETUP_FLIGHT_STATUS_NOTIFICATIONS.sql)'
\echo '3. ☐ Edge Function deployed? (supabase functions deploy flight-status-notification)'
\echo '4. ☐ Firebase secrets configured in Supabase Dashboard?'
\echo '5. ☐ User has FCM token? (check users table above)'
\echo '6. ☐ Journey exists to test with? (check journeys table above)'
\echo '7. ☐ Check Edge Function logs in Supabase Dashboard'
\echo ''
\echo '🔗 Edge Function Logs:'
\echo '   https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/functions/flight-status-notification/logs'
\echo ''

