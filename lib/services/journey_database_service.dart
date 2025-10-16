import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/flight_tracking_model.dart';

class JourneyDatabaseService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Fetch journeys for a specific user from the database
  static Future<List<Map<String, dynamic>>> getUserJourneys(String userId) async {
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

        debugPrint('✅ Found ${response.length} journeys in database (simple query)');
        
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
  static FlightTrackingModel? convertToFlightTrackingModel(Map<String, dynamic> journeyData) {
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
      FlightPhase currentPhase = _determinePhaseFromJourney(journeyData, flight);
      
      // Parse departure and arrival times
      DateTime departureTime;
      DateTime arrivalTime;
      
      try {
        departureTime = DateTime.parse(flight['departure_time'] ?? flight['scheduled_departure'] ?? '');
      } catch (e) {
        debugPrint('❌ Error parsing departure time: $e');
        departureTime = DateTime.now();
      }
      
      try {
        arrivalTime = DateTime.parse(flight['arrival_time'] ?? flight['scheduled_arrival'] ?? '');
      } catch (e) {
        debugPrint('❌ Error parsing arrival time: $e');
        arrivalTime = DateTime.now().add(Duration(hours: 2));
      }

      // Extract airport codes - these should be stored as strings in the flights table
      String departureAirport = flight['departure_airport']?.toString() ?? '';
      String arrivalAirport = flight['arrival_airport']?.toString() ?? '';

      // Extract airline code - this should be stored as string in the flights table
      String carrier = flight['carrier_code']?.toString() ?? flight['airline']?.toString() ?? '';

      final flightTrackingModel = FlightTrackingModel(
        flightId: journeyData['id'], // Use journey ID as flight ID
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
        terminal: flight['terminal']?.toString(),
        gate: flight['gate']?.toString(),
        aircraftType: flight['aircraft_type']?.toString(),
        flightDuration: _calculateFlightDuration(departureTime, arrivalTime),
      );

      debugPrint('✅ Converted journey to FlightTrackingModel: ${flightTrackingModel.pnr}');
      return flightTrackingModel;
    } catch (e) {
      debugPrint('❌ Error converting journey to FlightTrackingModel: $e');
      return null;
    }
  }

  /// Determine flight phase from journey and flight data
  static FlightPhase _determinePhaseFromJourney(Map<String, dynamic> journey, Map<String, dynamic> flight) {
    // Check journey status first
    final journeyStatus = journey['status']?.toString().toLowerCase();
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
          return FlightPhase.preCheckIn;
        default:
          break;
      }
    }

    // Fallback: determine based on current time vs flight times
    final now = DateTime.now();
    final departureTime = DateTime.tryParse(flight['departure_time'] ?? '') ?? now;
    final arrivalTime = DateTime.tryParse(flight['arrival_time'] ?? '') ?? now.add(Duration(hours: 2));

    if (now.isAfter(arrivalTime.add(Duration(hours: 1)))) {
      return FlightPhase.completed;
    } else if (now.isAfter(arrivalTime)) {
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
  static List<FlightEvent> _extractEventsFromJourney(Map<String, dynamic> journey) {
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
    if (journey['journey_events'] != null && journey['journey_events'] is List) {
      final journeyEvents = journey['journey_events'] as List;
      for (final event in journeyEvents) {
        if (event is Map<String, dynamic>) {
          events.add(FlightEvent(
            eventType: event['event_type'] ?? 'UNKNOWN',
            timestamp: DateTime.tryParse(event['event_timestamp'] ?? '') ?? DateTime.now(),
            description: event['description'] ?? '',
            metadata: event['metadata'] ?? {},
          ));
        }
      }
    }

    return events;
  }

  /// Create a basic flight model from journey data only
  static FlightTrackingModel? _createBasicFlightModel(Map<String, dynamic> journeyData) {
    try {
      debugPrint('🔧 Creating basic flight model from journey data');
      
      // Extract basic information from journey data
      final pnr = journeyData['pnr']?.toString() ?? '';
      final seatNumber = journeyData['seat_number']?.toString();
      
      // Try to parse times from journey data
      DateTime departureTime = DateTime.now();
      DateTime arrivalTime = DateTime.now().add(Duration(hours: 2));
      
      if (journeyData['departure_time'] != null) {
        try {
          departureTime = DateTime.parse(journeyData['departure_time']);
        } catch (e) {
          debugPrint('⚠️ Could not parse departure_time: $e');
        }
      }
      
      if (journeyData['arrival_time'] != null) {
        try {
          arrivalTime = DateTime.parse(journeyData['arrival_time']);
        } catch (e) {
          debugPrint('⚠️ Could not parse arrival_time: $e');
        }
      }

      // Determine phase from journey status
      FlightPhase currentPhase = FlightPhase.preCheckIn;
      final status = journeyData['status']?.toString().toLowerCase();
      final currentPhaseStr = journeyData['current_phase']?.toString().toLowerCase();
      
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

  /// Calculate flight duration
  static String _calculateFlightDuration(DateTime departure, DateTime arrival) {
    final duration = arrival.difference(departure);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  /// Sync database journeys with local flight tracking
  static Future<List<FlightTrackingModel>> syncUserJourneys(String userId) async {
    try {
      debugPrint('🔄 Syncing journeys for user: $userId');
      
      final journeyData = await getUserJourneys(userId);
      final flightModels = <FlightTrackingModel>[];
      
      for (final journey in journeyData) {
        final flightModel = convertToFlightTrackingModel(journey);
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
