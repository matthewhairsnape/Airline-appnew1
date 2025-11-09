-- ============================================================================
-- FIX: Edge Function Not Being Called by Cron
-- ============================================================================
-- This fixes the issue where cron runs but Edge Function has no logs
-- ============================================================================

-- Step 1: Enable pg_net extension (CRITICAL!)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Step 2: Grant permissions
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, service_role;

-- Step 3: Verify pg_net is enabled
SELECT 
  'pg_net Extension' as "Check",
  CASE 
    WHEN EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN '✅ ENABLED'
    ELSE '❌ NOT ENABLED'
  END as "Status"
FROM pg_extension 
WHERE extname = 'pg_net'
LIMIT 1;

-- Step 4: Recreate the function with better error handling
CREATE OR REPLACE FUNCTION call_check_flight_statuses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  supabase_url text := 'https://otidfywfqxyxteixpqre.supabase.co';
  service_role_key text;
BEGIN
  -- Get service role key from app_settings table
  BEGIN
    SELECT value INTO service_role_key 
    FROM app_settings 
    WHERE key = 'supabase_service_role_key' 
    LIMIT 1;
  EXCEPTION
    WHEN OTHERS THEN
      service_role_key := NULL;
  END;
  
  -- Fallback: Try to get from custom setting
  IF service_role_key IS NULL THEN
    BEGIN
      service_role_key := current_setting('app.settings.supabase_service_role_key', true);
    EXCEPTION
      WHEN OTHERS THEN
        service_role_key := NULL;
    END;
  END IF;
  
  IF service_role_key IS NULL OR service_role_key = '' THEN
    RAISE WARNING '❌ Service role key not configured. Run QUICK_SETUP_SERVICE_ROLE_KEY.sql first.';
    RETURN;
  END IF;

  -- Call the Edge Function using pg_net (async, non-blocking)
  -- Note: Use PERFORM since we don't need the return value
  BEGIN
    PERFORM net.http_post(
      url := supabase_url || '/functions/v1/check-flight-statuses',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key,
        'apikey', service_role_key
      ),
      body := '{}'::jsonb
    );
    
    RAISE NOTICE '✅ Edge Function call initiated successfully (async)';
  EXCEPTION
    WHEN undefined_function THEN
      RAISE WARNING '❌ net.http_post function not found. pg_net extension might not be enabled.';
      RAISE WARNING '   Run: CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;';
    WHEN OTHERS THEN
      RAISE WARNING '❌ Failed to call check-flight-statuses: %', SQLERRM;
      RAISE WARNING '   Error code: %', SQLSTATE;
  END;
END;
$$;

-- Step 5: Test the function manually
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '🧪 TESTING FUNCTION';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  RAISE NOTICE 'Calling call_check_flight_statuses()...';
  PERFORM call_check_flight_statuses();
  RAISE NOTICE '';
  RAISE NOTICE '✅ Function call completed';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next Steps:';
  RAISE NOTICE '1. Check Supabase Dashboard → Logs → Database for any warnings';
  RAISE NOTICE '2. Wait 1-2 minutes';
  RAISE NOTICE '3. Check Supabase Dashboard → Edge Functions → check-flight-statuses → Logs';
  RAISE NOTICE '4. You should see execution logs if the fix worked';
  RAISE NOTICE '';
END $$;

