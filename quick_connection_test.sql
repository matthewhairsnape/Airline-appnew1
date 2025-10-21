-- ================================================
-- QUICK CONNECTION TEST
-- ================================================
-- Run this to quickly verify auth and data connections are working

-- 1. Check if user table has display_name column (needed for Apple Sign-In)
SELECT 
  '1. User Table Check' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name = 'display_name'
    ) THEN '✅ PASS - display_name column exists'
    ELSE '❌ FAIL - display_name column missing'
  END as result;

-- 2. Check if journeys table has passenger_id foreign key to users
SELECT 
  '2. Journeys User Link' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND tc.table_name = 'journeys'
        AND kcu.column_name = 'passenger_id'
        AND ccu.table_name = 'users'
    ) THEN '✅ PASS - journeys linked to users'
    ELSE '❌ FAIL - journeys not properly linked to users'
  END as result;

-- 3. Check if stage_feedback has user_id foreign key
SELECT 
  '3. Feedback User Link' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'stage_feedback' 
      AND column_name = 'user_id'
    ) THEN '✅ PASS - stage_feedback has user_id'
    ELSE '❌ FAIL - stage_feedback missing user_id'
  END as result;

-- 4. Check if airline_reviews has user_id foreign key
SELECT 
  '4. Reviews User Link' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'airline_reviews' 
      AND column_name = 'user_id'
    ) THEN '✅ PASS - airline_reviews has user_id'
    ELSE '❌ FAIL - airline_reviews missing user_id'
  END as result;

-- 5. Check if leaderboard_scores table exists
SELECT 
  '5. Leaderboard Table' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_name = 'leaderboard_scores'
    ) THEN '✅ PASS - leaderboard_scores table exists'
    ELSE '❌ FAIL - leaderboard_scores table missing'
  END as result;

-- 6. Check if leaderboard has scoring function
SELECT 
  '6. Leaderboard Function' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name LIKE '%score%'
        AND routine_schema = 'public'
    ) THEN '✅ PASS - scoring functions exist'
    ELSE '⚠️ WARNING - no scoring functions found'
  END as result;

-- 7. Check if RLS is enabled on user tables
SELECT 
  '7. RLS Protection' as test,
  CASE 
    WHEN (
      SELECT COUNT(*) 
      FROM pg_tables 
      WHERE schemaname = 'public' 
        AND tablename IN ('users', 'journeys', 'stage_feedback', 'airline_reviews')
        AND rowsecurity = true
    ) = 4 THEN '✅ PASS - RLS enabled on all user tables'
    ELSE '❌ FAIL - RLS not enabled on all tables'
  END as result;

-- 8. Check if top 40 airlines exist
SELECT 
  '8. Airlines Data' as test,
  CASE 
    WHEN (SELECT COUNT(*) FROM airlines) >= 40 
    THEN '✅ PASS - ' || (SELECT COUNT(*) FROM airlines)::text || ' airlines in database'
    ELSE '⚠️ WARNING - Only ' || (SELECT COUNT(*) FROM airlines)::text || ' airlines (need 40+)'
  END as result;

-- 9. Check if realtime is configured
SELECT 
  '9. Realtime Setup' as test,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime'
        AND tablename = 'leaderboard_scores'
    ) THEN '✅ PASS - leaderboard_scores in realtime publication'
    ELSE '⚠️ WARNING - leaderboard_scores not in realtime publication'
  END as result;

-- 10. Check if airlines have logos
SELECT 
  '10. Airline Logos' as test,
  CASE 
    WHEN (SELECT COUNT(*) FROM airlines WHERE logo_url IS NOT NULL) >= 30
    THEN '✅ PASS - ' || (SELECT COUNT(*) FROM airlines WHERE logo_url IS NOT NULL)::text || ' airlines have logos'
    ELSE '⚠️ WARNING - Only ' || (SELECT COUNT(*) FROM airlines WHERE logo_url IS NOT NULL)::text || ' airlines have logos'
  END as result;

-- SUMMARY
SELECT 
  '==================' as summary,
  'SUMMARY REPORT' as title,
  '==================' as separator;

SELECT 
  CASE 
    WHEN (
      -- All critical checks pass
      EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'display_name')
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'stage_feedback' AND column_name = 'user_id')
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'airline_reviews' AND column_name = 'user_id')
      AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leaderboard_scores')
      AND (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('users', 'journeys', 'stage_feedback', 'airline_reviews') AND rowsecurity = true) = 4
    ) THEN '🎉 ALL CRITICAL TESTS PASSED - System is ready!'
    ELSE '⚠️ SOME TESTS FAILED - Review results above'
  END as final_status;

