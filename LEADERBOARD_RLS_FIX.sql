-- =====================================================
-- LEADERBOARD SCORES RLS POLICY FIX
-- =====================================================
-- Fix for: "new row violates row-level security policy for table leaderboard_scores"

-- =====================================================
-- Step 1: Check Current RLS Status
-- =====================================================
-- Check if RLS is enabled on leaderboard_scores
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'leaderboard_scores';

-- Check existing policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'leaderboard_scores';

-- =====================================================
-- Step 2: CREATE REQUIRED RLS POLICIES
-- =====================================================

-- Policy 1: Allow SELECT for all authenticated users
DROP POLICY IF EXISTS "Anyone can view leaderboard scores" ON leaderboard_scores;

CREATE POLICY "Anyone can view leaderboard scores"
ON leaderboard_scores
FOR SELECT
USING (true);  -- Everyone can read leaderboard scores


-- Policy 2: Allow INSERT for authenticated users (when submitting reviews)
DROP POLICY IF EXISTS "Authenticated users can insert leaderboard scores" ON leaderboard_scores;

CREATE POLICY "Authenticated users can insert leaderboard scores"
ON leaderboard_scores
FOR INSERT
WITH CHECK (
    auth.uid() IS NOT NULL  -- User must be authenticated
);


-- Policy 3: Allow UPDATE for authenticated users
DROP POLICY IF EXISTS "Authenticated users can update leaderboard scores" ON leaderboard_scores;

CREATE POLICY "Authenticated users can update leaderboard scores"
ON leaderboard_scores
FOR UPDATE
USING (auth.uid() IS NOT NULL)  -- User must be authenticated
WITH CHECK (auth.uid() IS NOT NULL);


-- Policy 4: Allow DELETE for authenticated users (if needed)
DROP POLICY IF EXISTS "Authenticated users can delete leaderboard scores" ON leaderboard_scores;

CREATE POLICY "Authenticated users can delete leaderboard scores"
ON leaderboard_scores
FOR DELETE
USING (auth.uid() IS NOT NULL);  -- User must be authenticated


-- =====================================================
-- Step 3: Verify Policies Were Created
-- =====================================================
SELECT 
    policyname,
    cmd as operation,
    CASE 
        WHEN qual = 'true' THEN 'All rows'
        WHEN qual LIKE '%auth.uid()%' THEN 'Authenticated users only'
        ELSE qual
    END as who_can_access
FROM pg_policies
WHERE tablename = 'leaderboard_scores'
ORDER BY cmd;


-- =====================================================
-- Step 4: Test INSERT (Verify It Works)
-- =====================================================
-- This should now work without RLS errors
-- Replace with actual values from your review submission
/*
INSERT INTO leaderboard_scores (
    airline_id,
    score_type,
    score_value,
    review_count,
    raw_score,
    bayesian_score,
    confidence_level,
    phases_completed
) VALUES (
    'b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7',  -- Your airline_id
    'overall',
    4.5,
    1,
    4.5,
    4.5,
    'low',
    1
)
ON CONFLICT (airline_id, score_type) 
DO UPDATE SET
    score_value = EXCLUDED.score_value,
    review_count = leaderboard_scores.review_count + 1,
    raw_score = EXCLUDED.raw_score,
    bayesian_score = EXCLUDED.bayesian_score,
    confidence_level = EXCLUDED.confidence_level,
    phases_completed = EXCLUDED.phases_completed,
    updated_at = NOW()
RETURNING *;
*/


-- =====================================================
-- ALTERNATIVE: More Restrictive Policies (Optional)
-- =====================================================
-- If you want more control, use these instead:

/*
-- Only allow INSERT/UPDATE through authenticated users who own a journey
DROP POLICY IF EXISTS "Users can manage scores for their reviewed airlines" ON leaderboard_scores;

CREATE POLICY "Users can manage scores for their reviewed airlines"
ON leaderboard_scores
FOR ALL
USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM feedback f
        JOIN journeys j ON f.journey_id = j.id
        WHERE j.passenger_id::text = auth.uid()::text
        AND f.airline_id = leaderboard_scores.airline_id
    )
)
WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM feedback f
        JOIN journeys j ON f.journey_id = j.id
        WHERE j.passenger_id::text = auth.uid()::text
        AND f.airline_id = leaderboard_scores.airline_id
    )
);
*/


-- =====================================================
-- QUICK TEST: Check If Policies Allow Operations
-- =====================================================

-- Test 1: Can you SELECT?
SELECT COUNT(*) as total_scores FROM leaderboard_scores;

-- Test 2: Check specific airline scores
SELECT * FROM leaderboard_scores 
WHERE airline_id = 'b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7';

-- Test 3: Try UPSERT (this simulates what your app does)
-- Uncomment and modify with actual values to test
/*
INSERT INTO leaderboard_scores (airline_id, score_type, score_value, review_count)
VALUES ('b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7', 'test_score', 5.0, 1)
ON CONFLICT (airline_id, score_type) 
DO UPDATE SET score_value = EXCLUDED.score_value
RETURNING *;
*/


-- =====================================================
-- ROLLBACK OPTIONS (If something goes wrong)
-- =====================================================

-- Remove all policies (start fresh)
/*
DROP POLICY IF EXISTS "Anyone can view leaderboard scores" ON leaderboard_scores;
DROP POLICY IF EXISTS "Authenticated users can insert leaderboard scores" ON leaderboard_scores;
DROP POLICY IF EXISTS "Authenticated users can update leaderboard scores" ON leaderboard_scores;
DROP POLICY IF EXISTS "Authenticated users can delete leaderboard scores" ON leaderboard_scores;
*/

-- Disable RLS entirely (NOT RECOMMENDED FOR PRODUCTION)
/*
ALTER TABLE leaderboard_scores DISABLE ROW LEVEL SECURITY;
*/

-- Re-enable RLS
/*
ALTER TABLE leaderboard_scores ENABLE ROW LEVEL SECURITY;
*/


-- =====================================================
-- RECOMMENDED: Service Role Function for Leaderboard Updates
-- =====================================================
-- This is the BEST approach - create a function that bypasses RLS
-- Your app calls this function instead of direct INSERT/UPDATE

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

-- Test the function
-- SELECT * FROM update_leaderboard_score(
--     'b5a55dcc-f64a-45e2-96d7-4f04a7d3f1b7',
--     'overall',
--     4.5,
--     1,
--     4.5,
--     4.5,
--     'low',
--     1
-- );


-- =====================================================
-- VERIFICATION CHECKLIST
-- =====================================================
-- Run these to verify everything is working:

-- 1. Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'leaderboard_scores';
-- Should show: rowsecurity = true

-- 2. Check policies exist
SELECT COUNT(*) as policy_count 
FROM pg_policies 
WHERE tablename = 'leaderboard_scores';
-- Should show: at least 4 policies

-- 3. Check function exists
SELECT proname, prosecdef 
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';
-- Should show: update_leaderboard_score with prosecdef = true

-- 4. Test actual operation (modify with your data)
-- SELECT * FROM update_leaderboard_score(...);


-- =====================================================
-- SUMMARY
-- =====================================================
-- Option 1 (Recommended): Use the update_leaderboard_score() function
--   - Bypasses RLS safely
--   - Handles UPSERT logic
--   - Clean and secure
--
-- Option 2: Use RLS policies created above
--   - Allows direct INSERT/UPDATE
--   - Requires authenticated user
--   - Standard approach
--
-- Both options will fix your RLS error!

