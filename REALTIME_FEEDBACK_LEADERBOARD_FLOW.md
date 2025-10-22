# Real-Time Feedback to Leaderboard Data Flow

## 🔄 Complete Data Flow Architecture

### **1. Feedback Collection Phase**
```
Passenger Experience → App Feedback → Supabase Database
```

#### **Feedback Sources:**
- **Pre-Flight**: Check-in, Security, Boarding, Airport Facilities
- **In-Flight**: Seat Comfort, Crew Service, Wi-Fi, Food & Beverage, Entertainment
- **Post-Flight**: Overall Experience, Baggage, Communication

#### **Data Structure:**
```json
{
  "feedback_id": "uuid",
  "journey_id": "uuid", 
  "user_id": "uuid",
  "flight_id": "uuid",
  "stage": "preFlight|inFlight|postFlight",
  "likes": ["Good Wi-Fi", "Crew helpful", "Comfortable seat"],
  "dislikes": ["Cold meal", "Delayed boarding", "Poor Wi-Fi"],
  "overall_rating": 4,
  "feedback_timestamp": "2024-01-15T10:30:00Z"
}
```

### **2. Real-Time Processing Phase**
```
Supabase Triggers → Score Calculation → Leaderboard Updates
```

#### **Database Tables:**
- **`stage_feedback`**: Raw feedback data
- **`leaderboard_scores`**: Calculated scores by category
- **`realtime_feedback_view`**: Live feedback aggregation

#### **Score Calculation Formula:**
```sql
score = (likes_count - dislikes_count) / total_feedback_count
```

### **3. Category Mapping System**

#### **UI Categories → Database Score Types:**
```dart
'Wi-Fi Experience' → 'wifi_experience'
'Crew Friendliness' → 'crew_friendliness'  
'Seat Comfort' → 'seat_comfort'
'Food & Beverage' → 'food_beverage'
'Operations & Timeliness' → 'operations_timeliness'
```

#### **Feedback Tags → Categories:**
```dart
// Wi-Fi Experience
["Good Wi-Fi", "Poor Wi-Fi", "Wi-Fi connectivity", "Wi-Fi and IFE"]

// Crew Friendliness  
["Crew helpful", "Friendly service", "Unfriendly crew", "Cabin crew"]

// Seat Comfort
["Comfortable seat", "Uncomfortable seat", "Clean cabin", "Seat comfort"]

// Food & Beverage
["Good food", "Cold meal", "Poor quality beverage", "Food and beverage"]

// Operations & Timeliness
["Smooth boarding", "Delayed boarding", "Gate chaos", "Baggage delay"]
```

### **4. Real-Time Updates Flow**

#### **Supabase Realtime Subscriptions:**
```dart
// 1. Subscribe to feedback updates
RealtimeDataService.subscribeToFeedback(journeyId)

// 2. Subscribe to leaderboard updates  
SupabaseLeaderboardService.subscribeToLeaderboardUpdates()

// 3. Subscribe to issues updates
SupabaseLeaderboardService.subscribeToIssues()
```

#### **Update Triggers:**
1. **New Feedback Submitted** → `stage_feedback` table insert
2. **Score Recalculation** → `leaderboard_scores` table update
3. **UI Refresh** → Leaderboard and Issues screens update

### **5. Leaderboard Display Logic**

#### **Category Filtering:**
```dart
// When user selects "Wi-Fi Experience" tab:
1. MapCategoryToScoreType("Wi-Fi Experience") → "wifi_experience"
2. Query leaderboard_scores WHERE score_type = "wifi_experience"
3. Order by score_value DESC
4. Display top 40 airlines
```

#### **Real-Time Updates:**
```dart
// Stream updates to UI
Stream<List<Map<String, dynamic>>> subscribeToLeaderboardUpdates({
  String? scoreType,  // Category filter
  int limit = 40,     // Number of results
})
```

### **6. Issues Tab Integration**

#### **Real-Time Issues Feed:**
```dart
// Subscribe to real-time feedback for issues
Stream<List<Map<String, dynamic>>> subscribeToIssues() {
  return _client
    .from('realtime_feedback_view')
    .stream(primaryKey: ['feedback_id'])
    .order('feedback_id', ascending: false)
    .limit(100);
}
```

#### **Issues Data Structure:**
```json
{
  "feedback_id": "uuid",
  "flight_number": "BA123",
  "airline": "British Airways", 
  "phase": "In-flight",
  "likes": [{"text": "Good Wi-Fi", "count": 12}],
  "dislikes": [{"text": "Cold meal", "count": 8}],
  "logo": "https://...",
  "phaseColor": "#FF5722"
}
```

## 🚀 Performance Optimizations

### **Database Indexing:**
- `leaderboard_scores(score_type, score_value)`
- `stage_feedback(journey_id, feedback_timestamp)`
- `realtime_feedback_view(feedback_id)`

### **Caching Strategy:**
- **Leaderboard Data**: Cached for 5 minutes
- **Category Scores**: Real-time updates
- **Issues Feed**: Live streaming

### **Real-Time Efficiency:**
- **Selective Updates**: Only affected categories refresh
- **Batch Processing**: Multiple feedback updates processed together
- **Connection Pooling**: Optimized Supabase connections

## 📊 Data Flow Summary

```
1. Passenger submits feedback → stage_feedback table
2. Supabase triggers → Score calculation service
3. Scores calculated → leaderboard_scores table  
4. Real-time subscription → UI updates
5. Category filtering → Filtered leaderboard display
6. Issues aggregation → Real-time issues feed
```

## 🔧 Technical Implementation

### **Key Services:**
- **`RealtimeDataService`**: Handles all real-time subscriptions
- **`SupabaseLeaderboardService`**: Manages leaderboard data
- **`LeaderboardCategoryService`**: Category definitions and mapping
- **`PhaseFeedbackService`**: Feedback processing and scoring

### **Provider Architecture:**
- **`LeaderboardProvider`**: State management for leaderboard
- **`UserDataProvider`**: User authentication and data
- **Real-time streams**: Automatic UI updates

### **Database Schema:**
```sql
-- Core tables
stage_feedback (feedback_id, journey_id, user_id, likes, dislikes, rating)
leaderboard_scores (airline_id, score_type, score_value, updated_at)
realtime_feedback_view (feedback_id, flight_number, airline, phase, likes, dislikes)

-- Real-time triggers
CREATE TRIGGER update_leaderboard_scores 
ON stage_feedback FOR EACH ROW 
EXECUTE FUNCTION calculate_leaderboard_scores();
```

This architecture ensures **real-time updates** from passenger feedback directly flow into the leaderboard categories, providing live insights into airline performance across all experience dimensions! 🎉

