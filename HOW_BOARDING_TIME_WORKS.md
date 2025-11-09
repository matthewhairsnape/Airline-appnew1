# 🛫 How Boarding Time is Determined

## Overview

The boarding time is calculated from Cirium API data based on the **gate departure time** from the `operationalTimes` object.

## Data Source

The boarding time comes from Cirium API's `operationalTimes` object in the flight status response:

```json
{
  "operationalTimes": {
    "estimatedGateDeparture": {
      "dateLocal": "2025-11-05T14:30:00",
      "dateUtc": "2025-11-05T18:30:00Z"
    },
    "scheduledGateDeparture": {
      "dateLocal": "2025-11-05T14:30:00",
      "dateUtc": "2025-11-05T18:30:00Z"
    }
  }
}
```

## Boarding Time Calculation Logic

### Step 1: Get Gate Departure Time

The system looks for gate departure time in this priority order:
1. **`estimatedGateDeparture`** (preferred - more accurate)
2. **`scheduledGateDeparture`** (fallback - if estimated not available)

### Step 2: Calculate Boarding Start Time

**Boarding start time = Gate Departure Time - 1 hour**

Example:
- Gate Departure: `14:30:00`
- Boarding Start: `13:30:00` (1 hour before)

### Step 3: Determine if Boarding Has Started

Boarding phase is triggered when:
```
Current Time >= Boarding Start Time AND Current Time < Gate Departure Time
```

**Example:**
- Gate Departure: `14:30:00`
- Boarding Window: `13:30:00` → `14:30:00`
- Current Time: `14:00:00` ✅ **BOARDING PHASE**

## Logging

When you check the logs, you'll now see:

### 1. Full Cirium API Response
```
📡 CIRIUM API RESPONSE RECEIVED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✈️  Flight: DL755
📍 Route: ATL → JFK
📊 Status: L
🕐 OPERATIONAL TIMES:
   estimatedGateDeparture: 2025-11-05T14:30:00 ⚠️ USED FOR BOARDING
   scheduledGateDeparture: 2025-11-05T14:30:00 ⚠️ USED FOR BOARDING
📋 FULL RESPONSE JSON: {...}
```

### 2. Boarding Time Calculation
```
🔍 DETERMINING FLIGHT PHASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🕐 Current Time: 2025-11-05 14:00:00
🕐 Scheduled Departure Time: 2025-11-05 14:30:00
✅ Found gate departure time: 2025-11-05 14:30:00
   Source: estimatedGateDeparture
   Time until departure: 0h 30m
   ⏰ Boarding start time (1 hour before departure): 2025-11-05 13:30:00
   Is now after boarding start? true
   Is now before gate departure? true

✅ BOARDING PHASE DETECTED!
   Current time is within 1 hour window before gate departure
   Boarding window: 2025-11-05 13:30:00 → 2025-11-05 14:30:00
✅ Phase determined: BOARDING
```

## Key Points

1. **Boarding Time = Gate Departure - 1 hour**
   - This is a standard industry practice
   - Most airlines start boarding approximately 1 hour before departure

2. **Data Priority:**
   - `estimatedGateDeparture` is used if available (more accurate)
   - Falls back to `scheduledGateDeparture` if estimated is not available

3. **Time Window:**
   - Boarding phase is active from **1 hour before** gate departure until **gate departure time**
   - After gate departure, flight moves to `departed` phase
   - Once runway departure occurs, flight moves to `inFlight` phase

## Example Timeline

For a flight with gate departure at `14:30:00`:

- `13:29:59` → **CHECK_IN_OPEN** (if within check-in window)
- `13:30:00` → **BOARDING** (1 hour before gate departure)
- `14:30:00` → **DEPARTED** (gate departure time)
- `14:35:00` → **IN_FLIGHT** (runway departure)

## Troubleshooting

If boarding time is not showing correctly, check logs for:
1. Is `estimatedGateDeparture` or `scheduledGateDeparture` present in API response?
2. What is the current time vs. gate departure time?
3. Is the current time within the 1-hour window?

The detailed logs will show all this information clearly.

