-- Supabase Fresh Install Script
-- Use this ONLY if you want to start fresh and don't have important existing data
-- This will drop all existing tables and recreate them

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist (in reverse dependency order)
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS issues CASCADE;
DROP TABLE IF EXISTS feedback CASCADE;
DROP TABLE IF EXISTS journeys CASCADE;
DROP TABLE IF EXISTS passengers CASCADE;
DROP TABLE IF EXISTS flights CASCADE;

-- Drop existing views if they exist
DROP VIEW IF EXISTS realtime_feedback_view CASCADE;
DROP VIEW IF EXISTS flight_feedback_aggregates CASCADE;

-- 1. FLIGHTS TABLE
CREATE TABLE flights (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flight_number TEXT NOT NULL,
  carrier_code TEXT NOT NULL,
  tail_number TEXT,
  departure_airport TEXT NOT NULL,
  arrival_airport TEXT NOT NULL,
  departure_time TIMESTAMPTZ NOT NULL,
  arrival_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'boarding', 'enroute', 'landed', 'delayed')),
  aircraft_type TEXT,
  last_event TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PASSENGERS TABLE
CREATE TABLE passengers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT,
  pnr TEXT NOT NULL,
  seat_number TEXT,
  class_of_service TEXT CHECK (class_of_service IN ('Economy', 'Premium Economy', 'Business', 'First')),
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. JOURNEYS TABLE
CREATE TABLE journeys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  passenger_id UUID REFERENCES passengers(id) ON DELETE CASCADE,
  flight_id UUID REFERENCES flights(id) ON DELETE CASCADE,
  pnr TEXT NOT NULL,
  seat_number TEXT,
  visit_status TEXT DEFAULT 'Upcoming' CHECK (visit_status IN ('Upcoming', 'In Progress', 'Completed')),
  connection_time_mins INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(passenger_id, flight_id)
);

-- 4. FEEDBACK TABLE
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  flight_id UUID REFERENCES flights(id) ON DELETE CASCADE,
  phase TEXT NOT NULL CHECK (phase IN ('on_ground', 'in_air', 'landed')),
  category TEXT NOT NULL,
  rating NUMERIC(2, 1) CHECK (rating >= 1.0 AND rating <= 5.0),
  sentiment TEXT CHECK (sentiment IN ('positive', 'neutral', 'negative')),
  comment TEXT,
  timestamp TIMESTAMPTZ NOT NULL,
  tags JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ISSUES TABLE
CREATE TABLE issues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flight_id UUID REFERENCES flights(id) ON DELETE CASCADE,
  seat_number TEXT,
  summary TEXT NOT NULL,
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ALERTS TABLE
CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flight_id UUID REFERENCES flights(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cleared')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- INDEXES FOR PERFORMANCE
CREATE INDEX idx_flights_flight_number ON flights (flight_number);
CREATE INDEX idx_flights_carrier_number ON flights(carrier_code, flight_number);
CREATE INDEX idx_journeys_passenger_id ON journeys (passenger_id);
CREATE INDEX idx_journeys_flight_id ON journeys (flight_id);
CREATE INDEX idx_feedback_journey_id ON feedback (journey_id);
CREATE INDEX idx_feedback_flight_id ON feedback (flight_id);
CREATE INDEX idx_feedback_phase ON feedback (phase);
CREATE INDEX idx_feedback_category ON feedback (category);
CREATE INDEX idx_feedback_sentiment ON feedback (sentiment);
CREATE INDEX idx_feedback_timestamp ON feedback (timestamp DESC);
CREATE INDEX idx_issues_flight_id ON issues (flight_id);
CREATE INDEX idx_alerts_flight_id ON alerts (flight_id);

-- REAL-TIME VIEW FOR DASHBOARD
CREATE VIEW realtime_feedback_view AS
SELECT
  f.id AS feedback_id,
  p.name AS passenger_name,
  j.seat_number AS seat_number,
  fl.flight_number,
  fl.carrier_code,
  fl.departure_airport,
  fl.arrival_airport,
  f.phase,
  f.category,
  f.rating,
  f.sentiment,
  f.comment,
  f.tags,
  f.timestamp AS feedback_time,
  f.created_at
FROM feedback f
JOIN journeys j ON f.journey_id = j.id
JOIN passengers p ON j.passenger_id = p.id
JOIN flights fl ON j.flight_id = fl.id
ORDER BY f.timestamp DESC;

-- AGGREGATE VIEW FOR FLIGHT FEEDBACK
CREATE VIEW flight_feedback_aggregates AS
SELECT
    fl.id AS flight_id,
    fl.flight_number,
    fl.carrier_code,
    fl.departure_airport,
    fl.arrival_airport,
    fl.status,
    COUNT(f.id) AS total_feedback_count,
    COUNT(CASE WHEN f.sentiment = 'positive' THEN 1 END) AS positive_feedback_count,
    COUNT(CASE WHEN f.sentiment = 'negative' THEN 1 END) AS negative_feedback_count,
    AVG(f.rating) AS average_rating,
    (COUNT(CASE WHEN f.sentiment = 'positive' THEN 1 END)::NUMERIC / NULLIF(COUNT(f.id), 0)) * 100 AS positive_sentiment_percentage,
    (COUNT(CASE WHEN f.sentiment = 'negative' THEN 1 END)::NUMERIC / NULLIF(COUNT(f.id), 0)) * 100 AS negative_sentiment_percentage,
    ARRAY_AGG(DISTINCT tag) FILTER (WHERE tag IS NOT NULL) AS common_tags
FROM flights fl
LEFT JOIN feedback f ON fl.id = f.flight_id
LEFT JOIN LATERAL jsonb_array_elements_text(f.tags) AS tag ON TRUE
GROUP BY fl.id, fl.flight_number, fl.carrier_code, fl.departure_airport, fl.arrival_airport, fl.status;

-- ENABLE REALTIME FOR FEEDBACK TABLE
ALTER PUBLICATION supabase_realtime ADD TABLE feedback;

-- ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE flights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public flights are viewable by everyone." ON flights FOR SELECT USING (true);

ALTER TABLE passengers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Passengers can view their own data." ON passengers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Passengers can insert their own data." ON passengers FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Journey owners can view their journeys." ON journeys FOR SELECT USING (EXISTS (SELECT 1 FROM passengers WHERE passengers.id = journeys.passenger_id AND passengers.user_id = auth.uid()));
CREATE POLICY "Journey owners can insert their journeys." ON journeys FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM passengers WHERE passengers.id = journeys.passenger_id AND passengers.user_id = auth.uid()));

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Feedback can be viewed by journey owners." ON feedback FOR SELECT USING (EXISTS (SELECT 1 FROM journeys j JOIN passengers p ON j.passenger_id = p.id WHERE j.id = feedback.journey_id AND p.user_id = auth.uid()));
CREATE POLICY "Feedback can be inserted by authenticated users." ON feedback FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Success message
SELECT 'Fresh install completed successfully! All tables, views, and policies have been created.' AS result;
