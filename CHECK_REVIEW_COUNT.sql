-- =====================================================
-- CHECK REVIEW COUNT STATUS
-- =====================================================
-- Run these queries to diagnose why review_count might be zero

-- =====================================================
-- 1. Check if the update_leaderboard_score function exists
-- =====================================================
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    pg_get_function_identity_arguments(oid) as parameters
FROM pg_proc 
WHERE proname = 'update_leaderboard_score';

-- Expected: Should return 1 row showing the function exists
-- If no rows: The function hasn't been created yet! Run FINAL_FIX_TO_RUN_NOW.sql


-- =====================================================
-- 2. Check current leaderboard_scores data
-- =====================================================
SELECT 
    ls.id,
    a.name as airline_name,
    a.iata_code,
    ls.score_type,
    ls.score_value,
    ls.review_count,  -- ⭐ This should increment with each review
    ls.updated_at
FROM leaderboard_scores ls
LEFT JOIN airlines a ON ls.airline_id = a.id
ORDER BY ls.updated_at DESC
LIMIT 20;

-- What to look for:
-- - review_count should be > 0 for airlines with reviews
-- - review_count should increment with each new review
-- - If all are 0, the function may not be working


-- =====================================================
-- 3. Check how many airline reviews exist
-- =====================================================
SELECT 
    a.name as airline_name,
    a.iata_code,
    COUNT(*) as total_reviews,
    AVG(CAST(ar.overall_score AS NUMERIC)) as avg_score
FROM airline_reviews ar
JOIN airlines a ON ar.airline_id = a.id
GROUP BY a.id, a.name, a.iata_code
ORDER BY total_reviews DESC;

-- This shows actual reviews vs leaderboard counts
-- Compare this with leaderboard_scores.review_count


-- =====================================================
-- 4. Check if reviews are being submitted but not counted
-- =====================================================
SELECT 
    a.name as airline_name,
    a.iata_code,
    (SELECT COUNT(*) FROM airline_reviews WHERE airline_id = a.id) as actual_reviews,
    COALESCE(
        (SELECT review_count FROM leaderboard_scores 
         WHERE airline_id = a.id AND score_type = 'overall' LIMIT 1), 
        0
    ) as leaderboard_count,
    CASE 
        WHEN (SELECT COUNT(*) FROM airline_reviews WHERE airline_id = a.id) > 
             COALESCE((SELECT review_count FROM leaderboard_scores 
                       WHERE airline_id = a.id AND score_type = 'overall' LIMIT 1), 0)
        THEN '❌ MISMATCH: Reviews not counted!'
        ELSE '✅ Counts match'
    END as status
FROM airlines a
WHERE EXISTS (SELECT 1 FROM airline_reviews WHERE airline_id = a.id)
ORDER BY actual_reviews DESC;

-- This compares actual reviews with leaderboard counts
-- If mismatched, reviews are being submitted but not counted


-- =====================================================
-- 5. Test the function manually (use your airline ID)
-- =====================================================
-- Replace with an actual airline_id from your database
-- This will add 1 to the review count for testing

-- First, get an airline ID:
SELECT id, name, iata_code FROM airlines LIMIT 5;

-- Then test the function (uncomment and replace the UUID):
-- SELECT * FROM update_leaderboard_score(
--     'YOUR-AIRLINE-ID-HERE'::uuid,
--     'test_manual',
--     4.5,
--     1,  -- This adds 1 to review_count
--     4.5,
--     4.5,
--     'medium',
--     1
-- );

-- Check if it worked:
-- SELECT * FROM leaderboard_scores WHERE score_type = 'test_manual';

-- Clean up test:
-- DELETE FROM leaderboard_scores WHERE score_type = 'test_manual';


-- =====================================================
-- 6. Check recent airline review submissions
-- =====================================================
SELECT 
    ar.created_at,
    ar.updated_at,
    u.email as user_email,
    a.name as airline_name,
    a.iata_code,
    ar.overall_score,
    j.pnr
FROM airline_reviews ar
JOIN airlines a ON ar.airline_id = a.id
LEFT JOIN auth.users u ON ar.user_id = u.id
LEFT JOIN journeys j ON ar.journey_id = j.id
ORDER BY ar.created_at DESC
LIMIT 10;

-- Shows recent review submissions
-- Compare timestamps with leaderboard_scores.updated_at


-- =====================================================
-- DIAGNOSIS SUMMARY
-- =====================================================
-- After running these queries, you should know:
-- 
-- ✅ Function exists? (Query 1)
-- ✅ Are there leaderboard scores? (Query 2)
-- ✅ Are reviews being submitted? (Query 3)
-- ✅ Do counts match? (Query 4)
-- ✅ Does manual test work? (Query 5)
-- ✅ Recent activity? (Query 6)
--
-- Common Issues:
-- 1. Function not created → Run FINAL_FIX_TO_RUN_NOW.sql
-- 2. RLS blocking updates → Function should bypass this
-- 3. Reviews submitted but not triggering function → Check app code
-- 4. Old reviews before function was created → Won't be counted retroactively

