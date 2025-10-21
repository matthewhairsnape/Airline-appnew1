-- Fix RLS policies to allow INSERT operations for airlines and airports
-- Run this in your Supabase SQL Editor

-- Add INSERT policies for airlines table
CREATE POLICY "Authenticated users can insert airlines" ON airlines
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Add INSERT policies for airports table  
CREATE POLICY "Authenticated users can insert airports" ON airports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Add INSERT policies for flights table
CREATE POLICY "Authenticated users can insert flights" ON flights
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Add INSERT policies for journeys table (fix the user_id vs passenger_id issue)
-- First drop the existing policies
DROP POLICY IF EXISTS "Users can insert their own journeys" ON journeys;
DROP POLICY IF EXISTS "Users can view their own journeys" ON journeys;
DROP POLICY IF EXISTS "Users can update their own journeys" ON journeys;

-- Create new policies that work with passenger_id directly (assuming passenger_id = user_id)
CREATE POLICY "Users can view their own journeys" ON journeys
  FOR SELECT USING (auth.uid()::text = passenger_id::text);

CREATE POLICY "Users can insert their own journeys" ON journeys
  FOR INSERT WITH CHECK (auth.uid()::text = passenger_id::text);

CREATE POLICY "Users can update their own journeys" ON journeys
  FOR UPDATE USING (auth.uid()::text = passenger_id::text);

-- Add INSERT policies for journey_events table
CREATE POLICY "Authenticated users can insert journey events" ON journey_events
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('airlines', 'airports', 'flights', 'journeys', 'journey_events')
ORDER BY tablename, policyname;
