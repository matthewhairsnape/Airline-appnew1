-- Final Supabase Schema for Airline App
-- Run this in your Supabase SQL Editor

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update existing users table to match Flutter app expectations
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create missing tables that your Flutter app needs

-- Airports table (if not exists)
CREATE TABLE IF NOT EXISTS airports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  iata_code TEXT UNIQUE NOT NULL,
  icao_code TEXT,
  name TEXT NOT NULL,
  city TEXT,
  country TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  timezone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update flights table to match Flutter app expectations
ALTER TABLE flights ADD COLUMN IF NOT EXISTS aircraft_type TEXT;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS gate TEXT;
ALTER TABLE flights ADD COLUMN IF NOT EXISTS terminal TEXT;

-- Update journeys table to match Flutter app expectations  
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS flight_id UUID REFERENCES flights(id) ON DELETE CASCADE;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS pnr TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS seat_number TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS class_of_travel TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS terminal TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS gate TEXT;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS boarding_pass_scanned_at TIMESTAMPTZ;
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'scheduled';
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS current_phase TEXT DEFAULT 'pre_check_in';

-- Update journey_events table (rename flight_events if needed)
CREATE TABLE IF NOT EXISTS journey_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_timestamp TIMESTAMPTZ NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update stage_feedback table (rename feedback if needed)
ALTER TABLE feedback RENAME TO stage_feedback;

ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE;
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS stage TEXT;
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS positive_selections JSONB DEFAULT '{}';
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS negative_selections JSONB DEFAULT '{}';
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS custom_feedback JSONB DEFAULT '{}';
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS overall_rating INTEGER;
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS additional_comments TEXT;
ALTER TABLE stage_feedback ADD COLUMN IF NOT EXISTS feedback_timestamp TIMESTAMPTZ DEFAULT NOW();

-- Create airline_reviews table
CREATE TABLE IF NOT EXISTS airline_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  airline_id UUID REFERENCES airlines(id) ON DELETE CASCADE,
  overall_score DECIMAL(3, 2),
  seat_comfort INTEGER,
  cabin_service INTEGER,
  food_beverage INTEGER,
  entertainment INTEGER,
  value_for_money INTEGER,
  comments TEXT,
  would_recommend BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(journey_id)
);

-- Create airport_reviews table
CREATE TABLE IF NOT EXISTS airport_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  airport_id UUID REFERENCES airports(id) ON DELETE CASCADE,
  overall_score DECIMAL(3, 2),
  cleanliness INTEGER,
  facilities INTEGER,
  staff INTEGER,
  waiting_time INTEGER,
  accessibility INTEGER,
  comments TEXT,
  would_recommend BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(journey_id, airport_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_journeys_user_id ON journeys(user_id);
CREATE INDEX IF NOT EXISTS idx_journeys_flight_id ON journeys(flight_id);
CREATE INDEX IF NOT EXISTS idx_journey_events_journey_id ON journey_events(journey_id);
CREATE INDEX IF NOT EXISTS idx_stage_feedback_journey_id ON stage_feedback(journey_id);
CREATE INDEX IF NOT EXISTS idx_airline_reviews_airline_id ON airline_reviews(airline_id);
CREATE INDEX IF NOT EXISTS idx_airport_reviews_airport_id ON airport_reviews(airport_id);
CREATE INDEX IF NOT EXISTS idx_flights_airline_id ON flights(airline_id);
CREATE INDEX IF NOT EXISTS idx_flights_departure_airport ON flights(departure_airport_id);
CREATE INDEX IF NOT EXISTS idx_flights_arrival_airport ON flights(arrival_airport_id);

-- Enable Row Level Security on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE journey_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE stage_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE airline_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE airport_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlines ENABLE ROW LEVEL SECURITY;
ALTER TABLE airports ENABLE ROW LEVEL SECURITY;
ALTER TABLE flights ENABLE ROW LEVEL SECURITY;

-- Drop existing policies and create new ones
DROP POLICY IF EXISTS "Allow public read access" ON users;
DROP POLICY IF EXISTS "Allow individual insert access" ON users;
DROP POLICY IF EXISTS "Allow individual update access" ON users;
DROP POLICY IF EXISTS "Allow individual delete access" ON users;

-- Users table policies
CREATE POLICY "Users can view their own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Journeys table policies
CREATE POLICY "Users can view their own journeys" ON journeys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own journeys" ON journeys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own journeys" ON journeys
  FOR UPDATE USING (auth.uid() = user_id);

-- Journey events table policies
CREATE POLICY "Users can view their own journey events" ON journey_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM journeys WHERE journeys.id = journey_events.journey_id AND journeys.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own journey events" ON journey_events
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM journeys WHERE journeys.id = journey_events.journey_id AND journeys.user_id = auth.uid()
    )
  );

-- Stage feedback table policies
CREATE POLICY "Users can view their own stage feedback" ON stage_feedback
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stage feedback" ON stage_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own stage feedback" ON stage_feedback
  FOR UPDATE USING (auth.uid() = user_id);

-- Airline reviews table policies
CREATE POLICY "Users can view their own airline reviews" ON airline_reviews
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view all airline reviews" ON airline_reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own airline reviews" ON airline_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Airport reviews table policies
CREATE POLICY "Users can view their own airport reviews" ON airport_reviews
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view all airport reviews" ON airport_reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own airport reviews" ON airport_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Public read access for reference data
CREATE POLICY "Anyone can view airlines" ON airlines
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view airports" ON airports
  FOR SELECT USING (true);

CREATE POLICY "Anyone can view flights" ON flights
  FOR SELECT USING (true);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at column to tables that need it
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE flights ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create triggers to auto-update updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_journeys_updated_at ON journeys;
CREATE TRIGGER update_journeys_updated_at BEFORE UPDATE ON journeys
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_flights_updated_at ON flights;
CREATE TRIGGER update_flights_updated_at BEFORE UPDATE ON flights
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
