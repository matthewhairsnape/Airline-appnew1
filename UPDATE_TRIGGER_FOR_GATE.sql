-- ============================================================================
-- UPDATE: Add Gate and Terminal Change Notifications
-- ============================================================================
-- Run this to update your trigger to also send notifications for gate/terminal changes
-- ============================================================================

-- Step 1: Update the function to detect gate/terminal changes
CREATE OR REPLACE FUNCTION notify_flight_status_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  supabase_url text;
  service_role_key text;
  flight_info RECORD;
  user_id_val uuid;
  notification_type text;
  should_notify boolean := false;
BEGIN
  -- Get Supabase configuration
  supabase_url := current_setting('app.settings.supabase_url', true);
  service_role_key := current_setting('app.settings.supabase_service_role_key', true);

  -- Use default values if settings not found
  IF supabase_url IS NULL THEN
    supabase_url := 'https://otidfywfqxyxteixpqre.supabase.co';
  END IF;

  -- Determine if notification should be sent
  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
      should_notify := true;
      notification_type := 'status_change';
    ELSIF (OLD.current_phase IS DISTINCT FROM NEW.current_phase) THEN
      should_notify := true;
      notification_type := 'phase_change';
    ELSIF (OLD.gate IS DISTINCT FROM NEW.gate) THEN
      should_notify := true;
      notification_type := 'gate_change';
    ELSIF (OLD.terminal IS DISTINCT FROM NEW.terminal) THEN
      should_notify := true;
      notification_type := 'terminal_change';
    END IF;
  ELSIF (TG_OP = 'INSERT' AND NEW.status = 'active') THEN
    should_notify := true;
    notification_type := 'journey_created';
  END IF;

  IF NOT should_notify THEN
    RETURN NEW;
  END IF;

  -- Get user_id from journey's passenger_id
  BEGIN
    user_id_val := NEW.passenger_id;
    IF user_id_val IS NULL THEN
      -- Fallback: try to get from flights table
      SELECT f.user_id INTO user_id_val FROM flights f WHERE f.id = NEW.flight_id LIMIT 1;
      -- Another fallback: try journey_users table
      IF user_id_val IS NULL THEN
        SELECT ju.user_id INTO user_id_val FROM journey_users ju WHERE ju.journey_id = NEW.id LIMIT 1;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      user_id_val := NULL;
  END;

  IF user_id_val IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get flight information
  BEGIN
    SELECT f.carrier_code, f.flight_number, f.departure_airport, f.arrival_airport
    INTO flight_info FROM flights f WHERE f.id = NEW.flight_id LIMIT 1;
  EXCEPTION
    WHEN OTHERS THEN
      flight_info := NULL;
  END;

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
        'journeyId', NEW.id,
        'status', NEW.status,
        'phase', COALESCE(NEW.current_phase, ''),
        'gate', COALESCE(NEW.gate, ''),
        'terminal', COALESCE(NEW.terminal, ''),
        'oldGate', COALESCE(OLD.gate, ''),
        'oldTerminal', COALESCE(OLD.terminal, ''),
        'notificationType', notification_type
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Notification failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Step 2: Update trigger to include gate and terminal
DROP TRIGGER IF EXISTS journey_status_notification_trigger ON journeys;

CREATE TRIGGER journey_status_notification_trigger
  AFTER INSERT OR UPDATE OF status, current_phase, gate, terminal ON journeys
  FOR EACH ROW
  EXECUTE FUNCTION notify_flight_status_change();

-- Step 3: Verify
DO $$
DECLARE
  trigger_columns TEXT[];
BEGIN
  SELECT array_agg(a.attname ORDER BY a.attnum)
  INTO trigger_columns
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_attribute a ON a.attrelid = c.oid
  WHERE t.tgname = 'journey_status_notification_trigger'
    AND a.attnum = ANY(t.tgattr)
    AND NOT a.attisdropped;
  
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '✅ Trigger Updated Successfully';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Trigger now monitors: %', array_to_string(trigger_columns, ', ');
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next: Deploy the updated Edge Function:';
  RAISE NOTICE '   supabase functions deploy flight-update-notification --project-ref otidfywfqxyxteixpqre --no-verify-jwt';
END $$;

