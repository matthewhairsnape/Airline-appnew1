# Fix Leaderboard Logos - Supabase Setup

## Problem
Airline logos aren't showing because:
1. Airlines in `leaderboard_rankings` table don't exist in `airlines` table
2. OR airlines exist but don't have `logo_url` or `iata_code` populated

## Solution
Populate the `airlines` table in Supabase with all airlines from your leaderboard.

---

## Step 1: Check What Airlines Are Missing

Run this SQL in Supabase to see which airlines are referenced in leaderboard but missing from airlines table:

```sql
-- Find airline_ids in leaderboard_rankings that don't exist in airlines table
SELECT DISTINCT lr.airline_id, lr.category
FROM leaderboard_rankings lr
LEFT JOIN airlines a ON lr.airline_id = a.id
WHERE a.id IS NULL
AND lr.is_active = true
LIMIT 50;
```

---

## Step 2: Populate Airlines Table

### Option A: Insert All Airlines from Your Leaderboard Data

Based on your local seed data, here are the airlines you need:

```sql
-- Insert all airlines from leaderboard (with logos)
INSERT INTO airlines (iata_code, name, icao_code, country, logo_url)
VALUES 
  -- First Class airlines
  ('NH', 'All Nippon Airways (ANA)', 'ANA', 'Japan', 'https://images.kiwi.com/airlines/256/NH.png'),
  ('LH', 'Lufthansa', 'DLH', 'Germany', 'https://images.kiwi.com/airlines/256/LH.png'),
  ('EK', 'Emirates', 'UAE', 'United Arab Emirates', 'https://images.kiwi.com/airlines/256/EK.png'),
  ('AS', 'Alaska Airlines', 'ASA', 'United States', 'https://images.kiwi.com/airlines/256/AS.png'),
  ('LX', 'Swiss International Air Lines', 'SWR', 'Switzerland', 'https://images.kiwi.com/airlines/256/LX.png'),
  ('QR', 'Qatar Airways', 'QTR', 'Qatar', 'https://images.kiwi.com/airlines/256/QR.png'),
  ('AF', 'Air France', 'AFR', 'France', 'https://images.kiwi.com/airlines/256/AF.png'),
  ('QF', 'Qantas Airways', 'QFA', 'Australia', 'https://images.kiwi.com/airlines/256/QF.png'),
  ('KE', 'Korean Air', 'KAL', 'South Korea', 'https://images.kiwi.com/airlines/256/KE.png'),
  ('GF', 'Gulf Air', 'GFA', 'Bahrain', 'https://images.kiwi.com/airlines/256/GF.png'),
  ('BA', 'British Airways', 'BAW', 'United Kingdom', 'https://images.kiwi.com/airlines/256/BA.png'),
  ('TG', 'Thai Airways', 'THA', 'Thailand', 'https://images.kiwi.com/airlines/256/TG.png'),
  ('SQ', 'Singapore Airlines', 'SIA', 'Singapore', 'https://images.kiwi.com/airlines/256/SQ.png'),
  ('CA', 'Air China', 'CCA', 'China', 'https://images.kiwi.com/airlines/256/CA.png'),
  
  -- Business Class airlines
  ('5W', 'Wizz Air Abu Dhabi', 'WAZ', 'United Arab Emirates', 'https://images.kiwi.com/airlines/256/5W.png'),
  ('TW', 'TWB Airlines', 'TWB', NULL, 'https://images.kiwi.com/airlines/256/TW.png'),
  ('U6', 'Ural Airlines', 'SVR', 'Russia', 'https://images.kiwi.com/airlines/256/U6.png'),
  ('AD', 'Azul Brazilian Airlines', 'AZU', 'Brazil', 'https://images.kiwi.com/airlines/256/AD.png'),
  ('UK', 'Vistara', 'VTI', 'India', 'https://images.kiwi.com/airlines/256/UK.png'),
  ('FI', 'Icelandair', 'ICE', 'Iceland', 'https://images.kiwi.com/airlines/256/FI.png'),
  ('D7', 'AirAsia X', 'XAX', 'Malaysia', 'https://images.kiwi.com/airlines/256/D7.png'),
  ('BT', 'airBaltic', 'BTI', 'Latvia', 'https://images.kiwi.com/airlines/256/BT.png'),
  ('JX', 'StarLux', 'SJX', 'Taiwan', 'https://images.kiwi.com/airlines/256/JX.png'),
  ('HY', 'Uzbekistan Airways', 'UZB', 'Uzbekistan', 'https://images.kiwi.com/airlines/256/HY.png'),
  ('CZ', 'China Southern Airlines', 'CSN', 'China', 'https://images.kiwi.com/airlines/256/CZ.png'),
  ('SU', 'Aeroflot', 'AFL', 'Russia', 'https://images.kiwi.com/airlines/256/SU.png'),
  ('EY', 'Etihad Airways', 'ETD', 'United Arab Emirates', 'https://images.kiwi.com/airlines/256/EY.png'),
  ('OU', 'Croatia Airlines', 'CTN', 'Croatia', 'https://images.kiwi.com/airlines/256/OU.png'),
  ('AY', 'Finnair', 'FIN', 'Finland', 'https://images.kiwi.com/airlines/256/AY.png'),
  ('SV', 'Saudia', 'SVA', 'Saudi Arabia', 'https://images.kiwi.com/airlines/256/SV.png'),
  ('ET', 'Ethiopian Airlines', 'ETH', 'Ethiopia', 'https://images.kiwi.com/airlines/256/ET.png'),
  
  -- Premium Economy airlines
  ('LY', 'El Al', 'ELY', 'Israel', 'https://images.kiwi.com/airlines/256/LY.png'),
  ('V7', 'Volotea', 'VOE', 'Spain', 'https://images.kiwi.com/airlines/256/V7.png'),
  ('JQ', 'Jetstar Airways', 'JST', 'Australia', 'https://images.kiwi.com/airlines/256/JQ.png'),
  ('J2', 'Azerbaijan Airlines', 'AHY', 'Azerbaijan', 'https://images.kiwi.com/airlines/256/J2.png'),
  ('FA', 'FlySafair', 'SFR', 'South Africa', 'https://images.kiwi.com/airlines/256/FA.png'),
  ('NO', 'Neos', 'NOS', 'Italy', 'https://images.kiwi.com/airlines/256/NO.png'),
  ('JL', 'Japan Airlines', 'JAL', 'Japan', 'https://images.kiwi.com/airlines/256/JL.png'),
  ('F3', 'flyadeal', 'FAD', 'Saudi Arabia', 'https://images.kiwi.com/airlines/256/F3.png'),
  ('B6', 'JetBlue Airways', 'JBU', 'United States', 'https://images.kiwi.com/airlines/256/B6.png'),
  
  -- Economy airlines
  ('GA', 'Garuda Indonesia', 'GIA', 'Indonesia', 'https://images.kiwi.com/airlines/256/GA.png'),
  ('VS', 'Virgin Atlantic', 'VIR', 'United Kingdom', 'https://images.kiwi.com/airlines/256/VS.png'),
  ('NZ', 'Air New Zealand', 'ANZ', 'New Zealand', 'https://images.kiwi.com/airlines/256/NZ.png'),
  ('UO', 'Hong Kong Express', 'HKE', 'Hong Kong', 'https://images.kiwi.com/airlines/256/UO.png'),
  ('QZ', 'Indonesia AirAsia', 'AWQ', 'Indonesia', 'https://images.kiwi.com/airlines/256/QZ.png'),
  ('7C', 'Jeju Air', 'JJA', 'South Korea', 'https://images.kiwi.com/airlines/256/7C.png'),
  ('G9', 'Air Arabia', 'ABY', 'United Arab Emirates', 'https://images.kiwi.com/airlines/256/G9.png'),
  ('VA', 'Virgin Australia', 'VOZ', 'Australia', 'https://images.kiwi.com/airlines/256/VA.png'),
  ('BR', 'EVA Air', 'EVA', 'Taiwan', 'https://images.kiwi.com/airlines/256/BR.png'),
  
  -- Airport Experience airlines
  ('N4', 'Nordwind Airlines', 'NWS', 'Russia', 'https://images.kiwi.com/airlines/256/N4.png'),
  ('BX', 'Air Busan', 'ABL', 'South Korea', 'https://images.kiwi.com/airlines/256/BX.png'),
  ('XY', 'Flynas', 'KNE', 'Saudi Arabia', 'https://images.kiwi.com/airlines/256/XY.png'),
  ('PG', 'Bangkok Airways', 'BKP', 'Thailand', 'https://images.kiwi.com/airlines/256/PG.png'),
  ('TO', 'Transavia France', 'TVF', 'France', 'https://images.kiwi.com/airlines/256/TO.png'),
  ('FD', 'Thai AirAsia', 'AIQ', 'Thailand', 'https://images.kiwi.com/airlines/256/FD.png'),
  ('WZ', 'Red Wings Airlines', 'RWZ', 'Russia', 'https://images.kiwi.com/airlines/256/WZ.png'),
  ('DL', 'Delta Air Lines', 'DAL', 'United States', 'https://images.kiwi.com/airlines/256/DL.png'),
  
  -- F&B airlines
  ('GK', 'Jetstar Japan', 'JJP', 'Japan', 'https://images.kiwi.com/airlines/256/GK.png'),
  ('W9', 'Wizz Air UK', 'WUK', 'United Kingdom', 'https://images.kiwi.com/airlines/256/W9.png'),
  ('HY', 'Uzbekistan Airways', 'UZB', 'Uzbekistan', 'https://images.kiwi.com/airlines/256/HY.png'),
  ('B2', 'Belavia', 'BRU', 'Belarus', 'https://images.kiwi.com/airlines/256/B2.png'),
  ('DE', 'Condor', 'CFG', 'Germany', 'https://images.kiwi.com/airlines/256/DE.png'),
  ('OZ', 'Asiana Airlines', 'AAR', 'South Korea', 'https://images.kiwi.com/airlines/256/OZ.png'),
  ('KC', 'Air Astana', 'KZR', 'Kazakhstan', 'https://images.kiwi.com/airlines/256/KC.png'),
  ('AK', 'AirAsia', 'AXM', 'Malaysia', 'https://images.kiwi.com/airlines/256/AK.png'),
  ('AT', 'Royal Air Maroc', 'RAM', 'Morocco', 'https://images.kiwi.com/airlines/256/AT.png'),
  ('TK', 'Turkish Airlines', 'THY', 'Turkey', 'https://images.kiwi.com/airlines/256/TK.png'),
  
  -- Seat Comfort airlines
  ('LZ', 'Bulgaria Air', 'LZB', 'Bulgaria', 'https://images.kiwi.com/airlines/256/LZ.png'),
  ('EN', 'Air Dolomiti', 'DLA', 'Italy', 'https://images.kiwi.com/airlines/256/EN.png'),
  ('G3', 'GOL Linhas Aéreas', 'GLO', 'Brazil', 'https://images.kiwi.com/airlines/256/G3.png'),
  ('EI', 'Aer Lingus', 'EIN', 'Ireland', 'https://images.kiwi.com/airlines/256/EI.png'),
  ('CX', 'Cathay Pacific', 'CPA', 'Hong Kong', 'https://images.kiwi.com/airlines/256/CX.png'),
  ('CI', 'China Airlines', 'CAL', 'Taiwan', 'https://images.kiwi.com/airlines/256/CI.png'),
  
  -- IFE and Wifi airlines
  ('WN', 'Southwest Airlines', 'SWA', 'United States', 'https://images.kiwi.com/airlines/256/WN.png'),
  ('TR', 'Scoot', 'SCO', 'Singapore', 'https://images.kiwi.com/airlines/256/TR.png'),
  ('AM', 'Aeroméxico', 'AMX', 'Mexico', 'https://images.kiwi.com/airlines/256/AM.png'),
  ('UA', 'United Airlines', 'UAL', 'United States', 'https://images.kiwi.com/airlines/256/UA.png'),
  ('AA', 'American Airlines', 'AAL', 'United States', 'https://images.kiwi.com/airlines/256/AA.png'),
  
  -- Onboard Service airlines
  ('DY', 'Norwegian Air Shuttle', 'NAX', 'Norway', 'https://images.kiwi.com/airlines/256/DY.png'),
  ('Y4', 'Volaris', 'VOI', 'Mexico', 'https://images.kiwi.com/airlines/256/Y4.png'),
  ('KL', 'KLM Royal Dutch Airlines', 'KLM', 'Netherlands', 'https://images.kiwi.com/airlines/256/KL.png'),
  ('SK', 'SAS - Scandinavian Airlines', 'SAS', 'Sweden', 'https://images.kiwi.com/airlines/256/SK.png'),
  
  -- Cleanliness airlines
  ('VN', 'Vietnam Airlines', 'HVN', 'Vietnam', 'https://images.kiwi.com/airlines/256/VN.png'),
  ('FZ', 'flydubai', 'FDB', 'United Arab Emirates', 'https://images.kiwi.com/airlines/256/FZ.png'),
  ('F9', 'Frontier Airlines', 'FFT', 'United States', 'https://images.kiwi.com/airlines/256/F9.png'),
  ('I2', 'Iberia Express', 'IBS', 'Spain', 'https://images.kiwi.com/airlines/256/I2.png'),
  ('LJ', 'Jin Air', 'JNA', 'South Korea', 'https://images.kiwi.com/airlines/256/LJ.png')
ON CONFLICT (iata_code) DO UPDATE 
SET 
  name = EXCLUDED.name,
  logo_url = EXCLUDED.logo_url,
  icao_code = COALESCE(EXCLUDED.icao_code, airlines.icao_code),
  country = COALESCE(EXCLUDED.country, airlines.country);
```

### Option B: Update Existing Airlines with Logos

If airlines already exist but don't have logos:

```sql
-- Update existing airlines with logo URLs based on IATA code
UPDATE airlines
SET logo_url = 'https://images.kiwi.com/airlines/256/' || UPPER(iata_code) || '.png'
WHERE logo_url IS NULL 
AND iata_code IS NOT NULL 
AND LENGTH(iata_code) >= 2;
```

---

## Step 3: Verify the Fix

Run these queries to verify:

```sql
-- Check airlines with logos
SELECT iata_code, name, logo_url 
FROM airlines 
WHERE logo_url IS NOT NULL 
ORDER BY iata_code;

-- Check leaderboard rankings that can't find airlines
SELECT DISTINCT lr.airline_id, lr.category
FROM leaderboard_rankings lr
LEFT JOIN airlines a ON lr.airline_id = a.id
WHERE a.id IS NULL
AND lr.is_active = true;
```

---

## How Logo Resolution Works

The app tries to get logos in this order:

1. **From Supabase `airlines.logo_url`** (if populated)
2. **From local override map** (if IATA code matches)
3. **From CDN using IATA code**: `https://images.kiwi.com/airlines/256/{IATA}.png`
4. **From CDN using ICAO code**: `https://images.kiwi.com/airlines/256/{ICAO}.png`
5. **Fallback icon** (if all fail)

---

## Important Notes

- The `airlines!inner()` join in the query requires airlines to exist in the `airlines` table
- If an airline doesn't exist, the entire leaderboard row is filtered out
- Ensure `iata_code` is populated (even if `logo_url` is NULL) so CDN fallback works
- Logo URLs use the Kiwi.com CDN which serves airline logos by IATA code

