-- ============================================================================
-- QUICK FIX: Ensure Trigger is Set Up Correctly
-- ============================================================================
-- Run this to fix common trigger issues
-- ============================================================================

-- Step 1: Ensure pg_net extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Step 2: Recreate the function (ensures it uses correct URL and headers)
CREATE OR REPLACE FUNCTION notify_flight_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  supabase_url text := 'https://otidfywfqxyxteixpqre.supabase.co';
  service_role_key text;
  user_id_val uuid;
  notification_type text;
  should_notify boolean := false;
BEGIN
  -- Get service role key from environment or use default
  service_role_key := current_setting('app.settings.supabase_service_role_key', true);
  
  -- If not found, try to get from Supabase vault (if configured)
  IF service_role_key IS NULL THEN
    -- You need to set this in Supabase Dashboard → Settings → Edge Functions → Secrets
    RAISE WARNING 'Service role key not configured. Notification will fail.';
    RETURN NEW;
  END IF;

  -- Determine if notification should be sent
  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
      should_notify := true;
      notification_type := 'status_change';
    ELSIF (OLD.current_phase IS DISTINCT FROM NEW.current_phase) THEN
      should_notify := true;
      notification_type := 'phase_change';
    END IF;
  ELSIF (TG_OP = 'INSERT' AND NEW.status = 'active') THEN
    should_notify := true;
    notification_type := 'journey_created';
  END IF;

  IF NOT should_notify THEN
    RETURN NEW;
  END IF;

  -- Get user_id from journey's passenger_id
  user_id_val := NEW.passenger_id;
  
  IF user_id_val IS NULL THEN
    RAISE WARNING 'No passenger_id found for journey %. Skipping notification.', NEW.id;
    RETURN NEW;
  END IF;

  -- Send notification via Edge Function
  BEGIN
    PERFORM net.http_post(
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
        'notificationType', notification_type
      )
    );
    RAISE NOTICE 'Notification sent for journey %: phase=%, status=%', NEW.id, NEW.current_phase, NEW.status;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to send notification for journey %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Step 3: Recreate trigger (drop and recreate to ensure it's active)
DROP TRIGGER IF EXISTS journey_status_notification_trigger ON journeys;

CREATE TRIGGER journey_status_notification_trigger
  AFTER INSERT OR UPDATE OF status, current_phase ON journeys
  FOR EACH ROW
  EXECUTE FUNCTION notify_flight_status_change();

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION notify_flight_status_change() TO postgres, service_role;

-- Step 5: Verify
DO $$
DECLARE
  has_trigger BOOLEAN;
  has_function BOOLEAN;
  trigger_enabled CHAR;
BEGIN
  SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger') INTO has_trigger;
  SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'notify_flight_status_change') INTO has_function;
  SELECT tgenabled INTO trigger_enabled FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger';
  
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '✅ Setup Verification';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Trigger exists: %', CASE WHEN has_trigger THEN '✅ YES' ELSE '❌ NO' END;
  RAISE NOTICE 'Function exists: %', CASE WHEN has_function THEN '✅ YES' ELSE '❌ NO' END;
  RAISE NOTICE 'Trigger enabled: %', CASE WHEN trigger_enabled = 'O' THEN '✅ YES' ELSE '❌ NO' END;
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT: Make sure service_role_key is set in Supabase Secrets!';
  RAISE NOTICE '   Go to: Dashboard → Settings → Edge Functions → Secrets';
  RAISE NOTICE '   Add: SUPABASE_SERVICE_ROLE_KEY with your service role key';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next: Test with:';
  RAISE NOTICE '   UPDATE journeys SET current_phase = ''boarding'', status = ''in_progress'', updated_at = NOW()';
  RAISE NOTICE '   WHERE id = ''YOUR_JOURNEY_ID'';';
END $$;

