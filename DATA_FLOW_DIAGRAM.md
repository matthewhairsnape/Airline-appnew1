# 🔄 Complete Data Flow Diagram

## 📱 Apple Authentication → User Data → Leaderboard Scoring

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER AUTHENTICATION                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
         ┌─────────────────────┐         ┌─────────────────────┐
         │   APPLE SIGN-IN     │         │    GUEST MODE       │
         │   (Primary Method)  │         │    (Skip Auth)      │
         └──────────┬──────────┘         └──────────┬──────────┘
                    │                               │
                    │ idToken                       │ No Session
                    │ authorizationCode             │
                    │ email, fullName               │
                    │                               │
                    ▼                               │
         ┌─────────────────────┐                   │
         │  SUPABASE AUTH      │                   │
         │  • Validates Apple  │                   │
         │  • Creates JWT      │                   │
         │  • Returns User ID  │                   │
         └──────────┬──────────┘                   │
                    │                               │
                    │ auth.uid()                    │
                    │                               │
                    ▼                               │
         ┌─────────────────────┐                   │
         │   USERS TABLE       │◄──────────────────┘
         │                     │  (Guest: No Entry)
         │  • id: UUID         │
         │  • email            │
         │  • display_name     │
         │  • avatar_url       │
         │  • created_at       │
         └──────────┬──────────┘
                    │
                    │ passenger_id (FK)
                    │
┌───────────────────┴───────────────────────────────────────────────────┐
│                        USER DATA LAYER                                 │
└────────────────────────────────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┬───────────────┐
        │           │           │               │
        ▼           ▼           ▼               ▼
┌──────────┐ ┌──────────┐ ┌──────────┐  ┌─────────────┐
│ JOURNEYS │ │ FEEDBACK │ │ REVIEWS  │  │   EVENTS    │
└──────────┘ └──────────┘ └──────────┘  └─────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         JOURNEYS TABLE                                   │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  • id: UUID                                                     │    │
│  │  • passenger_id: UUID → users.id ◄─── USER CONNECTION         │    │
│  │  • flight_id: UUID → flights.id                                │    │
│  │  • pnr: TEXT (booking reference)                               │    │
│  │  • seat_number: TEXT                                           │    │
│  │  • status: 'scheduled' | 'active' | 'completed'                │    │
│  │  • current_phase: 'pre_check_in' | 'boarding' | 'in_flight'   │    │
│  │  • created_at: TIMESTAMPTZ                                     │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  RLS POLICY:                                                             │
│    ✅ SELECT: WHERE auth.uid() = passenger_id                           │
│    ✅ INSERT: WITH CHECK auth.uid() = passenger_id                      │
│    ✅ UPDATE: WHERE auth.uid() = passenger_id                           │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ journey_id (FK)
                    │
        ┌───────────┼───────────┬───────────────┐
        │           │           │               │
        ▼           ▼           ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ STAGE        │ │ AIRLINE      │ │ AIRPORT      │ │ JOURNEY      │
│ FEEDBACK     │ │ REVIEWS      │ │ REVIEWS      │ │ EVENTS       │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      STAGE_FEEDBACK TABLE                                │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  • id: UUID                                                     │    │
│  │  • user_id: UUID → users.id ◄─── USER CONNECTION              │    │
│  │  • journey_id: UUID → journeys.id                              │    │
│  │  • flight_id: UUID → flights.id                                │    │
│  │  • stage: 'Pre-Flight' | 'In-Flight' | 'Post-Flight'          │    │
│  │  • positive_selections: JSONB (likes)                          │    │
│  │  • negative_selections: JSONB (dislikes)                       │    │
│  │  • overall_rating: INTEGER (1-5)                               │    │
│  │  • additional_comments: TEXT                                   │    │
│  │  • feedback_timestamp: TIMESTAMPTZ                             │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  RLS POLICY:                                                             │
│    ✅ SELECT: WHERE auth.uid() = user_id                                │
│    ✅ INSERT: WITH CHECK auth.uid() = user_id                           │
│    ✅ UPDATE: WHERE auth.uid() = user_id                                │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ TRIGGER: after INSERT or UPDATE
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│               SCORING CALCULATION FUNCTION                               │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  calculate_airline_scores_for_single_airline(airline_id)       │    │
│  │                                                                 │    │
│  │  1. Aggregate all feedback for this airline                    │    │
│  │  2. Calculate raw average score                                │    │
│  │  3. Count total reviews                                        │    │
│  │  4. Apply Bayesian smoothing:                                  │    │
│  │     Formula: (v/(v+m))*S + (m/(v+m))*C                         │    │
│  │     • v = review count                                         │    │
│  │     • m = minimum volume (30)                                  │    │
│  │     • S = raw average                                          │    │
│  │     • C = global average                                       │    │
│  │  5. Determine confidence level:                                │    │
│  │     • 0-10 reviews: Low                                        │    │
│  │     • 11-50 reviews: Medium                                    │    │
│  │     • 51+ reviews: High                                        │    │
│  │  6. Calculate phase-based weights:                             │    │
│  │     • Pre-Flight: 20%                                          │    │
│  │     • In-Flight: 30%                                           │    │
│  │     • Post-Flight: 50%                                         │    │
│  │  7. Insert/Update leaderboard_scores                           │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ INSERT/UPDATE
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    LEADERBOARD_SCORES TABLE                              │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  • id: UUID                                                     │    │
│  │  • airline_id: UUID → airlines.id                              │    │
│  │  • score_type: 'overall' | 'wifi' | 'seat_comfort' | 'food'   │    │
│  │  • score_value: DECIMAL (Bayesian adjusted, 0-5.0)            │    │
│  │  • raw_score: DECIMAL (raw average)                            │    │
│  │  • review_count: INTEGER                                       │    │
│  │  • bayesian_score: DECIMAL                                     │    │
│  │  • confidence_level: 'low' | 'medium' | 'high'                │    │
│  │  • phases_completed: INTEGER                                   │    │
│  │  • last_updated: TIMESTAMPTZ                                   │    │
│  │                                                                 │    │
│  │  UNIQUE (airline_id, score_type)                               │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  RLS POLICY:                                                             │
│    ✅ SELECT: USING (true)  ◄─── PUBLIC READ                           │
│                                                                          │
│  REALTIME:                                                               │
│    ✅ pg_notify('leaderboard_update', NEW.id::text)                     │
│    ✅ Supabase Realtime stream broadcasts changes                       │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ pg_notify / Realtime Stream
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP UI LAYER                                │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  SupabaseLeaderboardService.subscribeToLeaderboardUpdates()   │    │
│  │                                                                 │    │
│  │  • Listens to leaderboard_scores stream                        │    │
│  │  • Filters by score_type (overall, wifi, etc.)                 │    │
│  │  • Orders by score_value DESC                                  │    │
│  │  • Limits to top 40                                            │    │
│  │  • Enriches with airline details (name, logo)                  │    │
│  │  • Returns Stream<List<Map<String, dynamic>>>                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  LeaderboardProvider (Riverpod)                                │    │
│  │                                                                 │    │
│  │  • Manages leaderboard state                                   │    │
│  │  • Handles category switching                                  │    │
│  │  • Formats data for UI                                         │    │
│  │  • Updates UI automatically on stream changes                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  LeaderboardScreen (UI)                                        │    │
│  │                                                                 │    │
│  │  • Displays top 40 airlines                                    │    │
│  │  • Shows airline logos from Supabase                           │    │
│  │  • Displays scores with 1 decimal (e.g., 4.5)                 │    │
│  │  • Confidence badges (Low/Medium/High)                         │    │
│  │  • Real-time updates (no manual refresh)                       │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                    EXAMPLE USER JOURNEY                                  │
└─────────────────────────────────────────────────────────────────────────┘

1️⃣  USER SIGNS IN
    │
    ├─► Apple ID: john@example.com
    ├─► Supabase creates: user_id = "abc-123-def-456"
    └─► Session stored with JWT token

2️⃣  USER ADDS FLIGHT
    │
    ├─► Scans boarding pass: PNR = "XYZ789", Flight = "BA213"
    ├─► Journey created with passenger_id = "abc-123-def-456"
    └─► Journey ID = "journey-001"

3️⃣  USER SUBMITS PRE-FLIGHT FEEDBACK
    │
    ├─► Likes: "Fast check-in", "Clean lounge"
    ├─► Dislikes: "Long security line"
    ├─► Rating: 4/5
    ├─► Saved to stage_feedback with:
    │   • user_id = "abc-123-def-456"
    │   • journey_id = "journey-001"
    │   • stage = "Pre-Flight"
    └─► TRIGGER fires → calculate_airline_scores_for_single_airline(BA)

4️⃣  SCORING CALCULATION
    │
    ├─► Aggregate all BA feedback from all users
    ├─► Calculate raw average: 4.2
    ├─► Review count: 25 reviews
    ├─► Apply Bayesian smoothing:
    │   • v = 25, m = 30, S = 4.2, C = 4.0
    │   • Score = (25/(25+30))*4.2 + (30/(25+30))*4.0
    │   • Score = 4.09 (adjusted down due to low review count)
    ├─► Confidence: "Medium" (25 reviews)
    └─► Update leaderboard_scores:
        • airline_id = BA
        • score_value = 4.09
        • review_count = 25
        • confidence_level = "medium"

5️⃣  REALTIME UPDATE
    │
    ├─► pg_notify broadcasts: "leaderboard_update"
    ├─► Supabase Realtime stream picks up change
    └─► Flutter app receives update via subscribeToLeaderboardUpdates()

6️⃣  UI UPDATES
    │
    ├─► LeaderboardProvider updates state
    ├─► LeaderboardScreen re-renders
    ├─► British Airways moves from #5 to #7 (score dropped)
    └─► User sees updated rankings (no manual refresh)

7️⃣  USER SUBMITS IN-FLIGHT FEEDBACK
    │
    ├─► Likes: "Comfortable seats", "Good entertainment"
    ├─► Dislikes: "Cold meals"
    ├─► Rating: 5/5
    └─► Process repeats from step 3

8️⃣  FINAL SCORE CALCULATION
    │
    ├─► Pre-Flight: 4/5 (weight: 20% = 0.8)
    ├─► In-Flight: 5/5 (weight: 30% = 1.5)
    ├─► Post-Flight: Not submitted (catch-up: 4.5, weight: 50% = 2.25)
    ├─► Overall = 0.8 + 1.5 + 2.25 = 4.55
    ├─► Apply Bayesian (26 reviews now): 4.14
    └─► BA now ranks #6 with score 4.1 ⭐


┌─────────────────────────────────────────────────────────────────────────┐
│                    DATA SECURITY & ISOLATION                             │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐         ┌─────────────────┐
│  USER A         │         │  USER B         │
│  john@email.com │         │  jane@email.com │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ auth.uid() = "user-A"     │ auth.uid() = "user-B"
         │                           │
    ┌────▼────┐                 ┌────▼────┐
    │ Journey │                 │ Journey │
    │ BA213   │                 │ EK215   │
    │ PNR:ABC │                 │ PNR:XYZ │
    └────┬────┘                 └────┬────┘
         │                           │
    ┌────▼────┐                 ┌────▼────┐
    │Feedback │                 │Feedback │
    │ 4/5 ⭐  │                 │ 5/5 ⭐  │
    └─────────┘                 └─────────┘

    RLS POLICY ENSURES:
    • User A can ONLY see Journey BA213
    • User B can ONLY see Journey EK215
    • User A CANNOT access User B's feedback
    • User B CANNOT access User A's feedback

    BUT:
    • Both User A and User B can see the PUBLIC leaderboard
    • Leaderboard aggregates feedback from ALL users
    • Individual feedback is anonymous in leaderboard scores


┌─────────────────────────────────────────────────────────────────────────┐
│                           SUMMARY                                        │
└─────────────────────────────────────────────────────────────────────────┘

✅ USER AUTHENTICATION
   • Apple Sign-In → Supabase Auth → JWT Token → auth.uid()

✅ USER DATA LINKING
   • journeys.passenger_id → users.id
   • stage_feedback.user_id → users.id
   • airline_reviews.user_id → users.id

✅ FEEDBACK → SCORING FLOW
   • User submits feedback (with user_id)
   • Trigger calculates airline scores
   • Bayesian smoothing applied
   • Leaderboard updated

✅ REAL-TIME UPDATES
   • pg_notify broadcasts changes
   • Supabase Realtime stream
   • Flutter app subscribes
   • UI updates automatically

✅ SECURITY
   • RLS protects user data
   • Foreign keys enforce integrity
   • Public read for leaderboard
   • Private write for user data

✅ NO MOCK DATA
   • All production-ready
   • Real user authentication
   • Real feedback aggregation
   • Real leaderboard scoring
```

