-- Flight Status Triggers and Functions
-- Run this in your Supabase SQL Editor

-- Create function to process flight status updates
CREATE OR REPLACE FUNCTION process_flight_status_update()
RETURNS TRIGGER AS $$
DECLARE
  journey_record RECORD;
  user_record RECORD;
  notification_message TEXT;
  event_title TEXT;
  event_description TEXT;
BEGIN
  -- Get journey details with user information
  SELECT 
    j.*,
    u.fcm_token,
    u.display_name,
    f.flight_number,
    f.airline_id,
    a.iata_code as airline_code
  INTO journey_record
  FROM journeys j
  JOIN users u ON j.user_id = u.id
  JOIN flights f ON j.flight_id = f.id
  JOIN airlines a ON f.airline_id = a.id
  WHERE j.id = NEW.id;

  -- Only process if phase has changed
  IF OLD.current_phase IS DISTINCT FROM NEW.current_phase THEN
    -- Create journey event
    event_title := CASE NEW.current_phase
      WHEN 'boarding' THEN 'Flight Boarding'
      WHEN 'gate_closed' THEN 'Gate Closed'
      WHEN 'departed' THEN 'Flight Departed'
      WHEN 'in_flight' THEN 'In Flight'
      WHEN 'landed' THEN 'Flight Landed'
      WHEN 'arrived' THEN 'Flight Arrived'
      WHEN 'cancelled' THEN 'Flight Cancelled'
      WHEN 'delayed' THEN 'Flight Delayed'
      ELSE 'Status Update'
    END;

    event_description := CASE NEW.current_phase
      WHEN 'boarding' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' is now boarding. Please proceed to the gate.'
      WHEN 'gate_closed' THEN 'Gate is now closed for flight ' || journey_record.airline_code || journey_record.flight_number || '. Please contact airline staff.'
      WHEN 'departed' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' has departed. Enjoy your journey!'
      WHEN 'in_flight' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' is in progress.'
      WHEN 'landed' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' has landed.'
      WHEN 'arrived' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' has arrived. Welcome to your destination!'
      WHEN 'cancelled' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' has been cancelled. Please contact airline for assistance.'
      WHEN 'delayed' THEN 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' has been delayed. Please check for updates.'
      ELSE 'Flight ' || journey_record.airline_code || journey_record.flight_number || ' status has been updated.'
    END;

    -- Insert journey event
    INSERT INTO journey_events (
      journey_id,
      event_type,
      title,
      description,
      event_timestamp,
      metadata
    ) VALUES (
      NEW.id,
      'status_change',
      event_title,
      event_description,
      NOW(),
      jsonb_build_object(
        'old_phase', OLD.current_phase,
        'new_phase', NEW.current_phase,
        'flight_number', journey_record.flight_number,
        'airline_code', journey_record.airline_code
      )
    );

    -- Send push notification if user has FCM token
    IF journey_record.fcm_token IS NOT NULL THEN
      notification_message := CASE NEW.current_phase
        WHEN 'boarding' THEN '🛫 Your flight ' || journey_record.airline_code || journey_record.flight_number || ' is now boarding! Please proceed to the gate.'
        WHEN 'gate_closed' THEN '⚠️ Gate is now closed for flight ' || journey_record.airline_code || journey_record.flight_number || '. Please contact airline staff.'
        WHEN 'departed' THEN '✈️ Flight ' || journey_record.airline_code || journey_record.flight_number || ' has departed. Enjoy your journey!'
        WHEN 'in_flight' THEN '✈️ Flight ' || journey_record.airline_code || journey_record.flight_number || ' is in progress.'
        WHEN 'landed' THEN '🛬 Flight ' || journey_record.airline_code || journey_record.flight_number || ' has landed. Welcome to your destination!'
        WHEN 'arrived' THEN '✅ Flight ' || journey_record.airline_code || journey_record.flight_number || ' has arrived. Thank you for flying with us!'
        WHEN 'cancelled' THEN '❌ Flight ' || journey_record.airline_code || journey_record.flight_number || ' has been cancelled. Please contact airline for assistance.'
        WHEN 'delayed' THEN '⏰ Flight ' || journey_record.airline_code || journey_record.flight_number || ' has been delayed. Please check for updates.'
        ELSE '📱 Flight ' || journey_record.airline_code || journey_record.flight_number || ' status update available.'
      END;

      -- Insert notification queue entry (you can process this with a separate worker)
      INSERT INTO notification_queue (
        user_id,
        fcm_token,
        title,
        body,
        data,
        created_at
      ) VALUES (
        journey_record.user_id,
        journey_record.fcm_token,
        'Flight Status Update',
        notification_message,
        jsonb_build_object(
          'type', 'flight_status_update',
          'phase', NEW.current_phase,
          'journey_id', NEW.id,
          'flight_number', journey_record.flight_number,
          'airline_code', journey_record.airline_code
        ),
        NOW()
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create notification queue table
CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  error_message TEXT
);

-- Create index for efficient processing
CREATE INDEX IF NOT EXISTS idx_notification_queue_status_created 
ON notification_queue(status, created_at) 
WHERE status = 'pending';

-- Create trigger for journey phase updates
DROP TRIGGER IF EXISTS journey_phase_update_trigger ON journeys;
CREATE TRIGGER journey_phase_update_trigger
  AFTER UPDATE OF current_phase ON journeys
  FOR EACH ROW
  EXECUTE FUNCTION process_flight_status_update();

-- Create function to process notification queue
CREATE OR REPLACE FUNCTION process_notification_queue()
RETURNS void AS $$
DECLARE
  notification_record RECORD;
  result JSONB;
BEGIN
  -- Get pending notifications (limit to 10 at a time)
  FOR notification_record IN
    SELECT * FROM notification_queue
    WHERE status = 'pending'
    AND retry_count < max_retries
    ORDER BY created_at ASC
    LIMIT 10
  LOOP
    BEGIN
      -- Call the send-push-notification function
      SELECT supabase_functions.invoke(
        'send-push-notification',
        jsonb_build_object(
          'token', notification_record.fcm_token,
          'title', notification_record.title,
          'body', notification_record.body,
          'data', notification_record.data
        )
      ) INTO result;

      -- Update notification status
      UPDATE notification_queue
      SET 
        status = 'sent',
        processed_at = NOW(),
        error_message = NULL
      WHERE id = notification_record.id;

    EXCEPTION WHEN OTHERS THEN
      -- Update retry count and error message
      UPDATE notification_queue
      SET 
        retry_count = retry_count + 1,
        error_message = SQLERRM,
        status = CASE 
          WHEN retry_count + 1 >= max_retries THEN 'failed'
          ELSE 'pending'
        END
      WHERE id = notification_record.id;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old notifications
CREATE OR REPLACE FUNCTION cleanup_notification_queue()
RETURNS void AS $$
BEGIN
  -- Delete notifications older than 7 days
  DELETE FROM notification_queue
  WHERE created_at < NOW() - INTERVAL '7 days';
  
  -- Delete failed notifications older than 1 day
  DELETE FROM notification_queue
  WHERE status = 'failed'
  AND created_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;

-- Create scheduled job to process notifications (requires pg_cron extension)
-- You can also call this function manually or from your application
-- SELECT cron.schedule('process-notifications', '*/1 * * * *', 'SELECT process_notification_queue();');
-- SELECT cron.schedule('cleanup-notifications', '0 2 * * *', 'SELECT cleanup_notification_queue();');

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION process_flight_status_update() TO authenticated;
GRANT EXECUTE ON FUNCTION process_notification_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_notification_queue() TO authenticated;

-- Enable RLS on notification_queue
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

-- Create policy for notification_queue
CREATE POLICY "Users can view their own notifications" ON notification_queue
  FOR SELECT USING (auth.uid() = user_id);

-- Create function to get user's notification history
CREATE OR REPLACE FUNCTION get_user_notifications(user_uuid UUID)
RETURNS TABLE (
  id UUID,
  title TEXT,
  body TEXT,
  data JSONB,
  status TEXT,
  created_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    nq.id,
    nq.title,
    nq.body,
    nq.data,
    nq.status,
    nq.created_at,
    nq.processed_at
  FROM notification_queue nq
  WHERE nq.user_id = user_uuid
  ORDER BY nq.created_at DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_notifications(UUID) TO authenticated;
