# 🛬 How Landing Time is Calculated

## Overview

The landing time is calculated from Cirium API data based on **actual arrival times** from the `operationalTimes` object. The system prioritizes actual times over scheduled times and updates in real-time as the flight progresses.

## Data Source

The landing time comes from Cirium API's `operationalTimes` object in the flight status response:

```json
{
  "operationalTimes": {
    "actualGateArrival": {
      "dateLocal": "2025-11-05T22:30:00",
      "dateUtc": "2025-11-06T03:30:00Z"
    },
    "actualRunwayArrival": {
      "dateLocal": "2025-11-05T22:15:00",
      "dateUtc": "2025-11-06T03:15:00Z"
    },
    "estimatedGateArrival": {
      "dateLocal": "2025-11-05T22:30:00",
      "dateUtc": "2025-11-06T03:30:00Z"
    },
    "scheduledGateArrival": {
      "dateLocal": "2025-11-05T22:30:00",
      "dateUtc": "2025-11-06T03:30:00Z"
    }
  }
}
```

## Landing Time Calculation Logic

### Priority Order

The system extracts landing time in this **priority order** (most accurate first):

1. **`actualGateArrival`** (Highest Priority)
   - When the plane actually arrives at the gate
   - Most accurate for passenger arrival time
   - Used if available

2. **`actualRunwayArrival`** (Second Priority)
   - When the plane actually touches down on the runway
   - Actual landing time (wheels down)
   - Used if `actualGateArrival` is not available

3. **`estimatedGateArrival`** (Third Priority)
   - Estimated gate arrival time
   - Used if actual times are not yet available
   - More accurate than scheduled time

4. **`scheduledArrival`** (Fallback)
   - Original scheduled arrival time from `arrivalDate`
   - Used only if no actual/estimated times are available
   - This is the initial time shown when flight is first scanned

### Time Conversion

**CRITICAL: All times MUST be in UTC to UTC conversion**

All times are converted to **UTC** for consistency and accuracy:
- Cirium provides both `dateLocal` (airport timezone) and `dateUtc` (UTC timezone)
- **System ALWAYS prefers `dateUtc`** to ensure correct landing time regardless of user's location
- `dateLocal` is in the airport's local timezone (e.g., Dubai time), which can cause incorrect conversion when user is in different timezone
- If `dateUtc` is missing (uncommon), system falls back to `dateLocal` with a warning
- This ensures accurate duration calculations and prevents timezone offset errors
- **Example**: User in Dubai viewing flight landing in New York - using UTC ensures correct time regardless of user location

### Real-Time Updates

The landing time is updated in real-time during flight tracking:

1. **Initial Scan**: Uses `scheduledArrival` from `arrivalDate`
2. **During Flight**: Polls Cirium API every 30 seconds
3. **When Landing**: Updates to `actualRunwayArrival` (wheels down)
4. **At Gate**: Updates to `actualGateArrival` (final arrival time)

## Code Implementation

### Extraction Method

The landing time is extracted in `_extractActualArrivalTime()` method:

```dart
DateTime? _extractActualArrivalTime(Map<String, dynamic> flightStatus) {
  final operationalTimes = flightStatus['operationalTimes'] ?? {};
  
  // Priority 1: actualGateArrival (most accurate)
  if (operationalTimes['actualGateArrival'] != null) {
    final gateArrival = operationalTimes['actualGateArrival'] as Map<String, dynamic>;
    
    // CRITICAL: Always prefer dateUtc (UTC time) over dateLocal
    // dateLocal is in airport timezone, which can cause incorrect conversion
    // when user is in different timezone (e.g., Dubai vs New York)
    if (gateArrival['dateUtc'] != null) {
      final arrivalTime = DateTime.parse(gateArrival['dateUtc']);
      // Ensure it's UTC (should already be, but double-check)
      return arrivalTime.isUtc ? arrivalTime : DateTime.parse(gateArrival['dateUtc'] + 'Z');
    } else if (gateArrival['dateLocal'] != null) {
      // FALLBACK: If dateUtc not available, parse dateLocal but warn
      debugPrint('⚠️ WARNING: actualGateArrival missing dateUtc, using dateLocal (may be inaccurate)');
      final arrivalTime = DateTime.parse(gateArrival['dateLocal']);
      return arrivalTime.toUtc();
    }
  }
  
  // Priority 2: actualRunwayArrival (landing time)
  // (similar logic - always prefer dateUtc)
  
  // Priority 3: estimatedGateArrival
  // (similar logic - always prefer dateUtc)
  
  // Return null if no actual/estimated time available (use scheduled)
  return null;
}
```

### Real-Time Update Logic

During polling, the system checks if landing time has changed:

```dart
// Extract actual arrival time if available (real-time landing time)
DateTime? actualArrivalTime = _extractActualArrivalTime(flightStatus);

// Check if arrival time changed
final arrivalTimeChanged = actualArrivalTime != null && 
    actualArrivalTime != flight.arrivalTime;

if (arrivalTimeChanged) {
  debugPrint('🕐 Landing time updated: ${flight.arrivalTime} → $actualArrivalTime');
  
  // Update flight with new arrival time
  final updatedFlight = flight.copyWith(
    arrivalTime: actualArrivalTime ?? flight.arrivalTime,
    // ... other updates
  );
}
```

## Logging

When you check the logs, you'll see:

### 1. Full Cirium API Response
```
📡 CIRIUM API RESPONSE RECEIVED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✈️  Flight: DL755
📍 Route: ATL → JFK
📊 Status: L (Landed)
🕐 OPERATIONAL TIMES (for phase determination):
   actualGateArrival: 2025-11-05T22:30:00 ✅ USED FOR LANDING TIME
   actualRunwayArrival: 2025-11-05T22:15:00
   estimatedGateArrival: 2025-11-05T22:30:00
   scheduledGateArrival: 2025-11-05T22:30:00
```

### 2. Landing Time Extraction
```
✅ Found actual gate arrival time: 2025-11-06T03:30:00Z
🕐 Landing time updated: 2025-11-06T03:30:00Z → 2025-11-06T03:30:00Z
```

### 3. Visual Indicator

When actual landing time is available, the UI shows an update icon (🔄) next to the arrival time:
- **Green update icon**: Actual landing time detected
- **No icon**: Scheduled arrival time (not yet landed)

## Example Timeline

For a flight with scheduled arrival at `22:30:00`:

1. **Initial Scan** (before flight)
   - Landing time: `22:30:00` (scheduled)
   - Source: `scheduledArrival` from `arrivalDate`
   - No update icon

2. **During Flight** (in air)
   - Landing time: `22:30:00` (scheduled)
   - Source: `scheduledArrival` (no actual times yet)
   - No update icon

3. **After Landing** (wheels down)
   - Landing time: `22:15:00` (actual runway arrival)
   - Source: `actualRunwayArrival`
   - Update icon appears 🟢

4. **At Gate** (final arrival)
   - Landing time: `22:30:00` (actual gate arrival)
   - Source: `actualGateArrival` (most accurate)
   - Update icon remains 🟢

## Key Points

1. **Priority Order is Critical:**
   - `actualGateArrival` > `actualRunwayArrival` > `estimatedGateArrival` > `scheduledArrival`
   - This ensures the most accurate time is always shown

2. **Real-Time Updates:**
   - System polls Cirium API every 30 seconds during active flight tracking
   - Landing time updates automatically when actual times become available
   - UI refreshes to show the latest landing time

3. **UTC Time Handling (CRITICAL):**
   - All times are stored and calculated in UTC (UTC to UTC conversion)
   - System ALWAYS prefers `dateUtc` from Cirium API over `dateLocal`
   - `dateLocal` is in airport timezone and can cause incorrect conversion when user is in different timezone
   - Prevents timezone offset errors in duration calculations
   - UI displays in user's local timezone (conversion happens at display time)
   - **Example**: User in Dubai viewing flight landing in New York - using UTC ensures correct time

4. **Visual Feedback:**
   - Update icon (🔄) indicates actual landing time is available
   - Helps users distinguish between scheduled and actual times

## Troubleshooting

If landing time is not updating correctly, check logs for:

1. **Is actual time available?**
   - Check if `actualGateArrival` or `actualRunwayArrival` is in API response
   - Look for: `✅ Found actual gate arrival time: ...`

2. **Is polling active?**
   - Check if flight is being actively tracked
   - Look for: `🔄 Real-time update received: Landing time may have changed`

3. **Is time conversion correct?**
   - Verify times are in UTC format (check logs for "✅ Using arrival dateUtc")
   - Check for: `dateUtc` vs `dateLocal` in API response
   - If you see "⚠️ WARNING: missing dateUtc", Cirium API may not be providing UTC time
   - **CRITICAL**: Landing time must be in UTC to UTC to work correctly for users in different timezones

4. **Is UI updating?**
   - Check for: `🕐 Landing time updated: ... → ...`
   - Verify `setState()` is called in `my_journey_screen.dart`

The detailed logs will show all this information clearly.

## Relationship to Flight Duration

The landing time is critical for accurate flight duration calculation:

```dart
final duration = arrivalTimeUtc.difference(departureTimeUtc);
```

- **Before Landing**: Uses scheduled arrival → estimated duration
- **After Landing**: Uses actual arrival → actual duration
- **At Gate**: Uses actual gate arrival → final duration (includes taxi time)

This ensures flight duration is always accurate and updates in real-time.

