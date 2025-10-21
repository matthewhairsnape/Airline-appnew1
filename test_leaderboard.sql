-- Test script to verify leaderboard functionality
-- Run this after executing the main setup script

-- 1. Check if leaderboard_scores table has the correct structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'leaderboard_scores' 
ORDER BY ordinal_position;

-- 2. Check if triggers are created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'airline_reviews'
AND trigger_name LIKE '%score%';

-- 3. Check if functions are created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN ('calculate_airline_scores', 'trigger_calculate_scores');

-- 4. Check RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'leaderboard_scores';

-- 5. Check if realtime is enabled
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'leaderboard_scores';

-- 6. Test the score calculation function (only if you have airline review data)
-- SELECT calculate_airline_scores();

-- 7. Check current leaderboard data (after running calculate_airline_scores)
SELECT 
    ls.airline_id,
    a.name as airline_name,
    ls.score_type,
    ls.score_value,
    ls.updated_at
FROM leaderboard_scores ls
JOIN airlines a ON ls.airline_id = a.id
ORDER BY ls.score_type, ls.score_value DESC
LIMIT 20;

-- 8. Check if there are any airline reviews to calculate scores from
SELECT 
    COUNT(*) as total_reviews,
    COUNT(DISTINCT airline_id) as airlines_with_reviews,
    AVG(overall_score) as average_overall_score
FROM airline_reviews;
