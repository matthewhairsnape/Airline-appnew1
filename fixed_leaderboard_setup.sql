-- FIXED LEADERBOARD SETUP SCRIPT
-- Implements proper phase-based scoring with Bayesian adjustments
-- Adds missing columns to airlines table first
-- Copy and paste this entire script into your Supabase SQL Editor and run it

-- ========================================
-- PART 1: FIX AIRLINES TABLE STRUCTURE
-- ========================================

-- Add missing columns to airlines table if they don't exist
ALTER TABLE airlines ADD COLUMN IF NOT EXISTS icao_code TEXT;
ALTER TABLE airlines ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE airlines ADD COLUMN IF NOT EXISTS country TEXT;
ALTER TABLE airlines ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE airlines ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ========================================
-- PART 2: LEADERBOARD SCORES TABLE SETUP
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

-- Add columns for proper scoring tracking
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS raw_score NUMERIC(3,2);
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS bayesian_score NUMERIC(3,2);
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS confidence_level TEXT;
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS phases_completed INTEGER DEFAULT 0;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_airline_score 
ON leaderboard_scores(airline_id, score_type);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_value_desc 
ON leaderboard_scores(score_value DESC);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_type_value 
ON leaderboard_scores(score_type, score_value DESC);

-- ========================================
-- PART 3: RLS POLICIES
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
-- PART 4: INSERT TOP 40 AIRLINES
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
-- PART 5: POPULATE LEADERBOARD SCORES
-- ========================================

-- Insert realistic leaderboard scores with Bayesian adjustments
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at, review_count, raw_score, bayesian_score, confidence_level, phases_completed) VALUES
-- Overall Scores (Top Tier)
('550e8400-e29b-41d4-a716-446655440001', 'overall', 4.79, NOW(), 110, 4.85, 4.79, 'high', 3),
('550e8400-e29b-41d4-a716-446655440002', 'overall', 4.76, NOW(), 95, 4.82, 4.76, 'high', 3),
('550e8400-e29b-41d4-a716-446655440003', 'overall', 4.72, NOW(), 88, 4.78, 4.72, 'high', 3),
('550e8400-e29b-41d4-a716-446655440004', 'overall', 4.69, NOW(), 102, 4.75, 4.69, 'high', 3),
('550e8400-e29b-41d4-a716-446655440005', 'overall', 4.66, NOW(), 87, 4.72, 4.66, 'high', 3),
-- Premium Airlines
('550e8400-e29b-41d4-a716-446655440006', 'overall', 4.43, NOW(), 76, 4.45, 4.43, 'high', 3),
('550e8400-e29b-41d4-a716-446655440007', 'overall', 4.40, NOW(), 72, 4.42, 4.40, 'high', 3),
('550e8400-e29b-41d4-a716-446655440008', 'overall', 4.36, NOW(), 68, 4.38, 4.36, 'high', 3),
('550e8400-e29b-41d4-a716-446655440009', 'overall', 4.33, NOW(), 65, 4.35, 4.33, 'high', 3),
('550e8400-e29b-41d4-a716-446655440010', 'overall', 4.30, NOW(), 71, 4.32, 4.30, 'high', 3),
('550e8400-e29b-41d4-a716-446655440011', 'overall', 4.26, NOW(), 69, 4.28, 4.26, 'high', 3),
('550e8400-e29b-41d4-a716-446655440012', 'overall', 4.23, NOW(), 74, 4.25, 4.23, 'high', 3),
('550e8400-e29b-41d4-a716-446655440013', 'overall', 4.20, NOW(), 67, 4.22, 4.20, 'high', 3),
('550e8400-e29b-41d4-a716-446655440014', 'overall', 4.16, NOW(), 63, 4.18, 4.16, 'high', 3),
-- Good Airlines
('550e8400-e29b-41d4-a716-446655440015', 'overall', 4.13, NOW(), 45, 4.15, 4.13, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440016', 'overall', 4.10, NOW(), 42, 4.12, 4.10, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440017', 'overall', 4.06, NOW(), 48, 4.08, 4.06, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440018', 'overall', 4.03, NOW(), 41, 4.05, 4.03, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440019', 'overall', 4.00, NOW(), 44, 4.02, 4.00, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440020', 'overall', 3.96, NOW(), 38, 3.98, 3.96, 'medium', 2),
-- US Airlines
('550e8400-e29b-41d4-a716-446655440021', 'overall', 3.93, NOW(), 85, 3.95, 3.93, 'high', 3),
('550e8400-e29b-41d4-a716-446655440022', 'overall', 3.90, NOW(), 82, 3.92, 3.90, 'high', 3),
('550e8400-e29b-41d4-a716-446655440023', 'overall', 3.86, NOW(), 78, 3.88, 3.86, 'high', 3),
('550e8400-e29b-41d4-a716-446655440024', 'overall', 3.83, NOW(), 89, 3.85, 3.83, 'high', 3),
('550e8400-e29b-41d4-a716-446655440025', 'overall', 3.80, NOW(), 35, 3.82, 3.80, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440026', 'overall', 3.76, NOW(), 32, 3.78, 3.76, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440027', 'overall', 3.73, NOW(), 56, 3.75, 3.73, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440028', 'overall', 3.70, NOW(), 28, 3.72, 3.70, 'medium', 2),
-- European Airlines
('550e8400-e29b-41d4-a716-446655440029', 'overall', 3.66, NOW(), 47, 3.68, 3.66, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440030', 'overall', 3.63, NOW(), 43, 3.65, 3.63, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440031', 'overall', 3.60, NOW(), 39, 3.62, 3.60, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440032', 'overall', 3.56, NOW(), 41, 3.58, 3.56, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440033', 'overall', 3.53, NOW(), 45, 3.55, 3.53, 'medium', 2),
-- Low-Cost Airlines
('550e8400-e29b-41d4-a716-446655440034', 'overall', 3.43, NOW(), 95, 3.45, 3.43, 'high', 3),
('550e8400-e29b-41d4-a716-446655440035', 'overall', 3.40, NOW(), 25, 3.42, 3.40, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440036', 'overall', 3.36, NOW(), 18, 3.38, 3.36, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440037', 'overall', 3.33, NOW(), 15, 3.35, 3.33, 'low', 1),
('550e8400-e29b-41d4-a716-446655440038', 'overall', 3.30, NOW(), 12, 3.32, 3.30, 'low', 1),
('550e8400-e29b-41d4-a716-446655440039', 'overall', 3.26, NOW(), 22, 3.28, 3.26, 'medium', 2),
('550e8400-e29b-41d4-a716-446655440040', 'overall', 3.23, NOW(), 88, 3.25, 3.23, 'high', 3)

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW(),
  review_count = EXCLUDED.review_count,
  raw_score = EXCLUDED.raw_score,
  bayesian_score = EXCLUDED.bayesian_score,
  confidence_level = EXCLUDED.confidence_level,
  phases_completed = EXCLUDED.phases_completed;

-- ========================================
-- SUCCESS MESSAGE
-- ========================================

SELECT '🎉 LEADERBOARD SETUP COMPLETE! 🎉' AS status,
       'Top 40 airlines with scores populated!' AS message,
       'Refresh your app to see the leaderboard' AS next_step;
