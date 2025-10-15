import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }
static bool get isAuthenticated =>
    isInitialized && client.auth.currentSession?.user != null;
  static Future<void> initialize() async {
    // Try to get from environment variables first, then fallback to hardcoded values
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL', 
      defaultValue: 'https://otidfywfqxyxteixpqre.supabase.co'
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY', 
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90aWRmeXdmcXh5eHRlaXhwcXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5MzgzODMsImV4cCI6MjA3NTUxNDM4M30.o4TyfuLawwotXu9kUepuWmBF5QKVxflk7KHJSg6iJqI'
    );

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ Supabase credentials not found. Running without Supabase integration.');
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );

    _client = Supabase.instance.client;
    debugPrint('✅ Supabase initialized successfully');
  }

  static bool get isInitialized => _client != null;

  // Journey methods
  // Enhanced method to save flight data with validation
  static Future<Map<String, dynamic>?> saveFlightData({
    required String userId,
    required String pnr,
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? aircraftType,
    Map<String, dynamic>? ciriumData,
  }) async {
    if (!isInitialized) {
      debugPrint('❌ Supabase not initialized');
      return null;
    }

    // Validate required fields
    if (userId.isEmpty || pnr.isEmpty || carrier.isEmpty || flightNumber.isEmpty) {
      debugPrint('❌ Missing required flight data');
      return null;
    }

    try {
      // Check if journey already exists for this PNR
      final existingJourney = await client
          .from('journeys')
          .select('id')
          .eq('pnr', pnr)
          .eq('passenger_id', userId)
          .maybeSingle();

      if (existingJourney != null) {
        debugPrint('⚠️ Journey already exists for PNR: $pnr');
        return existingJourney;
      }

      // Try to create or get flight first
      final flightResult = await _createOrGetFlight(
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        scheduledDeparture: scheduledDeparture,
        scheduledArrival: scheduledArrival,
        aircraftType: aircraftType,
        terminal: terminal,
        gate: gate,
      );

      // Create journey with or without flight reference
      final journey = await client.from('journeys').insert({
        'passenger_id': userId,
        'flight_id': flightResult?['id'], // May be null if flight creation failed
        'pnr': pnr,
        'seat_number': seatNumber,
        'visit_status': 'Upcoming', // Use valid check constraint value
        'media': ciriumData, // Store Cirium data in media column
        // Store flight info directly in journey if flight creation failed
        'connection_time_mins': flightResult == null ? 0 : null,
      }).select().single();

      // Add initial event
      await client.from('journey_events').insert({
        'journey_id': journey['id'],
        'event_type': 'trip_added',
        'title': 'Trip Added',
        'description': 'Boarding pass scanned and confirmed successfully',
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'carrier': carrier,
          'flight_number': flightNumber,
          'pnr': pnr,
        },
      });

      debugPrint('✅ Flight data saved successfully: ${journey['id']}');
      return journey;
    } catch (e) {
      debugPrint('❌ Error saving flight data: $e');
      return null;
    }
  }

  // Helper method to create or get flight
  static Future<Map<String, dynamic>?> _createOrGetFlight({
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? aircraftType,
    String? terminal,
    String? gate,
  }) async {
    try {
      debugPrint('🔍 Looking for airline with IATA code: $carrier');
      
      // Get airline ID
      final airlineData = await client
          .from('airlines')
          .select('id, iata_code, name')
          .eq('iata_code', carrier)
          .maybeSingle();

      if (airlineData == null) {
        debugPrint('❌ Airline $carrier not found in database');
        
        // Try to create the airline if it doesn't exist
        debugPrint('🔄 Attempting to create airline: $carrier');
        try {
          final newAirline = await client.from('airlines').insert({
            'iata_code': carrier,
            'name': 'Airline $carrier', // Generic name
            'created_at': DateTime.now().toIso8601String(),
          }).select('id').single();
          
          debugPrint('✅ Created new airline: ${newAirline['id']}');
          return await _createOrGetFlight(
            carrier: carrier,
            flightNumber: flightNumber,
            departureAirport: departureAirport,
            arrivalAirport: arrivalAirport,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            aircraftType: aircraftType,
            terminal: terminal,
            gate: gate,
          );
        } catch (createError) {
          debugPrint('❌ Failed to create airline: $createError');
          
          // Fallback: Try to create a simplified journey without airline/airport references
          debugPrint('🔄 Attempting fallback approach without airline/airport references');
          return await _createJourneyWithoutReferences(
            carrier: carrier,
            flightNumber: flightNumber,
            departureAirport: departureAirport,
            arrivalAirport: arrivalAirport,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            aircraftType: aircraftType,
            terminal: terminal,
            gate: gate,
          );
        }
      }
      
      debugPrint('✅ Found airline: ${airlineData['name']} (${airlineData['iata_code']})');

      // Get airport IDs
      debugPrint('🔍 Looking for departure airport: $departureAirport');
      final depAirportData = await client
          .from('airports')
          .select('id, iata_code, name')
          .eq('iata_code', departureAirport)
          .maybeSingle();

      debugPrint('🔍 Looking for arrival airport: $arrivalAirport');
      final arrAirportData = await client
          .from('airports')
          .select('id, iata_code, name')
          .eq('iata_code', arrivalAirport)
          .maybeSingle();

      if (depAirportData == null || arrAirportData == null) {
        debugPrint('❌ Airports not found: dep=$departureAirport, arr=$arrivalAirport');
        
        // Try to create missing airports
        if (depAirportData == null) {
          debugPrint('🔄 Creating departure airport: $departureAirport');
          try {
            await client.from('airports').insert({
              'iata_code': departureAirport,
              'name': 'Airport $departureAirport',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('❌ Failed to create departure airport: $e');
          }
        }
        
        if (arrAirportData == null) {
          debugPrint('🔄 Creating arrival airport: $arrivalAirport');
          try {
            await client.from('airports').insert({
              'iata_code': arrivalAirport,
              'name': 'Airport $arrivalAirport',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('❌ Failed to create arrival airport: $e');
          }
        }
        
        // Retry the query after creating airports
        final retryDepAirport = await client
            .from('airports')
            .select('id')
            .eq('iata_code', departureAirport)
            .maybeSingle();
            
        final retryArrAirport = await client
            .from('airports')
            .select('id')
            .eq('iata_code', arrivalAirport)
            .maybeSingle();
            
        if (retryDepAirport == null || retryArrAirport == null) {
          debugPrint('❌ Still cannot find airports after creation attempt');
          return null;
        }
        
        // Use the retry results
        final depAirportId = retryDepAirport['id'];
        final arrAirportId = retryArrAirport['id'];
        
        debugPrint('✅ Using airport IDs: dep=$depAirportId, arr=$arrAirportId');
      } else {
        debugPrint('✅ Found airports: dep=${depAirportData['name']}, arr=${arrAirportData['name']}');
      }

      // Get the final airport IDs
      final depAirportId = depAirportData?['id'] ?? (await client
          .from('airports')
          .select('id')
          .eq('iata_code', departureAirport)
          .maybeSingle())?['id'];
          
      final arrAirportId = arrAirportData?['id'] ?? (await client
          .from('airports')
          .select('id')
          .eq('iata_code', arrivalAirport)
          .maybeSingle())?['id'];

      if (depAirportId == null || arrAirportId == null) {
        debugPrint('❌ Could not get airport IDs: dep=$depAirportId, arr=$arrAirportId');
        return null;
      }

      // Check if flight already exists
      var flightData = await client
          .from('flights')
          .select('id')
          .eq('flight_number', flightNumber)
          .eq('carrier_code', carrier)
          .eq('departure_time', scheduledDeparture.toIso8601String())
          .maybeSingle();

      if (flightData == null) {
        // Create new flight
        flightData = await client.from('flights').insert({
          'flight_number': flightNumber,
          'carrier_code': carrier,
          'departure_airport': departureAirport,
          'arrival_airport': arrivalAirport,
          'aircraft_type': aircraftType,
          'departure_time': scheduledDeparture.toIso8601String(),
          'arrival_time': scheduledArrival.toIso8601String(),
        }).select().single();
      }

      return flightData;
    } catch (e) {
      debugPrint('❌ Error creating/getting flight: $e');
      return null;
    }
  }

  // Fallback method to create journey without airline/airport references
  static Future<Map<String, dynamic>?> _createJourneyWithoutReferences({
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? aircraftType,
    String? terminal,
    String? gate,
  }) async {
    try {
      debugPrint('🔄 Creating journey without airline/airport references');
      
      // Create a simplified flight record with just the basic info
      final flightData = await client.from('flights').insert({
        'flight_number': flightNumber,
        'carrier_code': carrier, // Store carrier as text instead of foreign key
        'departure_airport': departureAirport, // Store as text instead of foreign key
        'arrival_airport': arrivalAirport, // Store as text instead of foreign key
        'aircraft_type': aircraftType,
        'departure_time': scheduledDeparture.toIso8601String(),
        'arrival_time': scheduledArrival.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();
      
      debugPrint('✅ Created simplified flight: ${flightData['id']}');
      return flightData;
    } catch (e) {
      debugPrint('❌ Error creating simplified flight: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createJourney({
    required String userId,
    required String pnr,
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? aircraftType,
  }) async {
    if (!isInitialized) return null;

    try {
      // Get airline ID
      final airlineData = await client
          .from('airlines')
          .select('id')
          .eq('iata_code', carrier)
          .maybeSingle();

      if (airlineData == null) {
        debugPrint('❌ Airline $carrier not found');
        return null;
      }

      // Get airport IDs
      final depAirportData = await client
          .from('airports')
          .select('id')
          .eq('iata_code', departureAirport)
          .maybeSingle();

      final arrAirportData = await client
          .from('airports')
          .select('id')
          .eq('iata_code', arrivalAirport)
          .maybeSingle();

      if (depAirportData == null || arrAirportData == null) {
        debugPrint('❌ Airports not found');
        return null;
      }

      // Create or get flight
      var flightData = await client
          .from('flights')
          .select('id')
          .eq('flight_number', flightNumber)
          .eq('airline_id', airlineData['id'])
          .eq('scheduled_departure', scheduledDeparture.toIso8601String())
          .maybeSingle();

      if (flightData == null) {
        flightData = await client.from('flights').insert({
          'airline_id': airlineData['id'],
          'flight_number': flightNumber,
          'departure_airport_id': depAirportData['id'],
          'arrival_airport_id': arrAirportData['id'],
          'aircraft_type': aircraftType,
          'scheduled_departure': scheduledDeparture.toIso8601String(),
          'scheduled_arrival': scheduledArrival.toIso8601String(),
        }).select().single();
      }

      // Create journey
      final journey = await client.from('journeys').insert({
        'passenger_id': userId,
        'flight_id': flightData['id'],
        'pnr': pnr,
        'seat_number': seatNumber,
        'visit_status': 'Upcoming', // Use valid check constraint value
      }).select().single();

      // Add initial event
      await client.from('journey_events').insert({
        'journey_id': journey['id'],
        'event_type': 'trip_added',
        'title': 'Trip Added',
        'description': 'Boarding pass scanned successfully',
        'event_timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Journey created in Supabase: ${journey['id']}');
      return journey;
    } catch (e) {
      debugPrint('❌ Error creating journey in Supabase: $e');
      return null;
    }
  }

  static Future<void> submitStageFeedback({
    required String journeyId,
    required String userId,
    required String stage,
    required Map<String, dynamic> positiveSelections,
    required Map<String, dynamic> negativeSelections,
    required Map<String, dynamic> customFeedback,
    int? overallRating,
    String? additionalComments,
  }) async {
    if (!isInitialized) return;

    try {
      await client.from('stage_feedback').upsert({
        'journey_id': journeyId,
        'user_id': userId,
        'stage': stage,
        'positive_selections': positiveSelections,
        'negative_selections': negativeSelections,
        'custom_feedback': customFeedback,
        'overall_rating': overallRating,
        'additional_comments': additionalComments,
        'feedback_timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Stage feedback submitted to Supabase: $stage');
    } catch (e) {
      debugPrint('❌ Error submitting stage feedback to Supabase: $e');
    }
  }

  static Future<Map<String, dynamic>?> submitCompleteReview({
    required String journeyId,
    required String userId,
    required String airlineId,
    required String airportId,
    required Map<String, int> airlineRatings,
    required Map<String, int> airportRatings,
    String? airlineComment,
    String? airportComment,
    List<String>? airlineImages,
    List<String>? airportImages,
  }) async {
    if (!isInitialized) return null;

    try {
      // Submit airline review
      final airlineReview = await client.from('airline_reviews').insert({
        'journey_id': journeyId,
        'user_id': userId,
        'airline_id': airlineId,
        'comfort_rating': airlineRatings['comfort'],
        'cleanliness_rating': airlineRatings['cleanliness'],
        'onboard_service_rating': airlineRatings['service'],
        'food_beverage_rating': airlineRatings['food'],
        'entertainment_wifi_rating': airlineRatings['entertainment'],
        'comment': airlineComment,
        'image_urls': airlineImages,
      }).select().single();

      // Submit airport review
      final airportReview = await client.from('airport_reviews').insert({
        'journey_id': journeyId,
        'user_id': userId,
        'airport_id': airportId,
        'accessibility_rating': airportRatings['accessibility'],
        'wait_times_rating': airportRatings['waitTimes'],
        'helpfulness_rating': airportRatings['helpfulness'],
        'ambience_comfort_rating': airportRatings['ambience'],
        'food_beverage_rating': airportRatings['food'],
        'amenities_rating': airportRatings['amenities'],
        'comment': airportComment,
        'image_urls': airportImages,
      }).select().single();

      debugPrint('✅ Complete review submitted to Supabase');
      return {
        'success': true,
        'airlineScore': airlineReview['overall_score'],
        'airportScore': airportReview['overall_score'],
      };
    } catch (e) {
      debugPrint('❌ Error submitting complete review to Supabase: $e');
      return {'success': false};
    }
  }

  static Future<List<Map<String, dynamic>>> getUserJourneys(String userId) async {
    if (!isInitialized) return [];

    try {
      final data = await client
          .from('journeys')
          .select('''
            *,
            flight:flights (
              *,
              airline:airlines (*),
              departure_airport:airports!flights_departure_airport_id_fkey (*),
              arrival_airport:airports!flights_arrival_airport_id_fkey (*)
            )
          ''')
          .eq('passenger_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error getting user journeys from Supabase: $e');
      return [];
    }
  }

  static RealtimeChannel subscribeToJourneyEvents(
    String journeyId,
    void Function(Map<String, dynamic>) callback,
  ) {
    return client
        .channel('journey_events:$journeyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'journey_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'journey_id',
            value: journeyId,
          ),
          callback: (payload) => callback(payload.newRecord),
        )
        .subscribe();
  }

  // User profile methods
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!isInitialized) return null;

    try {
      final data = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('❌ Error getting user profile from Supabase: $e');
      return null;
    }
  }

  static Future<bool> saveUserDataToSupabase(Map<String, dynamic> userData) async {
    if (!isInitialized) return false;

    try {
      await client
          .from('users')
          .upsert(userData);

      debugPrint('✅ User data saved to Supabase');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving user data to Supabase: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> syncUserDataFromSupabase(String userId) async {
    if (!isInitialized) return null;

    try {
      final data = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      debugPrint('✅ User data synced from Supabase');
      return data;
    } catch (e) {
      debugPrint('❌ Error syncing user data from Supabase: $e');
      return null;
    }
  }
}

