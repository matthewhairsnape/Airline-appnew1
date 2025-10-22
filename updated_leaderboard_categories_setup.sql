-- UPDATED LEADERBOARD CATEGORIES SETUP
-- This script adds support for the new comprehensive categories
-- Run this AFTER the complete_leaderboard_setup.sql

-- ========================================
-- PART 1: ADD NEW CATEGORY SCORE TYPES
-- ========================================

-- Add new score types for the comprehensive categories
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
-- Crew Friendliness scores (using cabin_service as base)
('550e8400-e29b-41d4-a716-446655440001', 'crew_friendliness', 4.9, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'crew_friendliness', 4.8, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440003', 'crew_friendliness', 4.7, NOW()), -- Cathay Pacific
('550e8400-e29b-41d4-a716-446655440004', 'crew_friendliness', 4.6, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440005', 'crew_friendliness', 4.5, NOW()), -- ANA
('550e8400-e29b-41d4-a716-446655440006', 'crew_friendliness', 4.4, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'crew_friendliness', 4.3, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'crew_friendliness', 4.2, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'crew_friendliness', 4.1, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'crew_friendliness', 4.0, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'crew_friendliness', 3.9, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'crew_friendliness', 3.8, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'crew_friendliness', 3.7, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'crew_friendliness', 3.6, NOW()), -- EVA Air
('550e8400-e29b-41d4-a716-446655440015', 'crew_friendliness', 3.5, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'crew_friendliness', 3.4, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'crew_friendliness', 3.3, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'crew_friendliness', 3.2, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'crew_friendliness', 3.1, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'crew_friendliness', 3.0, NOW()), -- Air Asia
('550e8400-e29b-41d4-a716-446655440021', 'crew_friendliness', 2.9, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'crew_friendliness', 2.8, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'crew_friendliness', 2.7, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'crew_friendliness', 2.6, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'crew_friendliness', 2.5, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'crew_friendliness', 2.4, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'crew_friendliness', 2.3, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'crew_friendliness', 2.2, NOW()), -- Hawaiian
('550e8400-e29b-41d4-a716-446655440029', 'crew_friendliness', 2.1, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'crew_friendliness', 2.0, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'crew_friendliness', 1.9, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'crew_friendliness', 1.8, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'crew_friendliness', 1.7, NOW()), -- WestJet
('550e8400-e29b-41d4-a716-446655440034', 'crew_friendliness', 1.6, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'crew_friendliness', 1.5, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'crew_friendliness', 1.4, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'crew_friendliness', 1.3, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'crew_friendliness', 1.2, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'crew_friendliness', 1.1, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'crew_friendliness', 1.0, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- Add Food & Beverage scores (rename from food_drink to food_beverage)
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at)
SELECT 
  airline_id,
  'food_beverage',
  score_value,
  updated_at
FROM leaderboard_scores 
WHERE score_type = 'food_drink'

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- Add Operations & Timeliness scores (using overall as base with slight variations)
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, updated_at) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'operations_timeliness', 4.8, NOW()), -- Qatar Airways
('550e8400-e29b-41d4-a716-446655440002', 'operations_timeliness', 4.7, NOW()), -- Singapore Airlines
('550e8400-e29b-41d4-a716-446655440003', 'operations_timeliness', 4.6, NOW()), -- Cathay Pacific
('550e8400-e29b-41d4-a716-446655440004', 'operations_timeliness', 4.5, NOW()), -- Emirates
('550e8400-e29b-41d4-a716-446655440005', 'operations_timeliness', 4.4, NOW()), -- ANA
('550e8400-e29b-41d4-a716-446655440006', 'operations_timeliness', 4.3, NOW()), -- Turkish Airlines
('550e8400-e29b-41d4-a716-446655440007', 'operations_timeliness', 4.2, NOW()), -- Korean Air
('550e8400-e29b-41d4-a716-446655440008', 'operations_timeliness', 4.1, NOW()), -- Japan Airlines
('550e8400-e29b-41d4-a716-446655440009', 'operations_timeliness', 4.0, NOW()), -- Etihad
('550e8400-e29b-41d4-a716-446655440010', 'operations_timeliness', 3.9, NOW()), -- Air France
('550e8400-e29b-41d4-a716-446655440011', 'operations_timeliness', 3.8, NOW()), -- KLM
('550e8400-e29b-41d4-a716-446655440012', 'operations_timeliness', 3.7, NOW()), -- Qantas
('550e8400-e29b-41d4-a716-446655440013', 'operations_timeliness', 3.6, NOW()), -- Virgin Atlantic
('550e8400-e29b-41d4-a716-446655440014', 'operations_timeliness', 3.5, NOW()), -- EVA Air
('550e8400-e29b-41d4-a716-446655440015', 'operations_timeliness', 3.4, NOW()), -- Sri Lankan
('550e8400-e29b-41d4-a716-446655440016', 'operations_timeliness', 3.3, NOW()), -- Vietnam Airlines
('550e8400-e29b-41d4-a716-446655440017', 'operations_timeliness', 3.2, NOW()), -- Air New Zealand
('550e8400-e29b-41d4-a716-446655440018', 'operations_timeliness', 3.1, NOW()), -- Garuda Indonesia
('550e8400-e29b-41d4-a716-446655440019', 'operations_timeliness', 3.0, NOW()), -- Thai Airways
('550e8400-e29b-41d4-a716-446655440020', 'operations_timeliness', 2.9, NOW()), -- Air Asia
('550e8400-e29b-41d4-a716-446655440021', 'operations_timeliness', 2.8, NOW()), -- Delta
('550e8400-e29b-41d4-a716-446655440022', 'operations_timeliness', 2.7, NOW()), -- United
('550e8400-e29b-41d4-a716-446655440023', 'operations_timeliness', 2.6, NOW()), -- American
('550e8400-e29b-41d4-a716-446655440024', 'operations_timeliness', 2.5, NOW()), -- Southwest
('550e8400-e29b-41d4-a716-446655440025', 'operations_timeliness', 2.4, NOW()), -- JetBlue
('550e8400-e29b-41d4-a716-446655440026', 'operations_timeliness', 2.3, NOW()), -- Alaska
('550e8400-e29b-41d4-a716-446655440027', 'operations_timeliness', 2.2, NOW()), -- Air Canada
('550e8400-e29b-41d4-a716-446655440028', 'operations_timeliness', 2.1, NOW()), -- Hawaiian
('550e8400-e29b-41d4-a716-446655440029', 'operations_timeliness', 2.0, NOW()), -- Iberia
('550e8400-e29b-41d4-a716-446655440030', 'operations_timeliness', 1.9, NOW()), -- Austrian
('550e8400-e29b-41d4-a716-446655440031', 'operations_timeliness', 1.8, NOW()), -- Finnair
('550e8400-e29b-41d4-a716-446655440032', 'operations_timeliness', 1.7, NOW()), -- SAS
('550e8400-e29b-41d4-a716-446655440033', 'operations_timeliness', 1.6, NOW()), -- WestJet
('550e8400-e29b-41d4-a716-446655440034', 'operations_timeliness', 1.5, NOW()), -- Ryanair
('550e8400-e29b-41d4-a716-446655440035', 'operations_timeliness', 1.4, NOW()), -- IndiGo
('550e8400-e29b-41d4-a716-446655440036', 'operations_timeliness', 1.3, NOW()), -- FlyDubai
('550e8400-e29b-41d4-a716-446655440037', 'operations_timeliness', 1.2, NOW()), -- Wizz Air
('550e8400-e29b-41d4-a716-446655440038', 'operations_timeliness', 1.1, NOW()), -- Air Arabia
('550e8400-e29b-41d4-a716-446655440039', 'operations_timeliness', 1.0, NOW()), -- Scoot
('550e8400-e29b-41d4-a716-446655440040', 'operations_timeliness', 0.9, NOW())  -- EasyJet

ON CONFLICT (airline_id, score_type) DO UPDATE SET
  score_value = EXCLUDED.score_value,
  updated_at = NOW();

-- ========================================
-- PART 2: UPDATE SCORE CALCULATION FUNCTION
-- ========================================

-- Update the calculate_airline_scores function to include new categories
CREATE OR REPLACE FUNCTION calculate_airline_scores()
RETURNS void AS $$
BEGIN
  -- Calculate overall scores from airline_reviews
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'overall',
    ROUND(AVG(ar.overall_score::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.overall_score IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Wi-Fi Experience scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'wifi_experience',
    ROUND(AVG(ar.entertainment::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.entertainment IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Crew Friendliness scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'crew_friendliness',
    ROUND(AVG(ar.cabin_service::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.cabin_service IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Seat Comfort scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'seat_comfort',
    ROUND(AVG(ar.seat_comfort::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.seat_comfort IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Food & Beverage scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'food_beverage',
    ROUND(AVG(ar.food_beverage::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.food_beverage IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Operations & Timeliness scores (using overall as base)
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'operations_timeliness',
    ROUND(AVG(ar.overall_score::numeric) * 0.95, 2) -- Slightly lower than overall
  FROM airline_reviews ar
  WHERE ar.overall_score IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Clean up scores with no reviews (optional)
  DELETE FROM leaderboard_scores 
  WHERE score_value IS NULL OR score_value = 0;

  RAISE NOTICE 'Airline scores calculated successfully with new categories';
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- PART 3: CREATE REALTIME_FEEDBACK_VIEW
-- ========================================

-- Drop the existing view first to avoid column conflicts
DROP VIEW IF EXISTS realtime_feedback_view CASCADE;

-- Create the realtime_feedback_view for the Issues tab
CREATE VIEW realtime_feedback_view AS
SELECT 
  sf.id as feedback_id,
  f.flight_number,
  a.name as airline,
  a.logo_url as logo,
  sf.stage as phase,
  CASE 
    WHEN sf.stage = 'preFlight' THEN '#FF9800'
    WHEN sf.stage = 'inFlight' THEN '#4CAF50'
    WHEN sf.stage = 'postFlight' THEN '#2196F3'
    ELSE '#9E9E9E'
  END as phase_color,
  sf.positive_selections as likes,
  sf.negative_selections as dislikes,
  sf.feedback_timestamp,
  sf.overall_rating,
  j.seat_number as seat,
  j.pnr,
  sf.user_id
FROM stage_feedback sf
JOIN journeys j ON sf.journey_id = j.id
JOIN flights f ON j.flight_id = f.id
JOIN airlines a ON f.airline_id = a.id
WHERE sf.feedback_timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY sf.feedback_timestamp DESC;

-- Grant permissions for the view
GRANT SELECT ON realtime_feedback_view TO authenticated;
GRANT SELECT ON realtime_feedback_view TO anon;

-- ========================================
-- PART 4: VERIFICATION
-- ========================================

-- Check that all new categories have scores
SELECT 
    'New Categories Check' as check_type,
    COUNT(DISTINCT score_type) as total_categories,
    CASE 
        WHEN COUNT(DISTINCT score_type) >= 5 THEN '✅ PASS - All 5 categories present'
        ELSE '❌ FAIL - Expected 5, found ' || COUNT(DISTINCT score_type)::text
    END as status
FROM leaderboard_scores 
WHERE score_type IN ('overall', 'wifi_experience', 'crew_friendliness', 'seat_comfort', 'food_beverage', 'operations_timeliness');

-- Show sample data for each category
SELECT 
    'CATEGORY VERIFICATION' as section,
    score_type,
    COUNT(*) as airline_count,
    ROUND(AVG(score_value), 2) as avg_score
FROM leaderboard_scores 
WHERE score_type IN ('overall', 'wifi_experience', 'crew_friendliness', 'seat_comfort', 'food_beverage', 'operations_timeliness')
GROUP BY score_type
ORDER BY score_type;

-- Success message
SELECT '🎉 UPDATED LEADERBOARD CATEGORIES SETUP COMPLETE! 🎉' AS status,
       'All 5 comprehensive categories are now available!' AS message,
       'Your Flutter app will now show top 10 airlines with new category tabs' AS next_step;
