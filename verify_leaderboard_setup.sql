-- Verification Script for Top 40 Airlines Leaderboard Setup
-- Run this after executing both setup scripts to verify everything is working

-- 1. Check that all 40 airlines are in the airlines table
SELECT 
    'Airlines Table Check' as check_type,
    COUNT(*) as total_airlines,
    CASE 
        WHEN COUNT(*) = 40 THEN '✅ PASS - All 40 airlines present'
        ELSE '❌ FAIL - Expected 40, found ' || COUNT(*)::text
    END as status
FROM airlines
WHERE id LIKE '550e8400-e29b-41d4-a716-4466554400%';

-- 2. Check that all airlines have overall scores
SELECT 
    'Overall Scores Check' as check_type,
    COUNT(*) as airlines_with_overall_scores,
    CASE 
        WHEN COUNT(*) = 40 THEN '✅ PASS - All airlines have overall scores'
        ELSE '❌ FAIL - Expected 40, found ' || COUNT(*)::text
    END as status
FROM leaderboard_scores 
WHERE score_type = 'overall' 
AND airline_id LIKE '550e8400-e29b-41d4-a716-4466554400%';

-- 3. Check that all airlines have Wi-Fi experience scores
SELECT 
    'Wi-Fi Scores Check' as check_type,
    COUNT(*) as airlines_with_wifi_scores,
    CASE 
        WHEN COUNT(*) = 40 THEN '✅ PASS - All airlines have Wi-Fi scores'
        ELSE '❌ FAIL - Expected 40, found ' || COUNT(*)::text
    END as status
FROM leaderboard_scores 
WHERE score_type = 'wifi_experience' 
AND airline_id LIKE '550e8400-e29b-41d4-a716-4466554400%';

-- 4. Check that all airlines have seat comfort scores
SELECT 
    'Seat Comfort Scores Check' as check_type,
    COUNT(*) as airlines_with_seat_scores,
    CASE 
        WHEN COUNT(*) = 40 THEN '✅ PASS - All airlines have seat comfort scores'
        ELSE '❌ FAIL - Expected 40, found ' || COUNT(*)::text
    END as status
FROM leaderboard_scores 
WHERE score_type = 'seat_comfort' 
AND airline_id LIKE '550e8400-e29b-41d4-a716-4466554400%';

-- 5. Check that all airlines have food and drink scores
SELECT 
    'Food & Drink Scores Check' as check_type,
    COUNT(*) as airlines_with_food_scores,
    CASE 
        WHEN COUNT(*) = 40 THEN '✅ PASS - All airlines have food & drink scores'
        ELSE '❌ FAIL - Expected 40, found ' || COUNT(*)::text
    END as status
FROM leaderboard_scores 
WHERE score_type = 'food_drink' 
AND airline_id LIKE '550e8400-e29b-41d4-a716-4466554400%';

-- 6. Check score ranges (should be realistic)
SELECT 
    'Score Range Check' as check_type,
    MIN(score_value) as min_score,
    MAX(score_value) as max_score,
    CASE 
        WHEN MIN(score_value) >= 0.8 AND MAX(score_value) <= 5.0 THEN '✅ PASS - Scores in realistic range'
        ELSE '❌ FAIL - Scores outside expected range'
    END as status
FROM leaderboard_scores 
WHERE score_type = 'overall';

-- 7. Show top 10 airlines by overall score
SELECT 
    'TOP 10 AIRLINES BY OVERALL SCORE' as section,
    '' as airline_name,
    '' as iata_code,
    '' as score,
    '' as country
UNION ALL
SELECT 
    'Rank ' || ROW_NUMBER() OVER (ORDER BY ls.score_value DESC)::text,
    a.name,
    a.iata_code,
    ls.score_value::text,
    a.country
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
WHERE ls.score_type = 'overall'
ORDER BY ls.score_value DESC
LIMIT 10;

-- 8. Show top 10 airlines by Wi-Fi experience
SELECT 
    'TOP 10 AIRLINES BY WI-FI EXPERIENCE' as section,
    '' as airline_name,
    '' as iata_code,
    '' as score,
    '' as country
UNION ALL
SELECT 
    'Rank ' || ROW_NUMBER() OVER (ORDER BY ls.score_value DESC)::text,
    a.name,
    a.iata_code,
    ls.score_value::text,
    a.country
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
WHERE ls.score_type = 'wifi_experience'
ORDER BY ls.score_value DESC
LIMIT 10;

-- 9. Show top 10 airlines by seat comfort
SELECT 
    'TOP 10 AIRLINES BY SEAT COMFORT' as section,
    '' as airline_name,
    '' as iata_code,
    '' as score,
    '' as country
UNION ALL
SELECT 
    'Rank ' || ROW_NUMBER() OVER (ORDER BY ls.score_value DESC)::text,
    a.name,
    a.iata_code,
    ls.score_value::text,
    a.country
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
WHERE ls.score_type = 'seat_comfort'
ORDER BY ls.score_value DESC
LIMIT 10;

-- 10. Show top 10 airlines by food and drink
SELECT 
    'TOP 10 AIRLINES BY FOOD & DRINK' as section,
    '' as airline_name,
    '' as iata_code,
    '' as score,
    '' as country
UNION ALL
SELECT 
    'Rank ' || ROW_NUMBER() OVER (ORDER BY ls.score_value DESC)::text,
    a.name,
    a.iata_code,
    ls.score_value::text,
    a.country
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
WHERE ls.score_type = 'food_drink'
ORDER BY ls.score_value DESC
LIMIT 10;

-- 11. Check if realtime is enabled
SELECT 
    'Realtime Check' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND tablename = 'leaderboard_scores'
        ) THEN '✅ PASS - Realtime enabled for leaderboard_scores'
        ELSE '❌ FAIL - Realtime not enabled for leaderboard_scores'
    END as status;

-- 12. Check if triggers are working
SELECT 
    'Trigger Check' as check_type,
    COUNT(*) as active_triggers,
    CASE 
        WHEN COUNT(*) >= 1 THEN '✅ PASS - Triggers are active'
        ELSE '❌ FAIL - No triggers found'
    END as status
FROM information_schema.triggers 
WHERE event_object_table = 'airline_reviews'
AND trigger_name LIKE '%score%';

-- 13. Final summary
SELECT 
    'SETUP COMPLETE' as message,
    'Top 40 airlines leaderboard is ready!' as description,
    'Run your Flutter app to see the realtime leaderboard' as next_step;
