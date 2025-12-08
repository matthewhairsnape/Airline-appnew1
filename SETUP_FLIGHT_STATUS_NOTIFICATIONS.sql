-- ============================================================================
-- FLIGHT STATUS NOTIFICATION SYSTEM - Optimized Version
-- ============================================================================

-- Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- ============================================================================
-- FUNCTION: Send flight status notification via Edge Function
-- ============================================================================

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

-- ============================================================================
-- TRIGGER
-- ============================================================================

DROP TRIGGER IF EXISTS journey_status_notification_trigger ON journeys;

CREATE TRIGGER journey_status_notification_trigger
  AFTER INSERT OR UPDATE OF status, current_phase, gate, terminal ON journeys
  FOR EACH ROW
  EXECUTE FUNCTION notify_flight_status_change();

-- ============================================================================
-- NOTIFICATION LOGS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent',
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_journey_id ON notification_logs(journey_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON notification_logs(sent_at DESC);

-- Row Level Security
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own notification logs" ON notification_logs;
DROP POLICY IF EXISTS "Service role can insert notification logs" ON notification_logs;

CREATE POLICY "Users can view their own notification logs"
  ON notification_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert notification logs"
  ON notification_logs FOR INSERT TO service_role WITH CHECK (true);

-- Permissions
GRANT EXECUTE ON FUNCTION notify_flight_status_change() TO postgres, service_role;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  has_trigger BOOLEAN;
  has_function BOOLEAN;
  has_table BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname = 'journey_status_notification_trigger') INTO has_trigger;
  SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'notify_flight_status_change') INTO has_function;
  SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_logs') INTO has_table;
  
  RAISE NOTICE '✅ Setup Complete';
  RAISE NOTICE '  Trigger: %', CASE WHEN has_trigger THEN '✓' ELSE '✗' END;
  RAISE NOTICE '  Function: %', CASE WHEN has_function THEN '✓' ELSE '✗' END;
  RAISE NOTICE '  Table: %', CASE WHEN has_table THEN '✓' ELSE '✗' END;
  RAISE NOTICE 'Next: Deploy Edge Function → supabase functions deploy flight-status-notification';
END $$;
