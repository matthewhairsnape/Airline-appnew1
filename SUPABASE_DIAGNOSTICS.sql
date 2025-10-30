-- =====================================================
-- Supabase Journey Completion Diagnostics
-- =====================================================
-- Run these queries in Supabase SQL Editor to diagnose issues

-- 1. Check all journeys in the database
-- =====================================================
SELECT 
    id,
    passenger_id,
    pnr,
    current_phase,
    visit_status,
    status,
    created_at,
    updated_at
FROM journeys
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check specific journey (replace 'your-journey-id' with actual ID)
-- =====================================================
SELECT 
    id,
    passenger_id,
    pnr,
    seat_number,
    current_phase,
    visit_status,
    status,
    flight_id,
    created_at,
    updated_at
FROM journeys
WHERE id = 'your-journey-id';

-- 3. Check journey events for a specific journey
-- =====================================================
SELECT 
    id,
    journey_id,
    event_type,
    title,
    description,
    event_timestamp,
    metadata
FROM journey_events
WHERE journey_id = 'your-journey-id'
ORDER BY event_timestamp DESC;

-- 4. Check RLS policies on journeys table
-- =====================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'journeys';

-- 5. Check if RLS is enabled on journeys table
-- =====================================================
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'journeys';

-- =====================================================
-- FIXES FOR COMMON ISSUES
-- =====================================================

-- FIX 1: Create or update RLS policy for journey updates
-- =====================================================
-- This allows users to update their own journeys
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can update their own journeys" ON journeys;

-- Create new policy
CREATE POLICY "Users can update their own journeys"
ON journeys
FOR UPDATE
USING (
    auth.uid()::text = passenger_id::text
)
WITH CHECK (
    auth.uid()::text = passenger_id::text
);

-- FIX 2: Create or update RLS policy for journey events
-- =====================================================
-- This allows inserting journey completion events
DROP POLICY IF EXISTS "Users can insert journey events for their journeys" ON journey_events;

CREATE POLICY "Users can insert journey events for their journeys"
ON journey_events
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM journeys
        WHERE journeys.id = journey_events.journey_id
        AND journeys.passenger_id::text = auth.uid()::text
    )
);

-- FIX 3: Create SELECT policy (if needed)
-- =====================================================
DROP POLICY IF EXISTS "Users can view their own journeys" ON journeys;

CREATE POLICY "Users can view their own journeys"
ON journeys
FOR SELECT
USING (
    auth.uid()::text = passenger_id::text
);

-- FIX 4: Test update manually (replace values)
-- =====================================================
-- This will show if the update works at the SQL level
UPDATE journeys
SET 
    status = 'completed',
    visit_status = 'Completed',
    current_phase = 'landed',
    updated_at = NOW()
WHERE id = 'your-journey-id'
RETURNING *;

-- FIX 5: Check for type mismatches
-- =====================================================
-- This checks if passenger_id is UUID or TEXT
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'journeys'
AND column_name IN ('id', 'passenger_id', 'user_id');

-- =====================================================
-- FIX 6: Enable pg_net Extension (Required for Triggers)
-- =====================================================
-- This extension is needed for the notify_flight_update trigger
-- If you get error "schema net does not exist", run this:

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant permissions
GRANT USAGE ON SCHEMA net TO postgres, anon, authenticated, service_role;

-- Verify it's enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- =====================================================
-- FIX 7: Check and Manage Triggers
-- =====================================================
-- Check existing triggers on journeys table
SELECT 
    tgname as trigger_name,
    tgenabled as enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'journeys'::regclass
AND tgname NOT LIKE 'RI_%'; -- Exclude internal constraint triggers

-- =====================================================
-- FIX 8: Temporarily Disable Problematic Trigger
-- =====================================================
-- If notify_flight_update_trigger is causing issues:
-- ALTER TABLE journeys DISABLE TRIGGER notify_flight_update_trigger;

-- Test journey completion now

-- Re-enable when pg_net is fixed:
-- ALTER TABLE journeys ENABLE TRIGGER notify_flight_update_trigger;

-- =====================================================
-- FIX 9: Drop and Recreate Trigger (If Needed)
-- =====================================================
-- If the trigger is broken, you can drop it:
-- DROP TRIGGER IF EXISTS notify_flight_update_trigger ON journeys;
-- DROP FUNCTION IF EXISTS notify_flight_update();

-- Note: You'll need to recreate it with proper error handling
-- See FIX 10 below

-- =====================================================
-- FIX 10: Create Error-Resistant Trigger Function
-- =====================================================
-- This version handles missing pg_net extension gracefully
/*
CREATE OR REPLACE FUNCTION notify_flight_update()
RETURNS TRIGGER AS $$
DECLARE
  notification_type TEXT;
  journey_record RECORD;
  flight_record RECORD;
  supabase_url TEXT;
  service_role_key TEXT;
  has_pg_net BOOLEAN;
BEGIN
  -- Check if pg_net extension exists
  SELECT EXISTS(
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) INTO has_pg_net;

  -- If pg_net is not available, just log and continue
  IF NOT has_pg_net THEN
    RAISE NOTICE 'pg_net extension not available, skipping notification';
    RETURN NEW;
  END IF;

  -- Your existing trigger logic here...
  -- (Keep the rest of your trigger code)
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't block the update
    RAISE WARNING 'Error in notify_flight_update: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
*/

-- =====================================================
-- TEMPORARY FIXES (DEVELOPMENT ONLY - NOT FOR PRODUCTION)
-- =====================================================

-- Option A: Temporarily disable RLS (NOT RECOMMENDED)
-- =====================================================
-- WARNING: This removes all security from the table
-- USE ONLY FOR TESTING
-- ALTER TABLE journeys DISABLE ROW LEVEL SECURITY;

-- To re-enable:
-- ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;

-- Option B: Create permissive policy for testing
-- =====================================================
-- WARNING: This allows anyone to update any journey
-- USE ONLY FOR TESTING
-- DROP POLICY IF EXISTS "Allow all updates for testing" ON journeys;
-- CREATE POLICY "Allow all updates for testing"
-- ON journeys
-- FOR UPDATE
-- USING (true)
-- WITH CHECK (true);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify journey was updated
-- =====================================================
SELECT 
    id,
    status,
    visit_status,
    current_phase,
    updated_at,
    updated_at > (NOW() - INTERVAL '5 minutes') as recently_updated
FROM journeys
WHERE id = 'your-journey-id';

-- Count completed journeys
-- =====================================================
SELECT 
    COUNT(*) as total_journeys,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_journeys,
    COUNT(*) FILTER (WHERE visit_status = 'Completed') as visit_completed_journeys,
    COUNT(*) FILTER (WHERE current_phase = 'landed') as landed_journeys
FROM journeys;

-- Check journey events by type
-- =====================================================
SELECT 
    event_type,
    COUNT(*) as event_count
FROM journey_events
GROUP BY event_type
ORDER BY event_count DESC;

-- Find journeys without completion events
-- =====================================================
SELECT 
    j.id,
    j.pnr,
    j.current_phase,
    j.status,
    j.visit_status,
    j.updated_at
FROM journeys j
LEFT JOIN journey_events je ON j.id = je.journey_id AND je.event_type = 'journey_completed'
WHERE je.id IS NULL
ORDER BY j.updated_at DESC;

