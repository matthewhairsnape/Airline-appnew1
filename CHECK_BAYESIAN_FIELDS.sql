-- =====================================================
-- CHECK WHY BAYESIAN FIELDS ARE EMPTY
-- =====================================================
-- Diagnostic queries to check raw_score, bayesian_score, confidence_level

-- =====================================================
-- 1. Check current leaderboard_scores with all fields
-- =====================================================
SELECT 
    ls.id,
    a.name as airline_name,
    a.iata_code,
    ls.score_type,
    ls.score_value,
    ls.review_count,
    ls.raw_score,           -- ⭐ Check if this is NULL or empty
    ls.bayesian_score,      -- ⭐ Check if this is NULL or empty
    ls.confidence_level,    -- ⭐ Check if this is NULL or empty
    ls.phases_completed,
    ls.updated_at
FROM leaderboard_scores ls
LEFT JOIN airlines a ON ls.airline_id = a.id
ORDER BY ls.updated_at DESC
LIMIT 20;

-- What to look for:
-- If raw_score, bayesian_score, confidence_level are NULL → Function not working correctly
-- If they have values → Function is working! ✅


-- =====================================================
-- 2. Check data types of these columns
-- =====================================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'leaderboard_scores'
AND column_name IN ('raw_score', 'bayesian_score', 'confidence_level', 'review_count')
ORDER BY ordinal_position;

-- Expected:
-- raw_score: numeric(3,2), nullable
-- bayesian_score: numeric(3,2), nullable
-- confidence_level: text, nullable
-- review_count: integer, default 0


-- =====================================================
-- 3. Check function definition
-- =====================================================
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as parameters,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';

-- This shows the complete function definition
-- Check if it includes raw_score, bayesian_score, confidence_level in INSERT and UPDATE


-- =====================================================
-- 4. Test the function manually with all fields
-- =====================================================
-- Get an airline ID first
SELECT id, name, iata_code FROM airlines LIMIT 5;

-- Test with explicit values (uncomment and replace airline_id):
/*
SELECT * FROM update_leaderboard_score(
    'YOUR-AIRLINE-ID-HERE'::uuid,
    'test_bayesian',
    4.5,           -- p_score_value
    1,             -- p_review_count
    4.5,           -- p_raw_score ⭐
    4.3,           -- p_bayesian_score ⭐
    'medium',      -- p_confidence_level ⭐
    1              -- p_phases_completed
);
*/

-- Check if the values were stored:
/*
SELECT 
    score_type,
    score_value,
    review_count,
    raw_score,          -- Should be 4.5
    bayesian_score,     -- Should be 4.3
    confidence_level    -- Should be 'medium'
FROM leaderboard_scores 
WHERE score_type = 'test_bayesian';
*/

-- Clean up test:
-- DELETE FROM leaderboard_scores WHERE score_type = 'test_bayesian';


-- =====================================================
-- 5. Check if old records are missing these values
-- =====================================================
SELECT 
    COUNT(*) as total_records,
    COUNT(raw_score) as records_with_raw_score,
    COUNT(bayesian_score) as records_with_bayesian_score,
    COUNT(confidence_level) as records_with_confidence_level,
    COUNT(*) - COUNT(raw_score) as missing_raw_score,
    COUNT(*) - COUNT(bayesian_score) as missing_bayesian_score,
    COUNT(*) - COUNT(confidence_level) as missing_confidence_level
FROM leaderboard_scores;

-- This shows how many records have these fields populated vs empty


-- =====================================================
-- 6. Check recent vs old records
-- =====================================================
SELECT 
    DATE(updated_at) as date,
    COUNT(*) as total_records,
    COUNT(raw_score) as with_raw_score,
    COUNT(bayesian_score) as with_bayesian_score,
    COUNT(confidence_level) as with_confidence_level
FROM leaderboard_scores
GROUP BY DATE(updated_at)
ORDER BY date DESC;

-- This shows if newer records have the fields populated


-- =====================================================
-- 7. Sample of records with and without these fields
-- =====================================================
-- Records WITH these fields
SELECT 
    'WITH FIELDS' as status,
    a.name,
    ls.score_type,
    ls.raw_score,
    ls.bayesian_score,
    ls.confidence_level,
    ls.updated_at
FROM leaderboard_scores ls
LEFT JOIN airlines a ON ls.airline_id = a.id
WHERE ls.raw_score IS NOT NULL
ORDER BY ls.updated_at DESC
LIMIT 5;

-- Records WITHOUT these fields
SELECT 
    'WITHOUT FIELDS' as status,
    a.name,
    ls.score_type,
    ls.raw_score,
    ls.bayesian_score,
    ls.confidence_level,
    ls.updated_at
FROM leaderboard_scores ls
LEFT JOIN airlines a ON ls.airline_id = a.id
WHERE ls.raw_score IS NULL
ORDER BY ls.updated_at DESC
LIMIT 5;


-- =====================================================
-- 8. SOLUTION: Update old records with calculated values
-- =====================================================
-- If you have old records without these fields, you can backfill them:

-- Preview what would be updated:
SELECT 
    id,
    airline_id,
    score_type,
    score_value,
    raw_score,          -- Currently NULL
    bayesian_score,     -- Currently NULL
    confidence_level,   -- Currently NULL
    -- What they should be:
    score_value as new_raw_score,                                    -- Use score_value as raw_score
    (1.0 / 31.0) * score_value + (30.0 / 31.0) * 3.5 as new_bayesian_score,  -- Calculate Bayesian
    CASE 
        WHEN review_count >= 50 THEN 'high'
        WHEN review_count >= 20 THEN 'medium'
        ELSE 'low'
    END as new_confidence_level
FROM leaderboard_scores
WHERE raw_score IS NULL OR bayesian_score IS NULL OR confidence_level IS NULL;

-- To actually update them (uncomment to run):
/*
UPDATE leaderboard_scores
SET 
    raw_score = score_value,
    bayesian_score = (1.0 / 31.0) * score_value + (30.0 / 31.0) * 3.5,
    confidence_level = CASE 
        WHEN review_count >= 50 THEN 'high'
        WHEN review_count >= 20 THEN 'medium'
        ELSE 'low'
    END
WHERE raw_score IS NULL OR bayesian_score IS NULL OR confidence_level IS NULL;
*/


-- =====================================================
-- DIAGNOSIS SUMMARY
-- =====================================================
-- After running these queries, you should know:
-- 
-- ✅ Are the fields NULL or just not visible? (Query 1)
-- ✅ Are the column types correct? (Query 2)
-- ✅ Does the function include these fields? (Query 3)
-- ✅ Does manual test work? (Query 4)
-- ✅ How many records are missing these fields? (Query 5)
-- ✅ Are new records better than old ones? (Query 6)
-- ✅ Can you see examples of both? (Query 7)
-- ✅ Can you backfill old records? (Query 8)
--
-- Common Issues:
-- 1. Old records created before fix → Backfill with Query 8
-- 2. Function not storing values → Recreate function
-- 3. Columns don't exist → Add columns to table
-- 4. App not passing values → Check Flutter code (already correct)

