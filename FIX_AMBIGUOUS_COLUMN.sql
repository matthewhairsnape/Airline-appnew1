-- =====================================================
-- FIX: Column Ambiguity in update_leaderboard_score
-- =====================================================
-- This fixes the "column reference airline_id is ambiguous" error

-- Drop the old function
DROP FUNCTION IF EXISTS update_leaderboard_score(UUID, TEXT, NUMERIC, INTEGER, NUMERIC, NUMERIC, TEXT, INTEGER);

-- Create the corrected function with fully qualified column names
CREATE OR REPLACE FUNCTION update_leaderboard_score(
    p_airline_id UUID,
    p_score_type TEXT,
    p_score_value NUMERIC,
    p_review_count INTEGER DEFAULT 1,
    p_raw_score NUMERIC DEFAULT NULL,
    p_bayesian_score NUMERIC DEFAULT NULL,
    p_confidence_level TEXT DEFAULT NULL,
    p_phases_completed INTEGER DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    airline_id UUID,
    score_type TEXT,
    score_value NUMERIC,
    review_count INTEGER,
    updated_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO leaderboard_scores (
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
        COALESCE(p_bayesian_score, p_score_value),
        COALESCE(p_confidence_level, 'low'),
        COALESCE(p_phases_completed, 0),
        NOW()
    )
    ON CONFLICT (airline_id, score_type)
    DO UPDATE SET
        score_value = EXCLUDED.score_value,
        -- Use table name qualification to avoid ambiguity
        review_count = leaderboard_scores.review_count + EXCLUDED.review_count,
        raw_score = EXCLUDED.raw_score,
        bayesian_score = EXCLUDED.bayesian_score,
        confidence_level = EXCLUDED.confidence_level,
        phases_completed = EXCLUDED.phases_completed,
        updated_at = NOW()
    RETURNING 
        leaderboard_scores.id,
        leaderboard_scores.airline_id,
        leaderboard_scores.score_type,
        leaderboard_scores.score_value,
        leaderboard_scores.review_count,
        leaderboard_scores.updated_at;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_leaderboard_score TO authenticated;

-- Verify the function was created successfully
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    pg_get_function_identity_arguments(oid) as parameters
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';

-- Test the function with your actual airline ID
SELECT * FROM update_leaderboard_score(
    '2f41f1ae-7656-47b7-92e1-5e845364ad7f'::uuid,  -- Your airline ID from logs
    'test_score',
    5.0,
    1,
    5.0,
    4.9,
    'low',
    1
);

-- Clean up test data if needed
-- DELETE FROM leaderboard_scores WHERE score_type = 'test_score';

-- =====================================================
-- EXPLANATION OF THE FIX
-- =====================================================
-- The issue was in the ON CONFLICT clause:
--
-- BEFORE (ambiguous):
--   review_count = review_count + EXCLUDED.review_count
--   PostgreSQL couldn't tell if "review_count" meant:
--   - The parameter p_review_count
--   - The column leaderboard_scores.review_count
--
-- AFTER (explicit):
--   review_count = leaderboard_scores.review_count + EXCLUDED.review_count
--   Now it's clear: use the existing value from the table
--
-- The EXCLUDED keyword refers to the values from the INSERT that conflicted
-- =====================================================

-- Success indicator
SELECT '✅ Function updated successfully! Test submitting a review now.' as status;

