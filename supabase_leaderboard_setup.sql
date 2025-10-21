-- Supabase Leaderboard Setup Script
-- This script sets up the complete leaderboard functionality with realtime updates
-- Run this in your Supabase SQL Editor

-- 1. Add UNIQUE constraint to leaderboard_scores table
ALTER TABLE leaderboard_scores 
ADD CONSTRAINT unique_airline_score_type 
UNIQUE (airline_id, score_type);

-- 2. Enable realtime for leaderboard_scores table
ALTER PUBLICATION supabase_realtime ADD TABLE leaderboard_scores;

-- 3. Create function to calculate airline scores from reviews
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
    ROUND(AVG(ar.entertainment::numeric), 2) -- Using entertainment as proxy for WiFi
  FROM airline_reviews ar
  WHERE ar.entertainment IS NOT NULL
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

  -- Calculate Food and Drink scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'food_drink',
    ROUND(AVG(ar.food_beverage::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.food_beverage IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Cabin Service scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'cabin_service',
    ROUND(AVG(ar.cabin_service::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.cabin_service IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Calculate Value for Money scores
  INSERT INTO leaderboard_scores (airline_id, score_type, score_value)
  SELECT 
    ar.airline_id,
    'value_for_money',
    ROUND(AVG(ar.value_for_money::numeric), 2)
  FROM airline_reviews ar
  WHERE ar.value_for_money IS NOT NULL
  GROUP BY ar.airline_id
  ON CONFLICT (airline_id, score_type) 
  DO UPDATE SET 
    score_value = EXCLUDED.score_value,
    updated_at = NOW();

  -- Clean up scores with no reviews (optional)
  DELETE FROM leaderboard_scores 
  WHERE score_value IS NULL OR score_value = 0;

  RAISE NOTICE 'Airline scores calculated successfully';
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger function that only broadcasts on score_value changes
CREATE OR REPLACE FUNCTION trigger_calculate_scores()
RETURNS TRIGGER AS $$
BEGIN
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
    
    -- Recalculate scores for the affected airline
    PERFORM calculate_airline_scores();
    
    RAISE NOTICE 'Scores recalculated for airline_id: %', COALESCE(NEW.airline_id, OLD.airline_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for airline_reviews table
DROP TRIGGER IF EXISTS airline_review_score_trigger ON airline_reviews;
CREATE TRIGGER airline_review_score_trigger
  AFTER INSERT OR UPDATE ON airline_reviews
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_scores();

-- 6. Create RLS policies for leaderboard_scores table
ALTER TABLE leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Allow public read access to leaderboard scores
CREATE POLICY "Allow public read access to leaderboard_scores" ON leaderboard_scores
  FOR SELECT USING (true);

-- Allow authenticated users to update scores (for admin purposes)
CREATE POLICY "Allow authenticated users to update leaderboard_scores" ON leaderboard_scores
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- 7. Add updated_at column if it doesn't exist
ALTER TABLE leaderboard_scores ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 8. Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_leaderboard_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_leaderboard_scores_updated_at ON leaderboard_scores;
CREATE TRIGGER update_leaderboard_scores_updated_at 
  BEFORE UPDATE ON leaderboard_scores
  FOR EACH ROW 
  EXECUTE FUNCTION update_leaderboard_updated_at();

-- 9. Create index for better performance
CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_airline_score 
ON leaderboard_scores(airline_id, score_type);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_value_desc 
ON leaderboard_scores(score_value DESC);

-- 10. Grant necessary permissions
GRANT EXECUTE ON FUNCTION calculate_airline_scores() TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_calculate_scores() TO authenticated;
GRANT EXECUTE ON FUNCTION update_leaderboard_updated_at() TO authenticated;

-- 11. Initial population of scores (run this to populate existing data)
-- Uncomment the line below to calculate scores for existing reviews
-- SELECT calculate_airline_scores();

-- Success message
SELECT 'Leaderboard setup completed successfully! Run SELECT calculate_airline_scores(); to populate initial data.' AS result;
