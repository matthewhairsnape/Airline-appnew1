# Data Saving Flow - From Boarding Pass Scan to Database

This document explains the complete flow of how data is saved when a boarding pass is scanned.

## Overview

When a user scans a boarding pass, the data goes through multiple steps before being saved to the database. This flow ensures data integrity, prevents duplicates, and maintains relationships between different entities.

## Complete Flow Diagram

```
1. Boarding Pass Scan
   ↓
2. Barcode Parsing & Data Extraction
   ↓
3. Cirium API Verification
   ↓
4. Data Processing & Validation
   ↓
5. Local Storage (BoardingPass)
   ↓
6. Supabase Database Save
   ├──→ 6a. Get/Create Airline
   ├──→ 6b. Get/Create Airports (Departure & Arrival)
   ├──→ 6c. Get/Create Flight
   ├──→ 6d. Duplicate Check (PNR + flight_id + seat_number)
   ├──→ 6e. Create Journey
   └──→ 6f. Create Journey Event
   ↓
7. Start Flight Tracking
   ↓
8. Show Confirmation Dialog
```

## Step-by-Step Flow

### Step 1: Boarding Pass Scan
**Location**: `lib/screen/reviewsubmission/scanner_screen/scanner_screen.dart`

- User scans boarding pass barcode (QR code, PDF417, etc.)
- Barcode data is captured and parsed
- Extracted data includes:
  - PNR (Passenger Name Record)
  - Carrier code (e.g., "AA", "DL")
  - Flight number
  - Departure airport code
  - Arrival airport code (if available)
  - Flight date
  - Seat number
  - Class of service

### Step 2: Cirium API Verification
**Location**: `lib/controller/fetch_flight_info_by_cirium.dart`

- App calls Cirium API to verify flight data
- Retrieves real-time flight information:
  - Airline name
  - Airport details (departure & arrival)
  - Scheduled/actual departure times
  - Scheduled/actual arrival times
  - Gate and terminal information
  - Aircraft type
  - Flight status

**See**: `CIRIUM_VERIFICATION_FLOW.md` for detailed verification process

### Step 3: Data Processing
**Location**: `_processFetchedFlightInfo()` method (Line 825+)

After Cirium verification, the app processes the data:

1. **Extracts flight status** from Cirium response
2. **Gets airline name** from Cirium appendix data
3. **Gets airport details** (city, country, etc.) from Cirium
4. **Extracts operational times** (departure/arrival)
5. **Creates BoardingPass object** with all verified data

### Step 4: Local Storage (BoardingPass)
**Location**: `lib/controller/boarding_pass_controller.dart`

```dart
// Line 926 in scanner_screen.dart
final result = await _boardingPassController.saveBoardingPass(newPass);
```

- Saves boarding pass data to local device storage
- Used for offline access and quick retrieval
- Format: `BoardingPass` model

### Step 5: Supabase Database Save
**Location**: `lib/services/supabase_service.dart`

The main database save happens through `createJourney()` method:

```dart
// Line 931 in scanner_screen.dart
journeyResult = await SupabaseService.createJourney(
  userId: userId,
  pnr: pnr,
  carrier: carrier,
  flightNumber: flightNumber,
  departureAirport: departureAirportCode,
  arrivalAirport: arrivalAirport['fs'].toString(),
  scheduledDeparture: departureEntireTime,
  scheduledArrival: arrivalEntireTime,
  seatNumber: seatNumber,
  classOfTravel: classOfService,
  terminal: flightStatus['airportResources']?['departureTerminal'],
  gate: flightStatus['airportResources']?['departureGate'],
  aircraftType: flightStatus['flightEquipment']?['iata'],
);
```

#### 5a. Get or Create Airline
**Method**: `_getOrCreateAirline()`

- Checks if airline exists in `airlines` table by IATA code
- If exists: Returns airline ID
- If not exists: Creates new airline record
- Stores: `id`, `iata_code`, `name`

#### 5b. Get or Create Airports
**Method**: `_getOrCreateAirportWithDetails()`

**For Departure Airport:**
- Checks if airport exists in `airports` table by IATA code
- If exists: Updates with new data if available, returns airport ID
- If not exists: Creates new airport record with:
  - IATA code
  - ICAO code (if available)
  - Name
  - City
  - Country
  - Latitude/Longitude
  - Timezone

**For Arrival Airport:**
- Same process as departure airport

#### 5c. Get or Create Flight
**Method**: `_createOrGetFlightEnhanced()`

- Checks if flight exists in `flights` table by:
  - Carrier code
  - Flight number
  - Departure airport
  - Arrival airport
  - Scheduled departure date

- If exists: Returns existing flight ID
- If not exists: Creates new flight record with:
  - `airline_id` (foreign key to airlines table)
  - `flight_number`
  - `departure_airport_id` (foreign key to airports table)
  - `arrival_airport_id` (foreign key to airports table)
  - `scheduled_departure` (UTC timestamp)
  - `scheduled_arrival` (UTC timestamp)
  - `departure_time` (actual departure, if available)
  - `arrival_time` (actual arrival, if available)
  - `aircraft_type` (if available)
  - `carrier_code`
  - `departure_airport` (IATA code as string)
  - `arrival_airport` (IATA code as string)

#### 5d. Duplicate Check
**Location**: Lines 843-861 in `supabase_service.dart`

Before creating a journey, the app checks for duplicates:

```dart
// Check if journey already exists for PNR + flight_id + seat_number combination
// All three must match for the same user to be considered a duplicate
if (flightResult != null && seatNumber != null && seatNumber.isNotEmpty) {
  final existingJourney = await client
      .from('journeys')
      .select('id, pnr, seat_number')
      .eq('pnr', pnr)
      .eq('passenger_id', userId)
      .eq('flight_id', flightResult['id'])
      .eq('seat_number', seatNumber)
      .maybeSingle();

  if (existingJourney != null) {
    // Duplicate detected - all three match
    return {'duplicate': true, 'existing_journey': existingJourney};
  }
}
```

**Duplicate Criteria:**
- Same `pnr`
- Same `flight_id`
- Same `seat_number`
- Same `passenger_id` (user)

**If duplicate**: Returns error, shows dialog, prevents journey creation
**If not duplicate**: Proceeds to create journey

#### 5e. Create Journey
**Location**: Lines 863-886 in `supabase_service.dart`

Creates a new record in the `journeys` table:

```dart
final journeyData = {
  'passenger_id': userId,              // Foreign key to users table
  'flight_id': flightResult?['id'],    // Foreign key to flights table
  'pnr': pnr,                          // Passenger Name Record
  'seat_number': seatNumber,           // Seat number (e.g., "12A")
  'visit_status': 'Upcoming',          // Journey status
  'media': ciriumData,                 // Full Cirium API response (JSON)
  'connection_time_mins': flightResult == null ? 0 : null,
};

// Optional fields
if (classOfTravel != null) {
  journeyData['class_of_travel'] = classOfTravel;  // First, Business, Economy
}
if (terminal != null) {
  journeyData['terminal'] = terminal;
}
if (gate != null) {
  journeyData['gate'] = gate;
}

final journey = await client
    .from('journeys')
    .insert(journeyData)
    .select()
    .single();
```

**Journey Table Fields:**
- `id` (UUID, primary key)
- `passenger_id` (UUID, foreign key → users table)
- `flight_id` (UUID, foreign key → flights table)
- `pnr` (string)
- `seat_number` (string, nullable)
- `visit_status` (enum: 'Upcoming', 'In Progress', 'Completed')
- `class_of_travel` (string, nullable)
- `terminal` (string, nullable)
- `gate` (string, nullable)
- `media` (JSONB) - Stores full Cirium API response
- `connection_time_mins` (integer, nullable)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 5f. Create Journey Event
**Location**: Lines 888-900 in `supabase_service.dart`

Creates an initial event record in `journey_events` table:

```dart
await client.from('journey_events').insert({
  'journey_id': journey['id'],         // Foreign key to journeys table
  'event_type': 'trip_added',          // Event type
  'title': 'Trip Added',               // Event title
  'description': 'Boarding pass scanned and confirmed successfully',
  'event_timestamp': DateTime.now().toIso8601String(),
  'metadata': {                         // Additional data (JSONB)
    'carrier': carrier,
    'flight_number': flightNumber,
    'pnr': pnr,
  },
});
```

**Journey Events Table:**
- Tracks all events related to a journey
- Used for timeline display
- Event types: `trip_added`, `journey_completed`, `phase_change`, etc.

### Step 6: Start Flight Tracking
**Location**: Lines 959-977 in `scanner_screen.dart`

After saving to database, starts real-time flight tracking:

```dart
final trackingStarted = await ref
    .read(flightTrackingProvider.notifier)
    .trackFlight(
      carrier: carrier,
      flightNumber: flightNumber,
      flightDate: date,
      departureAirport: departureAirportCode,
      pnr: pnr,
      existingFlightData: flightInfo,  // Pass Cirium data
    );
```

**What this does:**
- Initializes `CiriumFlightTrackingService`
- Starts periodic polling of Cirium API for flight status updates
- Monitors flight phase changes (pre-check-in, boarding, in-flight, landed, etc.)
- Sends push notifications on phase changes
- Updates journey status in real-time

### Step 7: Show Confirmation Dialog
**Location**: Lines 991-1004 in `scanner_screen.dart`

Displays confirmation dialog with flight details:

```dart
FlightConfirmationDialog.show(
  context,
  newPass,                    // BoardingPass object
  ciriumFlightData: flightInfo,  // Full Cirium response
  seatNumber: seatNumber,
  terminal: flightStatus['airportResources']?['departureTerminal'],
  gate: flightStatus['airportResources']?['departureGate'],
  aircraftType: flightStatus['flightEquipment']?['iata'],
  scheduledDeparture: departureEntireTime,
  scheduledArrival: arrivalEntireTime,
);
```

## Database Schema Relationships

```
users (1) ──→ (many) journeys
                │
                ├──→ (1) flights
                │      ├──→ (1) airlines
                │      ├──→ (1) airports (departure)
                │      └──→ (1) airports (arrival)
                │
                └──→ (many) journey_events
```

## Data Storage Locations

### 1. Local Storage (Device)
- **What**: `BoardingPass` object
- **Where**: Device local storage (via `BoardingPassController`)
- **Purpose**: Offline access, quick retrieval

### 2. Supabase Database
- **What**: Structured relational data
- **Tables**:
  - `users` - User profiles
  - `airlines` - Airline information
  - `airports` - Airport information
  - `flights` - Flight information
  - `journeys` - User journey records
  - `journey_events` - Journey event timeline

### 3. Journey Media Field
- **What**: Full Cirium API response (JSON)
- **Where**: `journeys.media` column (JSONB)
- **Purpose**: Stores complete flight data for reference
- **Contains**:
  - Flight statuses
  - Airport resources
  - Flight equipment
  - Operational times
  - Delays information

## Error Handling

### Duplicate Journey
- **Detection**: PNR + flight_id + seat_number all match
- **Action**: Shows dialog "This journey already exists in active mode"
- **Result**: Journey creation is prevented

### Missing Data
- **Airline not found**: Creates new airline with generic name
- **Airport not found**: Creates new airport with basic data
- **Flight not found**: Creates new flight record

### API Failures
- **Cirium API fails**: Falls back to offline mode
- **Supabase save fails**: Logs error, continues with tracking
- **Network issues**: Uses local storage, retries later

## Offline Mode Flow

If Cirium API is unavailable:

1. Uses boarding pass data only
2. Creates journey with estimated times
3. Saves to Supabase with limited data
4. Shows message: "Live flight status unavailable"
5. User can manually update later

## Summary

The data saving flow ensures:
1. ✅ **Data Verification**: Cirium API verifies flight data
2. ✅ **Data Integrity**: Relationships maintained (airlines, airports, flights)
3. ✅ **Duplicate Prevention**: Checks for existing journeys
4. ✅ **Complete Storage**: Saves to both local and cloud storage
5. ✅ **Real-time Tracking**: Starts flight monitoring
6. ✅ **User Feedback**: Shows confirmation with all details

All data is saved in a structured, relational format that enables:
- Journey history tracking
- Flight status monitoring
- Event timeline display
- Analytics and reporting
- Multi-device synchronization

