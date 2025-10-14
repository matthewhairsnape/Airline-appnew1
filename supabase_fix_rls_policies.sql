-- Fix RLS policies for airlines and airports tables
-- Run this in your Supabase SQL Editor
-- Based on the RLS pattern used in your auth setup

-- First, let's check what policies exist
-- You can run this to see current policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename IN ('airlines', 'airports', 'flights');

-- Drop existing restrictive policies if they exist
DROP POLICY IF EXISTS "Users can view airlines" ON airlines;
DROP POLICY IF EXISTS "Anyone can view airlines" ON airlines;
DROP POLICY IF EXISTS "Users can insert airlines" ON airlines;
DROP POLICY IF EXISTS "Anyone can insert airlines" ON airlines;
DROP POLICY IF EXISTS "Users can update airlines" ON airlines;
DROP POLICY IF EXISTS "Anyone can update airlines" ON airlines;

-- Create policies for airlines table following your auth pattern
-- Allow anyone to read airlines (needed for flight lookups)
CREATE POLICY "Anyone can view airlines" ON airlines
  FOR SELECT USING (true);

-- Allow authenticated users to insert airlines (needed for auto-creation)
CREATE POLICY "Authenticated users can insert airlines" ON airlines
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update airlines
CREATE POLICY "Authenticated users can update airlines" ON airlines
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Drop existing restrictive policies for airports if they exist
DROP POLICY IF EXISTS "Users can view airports" ON airports;
DROP POLICY IF EXISTS "Anyone can view airports" ON airports;
DROP POLICY IF EXISTS "Users can insert airports" ON airports;
DROP POLICY IF EXISTS "Anyone can insert airports" ON airports;
DROP POLICY IF EXISTS "Users can update airports" ON airports;
DROP POLICY IF EXISTS "Anyone can update airports" ON airports;

-- Create policies for airports table following your auth pattern
-- Allow anyone to read airports (needed for flight lookups)
CREATE POLICY "Anyone can view airports" ON airports
  FOR SELECT USING (true);

-- Allow authenticated users to insert airports (needed for auto-creation)
CREATE POLICY "Authenticated users can insert airports" ON airports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update airports
CREATE POLICY "Authenticated users can update airports" ON airports
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Also ensure flights table has proper policies
DROP POLICY IF EXISTS "Users can view flights" ON flights;
DROP POLICY IF EXISTS "Anyone can view flights" ON flights;
DROP POLICY IF EXISTS "Users can insert flights" ON flights;
DROP POLICY IF EXISTS "Anyone can insert flights" ON flights;
DROP POLICY IF EXISTS "Users can update flights" ON flights;
DROP POLICY IF EXISTS "Anyone can update flights" ON flights;

-- Create policies for flights table
CREATE POLICY "Anyone can view flights" ON flights
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert flights" ON flights
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update flights" ON flights
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Also ensure journeys table has proper policies for the passenger_id
DROP POLICY IF EXISTS "Users can view their own journeys" ON journeys;
DROP POLICY IF EXISTS "Users can insert their own journeys" ON journeys;
DROP POLICY IF EXISTS "Users can update their own journeys" ON journeys;

CREATE POLICY "Users can view their own journeys" ON journeys
  FOR SELECT USING (auth.uid()::text = passenger_id::text);

CREATE POLICY "Users can insert their own journeys" ON journeys
  FOR INSERT WITH CHECK (auth.uid()::text = passenger_id::text);

CREATE POLICY "Users can update their own journeys" ON journeys
  FOR UPDATE USING (auth.uid()::text = passenger_id::text);

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('airlines', 'airports', 'flights', 'journeys')
ORDER BY tablename, policyname;
