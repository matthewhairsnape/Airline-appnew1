-- ============================================================================
-- COMPLETE AUTOMATIC FLIGHT STATUS UPDATE SYSTEM
-- ============================================================================
-- This sets up the complete automatic system:
-- 1. Database trigger that fires when journey data changes
-- 2. Cron job that automatically checks flight statuses from Cirium API
-- 3. Edge Function that updates journeys, which triggers notifications
-- ============================================================================

-- Step 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- CRITICAL: Grant permissions for pg_net
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, service_role;

-- Step 2: Create/Update the trigger function for automatic notifications
CREATE OR REPLACE FUNCTION notify_flight_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  supabase_url text;
  service_role_key text;
  user_id_val uuid;
  notification_type text;
  should_notify boolean := false;
  http_response RECORD;
BEGIN
  -- Get Supabase configuration
  supabase_url := 'https://otidfywfqxyxteixpqre.supabase.co';
  
  -- Get service role key from app_settings table (created by SET_SERVICE_ROLE_KEY.sql)
  BEGIN
    SELECT value INTO service_role_key 
    FROM app_settings 
    WHERE key = 'supabase_service_role_key' 
    LIMIT 1;
  EXCEPTION
    WHEN OTHERS THEN
      service_role_key := NULL;
  END;
  
  -- Fallback: Try to get from custom setting (if set via Supabase Dashboard)
  IF service_role_key IS NULL THEN
    BEGIN
      service_role_key := current_setting('app.settings.supabase_service_role_key', true);
    EXCEPTION
      WHEN OTHERS THEN
        service_role_key := NULL;
    END;
  END IF;
  
  IF service_role_key IS NULL OR service_role_key = '' THEN
    RAISE WARNING '❌ TRIGGER: Service role key not configured. Run SET_SERVICE_ROLE_KEY.sql first to store the key in app_settings table.';
    RAISE WARNING '❌ TRIGGER: Cannot send notification for journey %', NEW.id;
    RETURN NEW;
  END IF;
  
  RAISE NOTICE '✅ TRIGGER: Service role key found (length: %)', LENGTH(service_role_key);

  -- Determine if notification should be sent
  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
      should_notify := true;
      notification_type := 'status_change';
      RAISE NOTICE '🔔 TRIGGER FIRED: Status changed from % to %', OLD.status, NEW.status;
    ELSIF (OLD.current_phase IS DISTINCT FROM NEW.current_phase) THEN
      should_notify := true;
      notification_type := 'phase_change';
      RAISE NOTICE '🔔 TRIGGER FIRED: Phase changed from % to %', OLD.current_phase, NEW.current_phase;
    ELSIF (OLD.gate IS DISTINCT FROM NEW.gate) THEN
      should_notify := true;
      notification_type := 'gate_change';
      RAISE NOTICE '🔔 TRIGGER FIRED: Gate changed from % to %', OLD.gate, NEW.gate;
    ELSIF (OLD.terminal IS DISTINCT FROM NEW.terminal) THEN
      should_notify := true;
      notification_type := 'terminal_change';
      RAISE NOTICE '🔔 TRIGGER FIRED: Terminal changed from % to %', OLD.terminal, NEW.terminal;
    END IF;
  ELSIF (TG_OP = 'INSERT' AND NEW.status = 'active') THEN
    should_notify := true;
    notification_type := 'journey_created';
    RAISE NOTICE '🔔 TRIGGER FIRED: New journey created with ID %', NEW.id;
  END IF;

  IF NOT should_notify THEN
    RAISE NOTICE '🔕 TRIGGER: No change detected, skipping notification';
    RETURN NEW;
  END IF;
  
  RAISE NOTICE '🔔 TRIGGER: Processing notification for journey %, type: %', NEW.id, notification_type;

  -- Get user_id from journey's passenger_id
  BEGIN
    user_id_val := NEW.passenger_id;
    IF user_id_val IS NULL THEN
      SELECT f.user_id INTO user_id_val FROM flights f WHERE f.id = NEW.flight_id LIMIT 1;
      IF user_id_val IS NULL THEN
        SELECT ju.user_id INTO user_id_val FROM journey_users ju WHERE ju.journey_id = NEW.id LIMIT 1;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      user_id_val := NULL;
  END;

  IF user_id_val IS NULL THEN
    RAISE WARNING '🔕 TRIGGER: No user_id found for journey %. Skipping notification.', NEW.id;
    RETURN NEW;
  END IF;
  
  RAISE NOTICE '🔔 TRIGGER: Found user_id % for journey %', user_id_val, NEW.id;

  -- Send notification via Edge Function (async, non-blocking)
  BEGIN
    RAISE NOTICE '🔔 TRIGGER: Calling Edge Function flight-update-notification...';
    RAISE NOTICE '🔔 TRIGGER: URL: %', supabase_url || '/functions/v1/flight-update-notification';
    RAISE NOTICE '🔔 TRIGGER: Service key length: %', LENGTH(service_role_key);
    
    SELECT * INTO http_response FROM net.http_post(
      url := supabase_url || '/functions/v1/flight-update-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key,
        'apikey', service_role_key
      ),
      body := jsonb_build_object(
        'journeyId', NEW.id::text,
        'status', COALESCE(NEW.status, ''),
        'phase', COALESCE(NEW.current_phase, ''),
        'gate', COALESCE(NEW.gate, ''),
        'terminal', COALESCE(NEW.terminal, ''),
        'oldGate', COALESCE(OLD.gate, ''),
        'oldTerminal', COALESCE(OLD.terminal, ''),
        'notificationType', notification_type
      )
    );
    
    RAISE NOTICE '✅ TRIGGER: Edge Function called successfully. Request ID: %', http_response.id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING '❌ TRIGGER: Notification failed for journey %: %', NEW.id, SQLERRM;
      RAISE WARNING '❌ TRIGGER: Error details: %', SQLSTATE;
  END;

  RETURN NEW;
END;
$$;

-- Step 3: Create/Update the trigger
-- Create separate triggers for INSERT and UPDATE to handle both cases
DROP TRIGGER IF EXISTS journey_status_notification_trigger_insert ON journeys;
DROP TRIGGER IF EXISTS journey_status_notification_trigger_update ON journeys;

-- Trigger for INSERT (new journeys)
CREATE TRIGGER journey_status_notification_trigger_insert
  AFTER INSERT ON journeys
  FOR EACH ROW
  WHEN (NEW.status = 'active')
  EXECUTE FUNCTION notify_flight_status_change();

-- Trigger for UPDATE (status/phase/gate/terminal changes)
CREATE TRIGGER journey_status_notification_trigger_update
  AFTER UPDATE OF status, current_phase, gate, terminal ON journeys
  FOR EACH ROW
  WHEN (
    (OLD.status IS DISTINCT FROM NEW.status) OR
    (OLD.current_phase IS DISTINCT FROM NEW.current_phase) OR
    (OLD.gate IS DISTINCT FROM NEW.gate) OR
    (OLD.terminal IS DISTINCT FROM NEW.terminal)
  )
  EXECUTE FUNCTION notify_flight_status_change();

-- Step 4: Create function to call check-flight-statuses Edge Function
CREATE OR REPLACE FUNCTION call_check_flight_statuses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  supabase_url text := 'https://otidfywfqxyxteixpqre.supabase.co';
  service_role_key text;
  http_response RECORD;
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
    RAISE WARNING 'Service role key not configured. Run SET_SERVICE_ROLE_KEY.sql first.';
    RETURN;
  END IF;

  -- Call the Edge Function using pg_net (async, non-blocking)
  -- Note: net.http_post is async, so we use PERFORM instead of SELECT
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
    
    RAISE NOTICE '✅ Flight status check initiated (async)';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING '❌ Failed to call check-flight-statuses: %', SQLERRM;
      RAISE WARNING '   Error code: %', SQLSTATE;
      -- Check if pg_net is enabled
      IF SQLSTATE = '42883' THEN
        RAISE WARNING '   💡 pg_net extension might not be enabled. Run: CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;';
      END IF;
  END;
END;
$$;

-- Step 5: Remove any existing cron jobs for flight status checking
SELECT cron.unschedule(jobname) FROM cron.job WHERE jobname LIKE '%flight-status%';

-- Step 6: Schedule the cron job (runs every 5 minutes)
-- This will automatically check all active flights and update their status
SELECT cron.schedule(
  'check-flight-statuses-automatic',
  '*/5 * * * *',  -- Every 5 minutes
  $$SELECT call_check_flight_statuses();$$
);

-- Alternative schedules (uncomment one if you want different frequency):
-- Every 10 minutes:
-- SELECT cron.schedule(
--   'check-flight-statuses-automatic',
--   '*/10 * * * *',
--   $$SELECT call_check_flight_statuses();$$
-- );

-- Every 15 minutes:
-- SELECT cron.schedule(
--   'check-flight-statuses-automatic',
--   '*/15 * * * *',
--   $$SELECT call_check_flight_statuses();$$
-- );

-- Step 7: Grant permissions
GRANT EXECUTE ON FUNCTION notify_flight_status_change() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION call_check_flight_statuses() TO postgres;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Step 8: Verification
DO $$
DECLARE
  trigger_exists BOOLEAN := false;
  trigger_enabled CHAR := 'O';
  function_exists BOOLEAN := false;
  cron_job_exists BOOLEAN := false;
  pg_net_exists BOOLEAN := false;
  pg_cron_exists BOOLEAN := false;
BEGIN
  SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname IN ('journey_status_notification_trigger_insert', 'journey_status_notification_trigger_update')) INTO trigger_exists;
  SELECT COALESCE(tgenabled, 'O') INTO trigger_enabled FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger_update' LIMIT 1;
  SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'notify_flight_status_change') INTO function_exists;
  SELECT EXISTS(SELECT 1 FROM cron.job WHERE jobname = 'check-flight-statuses-automatic') INTO cron_job_exists;
  SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_net') INTO pg_net_exists;
  SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO pg_cron_exists;
  
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '✅ AUTOMATIC SYSTEM SETUP COMPLETE';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  
  IF pg_net_exists THEN
    RAISE NOTICE 'pg_net extension: ✅ Installed';
  ELSE
    RAISE NOTICE 'pg_net extension: ❌ Missing';
  END IF;
  
  IF pg_cron_exists THEN
    RAISE NOTICE 'pg_cron extension: ✅ Installed';
  ELSE
    RAISE NOTICE 'pg_cron extension: ❌ Missing';
  END IF;
  
  IF function_exists THEN
    RAISE NOTICE 'Notification function: ✅ Exists';
  ELSE
    RAISE NOTICE 'Notification function: ❌ Missing';
  END IF;
  
  IF trigger_exists THEN
    RAISE NOTICE 'Notification trigger: ✅ Exists';
    IF trigger_enabled = 'O' THEN
      RAISE NOTICE 'Trigger status: ✅ ENABLED';
    ELSIF trigger_enabled = 'D' THEN
      RAISE NOTICE 'Trigger status: ❌ DISABLED';
    ELSE
      RAISE NOTICE 'Trigger status: ⚠️ UNKNOWN';
    END IF;
  ELSE
    RAISE NOTICE 'Notification trigger: ❌ Missing';
  END IF;
  
  IF cron_job_exists THEN
    RAISE NOTICE 'Cron job: ✅ Scheduled (every 5 minutes)';
  ELSE
    RAISE NOTICE 'Cron job: ❌ Not scheduled';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '📋 HOW IT WORKS AUTOMATICALLY:';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '1. Cron job runs every 5 minutes';
  RAISE NOTICE '2. Calls check-flight-statuses Edge Function';
  RAISE NOTICE '3. Edge Function fetches data from Cirium API';
  RAISE NOTICE '4. Edge Function updates journeys table';
  RAISE NOTICE '5. Database trigger fires automatically';
  RAISE NOTICE '6. Trigger calls flight-update-notification Edge Function';
  RAISE NOTICE '7. Push notification sent to user';
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '⚙️ REQUIRED CONFIGURATION:';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '1. Configure Service Role Key:';
  RAISE NOTICE '   Run SET_SERVICE_ROLE_KEY.sql to store your service role key';
  RAISE NOTICE '   Or update app_settings table directly';
  RAISE NOTICE '';
  RAISE NOTICE '2. Deploy Edge Functions:';
  RAISE NOTICE '   supabase functions deploy check-flight-statuses';
  RAISE NOTICE '   supabase functions deploy flight-update-notification';
  RAISE NOTICE '';
  RAISE NOTICE '3. Set Cirium API credentials in Edge Function secrets';
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '🧪 TESTING:';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Test cron job manually: SELECT call_check_flight_statuses();';
  RAISE NOTICE 'View cron execution: SELECT * FROM cron.job_run_details;';
  RAISE NOTICE 'View scheduled jobs: SELECT * FROM cron.job;';
  RAISE NOTICE '';
END $$;

