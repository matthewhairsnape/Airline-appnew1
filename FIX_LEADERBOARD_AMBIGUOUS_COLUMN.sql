-- ==========================================
-- Fix for Ambiguous Column Reference Error
-- ==========================================
-- Error: "column reference 'airline_id' is ambiguous"
-- Root Cause: Column names in WHERE clause match parameter names
-- Solution: Use table-qualified column names

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.update_leaderboard_score(
  uuid, text, numeric, integer, numeric, numeric, text, integer
);

-- Create corrected function with table-qualified column names
CREATE OR REPLACE FUNCTION public.update_leaderboard_score(
  p_airline_id UUID,
  p_score_type TEXT,
  p_score_value NUMERIC,
  p_review_count INTEGER DEFAULT 1,
  p_raw_score NUMERIC DEFAULT NULL,
  p_bayesian_score NUMERIC DEFAULT NULL,
  p_confidence_level TEXT DEFAULT 'low',
  p_phases_completed INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  airline_id UUID,
  score_type TEXT,
  score_value NUMERIC,
  review_count INTEGER,
  raw_score NUMERIC,
  bayesian_score NUMERIC,
  confidence_level TEXT,
  phases_completed INTEGER,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_count INTEGER;
  v_existing_score NUMERIC;
  v_new_count INTEGER;
  v_new_score NUMERIC;
  v_new_bayesian NUMERIC;
  v_new_confidence TEXT;
BEGIN
  -- Check if record exists
  -- ✅ FIX: Use table-qualified column names (leaderboard_scores.airline_id)
  SELECT 
    leaderboard_scores.review_count, 
    leaderboard_scores.score_value
  INTO v_existing_count, v_existing_score
  FROM public.leaderboard_scores
  WHERE leaderboard_scores.airline_id = p_airline_id
    AND leaderboard_scores.score_type = p_score_type;

  IF FOUND THEN
    -- Update existing record
    v_new_count := v_existing_count + p_review_count;
    
    -- Calculate weighted average for score_value
    v_new_score := (
      (v_existing_score * v_existing_count) + (p_score_value * p_review_count)
    ) / v_new_count;

    -- Calculate Bayesian score if not provided
    IF p_bayesian_score IS NULL THEN
      -- Bayesian average formula: (C * m + n * x) / (C + n)
      -- C = confidence parameter (30), m = prior mean (3.5)
      v_new_bayesian := (30.0 * 3.5 + v_new_count * v_new_score) / (30.0 + v_new_count);
    ELSE
      v_new_bayesian := p_bayesian_score;
    END IF;

    -- Determine confidence level based on review count
    IF v_new_count >= 100 THEN
      v_new_confidence := 'high';
    ELSIF v_new_count >= 30 THEN
      v_new_confidence := 'medium';
    ELSE
      v_new_confidence := 'low';
    END IF;

    -- ✅ FIX: Use table-qualified column names in UPDATE
    RETURN QUERY
    UPDATE public.leaderboard_scores
    SET 
      score_value = v_new_score,
      review_count = v_new_count,
      raw_score = COALESCE(p_raw_score, v_new_score),
      bayesian_score = v_new_bayesian,
      confidence_level = v_new_confidence,
      phases_completed = GREATEST(leaderboard_scores.phases_completed, p_phases_completed),
      updated_at = NOW()
    WHERE leaderboard_scores.airline_id = p_airline_id
      AND leaderboard_scores.score_type = p_score_type
    RETURNING 
      leaderboard_scores.id,
      leaderboard_scores.airline_id,
      leaderboard_scores.score_type,
      leaderboard_scores.score_value,
      leaderboard_scores.review_count,
      leaderboard_scores.raw_score,
      leaderboard_scores.bayesian_score,
      leaderboard_scores.confidence_level,
      leaderboard_scores.phases_completed,
      leaderboard_scores.updated_at;
  ELSE
    -- Insert new record
    v_new_bayesian := COALESCE(p_bayesian_score, (1.0 * p_score_value + 30.0 * 3.5) / 31.0);

    RETURN QUERY
    INSERT INTO public.leaderboard_scores (
      airline_id,
      score_type,
      score_value,
      review_count,
      raw_score,
      bayesian_score,
      confidence_level,
      phases_completed,
      updated_at
    ) VALUES (
      p_airline_id,
      p_score_type,
      p_score_value,
      p_review_count,
      COALESCE(p_raw_score, p_score_value),
      v_new_bayesian,
      p_confidence_level,
      p_phases_completed,
      NOW()
    )
    RETURNING 
      leaderboard_scores.id,
      leaderboard_scores.airline_id,
      leaderboard_scores.score_type,
      leaderboard_scores.score_value,
      leaderboard_scores.review_count,
      leaderboard_scores.raw_score,
      leaderboard_scores.bayesian_score,
      leaderboard_scores.confidence_level,
      leaderboard_scores.phases_completed,
      leaderboard_scores.updated_at;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.update_leaderboard_score(
  UUID, TEXT, NUMERIC, INTEGER, NUMERIC, NUMERIC, TEXT, INTEGER
) TO authenticated, anon;

-- Add helpful comment
COMMENT ON FUNCTION public.update_leaderboard_score IS 
'Updates or inserts leaderboard scores for an airline. Automatically calculates weighted averages and Bayesian scores. Fixed: ambiguous column references by using table-qualified names.';

-- ==========================================
-- Verification Query
-- ==========================================
-- Run this to test the function:
/*
SELECT * FROM public.update_leaderboard_score(
  p_airline_id := 'ad820640-c2e6-4558-a57d-ae04dbc1b6c2'::UUID,
  p_score_type := 'overall',
  p_score_value := 4.5,
  p_review_count := 1,
  p_raw_score := 4.5,
  p_bayesian_score := 4.2,
  p_confidence_level := 'low',
  p_phases_completed := 1
);
*/

-- ==========================================
-- Summary
-- ==========================================
-- This function now uses table-qualified column names throughout:
-- ✅ leaderboard_scores.airline_id instead of just airline_id
-- ✅ leaderboard_scores.score_type instead of just score_type
-- ✅ This eliminates ambiguity between parameters and table columns
-- ✅ PostgreSQL can now clearly distinguish between p_airline_id (parameter) and leaderboard_scores.airline_id (column)

