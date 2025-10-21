# ✅ Authentication & Connection Verification Checklist

## 🎯 Purpose
Use this checklist to verify that your Apple Sign-In authentication is properly integrated with Supabase and all user data connections are working correctly.

---

## 📋 Pre-Flight Checklist

### **1. Supabase Apple Sign-In Configuration**

- [ ] **Apple Provider Enabled in Supabase**
  - Go to: Supabase Dashboard → Authentication → Providers → Apple
  - Status: Should be "Enabled"

- [ ] **Client ID Configured**
  - Value should be: `com.exp.aero.signin`
  
- [ ] **Secret Key Configured**
  - JWT token generated from your Apple Developer Key
  - Team ID: `4SS8VUUV4W`
  - Key ID: `D738P9CC7G`
  - Expiration: April 19, 2026

---

### **2. Database Schema Verification**

Run this in Supabase SQL Editor:
```sql
-- Copy and paste from: quick_connection_test.sql
```

**Expected Results:**
- [ ] ✅ User Table Check - PASS
- [ ] ✅ Journeys User Link - PASS
- [ ] ✅ Feedback User Link - PASS
- [ ] ✅ Reviews User Link - PASS
- [ ] ✅ Leaderboard Table - PASS
- [ ] ✅ Leaderboard Function - PASS
- [ ] ✅ RLS Protection - PASS
- [ ] ✅ Airlines Data - PASS (40+ airlines)
- [ ] ✅ Realtime Setup - PASS
- [ ] ✅ Airline Logos - PASS (30+ with logos)

---

### **3. iOS App Configuration**

- [ ] **Xcode Capabilities**
  - Target → Signing & Capabilities → "Sign in with Apple" is enabled
  
- [ ] **Bundle Identifier**
  - Should match: `com.exp.aero.signin`
  
- [ ] **Entitlements File**
  - `Runner/Runner.entitlements` contains Apple Sign-In entitlement

- [ ] **Info.plist**
  - Contains Supabase URL and Anon Key

---

### **4. Flutter Code Verification**

Check these files exist and are correct:

- [ ] **`lib/provider/auth_provider.dart`**
  - Contains `signInWithApple()` method
  - Uses `OAuthProvider.apple`
  - Creates user profile if not exists

- [ ] **`lib/services/supabase_service.dart`**
  - Uses `passenger_id` for journeys (links to users)
  - Includes `userId` in all feedback submissions
  - Has `getUserJourneys()` method

- [ ] **`lib/services/supabase_leaderboard_service.dart`**
  - Has `subscribeToLeaderboardUpdates()` method
  - Connects to `leaderboard_scores` table

- [ ] **`lib/screen/logIn/skip_screen.dart`**
  - Has Apple Sign-In button
  - Calls `auth_provider.signInWithApple()`

---

## 🧪 Functional Testing

### **Test 1: Apple Sign-In Flow**

1. [ ] Open app on iOS device/simulator
2. [ ] Tap "Continue with Apple" button
3. [ ] Apple authentication popup appears
4. [ ] Complete authentication (Face ID/Touch ID/Password)
5. [ ] App navigates to main screen
6. [ ] Check Supabase Dashboard → Authentication → Users
7. [ ] Verify new user appears with correct email

**Expected:**
- User ID (UUID) created
- Email from Apple shown
- Display name populated

---

### **Test 2: Journey Creation & User Link**

1. [ ] Sign in with Apple
2. [ ] Navigate to "Add Flight" or scan boarding pass
3. [ ] Enter flight details (PNR, flight number, etc.)
4. [ ] Submit/Save flight
5. [ ] Check Supabase Dashboard → Table Editor → `journeys`
6. [ ] Find your journey by PNR
7. [ ] Verify `passenger_id` matches your user UUID from auth

**Expected:**
- Journey has your `passenger_id`
- Journey has correct `pnr`
- Journey has `flight_id` reference

---

### **Test 3: Feedback Submission & User Link**

1. [ ] Navigate to an active journey
2. [ ] Tap to submit feedback (Pre-Flight, In-Flight, or Post-Flight)
3. [ ] Select likes/dislikes
4. [ ] Give a rating (1-5 stars)
5. [ ] Submit feedback
6. [ ] Check Supabase Dashboard → Table Editor → `stage_feedback`
7. [ ] Find your feedback entry
8. [ ] Verify `user_id` matches your user UUID
9. [ ] Verify `journey_id` matches your journey

**Expected:**
- Feedback has your `user_id`
- Feedback has correct `journey_id`
- Feedback has correct `stage` (Pre-Flight/In-Flight/Post-Flight)
- Feedback has `positive_selections` and `negative_selections` JSONB

---

### **Test 4: Leaderboard Update**

1. [ ] After submitting feedback (Test 3)
2. [ ] Navigate to Leaderboard tab in app
3. [ ] Wait 2-3 seconds
4. [ ] Check if leaderboard shows airlines
5. [ ] Check Supabase Dashboard → Table Editor → `leaderboard_scores`
6. [ ] Verify scores exist for airlines
7. [ ] Verify `score_value` is calculated

**Expected:**
- Leaderboard shows top 40 airlines
- Airlines have scores (0-5.0 range)
- Airlines have logos displayed
- Rankings are in descending order

---

### **Test 5: Real-Time Updates**

1. [ ] Open app on device 1
2. [ ] Navigate to Leaderboard tab
3. [ ] Open Supabase Dashboard on computer
4. [ ] Table Editor → `leaderboard_scores`
5. [ ] Manually change a score for an airline
6. [ ] Watch app on device 1
7. [ ] Verify leaderboard updates automatically

**Expected:**
- App updates without refresh
- Rankings reorder based on new scores
- No delay > 2 seconds

---

### **Test 6: Row Level Security**

1. [ ] Sign in as User A
2. [ ] Create a journey (Journey A)
3. [ ] Sign out
4. [ ] Sign in as User B (different Apple ID)
5. [ ] Navigate to "My Journeys"
6. [ ] Verify User B does NOT see Journey A

**Expected:**
- Each user only sees their own journeys
- Each user only sees their own feedback
- Leaderboard is visible to all users (public read)

---

### **Test 7: Multiple Feedbacks → Score Update**

1. [ ] Submit feedback for British Airways (BA) - Rating: 4/5
2. [ ] Check leaderboard - note BA's score
3. [ ] Submit another feedback for BA - Rating: 2/5
4. [ ] Check leaderboard again
5. [ ] Verify BA's score changed (should be average: ~3/5)

**Expected:**
- Score updates after each feedback
- Score is average of all user ratings
- Bayesian adjustment applied (if review count < 30)

---

## 🔍 Debugging Tools

### **Check Current User Session:**
Add this to your Flutter app to debug:
```dart
final session = SupabaseService.client.auth.currentSession;
debugPrint('User ID: ${session?.user.id}');
debugPrint('User Email: ${session?.user.email}');
debugPrint('Session Expires: ${session?.expiresAt}');
```

### **Check Database Connections in SQL:**
```sql
-- Run in Supabase SQL Editor:

-- 1. Check if user exists
SELECT id, email, display_name FROM users WHERE email = 'your-email@example.com';

-- 2. Check journeys for user
SELECT id, pnr, passenger_id, flight_id FROM journeys WHERE passenger_id = 'YOUR_USER_UUID';

-- 3. Check feedback for user
SELECT id, user_id, journey_id, stage, overall_rating FROM stage_feedback WHERE user_id = 'YOUR_USER_UUID';

-- 4. Check leaderboard scores
SELECT airline_id, score_type, score_value, review_count FROM leaderboard_scores ORDER BY score_value DESC LIMIT 10;
```

---

## 🚨 Common Issues & Fixes

### **Issue 1: "User not authenticated" error when submitting feedback**

**Fix:**
```dart
// Ensure you're checking for session before submitting
final session = SupabaseService.client.auth.currentSession;
if (session?.user.id == null) {
  // Redirect to login
  Navigator.pushNamed(context, AppRoutes.login);
  return;
}
```

---

### **Issue 2: Journeys not showing for user**

**Cause:** RLS policy not matching `passenger_id` with `auth.uid()`

**Fix:**
```sql
-- Run in Supabase SQL Editor:
DROP POLICY IF EXISTS "Users can view their own journeys" ON journeys;

CREATE POLICY "Users can view their own journeys" ON journeys
  FOR SELECT USING (auth.uid()::text = passenger_id::text);
```

---

### **Issue 3: Leaderboard not updating in real-time**

**Cause:** Realtime not enabled for `leaderboard_scores`

**Fix:**
```sql
-- Run in Supabase SQL Editor:
ALTER PUBLICATION supabase_realtime ADD TABLE leaderboard_scores;
```

Or use broadcast method (preferred):
```sql
-- Ensure trigger includes pg_notify:
CREATE OR REPLACE FUNCTION notify_leaderboard_update()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('leaderboard_update', NEW.id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

### **Issue 4: Apple Sign-In "Invalid Client" error**

**Cause:** Client ID mismatch between Supabase and Apple Developer

**Fix:**
1. Go to Apple Developer Console
2. Verify Services ID matches: `com.exp.aero.signin`
3. Go to Supabase Dashboard → Authentication → Providers → Apple
4. Verify Client ID matches: `com.exp.aero.signin`
5. Regenerate secret key if needed:
   ```bash
   node generate_supabase_apple_secret.js
   ```

---

### **Issue 5: Leaderboard shows empty list**

**Cause:** No airlines in database or no scores calculated

**Fix:**
```sql
-- Check if airlines exist:
SELECT COUNT(*) FROM airlines;

-- If 0, run:
-- fixed_leaderboard_setup.sql

-- Check if scores exist:
SELECT COUNT(*) FROM leaderboard_scores;

-- If 0, run the calculate function manually:
SELECT calculate_airline_scores_for_single_airline(airline_id) FROM airlines;
```

---

## ✅ Final Verification

After completing all tests, you should have:

- [x] ✅ Apple Sign-In working with Supabase
- [x] ✅ User profiles created automatically
- [x] ✅ Journeys linked to authenticated users
- [x] ✅ Feedback submissions saved with user_id
- [x] ✅ Reviews linked to users and journeys
- [x] ✅ Leaderboard scores calculated from user feedback
- [x] ✅ Real-time updates working
- [x] ✅ Row Level Security protecting user data
- [x] ✅ Top 40 airlines displayed with logos
- [x] ✅ No mock/sample data in production

---

## 📞 Support

If any test fails:

1. **Check Logs:**
   - Xcode Console for iOS errors
   - Supabase Dashboard → Logs for backend errors
   - Flutter console: `flutter run --verbose`

2. **Verify Environment:**
   - Supabase URL and Keys in `lib/config/supabase_config.dart`
   - Apple Developer Team ID: `4SS8VUUV4W`
   - Apple Key ID: `D738P9CC7G`

3. **Run Diagnostic Scripts:**
   - `quick_connection_test.sql` in Supabase SQL Editor
   - `verify_auth_and_connections.sql` for detailed check

---

## 🎉 Success Criteria

**Your system is working correctly when:**
1. ✅ Users can sign in with Apple
2. ✅ User data is isolated (each user sees only their data)
3. ✅ Feedback affects leaderboard scores
4. ✅ Leaderboard updates in real-time
5. ✅ No errors in console/logs
6. ✅ All RLS policies protect user privacy

**You're ready for production!** 🚀

