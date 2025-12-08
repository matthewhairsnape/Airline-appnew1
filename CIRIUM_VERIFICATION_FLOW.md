# Cirium API Verification Flow for Boarding Pass Scanning

## Overview

**YES, the app DOES verify boarding pass data with the Cirium API** when a new boarding pass is scanned. This document explains the complete verification flow.

## Verification Process

### Step 1: Boarding Pass Scanning
When a user scans a boarding pass barcode:
- Location: `lib/screen/reviewsubmission/scanner_screen/scanner_screen.dart`
- The barcode is parsed to extract:
  - PNR (Passenger Name Record)
  - Carrier code (e.g., "AA", "DL")
  - Flight number
  - Departure airport code
  - Flight date
  - Seat number
  - Class of service

### Step 2: Flight Identifier Validation
**Before** calling Cirium API, the app validates the extracted data:
```dart
// Line 348-358 in scanner_screen.dart
if (!_isValidFlightIdentifier(carrier, flightNumber)) {
  debugPrint("❌ Invalid flight identifier");
  // Shows error and restarts scanner
  return;
}
```

### Step 3: Cirium API Call
The app makes a **real-time API call** to Cirium to verify and fetch flight data:

**Location**: `lib/controller/fetch_flight_info_by_cirium.dart`

**API Endpoints Used**:
1. **Real-time API** (for current/future flights):
   ```
   https://api.flightstats.com/flex/flightstatus/rest/v3/json/flight/status/{carrier}/{flightNumber}/dep/{year}/{month}/{day}
   ```

2. **Historical API** (for past flights > 1 day old):
   ```
   https://api.flightstats.com/flex/flightstatus/historical/rest/v3/json/flight/status/{carrier}/{flightNumber}/dep/{year}/{month}/{day}
   ```

**Code Flow** (Lines 388-415 in scanner_screen.dart):
```dart
// Try the scanned date first
try {
  Map<String, dynamic> flightInfo =
      await _fetchFlightInfo.fetchFlightInfo(
    carrier: carrier,
    flightNumber: flightNumber,
    flightDate: date,
    departureAirport: departureAirport,
  );

  // Check if flight data was found
  if (flightInfo['flightStatuses']?.isEmpty ?? true) {
    debugPrint("❌ No flight found in Cirium");
    // Falls back to offline mode
    return;
  }

  debugPrint("✅ Found flight data with ${flightInfo['flightStatuses'].length} status(es)");

  // Process the verified flight data
  await _processFetchedFlightInfo(flightInfo, ...);
}
```

### Step 4: Verification Results

#### ✅ **Success Case**: Flight Found in Cirium
- Cirium API returns flight status data
- App extracts verified information:
  - **Airline name** (from Cirium appendix)
  - **Departure airport** (verified)
  - **Arrival airport** (from Cirium)
  - **Departure time** (actual/scheduled from Cirium)
  - **Arrival time** (actual/scheduled from Cirium)
  - **Flight status** (on-time, delayed, cancelled, etc.)
  - **Gate information** (if available)
  - **Terminal information** (if available)
  - **Aircraft type** (if available)

- This verified data is then:
  1. Saved to Supabase database
  2. Used to create a journey entry
  3. Starts real-time flight tracking
  4. Shows confirmation dialog with verified data

#### ❌ **Failure Case**: Flight Not Found or API Error
- If Cirium API fails or returns no data:
  - App falls back to **offline mode**
  - Uses only the data extracted from boarding pass barcode
  - Shows message: "Live flight status is unavailable. We're showing the details from your boarding pass only."
  - Still saves the journey but without real-time updates

### Step 5: Data Processing
**Location**: `_processFetchedFlightInfo()` method (Line 825+)

When Cirium data is successfully retrieved:
1. **Extracts flight status** from `flightInfo['flightStatuses'][0]`
2. **Gets airline name** from Cirium appendix data
3. **Gets airport details** from Cirium appendix data
4. **Extracts operational times** (departure/arrival)
5. **Creates journey** in Supabase with verified data
6. **Starts flight tracking** using `CiriumFlightTrackingService`

## What Gets Verified

### ✅ Verified from Cirium:
- **Flight exists** and is valid
- **Airline name** (official name from Cirium)
- **Route** (departure → arrival airports)
- **Flight times** (scheduled and actual)
- **Flight status** (on-time, delayed, cancelled, etc.)
- **Gate and terminal** (if available)
- **Aircraft information** (if available)

### 📱 From Boarding Pass Only (if Cirium fails):
- PNR
- Carrier code
- Flight number
- Departure airport
- Flight date
- Seat number
- Class of service

## Logging

The app logs the entire verification process:
- `➡️ Cirium lookup: [carrier][flightNumber] on [date] from [airport]`
- `📦 Cirium response: [response data]`
- `✅ Found flight data with [count] status(es)`
- `❌ No flight found in Cirium` (if not found)
- `⚠️ Cirium lookup failed` (if API error)

## Benefits of Cirium Verification

1. **Data Accuracy**: Ensures flight data is correct and up-to-date
2. **Real-time Updates**: Enables live flight status tracking
3. **Error Detection**: Catches invalid or incorrect boarding pass data
4. **Enhanced Information**: Provides gate, terminal, aircraft type, etc.
5. **Status Monitoring**: Tracks delays, cancellations, gate changes

## Fallback Behavior

If Cirium verification fails:
- App **does not block** the user
- Uses boarding pass data as fallback
- Still creates journey entry
- Shows clear message about offline mode
- User can manually verify later

## Summary

**YES, the app verifies boarding pass data with Cirium API** every time a new boarding pass is scanned. The verification:

1. ✅ Validates flight identifiers first
2. ✅ Calls Cirium API (real-time or historical)
3. ✅ Verifies flight exists and extracts detailed data
4. ✅ Uses verified data to create journey
5. ✅ Falls back gracefully if verification fails

This ensures data accuracy and enables real-time flight tracking features.

