import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/flight_tracking_model.dart';

class JourneyDatabaseService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Fetch journeys for a specific user from the database
  static Future<List<Map<String, dynamic>>> getUserJourneys(
      String userId) async {
    try {
      debugPrint('🔍 Fetching journeys for user: $userId');

      // First try with the join query
      try {
        final response = await _client
            .from('journeys')
            .select('''
              *,
              flight:flights (
                *
              )
            ''')
            .eq('passenger_id', userId)
            .order('created_at', ascending: false);

        debugPrint('✅ Found ${response.length} journeys in database with join');

        // Debug: Log the structure of the first journey if available
        if (response.isNotEmpty) {
          debugPrint('🔍 Sample journey data: ${response.first}');
        }

        return List<Map<String, dynamic>>.from(response);
      } catch (joinError) {
        debugPrint('⚠️ Join query failed, trying simple query: $joinError');

        // Fallback: Simple query without joins
        final response = await _client
            .from('journeys')
            .select('*')
            .eq('passenger_id', userId)
            .order('created_at', ascending: false);

        debugPrint(
            '✅ Found ${response.length} journeys in database (simple query)');

        // Debug: Log the structure of the first journey if available
        if (response.isNotEmpty) {
          debugPrint('🔍 Sample journey data: ${response.first}');
        }

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('❌ Error fetching journeys from database: $e');
      return [];
    }
  }

  /// Convert database journey data to FlightTrackingModel
  static Future<FlightTrackingModel?> convertToFlightTrackingModel(
      Map<String, dynamic> journeyData) async {
    try {
      final flight = journeyData['flight'];
      if (flight == null) {
        debugPrint('⚠️ No flight data found for journey: ${journeyData['id']}');
        debugPrint('🔍 Journey data structure: $journeyData');

        // Try to create a basic flight model from journey data only
        return _createBasicFlightModel(journeyData);
      }

      debugPrint('🔍 Flight data structure: $flight');

      // Determine flight phase based on journey status or flight data
      FlightPhase currentPhase =
          await _determinePhaseFromJourney(journeyData, flight);

      // Parse departure and arrival times
      // CRITICAL: Times from database are stored in UTC, must parse as UTC
      DateTime departureTime;
      DateTime arrivalTime;

      try {
        final departureTimeStr = flight['departure_time'] ?? flight['scheduled_departure'] ?? '';
        if (departureTimeStr.toString().isEmpty) {
          departureTime = DateTime.now().toUtc();
        } else {
          departureTime = _parseDateTimeAsUtc(departureTimeStr.toString());
        }
      } catch (e) {
        debugPrint('❌ Error parsing departure time: $e');
        departureTime = DateTime.now().toUtc();
      }

      try {
        final arrivalTimeStr = flight['arrival_time'] ?? flight['scheduled_arrival'] ?? '';
        if (arrivalTimeStr.toString().isEmpty) {
          arrivalTime = DateTime.now().toUtc().add(Duration(hours: 2));
        } else {
          arrivalTime = _parseDateTimeAsUtc(arrivalTimeStr.toString());
        }
      } catch (e) {
        debugPrint('❌ Error parsing arrival time: $e');
        arrivalTime = DateTime.now().toUtc().add(Duration(hours: 2));
      }

      // Extract airport codes - these should be stored as strings in the flights table
      String departureAirport = flight['departure_airport']?.toString() ?? '';
      String arrivalAirport = flight['arrival_airport']?.toString() ?? '';

      // Extract airline code - this should be stored as string in the flights table
      String carrier = flight['carrier_code']?.toString() ??
          flight['airline']?.toString() ??
          '';

      final flightTrackingModel = FlightTrackingModel(
        flightId: journeyData['id'], // Use journey ID as flight ID
        journeyId: journeyData['id'], // Store journey ID separately
        pnr: journeyData['pnr'] ?? '',
        carrier: carrier,
        flightNumber: flight['flight_number']?.toString() ?? '',
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        currentPhase: currentPhase,
        phaseStartTime: journeyData['created_at'] != null
            ? DateTime.parse(journeyData['created_at'])
            : DateTime.now(),
        ciriumData: flight, // Store the full flight data
        events: _extractEventsFromJourney(journeyData),
        isVerified: true,
        seatNumber: journeyData['seat_number']?.toString(),
        terminal: journeyData['terminal']?.toString() ?? flight['terminal']?.toString(),
        gate: journeyData['gate']?.toString() ?? flight['gate']?.toString(),
        aircraftType: flight['aircraft_type']?.toString(),
        flightDuration: _calculateFlightDuration(departureTime, arrivalTime),
      );

      debugPrint(
          '✅ Converted journey to FlightTrackingModel: ${flightTrackingModel.pnr}');
      return flightTrackingModel;
    } catch (e) {
      debugPrint('❌ Error converting journey to FlightTrackingModel: $e');
      return null;
    }
  }

  /// Determine flight phase from journey and flight data
  static Future<FlightPhase> _determinePhaseFromJourney(
      Map<String, dynamic> journey, Map<String, dynamic> flight) async {
    final journeyId = journey['id']?.toString();
    
    // PRIORITY 1: Check for completion event FIRST (most reliable indicator)
    // This handles cases where table update failed but event was created
    if (journeyId != null) {
      try {
        debugPrint('🔍 Checking for completion event for journey: $journeyId');
        final completionEvent = await _client
            .from('journey_events')
            .select('id')
            .eq('journey_id', journeyId)
            .eq('event_type', 'journey_completed')
            .limit(1)
            .maybeSingle();

        if (completionEvent != null) {
          debugPrint('✅ Journey completion detected via event: $journeyId');
          return FlightPhase.completed;
        } else {
          debugPrint('🔍 No completion event found for journey: $journeyId');
        }
      } catch (eventError) {
        debugPrint('⚠️ Error checking journey events for completion: $eventError');
      }
    }

    // PRIORITY 2: Check visit_status - if it's 'Completed', journey is completed
    final visitStatus = journey['visit_status']?.toString();
    if (visitStatus == 'Completed') {
      debugPrint('✅ Journey completion detected via visit_status: ${journey['id']}');
      return FlightPhase.completed;
    }

    // PRIORITY 3: Check journey status
    final journeyStatus = journey['status']?.toString().toLowerCase();
    if (journeyStatus == 'completed') {
      debugPrint('✅ Journey completion detected via status: ${journey['id']}');
      return FlightPhase.completed;
    }

    // PRIORITY 4: Check current phase (but don't return immediately for pre_check_in)
    final currentPhase = journey['current_phase']?.toString().toLowerCase();

    if (currentPhase != null) {
      switch (currentPhase) {
        case 'completed':
          return FlightPhase.completed;
        case 'landed':
          return FlightPhase.landed;
        case 'in_flight':
        case 'inflight':
          return FlightPhase.inFlight;
        case 'departed':
          return FlightPhase.departed;
        case 'boarding':
          return FlightPhase.boarding;
        case 'check_in_open':
          return FlightPhase.checkInOpen;
        case 'pre_check_in':
          // Don't return immediately - might have completion event or time-based completion
          // Continue to fallback time-based check below
          break;
        default:
          break;
      }
    }

    // Fallback: determine phase based on current time vs flight times
    // NOTE: Do NOT automatically mark as completed - only user action can complete journeys
    // Completion must be explicit (via event, visit_status, or status field)
    final now = DateTime.now().toUtc();
    final departureTimeStr = flight['departure_time'] ?? flight['scheduled_departure'] ?? '';
    final arrivalTimeStr = flight['arrival_time'] ?? flight['scheduled_arrival'] ?? '';
    
    final departureTime = departureTimeStr.toString().isNotEmpty
        ? _parseDateTimeAsUtc(departureTimeStr.toString())
        : now;
    final arrivalTime = arrivalTimeStr.toString().isNotEmpty
        ? _parseDateTimeAsUtc(arrivalTimeStr.toString())
        : now.add(Duration(hours: 2));

    // Only use time-based logic for phase detection, NOT for completion
    // Journey completion must be explicitly done by user via the complete button
    if (now.isAfter(arrivalTime)) {
      // Flight has landed, but still active until user explicitly completes it
      return FlightPhase.landed;
    } else if (now.isAfter(departureTime)) {
      return FlightPhase.inFlight;
    } else if (now.isAfter(departureTime.subtract(Duration(hours: 1)))) {
      return FlightPhase.boarding;
    } else if (now.isAfter(departureTime.subtract(Duration(hours: 24)))) {
      return FlightPhase.checkInOpen;
    } else {
      return FlightPhase.preCheckIn;
    }
  }

  /// Extract events from journey data
  static List<FlightEvent> _extractEventsFromJourney(
      Map<String, dynamic> journey) {
    final events = <FlightEvent>[];

    // Add journey creation event
    if (journey['created_at'] != null) {
      events.add(FlightEvent(
        eventType: 'JOURNEY_CREATED',
        timestamp: DateTime.parse(journey['created_at']),
        description: 'Journey created in database',
        metadata: {'source': 'database'},
      ));
    }

    // Add any journey events if they exist
    if (journey['journey_events'] != null &&
        journey['journey_events'] is List) {
      final journeyEvents = journey['journey_events'] as List;
      for (final event in journeyEvents) {
        if (event is Map<String, dynamic>) {
          events.add(FlightEvent(
            eventType: event['event_type'] ?? 'UNKNOWN',
            timestamp: DateTime.tryParse(event['event_timestamp'] ?? '') ??
                DateTime.now(),
            description: event['description'] ?? '',
            metadata: event['metadata'] ?? {},
          ));
        }
      }
    }

    return events;
  }

  /// Create a basic flight model from journey data only
  static FlightTrackingModel? _createBasicFlightModel(
      Map<String, dynamic> journeyData) {
    try {
      debugPrint('🔧 Creating basic flight model from journey data');

      // Extract basic information from journey data
      final pnr = journeyData['pnr']?.toString() ?? '';
      final seatNumber = journeyData['seat_number']?.toString();

      // Try to parse times from journey data
      // CRITICAL: Times from database are stored in UTC, must parse as UTC
      DateTime departureTime = DateTime.now().toUtc();
      DateTime arrivalTime = DateTime.now().toUtc().add(Duration(hours: 2));

      if (journeyData['departure_time'] != null) {
        try {
          departureTime = _parseDateTimeAsUtc(journeyData['departure_time'].toString());
        } catch (e) {
          debugPrint('⚠️ Could not parse departure_time: $e');
        }
      }

      if (journeyData['arrival_time'] != null) {
        try {
          arrivalTime = _parseDateTimeAsUtc(journeyData['arrival_time'].toString());
        } catch (e) {
          debugPrint('⚠️ Could not parse arrival_time: $e');
        }
      }

      // Determine phase from journey status
      FlightPhase currentPhase = FlightPhase.preCheckIn;
      final status = journeyData['status']?.toString().toLowerCase();
      final currentPhaseStr =
          journeyData['current_phase']?.toString().toLowerCase();

      if (currentPhaseStr != null) {
        switch (currentPhaseStr) {
          case 'completed':
            currentPhase = FlightPhase.completed;
            break;
          case 'landed':
            currentPhase = FlightPhase.landed;
            break;
          case 'in_flight':
          case 'inflight':
            currentPhase = FlightPhase.inFlight;
            break;
          case 'departed':
            currentPhase = FlightPhase.departed;
            break;
          case 'boarding':
            currentPhase = FlightPhase.boarding;
            break;
          case 'check_in_open':
            currentPhase = FlightPhase.checkInOpen;
            break;
          default:
            currentPhase = FlightPhase.preCheckIn;
        }
      }

      final flightModel = FlightTrackingModel(
        flightId: journeyData['id']?.toString() ?? '',
        pnr: pnr,
        carrier: journeyData['carrier']?.toString() ?? '',
        flightNumber: journeyData['flight_number']?.toString() ?? '',
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureAirport: journeyData['departure_airport']?.toString() ?? '',
        arrivalAirport: journeyData['arrival_airport']?.toString() ?? '',
        currentPhase: currentPhase,
        phaseStartTime: journeyData['created_at'] != null
            ? DateTime.parse(journeyData['created_at'])
            : DateTime.now(),
        ciriumData: journeyData, // Store journey data as cirium data
        events: _extractEventsFromJourney(journeyData),
        isVerified: true,
        seatNumber: seatNumber,
        terminal: journeyData['terminal']?.toString(),
        gate: journeyData['gate']?.toString(),
        aircraftType: journeyData['aircraft_type']?.toString(),
        flightDuration: _calculateFlightDuration(departureTime, arrivalTime),
      );

      debugPrint('✅ Created basic flight model: ${flightModel.pnr}');
      return flightModel;
    } catch (e) {
      debugPrint('❌ Error creating basic flight model: $e');
      return null;
    }
  }

  /// Parse DateTime string as UTC (handles timezone-aware and timezone-naive strings)
  /// CRITICAL: Database times are stored in UTC. If no timezone info in string,
  /// we must append 'Z' to force UTC parsing, otherwise DateTime.parse() treats it as local time.
  static DateTime _parseDateTimeAsUtc(String timeString) {
    try {
      // Clean up the string - remove any trailing spaces
      final cleanString = timeString.trim();
      
      // Check if string already has timezone info
      // Formats: "2025-01-15T18:30:00Z", "2025-01-15T18:30:00+00:00", "2025-01-15T18:30:00-05:00"
      // Simple check: ends with 'Z' or has timezone offset pattern (+/-HH:MM) at the end
      final hasTimezone = cleanString.endsWith('Z') || 
          RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(cleanString);
      
      if (hasTimezone) {
        // Parse with timezone info
        final parsed = DateTime.parse(cleanString);
        // Convert to UTC if not already
        final utcTime = parsed.isUtc ? parsed : parsed.toUtc();
        debugPrint('🕐 Parsed time with timezone: $timeString -> $utcTime (UTC=${utcTime.isUtc})');
        return utcTime;
      }
      
      // If no timezone info, assume it's UTC and append 'Z' to force UTC parsing
      // Supabase returns UTC times but sometimes without 'Z' suffix
      // DateTime.parse() without timezone treats as LOCAL time, which would be wrong
      // This is the KEY FIX: by appending 'Z', we force UTC parsing
      final utcString = '${cleanString}Z';
      final parsed = DateTime.parse(utcString);
      debugPrint('🕐 Parsed time as UTC (appended Z): $timeString -> $parsed (UTC=${parsed.isUtc})');
      return parsed;
    } catch (e) {
      debugPrint('⚠️ Error parsing time as UTC: $timeString, error: $e');
      // Fallback: try normal parse and convert to UTC
      try {
        final parsed = DateTime.parse(timeString.trim());
        // If it parsed as local time, we need to account for timezone offset
        // But we don't know the original timezone, so this is a best-effort conversion
        final utcTime = parsed.isUtc ? parsed : parsed.toUtc();
        debugPrint('⚠️ Fallback parsing: $timeString -> $utcTime (was local=${!parsed.isUtc})');
        return utcTime;
      } catch (e2) {
        debugPrint('❌ Complete failure parsing time: $timeString');
        return DateTime.now().toUtc();
      }
    }
  }

  /// Calculate flight duration
  /// CRITICAL: Both times must be in UTC to get accurate duration
  static String _calculateFlightDuration(DateTime departure, DateTime arrival) {
    // Ensure both times are in UTC for accurate duration calculation
    final departureUtc = departure.isUtc ? departure : departure.toUtc();
    final arrivalUtc = arrival.isUtc ? arrival : arrival.toUtc();
    
    final duration = arrivalUtc.difference(departureUtc);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    debugPrint('🕐 Duration calculation: departure=$departureUtc, arrival=$arrivalUtc, duration=${hours}h ${minutes}m');
    
    return '${hours}h ${minutes}m';
  }

  /// Sync database journeys with local flight tracking
  static Future<List<FlightTrackingModel>> syncUserJourneys(
      String userId) async {
    try {
      debugPrint('🔄 Syncing journeys for user: $userId');

      final journeyData = await getUserJourneys(userId);
      final flightModels = <FlightTrackingModel>[];

      for (final journey in journeyData) {
        final flightModel = await convertToFlightTrackingModel(journey);
        if (flightModel != null) {
          flightModels.add(flightModel);
        }
      }

      debugPrint('✅ Synced ${flightModels.length} journeys from database');
      return flightModels;
    } catch (e) {
      debugPrint('❌ Error syncing user journeys: $e');
      return [];
    }
  }
}
