-- Supabase Database Schema for Airline App
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Airlines table
CREATE TABLE IF NOT EXISTS airlines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  iata_code TEXT UNIQUE NOT NULL,
  icao_code TEXT,
  name TEXT NOT NULL,
  country TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Airports table
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

-- Flights table
CREATE TABLE IF NOT EXISTS flights (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  airline_id UUID REFERENCES airlines(id) ON DELETE CASCADE,
  flight_number TEXT NOT NULL,
  departure_airport_id UUID REFERENCES airports(id) ON DELETE CASCADE,
  arrival_airport_id UUID REFERENCES airports(id) ON DELETE CASCADE,
  aircraft_type TEXT,
  scheduled_departure TIMESTAMPTZ NOT NULL,
  scheduled_arrival TIMESTAMPTZ NOT NULL,
  actual_departure TIMESTAMPTZ,
  actual_arrival TIMESTAMPTZ,
  status TEXT DEFAULT 'scheduled',
  gate TEXT,
  terminal TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(flight_number, airline_id, scheduled_departure)
);

-- Journeys table (user trips)
CREATE TABLE IF NOT EXISTS journeys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  flight_id UUID REFERENCES flights(id) ON DELETE CASCADE,
  pnr TEXT,
  seat_number TEXT,
  class_of_travel TEXT,
  terminal TEXT,
  gate TEXT,
  boarding_pass_scanned_at TIMESTAMPTZ,
  status TEXT DEFAULT 'scheduled',
  current_phase TEXT DEFAULT 'pre_check_in',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Journey events table (timeline)
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

-- Stage feedback table
CREATE TABLE IF NOT EXISTS stage_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  stage TEXT NOT NULL,
  positive_selections JSONB DEFAULT '{}',
  negative_selections JSONB DEFAULT '{}',
  custom_feedback JSONB DEFAULT '{}',
  overall_rating INTEGER,
  additional_comments TEXT,
  feedback_timestamp TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(journey_id, stage)
);

-- Airline reviews table
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

-- Airport reviews table
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

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_journeys_user_id ON journeys(user_id);
CREATE INDEX IF NOT EXISTS idx_journeys_flight_id ON journeys(flight_id);
CREATE INDEX IF NOT EXISTS idx_journey_events_journey_id ON journey_events(journey_id);
CREATE INDEX IF NOT EXISTS idx_stage_feedback_journey_id ON stage_feedback(journey_id);
CREATE INDEX IF NOT EXISTS idx_airline_reviews_airline_id ON airline_reviews(airline_id);
CREATE INDEX IF NOT EXISTS idx_airport_reviews_airport_id ON airport_reviews(airport_id);
CREATE INDEX IF NOT EXISTS idx_flights_airline_id ON flights(airline_id);
CREATE INDEX IF NOT EXISTS idx_flights_departure_airport ON flights(departure_airport_id);
CREATE INDEX IF NOT EXISTS idx_flights_arrival_airport ON flights(arrival_airport_id);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE journey_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE stage_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE airline_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE airport_reviews ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users table
CREATE POLICY "Users can view their own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- RLS Policies for journeys
CREATE POLICY "Users can view their own journeys" ON journeys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own journeys" ON journeys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own journeys" ON journeys
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for journey_events
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

-- RLS Policies for stage_feedback
CREATE POLICY "Users can view their own stage feedback" ON stage_feedback
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stage feedback" ON stage_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own stage feedback" ON stage_feedback
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for airline_reviews
CREATE POLICY "Users can view their own airline reviews" ON airline_reviews
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view all airline reviews" ON airline_reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own airline reviews" ON airline_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policies for airport_reviews
CREATE POLICY "Users can view their own airport reviews" ON airport_reviews
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view all airport reviews" ON airport_reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own airport reviews" ON airport_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Public read access for airlines and airports (reference data)
ALTER TABLE airlines ENABLE ROW LEVEL SECURITY;
ALTER TABLE airports ENABLE ROW LEVEL SECURITY;
ALTER TABLE flights ENABLE ROW LEVEL SECURITY;

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

-- Trigger to auto-update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_journeys_updated_at BEFORE UPDATE ON journeys
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

