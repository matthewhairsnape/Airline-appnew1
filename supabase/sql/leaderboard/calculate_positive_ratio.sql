-- ===================================================================================
-- Calculate Positive Ratio Function
-- -----------------------------------------------------------------------------------
-- This function calculates the positive_ratio for leaderboard rankings using the
-- formula: Positive Votes / (Positive + Negative Votes)
--
-- Formula: positive_ratio = (positive_count / (positive_count + negative_count)) * 100
-- Returns a percentage value (0-100)
-- ===================================================================================

CREATE OR REPLACE FUNCTION public.calculate_positive_ratio(
  p_positive_count INTEGER,
  p_negative_count INTEGER
) RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_total INTEGER;
  v_ratio NUMERIC(5,2);
BEGIN
  -- Handle edge cases
  IF p_positive_count IS NULL THEN
    p_positive_count := 0;
  END IF;
  
  IF p_negative_count IS NULL THEN
    p_negative_count := 0;
  END IF;
  
  -- Calculate total votes
  v_total := p_positive_count + p_negative_count;
  
  -- If no votes, return NULL (or 0 if preferred)
  IF v_total = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Calculate ratio: Positive Votes / (Positive + Negative Votes) * 100
  v_ratio := (p_positive_count::NUMERIC / v_total::NUMERIC) * 100.0;
  
  -- Round to 2 decimal places
  RETURN ROUND(v_ratio, 2);
END;
$$;

COMMENT ON FUNCTION public.calculate_positive_ratio IS 
'Calculates positive ratio percentage using formula: Positive Votes / (Positive + Negative Votes) * 100';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.calculate_positive_ratio(INTEGER, INTEGER) TO authenticated, anon, service_role;

-- ===================================================================================
-- Trigger to auto-calculate positive_ratio when positive_count or negative_count changes
-- ===================================================================================

CREATE OR REPLACE FUNCTION public.update_leaderboard_positive_ratio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Auto-calculate positive_ratio if positive_count or negative_count is provided
  IF NEW.positive_count IS NOT NULL OR NEW.negative_count IS NOT NULL THEN
    NEW.positive_ratio := public.calculate_positive_ratio(
      COALESCE(NEW.positive_count, 0),
      COALESCE(NEW.negative_count, 0)
    );
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.update_leaderboard_positive_ratio IS 
'Trigger function to automatically calculate positive_ratio when positive_count or negative_count is updated';

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_update_leaderboard_positive_ratio ON public.leaderboard_rankings;

-- Create trigger
CREATE TRIGGER trg_update_leaderboard_positive_ratio
BEFORE INSERT OR UPDATE ON public.leaderboard_rankings
FOR EACH ROW
WHEN (NEW.positive_count IS NOT NULL OR NEW.negative_count IS NOT NULL)
EXECUTE FUNCTION public.update_leaderboard_positive_ratio();

-- ===================================================================================
-- Example Usage:
-- ===================================================================================
-- SELECT public.calculate_positive_ratio(75, 25);  -- Returns 75.00 (75%)
-- SELECT public.calculate_positive_ratio(100, 0); -- Returns 100.00 (100%)
-- SELECT public.calculate_positive_ratio(0, 50);  -- Returns 0.00 (0%)
-- SELECT public.calculate_positive_ratio(0, 0);   -- Returns NULL (no votes)

