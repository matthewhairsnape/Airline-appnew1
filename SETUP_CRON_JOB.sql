-- ============================================================================
-- SETUP CRON JOB FOR FLIGHT STATUS CHECKING
-- ============================================================================
-- This sets up a cron job that periodically checks flight statuses and
-- updates journeys. When status changes, notifications are sent automatically.
-- ============================================================================

-- Step 1: Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Grant usage to postgres role
GRANT USAGE ON SCHEMA cron TO postgres;

-- Step 3: Create a function to call the Edge Function
CREATE OR REPLACE FUNCTION call_check_flight_statuses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  supabase_url text := 'https://otidfywfqxyxteixpqre.supabase.co';
  service_role_key text;
  response_status int;
  response_body text;
BEGIN
  -- Get service role key
  service_role_key := current_setting('app.settings.supabase_service_role_key', true);
  
  IF service_role_key IS NULL THEN
    RAISE WARNING 'Service role key not configured. Cannot call Edge Function.';
    RETURN;
  END IF;

  -- Call the Edge Function
  SELECT status, content::text
  INTO response_status, response_body
  FROM http((
    'POST',
    supabase_url || '/functions/v1/check-flight-statuses',
    ARRAY[
      http_header('Content-Type', 'application/json'),
      http_header('Authorization', 'Bearer ' || service_role_key),
      http_header('apikey', service_role_key)
    ],
    'application/json',
    '{}'
  )::http_request);

  -- Log the result
  RAISE NOTICE 'Flight status check completed: Status %, Response: %', response_status, LEFT(response_body, 200);
END;
$$;

-- Step 4: Schedule the cron job
-- Option A: Run every 5 minutes (for active monitoring)
SELECT cron.schedule(
  'check-flight-statuses-every-5min',
  '*/5 * * * *',  -- Every 5 minutes
  $$SELECT call_check_flight_statuses();$$
);

-- Option B: Run every 15 minutes (more conservative, less API calls)
-- Uncomment this and comment Option A if you want less frequent checks
-- SELECT cron.schedule(
--   'check-flight-statuses-every-15min',
--   '*/15 * * * *',  -- Every 15 minutes
--   $$SELECT call_check_flight_statuses();$$
-- );

-- Option C: Run every hour (least frequent, save API quota)
-- Uncomment this and comment Option A if you want hourly checks
-- SELECT cron.schedule(
--   'check-flight-statuses-hourly',
--   '0 * * * *',  -- Every hour
--   $$SELECT call_check_flight_statuses();$$
-- );

-- Step 5: Verify cron job is scheduled
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
WHERE jobname LIKE '%flight-status%';

-- Step 6: Alternative approach (if pg_cron doesn't work)
-- You can also use an external cron service like:
-- - cron-job.org
-- - EasyCron
-- - GitHub Actions
-- 
-- Call this URL periodically:
-- POST https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses
-- Headers:
--   Authorization: Bearer YOUR_SERVICE_ROLE_KEY
--   apikey: YOUR_SERVICE_ROLE_KEY

-- ============================================================================
-- MANUAL TESTING
-- ============================================================================

-- Test the function manually:
-- SELECT call_check_flight_statuses();

-- Or test the Edge Function directly via API:
-- curl -X POST 'https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses' \
--   -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
--   -H 'apikey: YOUR_SERVICE_ROLE_KEY' \
--   -H 'Content-Type: application/json' \
--   -d '{}'

-- ============================================================================
-- MANAGEMENT COMMANDS
-- ============================================================================

-- View all scheduled cron jobs:
-- SELECT * FROM cron.job;

-- View cron job execution history:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Unschedule a job:
-- SELECT cron.unschedule('check-flight-statuses-every-5min');

-- Update schedule:
-- SELECT cron.unschedule('check-flight-statuses-every-5min');
-- SELECT cron.schedule(
--   'check-flight-statuses-every-5min',
--   '*/10 * * * *',  -- New schedule: every 10 minutes
--   $$SELECT call_check_flight_statuses();$$
-- );

