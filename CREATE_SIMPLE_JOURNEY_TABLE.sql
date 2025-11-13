-- Create a new simplified journey table for direct boarding pass data storage
-- This table stores journey data immediately after scanning without Cirium verification

CREATE TABLE IF NOT EXISTS simple_journeys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pnr TEXT NOT NULL,
  carrier_code TEXT,
  flight_number TEXT,
  airline_name TEXT,
  departure_airport_code TEXT,
  departure_airport_name TEXT,
  departure_city TEXT,
  departure_country TEXT,
  arrival_airport_code TEXT,
  arrival_airport_name TEXT,
  arrival_city TEXT,
  arrival_country TEXT,
  flight_date DATE NOT NULL,
  scheduled_departure TIMESTAMPTZ,
  scheduled_arrival TIMESTAMPTZ,
  seat_number TEXT,
  class_of_travel TEXT,
  terminal TEXT,
  gate TEXT,
  aircraft_type TEXT,
  visit_status TEXT DEFAULT 'Upcoming' CHECK (visit_status IN ('Upcoming', 'In Progress', 'Completed')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  current_phase TEXT DEFAULT 'pre_check_in' CHECK (current_phase IN ('pre_check_in', 'check_in_open', 'security', 'boarding', 'departed', 'in_flight', 'landed', 'baggage_claim', 'completed')),
  boarding_pass_data JSONB, -- Store raw boarding pass data
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_simple_journeys_passenger_id ON simple_journeys(passenger_id);
CREATE INDEX IF NOT EXISTS idx_simple_journeys_pnr ON simple_journeys(pnr);
CREATE INDEX IF NOT EXISTS idx_simple_journeys_status ON simple_journeys(status);
CREATE INDEX IF NOT EXISTS idx_simple_journeys_created_at ON simple_journeys(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE simple_journeys ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to read their own journeys
CREATE POLICY "Users can view their own journeys"
  ON simple_journeys
  FOR SELECT
  USING (auth.uid() = passenger_id);

-- Create policy to allow users to insert their own journeys
CREATE POLICY "Users can insert their own journeys"
  ON simple_journeys
  FOR INSERT
  WITH CHECK (auth.uid() = passenger_id);

-- Create policy to allow users to update their own journeys
CREATE POLICY "Users can update their own journeys"
  ON simple_journeys
  FOR UPDATE
  USING (auth.uid() = passenger_id)
  WITH CHECK (auth.uid() = passenger_id);

-- Create policy to allow users to delete their own journeys
CREATE POLICY "Users can delete their own journeys"
  ON simple_journeys
  FOR DELETE
  USING (auth.uid() = passenger_id);

-- Add comment to table
COMMENT ON TABLE simple_journeys IS 'Simplified journey table for storing boarding pass data directly after scanning without Cirium verification';

