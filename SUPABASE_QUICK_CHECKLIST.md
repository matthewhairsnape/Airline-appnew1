# Supabase Quick Checklist - Post Cirium Removal

## 🎯 **What You MUST Do in Supabase**

### ✅ **1. Populate `airlines` Table** (CRITICAL)
**Why:** App looks up airlines by IATA code. If missing, journey creation fails.

**Action:**
```sql
-- Check what airlines you have
SELECT iata_code, name FROM airlines ORDER BY iata_code;

-- Add missing airlines (use your manual input list)
INSERT INTO airlines (iata_code, name, icao_code, country, logo_url)
VALUES 
  ('NH', 'All Nippon Airways (ANA)', 'ANA', 'Japan', 'https://images.kiwi.com/airlines/256/NH.png'),
  ('LH', 'Lufthansa', 'DLH', 'Germany', 'https://images.kiwi.com/airlines/256/LH.png'),
  -- Add all airlines from your manual input
ON CONFLICT (iata_code) DO UPDATE 
SET name = EXCLUDED.name, 
    logo_url = EXCLUDED.logo_url;
```

**Required Fields:**
- `iata_code` (REQUIRED) - Must match carrier codes from boarding passes
- `name` (REQUIRED) - Full airline name
- `icao_code` (optional)
- `country` (optional)
- `logo_url` (optional) - Use: `https://images.kiwi.com/airlines/256/{IATA}.png`

---

### ✅ **2. Populate `airports` Table** (CRITICAL)
**Why:** App looks up airports by IATA code. If missing, journey creation fails.

**Action:**
```sql
-- Check what airports you have
SELECT iata_code, name FROM airports ORDER BY iata_code;

-- Add missing airports (common ones)
INSERT INTO airports (iata_code, name, city, country)
VALUES 
  ('JFK', 'John F. Kennedy International Airport', 'New York', 'United States'),
  ('LAX', 'Los Angeles International Airport', 'Los Angeles', 'United States'),
  ('LHR', 'London Heathrow Airport', 'London', 'United Kingdom'),
  ('DXB', 'Dubai International Airport', 'Dubai', 'United Arab Emirates'),
  -- Add all airports from boarding passes
ON CONFLICT (iata_code) DO NOTHING;
```

**Required Fields:**
- `iata_code` (REQUIRED) - Must match airport codes from boarding passes
- `name` (REQUIRED) - Airport name
- `city` (optional)
- `country` (optional)

---

### ✅ **3. Verify Foreign Keys** (IMPORTANT)
**Why:** Broken foreign keys cause insert/update failures.

**Action:**
```sql
-- Check for broken airline references
SELECT f.id, f.airline_id, f.flight_number
FROM flights f
LEFT JOIN airlines a ON f.airline_id = a.id
WHERE a.id IS NULL;

-- Check for broken airport references
SELECT f.id, f.departure_airport_id, f.arrival_airport_id
FROM flights f
LEFT JOIN airports dep ON f.departure_airport_id = dep.id
LEFT JOIN airports arr ON f.arrival_airport_id = arr.id
WHERE dep.id IS NULL OR arr.id IS NULL;

-- Check for broken flight references in journeys
SELECT j.id, j.flight_id, j.pnr
FROM journeys j
LEFT JOIN flights f ON j.flight_id = f.id
WHERE f.id IS NULL;
```

**If you find broken references:** Fix them by:
- Adding missing airlines/airports
- Or updating flights/journeys to reference existing records

---

## 📊 **What Changed in Data Flow**

### **Before (Cirium):**
1. Scan boarding pass → Extract carrier, flight number, airports
2. Call Cirium API → Get full flight data (aircraft, gates, terminals, times)
3. Auto-create airline/airport if missing (from Cirium data)
4. Store Cirium response in `journeys.media` column

### **After (Manual):**
1. Scan boarding pass → Extract carrier, flight number, airports
2. Lookup airline in `airlines` table (MUST exist)
3. Lookup airports in `airports` table (MUST exist)
4. Create flight record (from boarding pass data only)
5. Store boarding pass data in `journeys.media` column (or NULL)

---

## ⚠️ **What Could Break**

### **Will Break:**
1. ❌ **Journey creation fails** if:
   - Airline IATA code not in `airlines` table
   - Airport IATA code not in `airports` table
   - **Fix:** Add missing airline/airport

2. ❌ **Foreign key violations** if:
   - `flight_id` references non-existent flight
   - `airline_id` references non-existent airline
   - `airport_id` references non-existent airport
   - **Fix:** Run validation queries above

### **Won't Break:**
1. ✅ **Leaderboard** - Uses `airlines` table (you're populating it)
2. ✅ **Feedback submission** - Uses `airlines` and `airports` tables
3. ✅ **Journey viewing** - Uses foreign key relationships (unchanged)

### **Might Need Code Update:**
1. ⚠️ **Code reading `media` column** - May expect Cirium data
   - **Files:** `lib/services/phase_feedback_service.dart` (line 273)
   - **Action:** Ensure code handles NULL or boarding pass data

---

## 🔍 **Quick Validation Queries**

```sql
-- Count your data
SELECT 
  (SELECT COUNT(*) FROM airlines) as airlines_count,
  (SELECT COUNT(*) FROM airports) as airports_count,
  (SELECT COUNT(*) FROM flights) as flights_count,
  (SELECT COUNT(*) FROM journeys) as journeys_count;

-- Find journeys with missing airlines
SELECT DISTINCT j.id, f.carrier_code
FROM journeys j
JOIN flights f ON j.flight_id = f.id
LEFT JOIN airlines a ON f.carrier_code = a.iata_code
WHERE a.iata_code IS NULL;

-- Find flights with missing airports
SELECT f.id, f.departure_airport_id, f.arrival_airport_id
FROM flights f
LEFT JOIN airports dep ON f.departure_airport_id = dep.id
LEFT JOIN airports arr ON f.arrival_airport_id = arr.id
WHERE dep.id IS NULL OR arr.id IS NULL;
```

---

## ✅ **Final Checklist**

- [ ] All airlines from manual input exist in `airlines` table
- [ ] All airports from boarding passes exist in `airports` table
- [ ] No broken foreign key references (run validation queries)
- [ ] Test journey creation with a sample boarding pass
- [ ] Verify leaderboard displays correctly
- [ ] Verify feedback submission works

---

## 📝 **No Schema Changes Needed**

✅ All table structures are compatible with manual input
✅ Foreign key relationships remain the same
✅ Column types and constraints are fine
✅ Only data population is required

