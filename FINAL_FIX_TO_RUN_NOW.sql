-- =====================================================
-- FINAL FIX - RUN THIS NOW IN SUPABASE SQL EDITOR
-- =====================================================
-- This fixes both the leaderboard issue and enables airline logos

-- =====================================================
-- STEP 1: Create Leaderboard Update Function
-- =====================================================
-- This function bypasses RLS and handles score updates

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
SECURITY DEFINER  -- This makes the function run with the privileges of the creator
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
        -- Explicitly qualify table name to avoid ambiguity with parameters
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_leaderboard_score TO authenticated;

-- Verify function was created
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    proargnames as parameter_names
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';

-- Test the function (uncomment to test with your airline ID)
-- SELECT * FROM update_leaderboard_score(
--     'b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7'::uuid,
--     'overall',
--     4.5,
--     1,
--     4.5,
--     4.5,
--     'low',
--     1
-- );


-- =====================================================
-- STEP 2: Verify Airlines Table Has logo_url Column
-- =====================================================
-- Check if logo_url column exists
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'airlines'
AND column_name = 'logo_url';
-- Should return 1 row showing: logo_url, text, YES


-- =====================================================
-- STEP 3: Add RLS Policies for Leaderboard (Optional)
-- =====================================================
-- These allow direct access if needed (though we're using the function)

DROP POLICY IF EXISTS "Anyone can view leaderboard scores" ON leaderboard_scores;
CREATE POLICY "Anyone can view leaderboard scores"
ON leaderboard_scores FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert leaderboard scores" ON leaderboard_scores;
CREATE POLICY "Authenticated users can insert leaderboard scores"
ON leaderboard_scores FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update leaderboard scores" ON leaderboard_scores;
CREATE POLICY "Authenticated users can update leaderboard scores"
ON leaderboard_scores FOR UPDATE
USING (auth.uid() IS NOT NULL)
WITH CHECK (auth.uid() IS NOT NULL);


-- =====================================================
-- VERIFICATION - Run These to Confirm Everything Works
-- =====================================================

-- 1. Check function exists
SELECT COUNT(*) as function_exists 
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';
-- Should return: 1

-- 2. Check RLS policies
SELECT COUNT(*) as policy_count 
FROM pg_policies 
WHERE tablename = 'leaderboard_scores';
-- Should return: 3

-- 3. Check airlines table structure
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'airlines'
ORDER BY ordinal_position;
-- Should show: id, name, logo_url, iata_code, etc.

-- 4. Test leaderboard function with your data
SELECT * FROM update_leaderboard_score(
    'b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7'::uuid,
    'test_score',
    5.0,
    1,
    5.0,
    4.9,
    'low',
    1
);
-- Should return 1 row with the inserted/updated score


-- =====================================================
-- SUCCESS INDICATORS
-- =====================================================
-- After running this file:
-- ✅ Function update_leaderboard_score exists
-- ✅ Function has SECURITY DEFINER privilege
-- ✅ Function is granted to authenticated users
-- ✅ RLS policies allow proper access
-- ✅ Airlines table ready for logo_url
-- ✅ Test query succeeds

-- Now test in your app:
-- 1. Submit a flight review
-- 2. Check console - should show:
--    ✅ Updated leaderboard_scores: overall = 4.5 (1 reviews)
--    ✅ Airline review submitted successfully
-- 3. No more "function not found" errors!

