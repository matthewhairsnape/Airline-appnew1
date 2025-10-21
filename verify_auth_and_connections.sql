-- ================================================
-- VERIFICATION SCRIPT FOR AUTHENTICATION & CONNECTIONS
-- ================================================
-- Run this in your Supabase SQL Editor to verify all connections

-- ================================================
-- 1. CHECK USER AUTHENTICATION SETUP
-- ================================================
SELECT '=== USER AUTHENTICATION SETUP ===' as check_type;

-- Check if users table exists and has correct columns
SELECT 
  'Users Table Structure' as check_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check RLS is enabled on users table
SELECT 
  'Users Table RLS Status' as check_name,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'users' 
  AND schemaname = 'public';

-- Check user policies
SELECT 
  'Users Table Policies' as check_name,
  policyname as policy_name,
  cmd as operation,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies 
WHERE tablename = 'users';

-- ================================================
-- 2. CHECK JOURNEYS AND FLIGHT TRACKING
-- ================================================
SELECT '=== JOURNEYS & FLIGHT TRACKING ===' as check_type;

-- Check journeys table structure
SELECT 
  'Journeys Table Structure' as check_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'journeys' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check foreign key relationships
SELECT 
  'Journeys Foreign Keys' as check_name,
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'journeys'
  AND tc.table_schema = 'public';

-- Check journeys RLS policies
SELECT 
  'Journeys Table Policies' as check_name,
  policyname as policy_name,
  cmd as operation,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END as with_check_clause
FROM pg_policies 
WHERE tablename = 'journeys';

-- ================================================
-- 3. CHECK FEEDBACK SYSTEM
-- ================================================
SELECT '=== FEEDBACK SYSTEM ===' as check_type;

-- Check stage_feedback table
SELECT 
  'Stage Feedback Table Structure' as check_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'stage_feedback' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check stage_feedback foreign keys
SELECT 
  'Stage Feedback Foreign Keys' as check_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'stage_feedback'
  AND tc.table_schema = 'public';

-- Check stage_feedback RLS policies
SELECT 
  'Stage Feedback Policies' as check_name,
  policyname as policy_name,
  cmd as operation
FROM pg_policies 
WHERE tablename = 'stage_feedback';

-- Check airline_reviews table
SELECT 
  'Airline Reviews Table Structure' as check_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'airline_reviews' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check airline_reviews foreign keys
SELECT 
  'Airline Reviews Foreign Keys' as check_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'airline_reviews'
  AND tc.table_schema = 'public';

-- ================================================
-- 4. CHECK LEADERBOARD SYSTEM
-- ================================================
SELECT '=== LEADERBOARD SYSTEM ===' as check_type;

-- Check leaderboard_scores table
SELECT 
  'Leaderboard Scores Table Structure' as check_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'leaderboard_scores' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check leaderboard triggers
SELECT 
  'Leaderboard Triggers' as check_name,
  trigger_name,
  event_manipulation as trigger_event,
  event_object_table as table_name,
  action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'public'
  AND (trigger_name LIKE '%score%' OR trigger_name LIKE '%leaderboard%')
ORDER BY trigger_name;

-- Check leaderboard functions
SELECT 
  'Leaderboard Functions' as check_name,
  routine_name as function_name,
  routine_type as type,
  data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
  AND (routine_name LIKE '%score%' OR routine_name LIKE '%leaderboard%')
ORDER BY routine_name;

-- Check realtime_feedback_view
SELECT 
  'Realtime Feedback View' as check_name,
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_name = 'realtime_feedback_view' 
  AND table_schema = 'public';

-- ================================================
-- 5. CHECK AIRLINES AND AIRPORTS
-- ================================================
SELECT '=== AIRLINES & AIRPORTS ===' as check_type;

-- Check airlines table
SELECT 
  'Airlines Count' as check_name,
  COUNT(*) as total_airlines,
  COUNT(CASE WHEN logo_url IS NOT NULL THEN 1 END) as airlines_with_logos
FROM airlines;

-- Check top 10 airlines by name
SELECT 
  'Top 10 Airlines' as check_name,
  id,
  name,
  iata_code,
  CASE WHEN logo_url IS NOT NULL THEN 'Has Logo' ELSE 'No Logo' END as logo_status
FROM airlines 
ORDER BY name 
LIMIT 10;

-- Check airports table
SELECT 
  'Airports Count' as check_name,
  COUNT(*) as total_airports
FROM airports;

-- ================================================
-- 6. CHECK REALTIME CONFIGURATION
-- ================================================
SELECT '=== REALTIME CONFIGURATION ===' as check_type;

-- Check realtime publication
SELECT 
  'Realtime Publication Tables' as check_name,
  schemaname,
  tablename
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- ================================================
-- 7. CHECK INDEXES FOR PERFORMANCE
-- ================================================
SELECT '=== INDEXES FOR PERFORMANCE ===' as check_type;

SELECT 
  'Important Indexes' as check_name,
  schemaname,
  tablename,
  indexname
FROM pg_indexes 
WHERE schemaname = 'public'
  AND tablename IN ('journeys', 'stage_feedback', 'airline_reviews', 'leaderboard_scores', 'flights')
ORDER BY tablename, indexname;

-- ================================================
-- 8. SUMMARY REPORT
-- ================================================
SELECT '=== SUMMARY REPORT ===' as check_type;

SELECT 
  'Table Existence Check' as check_name,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN '✅' ELSE '❌' END as users_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'journeys' AND table_schema = 'public') THEN '✅' ELSE '❌' END as journeys_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_feedback' AND table_schema = 'public') THEN '✅' ELSE '❌' END as stage_feedback_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'airline_reviews' AND table_schema = 'public') THEN '✅' ELSE '❌' END as airline_reviews_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_scores' AND table_schema = 'public') THEN '✅' ELSE '❌' END as leaderboard_scores_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'airlines' AND table_schema = 'public') THEN '✅' ELSE '❌' END as airlines_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'airports' AND table_schema = 'public') THEN '✅' ELSE '❌' END as airports_table,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flights' AND table_schema = 'public') THEN '✅' ELSE '❌' END as flights_table;

-- Check RLS is enabled on critical tables
SELECT 
  'RLS Status Check' as check_name,
  MAX(CASE WHEN tablename = 'users' AND rowsecurity THEN '✅' ELSE '❌' END) as users_rls,
  MAX(CASE WHEN tablename = 'journeys' AND rowsecurity THEN '✅' ELSE '❌' END) as journeys_rls,
  MAX(CASE WHEN tablename = 'stage_feedback' AND rowsecurity THEN '✅' ELSE '❌' END) as stage_feedback_rls,
  MAX(CASE WHEN tablename = 'airline_reviews' AND rowsecurity THEN '✅' ELSE '❌' END) as airline_reviews_rls,
  MAX(CASE WHEN tablename = 'leaderboard_scores' AND rowsecurity THEN '✅' ELSE '❌' END) as leaderboard_scores_rls
FROM pg_tables 
WHERE schemaname = 'public'
  AND tablename IN ('users', 'journeys', 'stage_feedback', 'airline_reviews', 'leaderboard_scores');

-- ================================================
-- DONE!
-- ================================================
SELECT '=== VERIFICATION COMPLETE ===' as status;

