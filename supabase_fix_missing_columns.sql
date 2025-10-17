-- Fix missing columns in flights and journeys tables
-- Run this in your Supabase SQL Editor

-- Add missing airline_id column to flights table
ALTER TABLE flights ADD COLUMN IF NOT EXISTS airline_id UUID REFERENCES airlines(id) ON DELETE SET NULL;

-- Add missing class_of_travel column to journeys table
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS class_of_travel TEXT;

-- Add other missing columns that might be needed
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS terminal TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS gate TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS boarding_pass_scanned_at TIMESTAMPTZ;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'scheduled';
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS current_phase TEXT DEFAULT 'pre_check_in';

-- Add missing columns to flights table
ALTER TABLE flights ADD COLUMN IF NOT EXISTS aircraft_type TEXT;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS gate TEXT;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS terminal TEXT;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS scheduled_departure TIMESTAMPTZ;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS scheduled_arrival TIMESTAMPTZ;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS departure_time TIMESTAMPTZ;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS arrival_time TIMESTAMPTZ;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS departure_airport_id UUID REFERENCES airports(id) ON DELETE SET NULL;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS arrival_airport_id UUID REFERENCES airports(id) ON DELETE SET NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_flights_airline_id ON flights(airline_id);
CREATE INDEX IF NOT EXISTS idx_journeys_class_of_travel ON journeys(class_of_travel);

-- Make old airport columns nullable if they exist and are NOT NULL
ALTER TABLE flights ALTER COLUMN departure_airport DROP NOT NULL;
ALTER TABLE flights ALTER COLUMN arrival_airport DROP NOT NULL;

-- Update existing flights to have airline_id if possible
-- This will try to match existing carrier_code to airline_id
UPDATE flights 
SET airline_id = (
  SELECT id FROM airlines 
  WHERE airlines.iata_code = flights.carrier_code 
  LIMIT 1
)
WHERE flights.airline_id IS NULL 
AND flights.carrier_code IS NOT NULL;
