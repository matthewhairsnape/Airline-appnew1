# Supabase Migration Guide: Removing Cirium Dependency

## Overview
This document outlines what needs to be updated in Supabase after removing Cirium flight tracking and switching to manual airline input.

---

## 📊 **Supabase Tables Involved**

### 1. **`airlines` Table** ✅ CRITICAL
**Current State:**
- Stores airline information (IATA code, name, ICAO code, country, logo_url)
- Used by: journeys, flights, leaderboard, feedback

**What Needs to Be Updated:**
- ✅ **Ensure all airlines from your manual input are in this table**
- ✅ **Required columns:**
  - `id` (UUID, primary key)
  - `iata_code` (TEXT, unique) - **MUST MATCH carrier codes from boarding passes**
  - `name` (TEXT) - Full airline name
  - `icao_code` (TEXT, optional) - ICAO code
  - `country` (TEXT, optional) - Country of origin
  - `logo_url` (TEXT, optional) - Logo URL

**Action Required:**
```sql
-- Verify all airlines exist
SELECT iata_code, name FROM airlines ORDER BY iata_code;

-- If missing airlines, insert them:
INSERT INTO airlines (iata_code, name, icao_code, country, logo_url)
VALUES 
  ('XX', 'Airline Name', 'XXX', 'Country', 'https://images.kiwi.com/airlines/256/XX.png')
ON CONFLICT (iata_code) DO NOTHING;
```

---

### 2. **`airports` Table** ✅ CRITICAL
**Current State:**
- Stores airport information (IATA code, name, city, country, coordinates)
- Used by: journeys, flights

**What Needs to Be Updated:**
- ✅ **Ensure all airports from boarding passes are in this table**
- ✅ **Required columns:**
  - `id` (UUID, primary key)
  - `iata_code` (TEXT, unique) - **MUST MATCH airport codes from boarding passes**
  - `name` (TEXT) - Airport name
  - `city` (TEXT, optional)
  - `country` (TEXT, optional)
  - `latitude` (NUMERIC, optional)
  - `longitude` (NUMERIC, optional)

**Action Required:**
```sql
-- Verify all airports exist
SELECT iata_code, name FROM airports ORDER BY iata_code;

-- If missing airports, insert them:
INSERT INTO airports (iata_code, name, city, country)
VALUES 
  ('XXX', 'Airport Name', 'City', 'Country')
ON CONFLICT (iata_code) DO NOTHING;
```

---

### 3. **`flights` Table** ⚠️ MODERATE IMPACT
**Current State:**
- Links airlines to airports
- Stores flight details (flight_number, scheduled times, aircraft type)
- Used by: journeys

**What Needs to Be Updated:**
- ✅ **No schema changes needed** - table structure is fine
- ⚠️ **Data flow change:**
  - **Before:** Flight data came from Cirium API (aircraft type, gates, terminals)
  - **After:** Flight data comes from boarding pass scan (manual input)
  - **Impact:** Some fields may be NULL (aircraft_type, terminal, gate) if not in boarding pass

**Columns Used:**
- `id` (UUID, primary key)
- `airline_id` (UUID, FK to airlines) - **REQUIRED**
- `flight_number` (TEXT) - **REQUIRED**
- `departure_airport_id` (UUID, FK to airports) - **REQUIRED**
- `arrival_airport_id` (UUID, FK to airports) - **REQUIRED**
- `scheduled_departure` (TIMESTAMPTZ) - **REQUIRED**
- `scheduled_arrival` (TIMESTAMPTZ) - **REQUIRED**
- `aircraft_type` (TEXT, optional) - May be NULL
- `terminal` (TEXT, optional) - May be NULL
- `gate` (TEXT, optional) - May be NULL
- `carrier_code` (TEXT, optional) - Backup for airline lookup

**Action Required:**
- ✅ **No action needed** - table will work with manual input
- ⚠️ **Ensure foreign key constraints are satisfied:**
  - All `airline_id` values must exist in `airlines` table
  - All `departure_airport_id` and `arrival_airport_id` must exist in `airports` table

---

### 4. **`journeys` Table** ⚠️ MODERATE IMPACT
**Current State:**
- Stores user journey records
- Links to flights, stores PNR, seat number, class of travel
- **Previously stored Cirium data in `media` column**

**What Needs to Be Updated:**
- ⚠️ **`media` column change:**
  - **Before:** Stored full Cirium API response JSON
  - **After:** May store boarding pass data or be NULL
  - **Impact:** Code that reads Cirium data from `media` column will need fallback

**Columns Used:**
- `id` (UUID, primary key)
- `passenger_id` (UUID, FK to auth.users) - **REQUIRED**
- `flight_id` (UUID, FK to flights) - **REQUIRED**
- `pnr` (TEXT) - **REQUIRED**
- `seat_number` (TEXT, optional)
- `class_of_travel` (TEXT, optional)
- `visit_status` (TEXT) - Default: 'Upcoming'
- `media` (JSONB, optional) - **Previously Cirium data, now boarding pass data**
- `terminal` (TEXT, optional)
- `gate` (TEXT, optional)
- `connection_time_mins` (INTEGER, optional)

**Action Required:**
- ✅ **No schema changes needed**
- ⚠️ **Update any code/queries that expect Cirium data in `media` column**
- ✅ **Ensure `flight_id` foreign key is always valid**

---

### 5. **`leaderboard_rankings` Table** ✅ NO IMPACT
**Current State:**
- Stores leaderboard rankings
- Links to airlines via `airline_id`

**What Needs to Be Updated:**
- ✅ **No changes needed** - uses `airlines` table which you're populating manually
- ✅ **Ensure all airlines in leaderboard exist in `airlines` table**

---

### 6. **`airline_reviews` Table** ✅ NO IMPACT
**Current State:**
- Stores airline reviews/feedback
- Links to airlines via `airline_id`

**What Needs to Be Updated:**
- ✅ **No changes needed** - uses `airlines` table

---

### 7. **`airport_reviews` Table** ✅ NO IMPACT
**Current State:**
- Stores airport reviews/feedback
- Links to airports via `airport_id`

**What Needs to Be Updated:**
- ✅ **No changes needed** - uses `airports` table

---

### 8. **`feedback` Table** ✅ NO IMPACT
**Current State:**
- Stores general feedback
- Links to journeys via `journey_id`

**What Needs to Be Updated:**
- ✅ **No changes needed**

---

## 🔄 **Data Flow Changes**

### **Before (With Cirium):**
```
Boarding Pass Scan
    ↓
Extract: carrier, flight_number, date, airports
    ↓
Call Cirium API → Get full flight data
    ↓
Store in Supabase:
  - airlines table (from Cirium response)
  - airports table (from Cirium response)
  - flights table (from Cirium response)
  - journeys table (with Cirium data in media column)
```

### **After (Manual Input):**
```
Boarding Pass Scan
    ↓
Extract: carrier, flight_number, date, airports
    ↓
Lookup in Supabase:
  - airlines table (must exist)
  - airports table (must exist)
    ↓
Create flight record (from boarding pass data only)
    ↓
Store in Supabase:
  - flights table (from boarding pass)
  - journeys table (with boarding pass data in media column)
```

---

## ⚠️ **Critical Dependencies to Verify**

### 1. **Foreign Key Constraints**
All foreign keys must reference existing records:

```sql
-- Check for orphaned flights (airline_id doesn't exist)
SELECT f.id, f.airline_id, f.flight_number
FROM flights f
LEFT JOIN airlines a ON f.airline_id = a.id
WHERE a.id IS NULL;

-- Check for orphaned flights (airport_id doesn't exist)
SELECT f.id, f.departure_airport_id, f.arrival_airport_id
FROM flights f
LEFT JOIN airports dep ON f.departure_airport_id = dep.id
LEFT JOIN airports arr ON f.arrival_airport_id = arr.id
WHERE dep.id IS NULL OR arr.id IS NULL;

-- Check for orphaned journeys (flight_id doesn't exist)
SELECT j.id, j.flight_id, j.pnr
FROM journeys j
LEFT JOIN flights f ON j.flight_id = f.id
WHERE f.id IS NULL;
```

### 2. **Required Data in `airlines` Table**
```sql
-- Verify all IATA codes from your manual input exist
-- Replace with your actual airline IATA codes
SELECT iata_code, name 
FROM airlines 
WHERE iata_code IN ('NH', 'LH', 'EK', 'AS', 'LX', 'QR', 'AF', 'QF', 'KE', 'GF', 'BA', 'TG', 'SQ', 'CA', ...)
ORDER BY iata_code;
```

### 3. **Required Data in `airports` Table**
```sql
-- Verify all airport IATA codes exist
-- Common airports that should exist:
SELECT iata_code, name 
FROM airports 
WHERE iata_code IN ('JFK', 'LAX', 'LHR', 'DXB', 'NRT', 'CDG', 'FRA', 'SYD', ...)
ORDER BY iata_code;
```

---

## 🛠️ **Action Items for Supabase**

### **Priority 1: Data Population** 🔴 CRITICAL

1. **Populate `airlines` Table:**
   - Ensure ALL airlines from your manual input exist
   - Include: IATA code, name, ICAO code (if available), country (if available), logo URL
   - Use the comprehensive list from `lib/services/supabase_service.dart` `_getAirlineDetailsLocal()` method

2. **Populate `airports` Table:**
   - Ensure ALL airports from boarding passes exist
   - Include: IATA code, name, city, country
   - Common airports: JFK, LAX, LHR, DXB, NRT, CDG, FRA, SYD, etc.

### **Priority 2: Data Validation** 🟡 IMPORTANT

1. **Run Foreign Key Checks:**
   - Verify no orphaned records in `flights` table
   - Verify no orphaned records in `journeys` table
   - Fix any broken foreign key references

2. **Verify Data Completeness:**
   - Check that all airlines in leaderboard exist in `airlines` table
   - Check that all airports referenced in flights exist in `airports` table

### **Priority 3: Code Updates** 🟢 LOW PRIORITY

1. **Update Code That Reads `media` Column:**
   - Search for: `journey['media']`, `ciriumData`, `media column`
   - Files to check:
     - `lib/services/phase_feedback_service.dart` (line 273-283)
     - `lib/services/supabase_service.dart` (line 870, 123)
   - **Action:** Ensure code handles NULL or boarding pass data in `media` column

2. **Remove Cirium API Calls:**
   - Files still referencing Cirium (for cleanup):
     - `lib/services/cirium_flight_tracking_service.dart` (can be deprecated)
     - `lib/controller/fetch_flight_info_by_cirium.dart` (can be deprecated)
     - `lib/services/cirium_api_service.dart` (can be deprecated)
   - **Action:** These can remain but won't be called - safe to leave for now

---

## 📋 **Migration Checklist**

### **Pre-Migration:**
- [ ] Export current `airlines` table data
- [ ] Export current `airports` table data
- [ ] Document all IATA codes used in your app
- [ ] Document all airport codes used in your app

### **Migration Steps:**
- [ ] Populate `airlines` table with all required airlines
- [ ] Populate `airports` table with all required airports
- [ ] Run foreign key validation queries
- [ ] Fix any orphaned records
- [ ] Test journey creation with manual input
- [ ] Verify leaderboard still works
- [ ] Verify feedback submission still works

### **Post-Migration:**
- [ ] Monitor for missing airline/airport errors
- [ ] Add missing airlines/airports as they appear
- [ ] Update code that reads `media` column (if needed)
- [ ] Remove Cirium API code (optional cleanup)

---

## 🔍 **What Could Break**

### **High Risk:**
1. **Journey Creation Fails:**
   - If airline IATA code doesn't exist in `airlines` table
   - If airport IATA code doesn't exist in `airports` table
   - **Fix:** Add missing airline/airport to respective table

2. **Foreign Key Violations:**
   - If `flight_id` in `journeys` references non-existent flight
   - If `airline_id` in `flights` references non-existent airline
   - If `airport_id` in `flights` references non-existent airport
   - **Fix:** Ensure all foreign keys reference existing records

### **Medium Risk:**
1. **Missing Data in `media` Column:**
   - Code expecting Cirium data in `media` column may fail
   - **Fix:** Update code to handle NULL or boarding pass data

2. **Leaderboard Missing Airlines:**
   - If airline in leaderboard doesn't exist in `airlines` table
   - **Fix:** Ensure all leaderboard airlines exist in `airlines` table

### **Low Risk:**
1. **Optional Fields NULL:**
   - `aircraft_type`, `terminal`, `gate` may be NULL (not in boarding pass)
   - **Impact:** Minimal - these are optional fields
   - **Fix:** None needed - code already handles NULL

---

## 📝 **SQL Scripts for Verification**

### **Check Missing Airlines:**
```sql
-- Find airlines referenced in flights but missing from airlines table
SELECT DISTINCT f.carrier_code
FROM flights f
LEFT JOIN airlines a ON f.carrier_code = a.iata_code
WHERE a.iata_code IS NULL AND f.carrier_code IS NOT NULL;
```

### **Check Missing Airports:**
```sql
-- Find airports referenced in flights but missing from airports table
SELECT DISTINCT f.departure_airport, f.arrival_airport
FROM flights f
WHERE (f.departure_airport IS NOT NULL 
  AND NOT EXISTS (SELECT 1 FROM airports WHERE iata_code = f.departure_airport))
OR (f.arrival_airport IS NOT NULL 
  AND NOT EXISTS (SELECT 1 FROM airports WHERE iata_code = f.arrival_airport));
```

### **Check Data Completeness:**
```sql
-- Count airlines
SELECT COUNT(*) as total_airlines FROM airlines;

-- Count airports
SELECT COUNT(*) as total_airports FROM airports;

-- Count flights
SELECT COUNT(*) as total_flights FROM flights;

-- Count journeys
SELECT COUNT(*) as total_journeys FROM journeys;
```

---

## ✅ **Summary**

**What You Need to Do:**
1. ✅ **Populate `airlines` table** - Ensure all airlines from manual input exist
2. ✅ **Populate `airports` table** - Ensure all airports from boarding passes exist
3. ✅ **Verify foreign keys** - Run validation queries
4. ⚠️ **Update code** - Handle NULL/boarding pass data in `media` column (if needed)

**What Won't Break:**
- ✅ Leaderboard (uses `airlines` table - you're populating it)
- ✅ Feedback submission (uses `airlines` and `airports` tables)
- ✅ Journey creation (as long as airlines/airports exist)

**What Might Break:**
- ⚠️ Journey creation if airline/airport doesn't exist
- ⚠️ Code reading Cirium data from `media` column (needs fallback)

**No Schema Changes Needed:**
- ✅ All table structures are compatible with manual input
- ✅ Foreign key relationships remain the same
- ✅ Column types and constraints are fine

