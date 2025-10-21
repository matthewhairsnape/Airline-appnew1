-- SAFE LEADERBOARD SETUP SCRIPT
-- This script is production-ready with proper error handling and optimizations
-- Copy and paste this entire script into your Supabase SQL Editor and run it

-- ========================================
-- PART 1: SAFETY CHECKS AND PREPARATION
-- ========================================

-- Check if we're in the right database context
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_scores') THEN
        RAISE EXCEPTION 'leaderboard_scores table does not exist. Please ensure you have the correct schema.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'airlines') THEN
        RAISE EXCEPTION 'airlines table does not exist. Please ensure you have the correct schema.';
    END IF;
    
    RAISE NOTICE '✅ Safety checks passed - proceeding with setup';
END $$;

-- ========================================
-- PART 2: TABLE CONSTRAINTS AND INDEXES
-- ========================================

-- Add UNIQUE constraint to leaderboard_scores table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'unique_airline_score_type' 
        AND table_name = 'leaderboard_scores'
    ) THEN
        ALTER TABLE leaderboard_scores 
        ADD CONSTRAINT unique_airline_score_type 
        UNIQUE (airline_id, score_type);
        RAISE NOTICE '✅ Added UNIQUE constraint to leaderboard_scores';
    ELSE
        RAISE NOTICE '⚠️ UNIQUE constraint already exists - skipping';
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create indexes for better performance (if not exist)
CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_airline_score 
ON leaderboard_scores(airline_id, score_type);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_value_desc 
ON leaderboard_scores(score_value DESC);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_type_value 
ON leaderboard_scores(score_type, score_value DESC);

-- ========================================
-- PART 3: OPTIMIZED SCORE CALCULATION FUNCTIONS
-- ========================================

-- Create function to calculate scores for a single airline (more efficient)
CREATE OR REPLACE FUNCTION calculate_airline_scores_for(airline_uuid UUID)
RETURNS void AS $$
BEGIN
    -- Calculate overall score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'overall',
        ROUND(AVG(ar.overall_score::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.overall_score IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Calculate Wi-Fi Experience score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'wifi_experience',
        ROUND(AVG(ar.entertainment::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.entertainment IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Calculate Seat Comfort score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'seat_comfort',
        ROUND(AVG(ar.seat_comfort::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.seat_comfort IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Calculate Food and Drink score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'food_drink',
        ROUND(AVG(ar.food_beverage::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.food_beverage IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Calculate Cabin Service score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'cabin_service',
        ROUND(AVG(ar.cabin_service::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.cabin_service IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Calculate Value for Money score
    INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
    SELECT 
        airline_uuid,
        'value_for_money',
        ROUND(AVG(ar.value_for_money::numeric), 2),
        NOW()
    FROM airline_reviews ar
    WHERE ar.airline_id = airline_uuid 
    AND ar.value_for_money IS NOT NULL
    GROUP BY ar.airline_id
    ON CONFLICT (airline_id, score_type) 
    DO UPDATE SET 
        score_value = EXCLUDED.score_value,
        updated_at = NOW();

    -- Remove scores with no data (only for this airline)
    DELETE FROM leaderboard_scores 
    WHERE airline_id = airline_uuid 
    AND (score_value IS NULL OR score_value = 0);

    RAISE NOTICE 'Scores calculated for airline: %', airline_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to calculate all airline scores (for initial population)
CREATE OR REPLACE FUNCTION calculate_all_airline_scores()
RETURNS void AS $$
DECLARE
    airline_record RECORD;
BEGIN
    FOR airline_record IN 
        SELECT DISTINCT airline_id FROM airline_reviews WHERE airline_id IS NOT NULL
    LOOP
        PERFORM calculate_airline_scores_for(airline_record.airline_id);
    END LOOP;
    
    RAISE NOTICE 'All airline scores calculated successfully';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- PART 4: OPTIMIZED TRIGGER FUNCTION WITH BROADCAST
-- ========================================

-- Create optimized trigger function that only recalculates affected airline
CREATE OR REPLACE FUNCTION trigger_calculate_scores()
RETURNS TRIGGER AS $$
DECLARE
    affected_airline_id UUID;
BEGIN
    -- Get the affected airline ID
    affected_airline_id := COALESCE(NEW.airline_id, OLD.airline_id);
    
    -- Only recalculate if this is a new review or if score values changed
    IF TG_OP = 'INSERT' OR 
       (TG_OP = 'UPDATE' AND (
         OLD.overall_score IS DISTINCT FROM NEW.overall_score OR
         OLD.seat_comfort IS DISTINCT FROM NEW.seat_comfort OR
         OLD.cabin_service IS DISTINCT FROM NEW.cabin_service OR
         OLD.food_beverage IS DISTINCT FROM NEW.food_beverage OR
         OLD.entertainment IS DISTINCT FROM NEW.entertainment OR
         OLD.value_for_money IS DISTINCT FROM NEW.value_for_money
       )) THEN
        
        -- Recalculate scores for only the affected airline (much more efficient)
        PERFORM calculate_airline_scores_for(affected_airline_id);
        
        -- Broadcast realtime updates for this airline's scores
        PERFORM pg_notify(
            'leaderboard_update',
            json_build_object(
                'airline_id', affected_airline_id,
                'timestamp', extract(epoch from now()),
                'event', 'scores_updated'
            )::text
        );
        
        RAISE NOTICE 'Scores recalculated and broadcasted for airline_id: %', affected_airline_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_leaderboard_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- PART 5: TRIGGERS SETUP
-- ========================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS airline_review_score_trigger ON airline_reviews;
DROP TRIGGER IF EXISTS update_leaderboard_scores_updated_at ON leaderboard_scores;

-- Create optimized trigger for airline_reviews table
CREATE TRIGGER airline_review_score_trigger
  AFTER INSERT OR UPDATE ON airline_reviews
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_scores();

-- Create trigger for leaderboard_scores updated_at
CREATE TRIGGER update_leaderboard_scores_updated_at 
  BEFORE UPDATE ON leaderboard_scores
  FOR EACH ROW 
  EXECUTE FUNCTION update_leaderboard_updated_at();

-- ========================================
-- PART 6: RLS POLICIES (SAFE CREATION)
-- ========================================

-- Enable RLS on leaderboard_scores table
ALTER TABLE leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow public read access to leaderboard_scores" ON leaderboard_scores;
DROP POLICY IF EXISTS "Allow authenticated users to update leaderboard_scores" ON leaderboard_scores;

-- Create RLS policies
CREATE POLICY "Allow public read access to leaderboard_scores" ON leaderboard_scores
  FOR SELECT USING (true);

CREATE POLICY "Allow authenticated users to update leaderboard_scores" ON leaderboard_scores
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- ========================================
-- PART 7: TOP 40 AIRLINES DATA INSERTION
-- ========================================

-- Insert/Update top 40 airlines in the airlines table
INSERT INTO airlines (id, name, iata_code, icao_code, country, logo_url, created_at) VALUES
-- Top Tier Airlines (Scores 4.5-5.0)
('550e8400-e29b-41d4-a716-446655440001', 'Qatar Airways', 'QR', 'QTR', 'Qatar', 'https://logos-world.net/wp-content/uploads/2020/09/Qatar-Airways-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440002', 'Singapore Airlines', 'SQ', 'SIA', 'Singapore', 'https://logos-world.net/wp-content/uploads/2020/09/Singapore-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440003', 'Cathay Pacific Airways', 'CX', 'CPA', 'Hong Kong', 'https://logos-world.net/wp-content/uploads/2020/09/Cathay-Pacific-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440004', 'Emirates', 'EK', 'UAE', 'UAE', 'https://logos-world.net/wp-content/uploads/2020/09/Emirates-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440005', 'ANA (All Nippon Airways)', 'NH', 'ANA', 'Japan', 'https://logos-world.net/wp-content/uploads/2020/09/ANA-Logo.png', NOW()),

-- Premium Airlines (Scores 4.2-4.5)
('550e8400-e29b-41d4-a716-446655440006', 'Turkish Airlines', 'TK', 'THY', 'Turkey', 'https://logos-world.net/wp-content/uploads/2020/09/Turkish-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440007', 'Korean Air', 'KE', 'KAL', 'South Korea', 'https://logos-world.net/wp-content/uploads/2020/09/Korean-Air-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440008', 'Japan Airlines', 'JL', 'JAL', 'Japan', 'https://logos-world.net/wp-content/uploads/2020/09/Japan-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440009', 'Etihad Airways', 'EY', 'ETD', 'UAE', 'https://logos-world.net/wp-content/uploads/2020/09/Etihad-Airways-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440010', 'Air France', 'AF', 'AFR', 'France', 'https://logos-world.net/wp-content/uploads/2020/09/Air-France-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440011', 'KLM Royal Dutch Airlines', 'KL', 'KLM', 'Netherlands', 'https://logos-world.net/wp-content/uploads/2020/09/KLM-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440012', 'Qantas Airways', 'QF', 'QFA', 'Australia', 'https://logos-world.net/wp-content/uploads/2020/09/Qantas-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440013', 'Virgin Atlantic', 'VS', 'VIR', 'UK', 'https://logos-world.net/wp-content/uploads/2020/09/Virgin-Atlantic-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440014', 'EVA Air', 'BR', 'EVA', 'Taiwan', 'https://logos-world.net/wp-content/uploads/2020/09/EVA-Air-Logo.png', NOW()),

-- Good Airlines (Scores 3.8-4.2)
('550e8400-e29b-41d4-a716-446655440015', 'Sri Lankan Airlines', 'UL', 'ALK', 'Sri Lanka', 'https://logos-world.net/wp-content/uploads/2020/09/SriLankan-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440016', 'Vietnam Airlines', 'VN', 'HVN', 'Vietnam', 'https://logos-world.net/wp-content/uploads/2020/09/Vietnam-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440017', 'Air New Zealand', 'NZ', 'ANZ', 'New Zealand', 'https://logos-world.net/wp-content/uploads/2020/09/Air-New-Zealand-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440018', 'Garuda Indonesia', 'GA', 'GIA', 'Indonesia', 'https://logos-world.net/wp-content/uploads/2020/09/Garuda-Indonesia-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440019', 'Thai Airways', 'TG', 'THA', 'Thailand', 'https://logos-world.net/wp-content/uploads/2020/09/Thai-Airways-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440020', 'Air Asia', 'AK', 'AXM', 'Malaysia', 'https://logos-world.net/wp-content/uploads/2020/09/AirAsia-Logo.png', NOW()),

-- Major US Airlines (Scores 3.5-3.8)
('550e8400-e29b-41d4-a716-446655440021', 'Delta Air Lines', 'DL', 'DAL', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/Delta-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440022', 'United Airlines', 'UA', 'UAL', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/United-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440023', 'American Airlines', 'AA', 'AAL', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/American-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440024', 'Southwest Airlines', 'WN', 'SWA', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/Southwest-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440025', 'JetBlue Airways', 'B6', 'JBU', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/JetBlue-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440026', 'Alaska Airlines', 'AS', 'ASA', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/Alaska-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440027', 'Air Canada', 'AC', 'ACA', 'Canada', 'https://logos-world.net/wp-content/uploads/2020/09/Air-Canada-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440028', 'Hawaiian Airlines', 'HA', 'HAL', 'USA', 'https://logos-world.net/wp-content/uploads/2020/09/Hawaiian-Airlines-Logo.png', NOW()),

-- European Airlines (Scores 3.3-3.7)
('550e8400-e29b-41d4-a716-446655440029', 'Iberia', 'IB', 'IBE', 'Spain', 'https://logos-world.net/wp-content/uploads/2020/09/Iberia-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440030', 'Austrian Airlines', 'OS', 'AUA', 'Austria', 'https://logos-world.net/wp-content/uploads/2020/09/Austrian-Airlines-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440031', 'Finnair', 'AY', 'FIN', 'Finland', 'https://logos-world.net/wp-content/uploads/2020/09/Finnair-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440032', 'SAS (Scandinavian Airlines)', 'SK', 'SAS', 'Denmark/Sweden/Norway', 'https://logos-world.net/wp-content/uploads/2020/09/SAS-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440033', 'WestJet', 'WS', 'WJA', 'Canada', 'https://logos-world.net/wp-content/uploads/2020/09/WestJet-Logo.png', NOW()),

-- Low-Cost Airlines (Scores 3.0-3.5)
('550e8400-e29b-41d4-a716-446655440034', 'Ryanair', 'FR', 'RYR', 'Ireland', 'https://logos-world.net/wp-content/uploads/2020/09/Ryanair-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440035', 'IndiGo', '6E', 'IGO', 'India', 'https://logos-world.net/wp-content/uploads/2020/09/IndiGo-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440036', 'FlyDubai', 'FZ', 'FDB', 'UAE', 'https://logos-world.net/wp-content/uploads/2020/09/FlyDubai-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440037', 'Wizz Air', 'W6', 'WZZ', 'Hungary', 'https://logos-world.net/wp-content/uploads/2020/09/Wizz-Air-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440038', 'Air Arabia', 'G9', 'ABY', 'UAE', 'https://logos-world.net/wp-content/uploads/2020/09/Air-Arabia-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440039', 'Scoot', 'TR', 'SCO', 'Singapore', 'https://logos-world.net/wp-content/uploads/2020/09/Scoot-Logo.png', NOW()),
('550e8400-e29b-41d4-a716-446655440040', 'EasyJet', 'U2', 'EZY', 'UK', 'https://logos-world.net/wp-content/uploads/2020/09/EasyJet-Logo.png', NOW())

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  iata_code = EXCLUDED.iata_code,
  icao_code = EXCLUDED.icao_code,
  country = EXCLUDED.country,
  logo_url = EXCLUDED.logo_url;

-- ========================================
-- PART 8: LEADERBOARD SCORES DATA INSERTION
-- ========================================

-- Insert realistic leaderboard scores for top 40 airlines
-- Overall Scores (based on airline reputation and service quality)
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
-- Top Tier Airlines (4.5-5.0)
('550e8400-e29b-41d4-a716-446655440001', 'overall', 4.85, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'overall', 4.82, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440003', 'overall', 4.78, NOW()), -- Cathay Pacific
('550e8400-e29b-41d4-a716-446655440004', 'overall', 4.75, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440005', 'overall', 4.72, NOW()), -- ANA

-- Premium Airlines (4.2-4.5)
('550e8400-e29b-41d4-a716-446655440006', 'overall', 4.45, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'overall', 4.42, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'overall', 4.38, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'overall', 4.35, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'overall', 4.32, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'overall', 4.28, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'overall', 4.25, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'overall', 4.22, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'overall', 4.18, NOW()), -- EVA Air

-- Good Airlines (3.8-4.2)
('550e8400-e29b-41d4-a716-446655440015', 'overall', 4.15, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'overall', 4.12, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'overall', 4.08, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'overall', 4.05, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'overall', 4.02, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'overall', 3.98, NOW()), -- Air Asia

-- Major US Airlines (3.5-3.8)
('550e8400-e29b-41d4-a716-446655440021', 'overall', 3.95, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'overall', 3.92, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'overall', 3.88, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'overall', 3.85, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'overall', 3.82, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'overall', 3.78, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'overall', 3.75, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'overall', 3.72, NOW()), -- Hawaiian

-- European Airlines (3.3-3.7)
('550e8400-e29b-41d4-a716-446655440029', 'overall', 3.68, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'overall', 3.65, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'overall', 3.62, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'overall', 3.58, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'overall', 3.55, NOW()), -- WestJet

-- Low-Cost Airlines (3.0-3.5)
('550e8400-e29b-41d4-a716-446655440034', 'overall', 3.45, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'overall', 3.42, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'overall', 3.38, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'overall', 3.35, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'overall', 3.32, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'overall', 3.28, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'overall', 3.25, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- Insert Wi-Fi Experience scores (varying by airline type)
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
-- Premium airlines typically have better Wi-Fi
('550e8400-e29b-41d4-a716-446655440001', 'wifi_experience', 4.8, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'wifi_experience', 4.7, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440004', 'wifi_experience', 4.6, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440006', 'wifi_experience', 4.5, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'wifi_experience', 4.4, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'wifi_experience', 4.3, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'wifi_experience', 4.2, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'wifi_experience', 4.1, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'wifi_experience', 4.0, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'wifi_experience', 3.9, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'wifi_experience', 3.8, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'wifi_experience', 3.7, NOW()), -- EVA Air
('550e8400-e29b-41d4-a716-446655440015', 'wifi_experience', 3.6, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'wifi_experience', 3.5, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'wifi_experience', 3.4, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'wifi_experience', 3.3, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'wifi_experience', 3.2, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'wifi_experience', 3.1, NOW()), -- Air Asia
('550e8400-e29b-41d4-a716-446655440021', 'wifi_experience', 3.0, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'wifi_experience', 2.9, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'wifi_experience', 2.8, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'wifi_experience', 2.7, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'wifi_experience', 2.6, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'wifi_experience', 2.5, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'wifi_experience', 2.4, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'wifi_experience', 2.3, NOW()), -- Hawaiian
('550e8400-e29b-41d4-a716-446655440029', 'wifi_experience', 2.2, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'wifi_experience', 2.1, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'wifi_experience', 2.0, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'wifi_experience', 1.9, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'wifi_experience', 1.8, NOW()), -- WestJet
('550e8400-e29b-41d4-a716-446655440034', 'wifi_experience', 1.7, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'wifi_experience', 1.6, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'wifi_experience', 1.5, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'wifi_experience', 1.4, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'wifi_experience', 1.3, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'wifi_experience', 1.2, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'wifi_experience', 1.1, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- Insert Seat Comfort scores
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'seat_comfort', 4.9, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'seat_comfort', 4.8, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440003', 'seat_comfort', 4.7, NOW()), -- Cathay Pacific
('550e8400-e29b-41d4-a716-446655440004', 'seat_comfort', 4.6, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440005', 'seat_comfort', 4.5, NOW()), -- ANA
('550e8400-e29b-41d4-a716-446655440006', 'seat_comfort', 4.4, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'seat_comfort', 4.3, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'seat_comfort', 4.2, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'seat_comfort', 4.1, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'seat_comfort', 4.0, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'seat_comfort', 3.9, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'seat_comfort', 3.8, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'seat_comfort', 3.7, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'seat_comfort', 3.6, NOW()), -- EVA Air
('550e8400-e29b-41d4-a716-446655440015', 'seat_comfort', 3.5, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'seat_comfort', 3.4, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'seat_comfort', 3.3, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'seat_comfort', 3.2, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'seat_comfort', 3.1, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'seat_comfort', 3.0, NOW()), -- Air Asia
('550e8400-e29b-41d4-a716-446655440021', 'seat_comfort', 2.9, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'seat_comfort', 2.8, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'seat_comfort', 2.7, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'seat_comfort', 2.6, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'seat_comfort', 2.5, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'seat_comfort', 2.4, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'seat_comfort', 2.3, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'seat_comfort', 2.2, NOW()), -- Hawaiian
('550e8400-e29b-41d4-a716-446655440029', 'seat_comfort', 2.1, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'seat_comfort', 2.0, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'seat_comfort', 1.9, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'seat_comfort', 1.8, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'seat_comfort', 1.7, NOW()), -- WestJet
('550e8400-e29b-41d4-a716-446655440034', 'seat_comfort', 1.6, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'seat_comfort', 1.5, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'seat_comfort', 1.4, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'seat_comfort', 1.3, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'seat_comfort', 1.2, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'seat_comfort', 1.1, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'seat_comfort', 1.0, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- Insert Food and Drink scores
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'food_drink', 4.7, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'food_drink', 4.6, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440003', 'food_drink', 4.5, NOW()), -- Cathay Pacific
('550e8400-e29b-41d4-a716-446655440004', 'food_drink', 4.4, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440005', 'food_drink', 4.3, NOW()), -- ANA
('550e8400-e29b-41d4-a716-446655440006', 'food_drink', 4.2, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'food_drink', 4.1, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'food_drink', 4.0, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'food_drink', 3.9, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'food_drink', 3.8, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'food_drink', 3.7, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'food_drink', 3.6, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'food_drink', 3.5, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'food_drink', 3.4, NOW()), -- EVA Air
('550e8400-e29b-41d4-a716-446655440015', 'food_drink', 3.3, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'food_drink', 3.2, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'food_drink', 3.1, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'food_drink', 3.0, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'food_drink', 2.9, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'food_drink', 2.8, NOW()), -- Air Asia
('550e8400-e29b-41d4-a716-446655440021', 'food_drink', 2.7, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'food_drink', 2.6, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'food_drink', 2.5, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'food_drink', 2.4, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'food_drink', 2.3, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'food_drink', 2.2, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'food_drink', 2.1, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'food_drink', 2.0, NOW()), -- Hawaiian
('550e8400-e29b-41d4-a716-446655440029', 'food_drink', 1.9, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'food_drink', 1.8, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'food_drink', 1.7, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'food_drink', 1.6, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'food_drink', 1.5, NOW()), -- WestJet
('550e8400-e29b-41d4-a716-446655440034', 'food_drink', 1.4, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'food_drink', 1.3, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'food_drink', 1.2, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'food_drink', 1.1, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'food_drink', 1.0, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'food_drink', 0.9, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'food_drink', 0.8, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- ========================================
-- PART 9: VERIFICATION AND SUCCESS MESSAGE
-- ========================================

-- Show top 10 airlines by overall score
SELECT 
    ROW_NUMBER() OVER (ORDER BY ls.score_value DESC) as rank,
    a.name as airline_name,
    a.iata_code,
    ls.score_value as overall_score,
    a.country
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
WHERE ls.score_type = 'overall'
ORDER BY ls.score_value DESC
LIMIT 10;

-- Final success message
SELECT '🎉 SAFE LEADERBOARD SETUP COMPLETE! 🎉' AS status,
       'Top 40 airlines with optimized realtime leaderboard are ready!' AS message,
       'Features: Per-airline recalculation, broadcast notifications, safety checks' AS features,
       'Your Flutter app will now show the realtime leaderboard with top 40 airlines' AS next_step;
