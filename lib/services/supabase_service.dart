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
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://otidfywfqxyxteixpqre.supabase.co');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90aWRmeXdmcXh5eHRlaXhwcXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5MzgzODMsImV4cCI6MjA3NTUxNDM4M30.o4TyfuLawwotXu9kUepuWmBF5QKVxflk7KHJSg6iJqI');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint(
          '⚠️ Supabase credentials not found. Running without Supabase integration.');
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
    if (userId.isEmpty ||
        pnr.isEmpty ||
        carrier.isEmpty ||
        flightNumber.isEmpty) {
      debugPrint('❌ Missing required flight data');
      return null;
    }

    try {
      // Try to create or get flight first (needed for duplicate check)R
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

      // Check if journey already exists for PNR + flight_id + seat_number combination
      // All three must match for the same user to be considered a duplicate
      // If any one doesn't match, allow the journey to be added
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
          debugPrint('⚠️ Duplicate journey detected: PNR=$pnr, flight_id=${flightResult['id']}, seat_number=$seatNumber all match for user=$userId');
          // Return a special indicator that this is a duplicate (all three match)
          return {'duplicate': true, 'existing_journey': existingJourney};
        }
      }

      // Create journey with or without flight reference
      final journey = await client
          .from('journeys')
          .insert({
            'passenger_id': userId,
            'flight_id':
                flightResult?['id'], // May be null if flight creation failed
            'pnr': pnr,
            'seat_number': seatNumber, // Seat number is saved
            'visit_status': 'Upcoming', // Use valid check constraint value
            'media': ciriumData, // Store Cirium data in media column
            // Store flight info directly in journey if flight creation failed
            'connection_time_mins': flightResult == null ? 0 : null,
          })
          .select()
          .single();

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

  // ============================================================================
  // OLD HELPER METHOD - Part of airline/airport creation flow
  // ============================================================================
  // This method is kept for reference but is not used in the new simplified flow
  // ============================================================================
  
  // Helper method to create or get flight
  /// OLD METHOD - Not used in new simplified flow
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

      // Get airline ID - handle duplicates by taking the first one
      final airlineList = await client
          .from('airlines')
          .select('id, iata_code, name')
          .eq('iata_code', carrier)
          .limit(1);

      final airlineData = airlineList.isNotEmpty ? airlineList.first : null;

      if (airlineData == null) {
        debugPrint('❌ Airline $carrier not found in database');

        // Try to create the airline if it doesn't exist
        debugPrint('🔄 Attempting to create airline: $carrier');
        try {
          final newAirline = await client
              .from('airlines')
              .insert({
                'iata_code': carrier,
                'name': 'Airline $carrier', // Generic name
                'created_at': DateTime.now().toIso8601String(),
              })
              .select('id')
              .single();

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
          debugPrint(
              '🔄 Attempting fallback approach without airline/airport references');
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

      debugPrint(
          '✅ Found airline: ${airlineData['name']} (${airlineData['iata_code']})');

      // Get airport IDs - handle duplicates by taking the first one
      debugPrint('🔍 Looking for departure airport: $departureAirport');
      final depAirportList = await client
          .from('airports')
          .select('id, iata_code, name')
          .eq('iata_code', departureAirport)
          .limit(1);
      final depAirportData = depAirportList.isNotEmpty ? depAirportList.first : null;

      debugPrint('🔍 Looking for arrival airport: $arrivalAirport');
      final arrAirportList = await client
          .from('airports')
          .select('id, iata_code, name')
          .eq('iata_code', arrivalAirport)
          .limit(1);
      final arrAirportData = arrAirportList.isNotEmpty ? arrAirportList.first : null;

      if (depAirportData == null || arrAirportData == null) {
        debugPrint(
            '❌ Airports not found: dep=$departureAirport, arr=$arrivalAirport');

        // Try to create missing airports with basic data
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
        debugPrint(
            '✅ Found airports: dep=${depAirportData['name']}, arr=${arrAirportData['name']}');
      }

      // Get the final airport IDs
      final depAirportId = depAirportData?['id'] ??
          (await client
              .from('airports')
              .select('id')
              .eq('iata_code', departureAirport)
              .maybeSingle())?['id'];

      final arrAirportId = arrAirportData?['id'] ??
          (await client
              .from('airports')
              .select('id')
              .eq('iata_code', arrivalAirport)
              .maybeSingle())?['id'];

      if (depAirportId == null || arrAirportId == null) {
        debugPrint(
            '❌ Could not get airport IDs: dep=$depAirportId, arr=$arrAirportId');
        return null;
      }

      // Check if flight already exists
      var flightData = await client
          .from('flights')
          .select('id')
          .eq('flight_number', flightNumber)
          .eq('airline_id', airlineData['id'])
          .eq('scheduled_departure', scheduledDeparture.toIso8601String())
          .maybeSingle();

      if (flightData == null) {
        // Create new flight with proper foreign key IDs
        flightData = await client
            .from('flights')
            .insert({
              'flight_number': flightNumber,
              'airline_id': airlineData['id'],  // ✅ Use airline_id (FK)
              'departure_airport_id': depAirportId,  // ✅ Use departure_airport_id (FK)
              'arrival_airport_id': arrAirportId,  // ✅ Use arrival_airport_id (FK)
              'aircraft_type': aircraftType,
              'scheduled_departure': scheduledDeparture.toIso8601String(),  // ✅ Use scheduled_departure
              'scheduled_arrival': scheduledArrival.toIso8601String(),  // ✅ Use scheduled_arrival
            })
            .select()
            .single();
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
      final flightData = await client
          .from('flights')
          .insert({
            'flight_number': flightNumber,
            'carrier_code':
                carrier, // Store carrier as text instead of foreign key
            'departure_airport':
                departureAirport, // Store as text instead of foreign key
            'arrival_airport':
                arrivalAirport, // Store as text instead of foreign key
            'aircraft_type': aircraftType,
            'departure_time': scheduledDeparture.toIso8601String(),
            'arrival_time': scheduledArrival.toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

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
      // Get airline ID - handle duplicates by taking the first one
      final airlineList = await client
          .from('airlines')
          .select('id')
          .eq('iata_code', carrier)
          .limit(1);
      final airlineData = airlineList.isNotEmpty ? airlineList.first : null;

      if (airlineData == null) {
        debugPrint('❌ Airline $carrier not found');
        return null;
      }

      // Get airport IDs - handle duplicates by taking the first one
      final depAirportList = await client
          .from('airports')
          .select('id')
          .eq('iata_code', departureAirport)
          .limit(1);
      final depAirportData = depAirportList.isNotEmpty ? depAirportList.first : null;

      final arrAirportList = await client
          .from('airports')
          .select('id')
          .eq('iata_code', arrivalAirport)
          .limit(1);
      final arrAirportData = arrAirportList.isNotEmpty ? arrAirportList.first : null;

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
        flightData = await client
            .from('flights')
            .insert({
              'airline_id': airlineData['id'],
              'flight_number': flightNumber,
              'departure_airport_id': depAirportData['id'],
              'arrival_airport_id': arrAirportData['id'],
              'aircraft_type': aircraftType,
              'scheduled_departure': scheduledDeparture.toIso8601String(),
              'scheduled_arrival': scheduledArrival.toIso8601String(),
            })
            .select()
            .single();
      }

      // Check if journey already exists for PNR + flight_id + seat_number combination
      // All three must match for the same user to be considered a duplicate
      // If any one doesn't match, allow the journey to be added
      if (flightData != null && seatNumber != null && seatNumber.isNotEmpty) {
        final existingJourney = await client
            .from('journeys')
            .select('id, pnr, seat_number')
            .eq('pnr', pnr)
            .eq('passenger_id', userId)
            .eq('flight_id', flightData['id'])
            .eq('seat_number', seatNumber)
            .maybeSingle();

        if (existingJourney != null) {
          debugPrint('⚠️ Duplicate journey detected: PNR=$pnr, flight_id=${flightData['id']}, seat_number=$seatNumber all match for user=$userId');
          // Return a special indicator that this is a duplicate (all three match)
          return {'duplicate': true, 'existing_journey': existingJourney};
        }
      }

      // Create journey
      final journey = await client
          .from('journeys')
          .insert({
            'passenger_id': userId,
            'flight_id': flightData['id'], // Flight info is saved via flight_id relationship
            'pnr': pnr,
            'seat_number': seatNumber, // Seat number is saved
            'visit_status': 'Upcoming', // Use valid check constraint value
          })
          .select()
          .single();

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
      // Check if this is "At the Airport" feedback that should go to airport_reviews
      final normalizedStage = stage.toLowerCase().trim();
      if (normalizedStage.contains('airport') ||
          normalizedStage.contains('at the airport') ||
          normalizedStage == 'pre-flight') {
        debugPrint('🏢 Routing airport feedback to airport_reviews table');

        // Get the flight ID from journey
        final journeyData = await client
            .from('journeys')
            .select('flight_id')
            .eq('id', journeyId)
            .maybeSingle();

        if (journeyData != null && journeyData['flight_id'] != null) {
          final flightId = journeyData['flight_id'] as String;

          // Get airport ID from flight
          final flightData = await client
              .from('flights')
              .select('departure_airport_id, arrival_airport_id')
              .eq('id', flightId)
              .maybeSingle();

          if (flightData != null) {
            final airportId = flightData['departure_airport_id'] ??
                flightData['arrival_airport_id'];

            if (airportId != null) {
              // Map feedback to airport review scores
              final scores = _mapToAirportScores(
                  positiveSelections, negativeSelections, overallRating ?? 3);

              await client.from('airport_reviews').upsert({
                'journey_id': journeyId,
                'user_id': userId,
                'airport_id': airportId,
                'overall_score': overallRating != null
                    ? (overallRating / 5.0).toStringAsFixed(2)
                    : '3.00',
                'cleanliness': scores['cleanliness'],
                'facilities': scores['facilities'],
                'staff': scores['staff'],
                'waiting_time': scores['waiting_time'],
                'accessibility': scores['accessibility'],
                'comments': _createCommentFromSelections(
                    positiveSelections, negativeSelections, additionalComments),
                'would_recommend': (overallRating ?? 3) >= 4,
                'created_at': DateTime.now().toIso8601String(),
              });

              debugPrint('✅ Airport review submitted to Supabase: $stage');
              return;
            }
          }
        }

        debugPrint(
            '⚠️ Could not find airport ID, falling back to stage_feedback');
      }

      // Default to stage_feedback table
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
      final airlineReview = await client
          .from('airline_reviews')
          .insert({
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
          })
          .select()
          .single();

      // Submit airport review
      final airportReview = await client
          .from('airport_reviews')
          .insert({
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
          })
          .select()
          .single();

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

  static Future<List<Map<String, dynamic>>> getUserJourneys(
      String userId) async {
    if (!isInitialized) return [];

    try {
      final data = await client.from('journeys').select('''
            *,
            flight:flights (
              *,
              airline:airlines (*),
              departure_airport:airports!flights_departure_airport_id_fkey (*),
              arrival_airport:airports!flights_arrival_airport_id_fkey (*)
            )
          ''').eq('passenger_id', userId).order('created_at', ascending: false);

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
      final data =
          await client.from('users').select().eq('id', userId).maybeSingle();

      return data;
    } catch (e) {
      debugPrint('❌ Error getting user profile from Supabase: $e');
      return null;
    }
  }

  static Future<bool> saveUserDataToSupabase(
      Map<String, dynamic> userData) async {
    if (!isInitialized) return false;

    try {
      await client.from('users').upsert(userData);

      debugPrint('✅ User data saved to Supabase');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving user data to Supabase: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> syncUserDataFromSupabase(
      String userId) async {
    if (!isInitialized) return null;

    try {
      final data =
          await client.from('users').select().eq('id', userId).maybeSingle();

      debugPrint('✅ User data synced from Supabase');
      return data;
    } catch (e) {
      debugPrint('❌ Error syncing user data from Supabase: $e');
      return null;
    }
  }

  // ============================================================================
  // OLD METHOD - COMMENTED OUT (Part of Cirium flow with airline/airport creation)
  // ============================================================================
  // This method is kept for reference but is not used in the new simplified flow
  // The new flow uses saveSimpleJourney() which doesn't create airline/airport records
  // ============================================================================
  
  /// Enhanced method to save flight data with comprehensive airport information
  /// OLD METHOD - Not used in new simplified flow
  static Future<Map<String, dynamic>?> saveFlightDataWithAirportDetails({
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
    Map<String, dynamic>? departureAirportData,
    Map<String, dynamic>? arrivalAirportData,
  }) async {
    if (!isInitialized) {
      debugPrint('❌ Supabase not initialized');
      return null;
    }

    // Validate required fields
    if (userId.isEmpty ||
        pnr.isEmpty ||
        carrier.isEmpty ||
        flightNumber.isEmpty) {
      debugPrint('❌ Missing required flight data');
      return null;
    }

    try {
      // Get or create airline (pass API data to extract airline details)
      final airlineData = await _getOrCreateAirline(carrier, apiData: ciriumData);
      if (airlineData == null) {
        debugPrint('❌ Could not get or create airline: $carrier');
        return null;
      }

      // Get or create airports with comprehensive data
      final depAirportId = await _getOrCreateAirportWithDetails(
        iataCode: departureAirport,
        airportData: departureAirportData,
      );

      final arrAirportId = await _getOrCreateAirportWithDetails(
        iataCode: arrivalAirport,
        airportData: arrivalAirportData,
      );

      if (depAirportId == null || arrAirportId == null) {
        debugPrint('❌ Could not get or create airports');
        return null;
      }

      // Create or get flight
      final flightResult = await _createOrGetFlightEnhanced(
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        scheduledDeparture: scheduledDeparture,
        scheduledArrival: scheduledArrival,
        aircraftType: aircraftType,
        terminal: terminal,
        gate: gate,
        airlineId: airlineData['id'],
        departureAirportId: depAirportId,
        arrivalAirportId: arrAirportId,
      );

      // Check if journey already exists for PNR + flight_id + seat_number combination
      // All three must match for the same user to be considered a duplicate
      // If any one doesn't match, allow the journey to be added
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
          debugPrint('⚠️ Duplicate journey detected: PNR=$pnr, flight_id=${flightResult['id']}, seat_number=$seatNumber all match for user=$userId');
          // Return a special indicator that this is a duplicate (all three match)
          return {'duplicate': true, 'existing_journey': existingJourney};
        }
      }

      // Create journey with fallback for missing columns
      final journeyData = {
        'passenger_id': userId,
        'flight_id': flightResult?['id'], // Flight info is saved via flight_id relationship
        'pnr': pnr,
        'seat_number': seatNumber, // Seat number is saved
        'visit_status': 'Upcoming',
        'media': ciriumData, // Store Cirium data in media column (can contain flight info)
        'connection_time_mins': flightResult == null ? 0 : null,
      };

      // Add optional columns if they exist
      if (classOfTravel != null) {
        journeyData['class_of_travel'] = classOfTravel;
      }
      if (terminal != null) {
        journeyData['terminal'] = terminal;
      }
      if (gate != null) {
        journeyData['gate'] = gate;
      }

      final journey =
          await client.from('journeys').insert(journeyData).select().single();

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

      debugPrint(
          '✅ Flight data with airport details saved successfully: ${journey['id']}');
      return journey;
    } catch (e) {
      debugPrint('❌ Error saving flight data with airport details: $e');
      return null;
    }
  }

  // ============================================================================
  // OLD HELPER METHOD - Part of airline/airport creation flow
  // ============================================================================
  // This method is kept for reference but is not used in the new simplified flow
  // ============================================================================
  
  /// Get or create airport with comprehensive details
  /// OLD METHOD - Not used in new simplified flow
  static Future<String?> _getOrCreateAirportWithDetails({
    required String iataCode,
    Map<String, dynamic>? airportData,
  }) async {
    try {
      // Check if airport exists - handle duplicates by taking the first one
      final existingAirportList = await client
          .from('airports')
          .select(
              'id, iata_code, icao_code, name, city, country, latitude, longitude, timezone')
          .eq('iata_code', iataCode)
          .limit(1);

      if (existingAirportList.isNotEmpty) {
        final existingAirport = existingAirportList.first;
        // Update with new data if available
        if (airportData != null) {
          final updateData = {
            'icao_code': airportData['icao_code'],
            'name': airportData['name'],
            'city': airportData['city'],
            'country': airportData['country'],
            'latitude': airportData['latitude'],
            'longitude': airportData['longitude'],
            'timezone': airportData['timezone'],
          };

          await client
              .from('airports')
              .update(updateData)
              .eq('iata_code', iataCode);
        }
        debugPrint('✅ Found airport: ${existingAirport['name']} (${existingAirport['iata_code']})');
        return existingAirport['id'] as String;
      }

      // Create new airport
      final airportInsertData = {
        'iata_code': iataCode,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (airportData != null) {
        airportInsertData.addAll({
          'icao_code': airportData['icao_code'],
          'name': airportData['name'],
          'city': airportData['city'],
          'country': airportData['country'],
          'latitude': airportData['latitude'],
          'longitude': airportData['longitude'],
          'timezone': airportData['timezone'],
        });
      } else {
        airportInsertData['name'] = 'Airport $iataCode';
      }

      final newAirport = await client
          .from('airports')
          .insert(airportInsertData)
          .select()
          .single();

      debugPrint('✅ Created new airport: ${newAirport['name']} (${newAirport['iata_code']})');
      return newAirport['id'] as String;
    } catch (e) {
      debugPrint('❌ Error getting or creating airport $iataCode: $e');
      return null;
    }
  }

  /// Get or create airline
  static Future<Map<String, dynamic>?> _getOrCreateAirline(
      String carrier,
      {Map<String, dynamic>? apiData}) async {  // Optional API data (Cirium, etc.)
    try {
      // Check if airline exists - handle duplicates by taking the first one
      final airlineList = await client
          .from('airlines')
          .select('id, iata_code, icao_code, name, country, logo_url')
          .eq('iata_code', carrier)
          .limit(1);

      if (airlineList.isNotEmpty) {
        final airlineData = airlineList.first;
        debugPrint('✅ Found airline: ${airlineData['name']} (${airlineData['iata_code']})');
        
        // Check if we need to update missing fields (logo, ICAO, country)
        final needsLogoUpdate = airlineData['logo_url'] == null || airlineData['logo_url'].toString().isEmpty;
        final needsIcaoUpdate = airlineData['icao_code'] == null || airlineData['icao_code'].toString().isEmpty;
        final needsCountryUpdate = airlineData['country'] == null || airlineData['country'].toString().isEmpty;
        
        if (needsLogoUpdate || needsIcaoUpdate || needsCountryUpdate) {
          try {
            final updateData = <String, dynamic>{
              'updated_at': DateTime.now().toIso8601String(),
            };
            
            if (needsLogoUpdate) {
              final logoUrl = _getAirlineLogoUrl(carrier);
              if (logoUrl != null) {
                updateData['logo_url'] = logoUrl;
                airlineData['logo_url'] = logoUrl;
                debugPrint('✅ Updated airline logo: $logoUrl');
              }
            }
            
            if (needsIcaoUpdate || needsCountryUpdate) {
              // Try to get details from API data first (if available), otherwise use local
              final details = _getAirlineDetailsFromApiOrLocal(carrier, apiData);
              if (needsIcaoUpdate && details['icao_code'] != null) {
                updateData['icao_code'] = details['icao_code'];
                airlineData['icao_code'] = details['icao_code'];
                debugPrint('✅ Updated ICAO code: ${details['icao_code']}');
              }
              if (needsCountryUpdate && details['country'] != null) {
                updateData['country'] = details['country'];
                airlineData['country'] = details['country'];
                debugPrint('✅ Updated country: ${details['country']}');
              }
              if (details['name'] != null && airlineData['name'] == 'Airline $carrier') {
                updateData['name'] = details['name'];
                airlineData['name'] = details['name'];
                debugPrint('✅ Updated airline name: ${details['name']}');
              }
            }
            
            if (updateData.length > 1) {  // More than just updated_at
              await client.from('airlines').update(updateData).eq('id', airlineData['id']);
            }
          } catch (updateError) {
            debugPrint('⚠️ Could not update airline: $updateError');
          }
        }
        
        return airlineData;
      }

      // Generate logo URL for new airline
      final logoUrl = _getAirlineLogoUrl(carrier);
      
      // Get airline details from Cirium/API data first, then fall back to local database
      final airlineDetails = _getAirlineDetailsFromApiOrLocal(carrier, apiData);

      // Create new airline with logo, ICAO code, and country
      final newAirline = await client
          .from('airlines')
          .insert({
            'iata_code': carrier,
            'name': airlineDetails['name'] ?? 'Airline $carrier',
            'icao_code': airlineDetails['icao_code'],
            'country': airlineDetails['country'],
            'logo_url': logoUrl,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id, iata_code, icao_code, name, country, logo_url')
          .single();

      debugPrint('✅ Created new airline: ${newAirline['name']} (${newAirline['iata_code']})');
      if (newAirline['icao_code'] != null) {
        debugPrint('   ICAO: ${newAirline['icao_code']}, Country: ${newAirline['country']}');
      }
      if (logoUrl != null) {
        debugPrint('   Logo: $logoUrl');
      }
      return newAirline;
    } catch (e) {
      debugPrint('❌ Error getting or creating airline: $e');
      return null;
    }
  }

  /// Get airline logo URL from public CDN
  /// Uses airline IATA code to fetch logo from aviation-edge.com or similar
  static String? _getAirlineLogoUrl(String iataCode) {
    if (iataCode.isEmpty) return null;
    
    // Option 1: Aviation Edge API (requires API key - replace with your key)
    // return 'https://aviation-edge.com/v2/public/airlineDatabase?key=YOUR_API_KEY&codeIataAirline=$iataCode';
    
    // Option 2: Use a public CDN that hosts airline logos
    // Many services provide airline logos by IATA code
    // This is a placeholder - replace with your preferred logo service
    return 'https://www.gstatic.com/flights/airline_logos/70px/$iataCode.png';
    
    // Option 3: Aeros API
    // return 'https://content.airhex.com/content/logos/airlines_${iataCode}_50_50_r.png';
    
    // Option 4: FlightRadar24 style
    // return 'https://images.kiwi.com/airlines/64/$iataCode.png';
    
    // Note: Choose the CDN that best fits your needs and is reliable
    // Consider caching logos locally or in your own storage for better performance
  }

  /// Get airline details from API data (Cirium/flight API) or fall back to local database
  /// Prioritizes API data over hardcoded values
  static Map<String, String?> _getAirlineDetailsFromApiOrLocal(
    String iataCode,
    Map<String, dynamic>? apiData,  // Cirium or other API response
  ) {
    // First, try to extract from API data if available
    if (apiData != null) {
      try {
        // Extract airline info from Cirium API response
        final flightStatuses = apiData['flightStatuses'] as List?;
        if (flightStatuses != null && flightStatuses.isNotEmpty) {
          final status = flightStatuses.first as Map<String, dynamic>;
          final carrier = status['carrier'] as Map<String, dynamic>?;
          
          if (carrier != null) {
            final name = carrier['name'] as String?;
            final icao = carrier['fs'] as String?;  // FlightStats ICAO code
            // Note: Country might not be in Cirium response
            
            if (name != null || icao != null) {
              debugPrint('✅ Using airline details from API: $name ($icao)');
              return {
                'name': name,
                'icao_code': icao,
                'country': null,  // Not typically in Cirium response
              };
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not extract airline from API data: $e');
      }
    }
    
    // Fall back to local database
    return _getAirlineDetailsLocal(iataCode);
  }

  /// Get airline details (name, ICAO code, country) from local database
  /// This is a fallback when API doesn't provide airline details
  static Map<String, String?> _getAirlineDetailsLocal(String iataCode) {
    // Comprehensive airline database mapping
    final airlines = <String, Map<String, String>>{
      // United States
      'AA': {'name': 'American Airlines', 'icao': 'AAL', 'country': 'United States'},
      'UA': {'name': 'United Airlines', 'icao': 'UAL', 'country': 'United States'},
      'DL': {'name': 'Delta Air Lines', 'icao': 'DAL', 'country': 'United States'},
      'WN': {'name': 'Southwest Airlines', 'icao': 'SWA', 'country': 'United States'},
      'B6': {'name': 'JetBlue Airways', 'icao': 'JBU', 'country': 'United States'},
      'AS': {'name': 'Alaska Airlines', 'icao': 'ASA', 'country': 'United States'},
      'NK': {'name': 'Spirit Airlines', 'icao': 'NKS', 'country': 'United States'},
      'F9': {'name': 'Frontier Airlines', 'icao': 'FFT', 'country': 'United States'},
      
      // Canada
      'AC': {'name': 'Air Canada', 'icao': 'ACA', 'country': 'Canada'},
      'WS': {'name': 'WestJet', 'icao': 'WJA', 'country': 'Canada'},
      
      // Europe
      'BA': {'name': 'British Airways', 'icao': 'BAW', 'country': 'United Kingdom'},
      'LH': {'name': 'Lufthansa', 'icao': 'DLH', 'country': 'Germany'},
      'AF': {'name': 'Air France', 'icao': 'AFR', 'country': 'France'},
      'KL': {'name': 'KLM Royal Dutch Airlines', 'icao': 'KLM', 'country': 'Netherlands'},
      'IB': {'name': 'Iberia', 'icao': 'IBE', 'country': 'Spain'},
      'AZ': {'name': 'ITA Airways', 'icao': 'ITY', 'country': 'Italy'},
      'LX': {'name': 'Swiss International Air Lines', 'icao': 'SWR', 'country': 'Switzerland'},
      'OS': {'name': 'Austrian Airlines', 'icao': 'AUA', 'country': 'Austria'},
      'SN': {'name': 'Brussels Airlines', 'icao': 'BEL', 'country': 'Belgium'},
      'TP': {'name': 'TAP Air Portugal', 'icao': 'TAP', 'country': 'Portugal'},
      'SK': {'name': 'Scandinavian Airlines', 'icao': 'SAS', 'country': 'Sweden'},
      'AY': {'name': 'Finnair', 'icao': 'FIN', 'country': 'Finland'},
      'FR': {'name': 'Ryanair', 'icao': 'RYR', 'country': 'Ireland'},
      'U2': {'name': 'easyJet', 'icao': 'EZY', 'country': 'United Kingdom'},
      
      // Middle East
      'EK': {'name': 'Emirates', 'icao': 'UAE', 'country': 'United Arab Emirates'},
      'QR': {'name': 'Qatar Airways', 'icao': 'QTR', 'country': 'Qatar'},
      'EY': {'name': 'Etihad Airways', 'icao': 'ETD', 'country': 'United Arab Emirates'},
      'SV': {'name': 'Saudia', 'icao': 'SVA', 'country': 'Saudi Arabia'},
      'WY': {'name': 'Oman Air', 'icao': 'OMA', 'country': 'Oman'},
      
      // Asia-Pacific
      'SQ': {'name': 'Singapore Airlines', 'icao': 'SIA', 'country': 'Singapore'},
      'CX': {'name': 'Cathay Pacific', 'icao': 'CPA', 'country': 'Hong Kong'},
      'NH': {'name': 'All Nippon Airways', 'icao': 'ANA', 'country': 'Japan'},
      'JL': {'name': 'Japan Airlines', 'icao': 'JAL', 'country': 'Japan'},
      'KE': {'name': 'Korean Air', 'icao': 'KAL', 'country': 'South Korea'},
      'OZ': {'name': 'Asiana Airlines', 'icao': 'AAR', 'country': 'South Korea'},
      'TG': {'name': 'Thai Airways', 'icao': 'THA', 'country': 'Thailand'},
      'MH': {'name': 'Malaysia Airlines', 'icao': 'MAS', 'country': 'Malaysia'},
      'GA': {'name': 'Garuda Indonesia', 'icao': 'GIA', 'country': 'Indonesia'},
      'PR': {'name': 'Philippine Airlines', 'icao': 'PAL', 'country': 'Philippines'},
      'VN': {'name': 'Vietnam Airlines', 'icao': 'HVN', 'country': 'Vietnam'},
      'AI': {'name': 'Air India', 'icao': 'AIC', 'country': 'India'},
      '6E': {'name': 'IndiGo', 'icao': 'IGO', 'country': 'India'},
      'QF': {'name': 'Qantas', 'icao': 'QFA', 'country': 'Australia'},
      'VA': {'name': 'Virgin Australia', 'icao': 'VOZ', 'country': 'Australia'},
      'NZ': {'name': 'Air New Zealand', 'icao': 'ANZ', 'country': 'New Zealand'},
      
      // China
      'CA': {'name': 'Air China', 'icao': 'CCA', 'country': 'China'},
      'CZ': {'name': 'China Southern Airlines', 'icao': 'CSN', 'country': 'China'},
      'MU': {'name': 'China Eastern Airlines', 'icao': 'CES', 'country': 'China'},
      'HU': {'name': 'Hainan Airlines', 'icao': 'CHH', 'country': 'China'},
      
      // Latin America
      'AM': {'name': 'Aeroméxico', 'icao': 'AMX', 'country': 'Mexico'},
      'Y4': {'name': 'Volaris', 'icao': 'VOI', 'country': 'Mexico'},
      'CM': {'name': 'Copa Airlines', 'icao': 'CMP', 'country': 'Panama'},
      'LA': {'name': 'LATAM Airlines', 'icao': 'LAN', 'country': 'Chile'},
      'AR': {'name': 'Aerolíneas Argentinas', 'icao': 'ARG', 'country': 'Argentina'},
      'AV': {'name': 'Avianca', 'icao': 'AVA', 'country': 'Colombia'},
      'G3': {'name': 'GOL Linhas Aéreas', 'icao': 'GLO', 'country': 'Brazil'},
      
      // Africa
      'SA': {'name': 'South African Airways', 'icao': 'SAA', 'country': 'South Africa'},
      'ET': {'name': 'Ethiopian Airlines', 'icao': 'ETH', 'country': 'Ethiopia'},
      'MS': {'name': 'EgyptAir', 'icao': 'MSR', 'country': 'Egypt'},
      'KQ': {'name': 'Kenya Airways', 'icao': 'KQA', 'country': 'Kenya'},
      
      // Low-cost carriers
      'WZ': {'name': 'Wizz Air', 'icao': 'WZZ', 'country': 'Hungary'},
      'VY': {'name': 'Vueling', 'icao': 'VLG', 'country': 'Spain'},
      'W6': {'name': 'Wizz Air', 'icao': 'WZZ', 'country': 'Hungary'},
      'U2': {'name': 'easyJet', 'icao': 'EZY', 'country': 'United Kingdom'},
      '3U': {'name': 'Sichuan Airlines', 'icao': 'CSC', 'country': 'China'},
      
      // Add more airlines as needed
    };

    final details = airlines[iataCode.toUpperCase()];
    
    return {
      'name': details?['name'],
      'icao_code': details?['icao'],
      'country': details?['country'],
    };
  }

  /// Enhanced create or get flight method
  static Future<Map<String, dynamic>?> _createOrGetFlightEnhanced({
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? aircraftType,
    String? terminal,
    String? gate,
    required String airlineId,
    required String departureAirportId,
    required String arrivalAirportId,
  }) async {
    try {
      // Detect available columns in flights table
      final availableColumns = await _detectFlightsTableColumns();
      debugPrint('🔍 Available columns: $availableColumns');
      debugPrint(
          '🔍 Time columns detected: scheduled_departure=${availableColumns['has_scheduled_departure']}, departure_time=${availableColumns['has_departure_time']}');
      debugPrint(
          '🔍 Flight data: carrier=$carrier, flightNumber=$flightNumber, departureAirport=$departureAirport, arrivalAirport=$arrivalAirport');
      debugPrint(
          '🔍 Airport IDs: departureAirportId=$departureAirportId, arrivalAirportId=$arrivalAirportId');

      // Build flight data based on available columns
      final flightInsertData = <String, dynamic>{
        'flight_number': flightNumber,
      };

      // Always include carrier_code as it's likely required
      flightInsertData['carrier_code'] = carrier;

      // Add airline_id if available
      if (availableColumns['has_airline_id'] == true) {
        flightInsertData['airline_id'] = airlineId;
      }

      // Add airport info - provide both old and new columns if they exist
      if (availableColumns['has_departure_airport_id'] == true &&
          availableColumns['has_arrival_airport_id'] == true) {
        flightInsertData['departure_airport_id'] = departureAirportId;
        flightInsertData['arrival_airport_id'] = arrivalAirportId;
      }

      // Also provide old column names if they exist (they might be required)
      if (availableColumns['has_departure_airport'] == true &&
          availableColumns['has_arrival_airport'] == true) {
        flightInsertData['departure_airport'] = departureAirport ?? 'UNKNOWN';
        flightInsertData['arrival_airport'] = arrivalAirport ?? 'UNKNOWN';
        debugPrint(
            '🔍 Adding old airport columns: departure=${departureAirport ?? 'UNKNOWN'}, arrival=${arrivalAirport ?? 'UNKNOWN'}');
      }

      // Add optional columns
      if (availableColumns['has_aircraft_type'] == true &&
          aircraftType != null) {
        flightInsertData['aircraft_type'] = aircraftType;
      }
      if (availableColumns['has_terminal'] == true && terminal != null) {
        flightInsertData['terminal'] = terminal;
      }
      if (availableColumns['has_gate'] == true && gate != null) {
        flightInsertData['gate'] = gate;
      }
      // Add time columns - always try both old and new column names
      // This ensures we satisfy NOT NULL constraints regardless of which columns exist
      flightInsertData['scheduled_departure'] =
          scheduledDeparture.toIso8601String();
      flightInsertData['departure_time'] = scheduledDeparture.toIso8601String();
      flightInsertData['scheduled_arrival'] =
          scheduledArrival.toIso8601String();
      flightInsertData['arrival_time'] = scheduledArrival.toIso8601String();

      debugPrint(
          '🔍 Adding time columns: scheduled_departure=${scheduledDeparture.toIso8601String()}, departure_time=${scheduledDeparture.toIso8601String()}');

      // Try to find existing flight
      var flightData = await client
          .from('flights')
          .select('id')
          .eq('flight_number', flightNumber)
          .maybeSingle();

      if (flightData == null) {
        // Create new flight
        debugPrint('🔍 Inserting flight data: $flightInsertData');
        flightData = await client
            .from('flights')
            .insert(flightInsertData)
            .select()
            .single();
        debugPrint('✅ Flight created successfully with available columns');
      } else {
        debugPrint('✅ Existing flight found');
      }

      return flightData;
    } catch (e) {
      debugPrint('❌ Error creating or getting flight: $e');

      // Ultimate fallback: create flight with required fields
      try {
        debugPrint('🔄 Attempting ultimate fallback with required fields');
        final ultimateFlightData = {
          'flight_number': flightNumber,
          'carrier_code': carrier, // This is required based on the error
          'departure_airport':
              departureAirport, // Old column names might be required
          'arrival_airport': arrivalAirport,
          'departure_time':
              scheduledDeparture.toIso8601String(), // Time columns are required
          'arrival_time': scheduledArrival.toIso8601String(),
        };

        final flightData = await client
            .from('flights')
            .insert(ultimateFlightData)
            .select()
            .single();
        debugPrint('✅ Ultimate fallback flight created successfully');
        return flightData;
      } catch (ultimateError) {
        debugPrint('❌ Ultimate fallback also failed: $ultimateError');
        return null;
      }
    }
  }

  /// Detect available columns in flights table
  static Future<Map<String, bool>> _detectFlightsTableColumns() async {
    try {
      // Try to query with all possible columns to see which ones exist
      await client
          .from('flights')
          .select(
              'id, flight_number, carrier_code, airline_id, departure_airport_id, arrival_airport_id, departure_airport, arrival_airport, scheduled_departure, scheduled_arrival, departure_time, arrival_time, aircraft_type, terminal, gate')
          .limit(1);

      return {
        'has_airline_id': true,
        'has_carrier_code': true,
        'has_departure_airport_id': true,
        'has_arrival_airport_id': true,
        'has_departure_airport': true,
        'has_arrival_airport': true,
        'has_scheduled_departure': true,
        'has_scheduled_arrival': true,
        'has_departure_time': true,
        'has_arrival_time': true,
        'has_aircraft_type': true,
        'has_terminal': true,
        'has_gate': true,
      };
    } catch (e) {
      // If the query fails, we'll detect columns individually
      final columns = <String, bool>{};

      // Test each column individually
      final columnTests = [
        'airline_id',
        'carrier_code',
        'departure_airport_id',
        'arrival_airport_id',
        'departure_airport',
        'arrival_airport',
        'scheduled_departure',
        'scheduled_arrival',
        'departure_time',
        'arrival_time',
        'aircraft_type',
        'terminal',
        'gate'
      ];

      for (final column in columnTests) {
        try {
          await client.from('flights').select(column).limit(1);
          columns[column] = true;
        } catch (e) {
          columns[column] = false;
        }
      }

      return columns;
    }
  }

  /// Map feedback selections to airport review scores
  static Map<String, int> _mapToAirportScores(
    Map<String, dynamic> positiveSelections,
    Map<String, dynamic> negativeSelections,
    int? overallRating,
  ) {
    // Default scores based on overall rating
    final baseScore = overallRating ?? 3;

    return {
      'cleanliness': baseScore,
      'facilities': baseScore,
      'staff': baseScore,
      'waiting_time': baseScore,
      'accessibility': baseScore,
    };
  }

  /// Create comment from feedback selections
  static String _createCommentFromSelections(
    Map<String, dynamic> positiveSelections,
    Map<String, dynamic> negativeSelections,
    String? additionalComments,
  ) {
    final comments = <String>[];

    // Add positive feedback
    for (final category in positiveSelections.keys) {
      final selections = positiveSelections[category] as List<dynamic>?;
      if (selections != null && selections.isNotEmpty) {
        comments.add('$category: ${selections.join(', ')}');
      }
    }

    // Add negative feedback
    for (final category in negativeSelections.keys) {
      final selections = negativeSelections[category] as List<dynamic>?;
      if (selections != null && selections.isNotEmpty) {
        comments.add('$category issues: ${selections.join(', ')}');
      }
    }

    // Add additional comments
    if (additionalComments != null && additionalComments.isNotEmpty) {
      comments.add('Additional: $additionalComments');
    }

    return comments.join('; ');
  }

  /// Check if a journey is completed
  /// Checks both journey table fields and journey events as fallback
  static Future<bool> isJourneyCompleted(String journeyId) async {
    if (!isInitialized) return false;
    try {
      // ============================================================================
      // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
      // ============================================================================
      // // First, check journey table fields
      // final journey = await client
      //     .from('journeys')
      //     .select('current_phase, visit_status, status')
      //     .eq('id', journeyId)
      //     .maybeSingle();

      // if (journey != null) {
      //   final phase = journey['current_phase']?.toString().toLowerCase();
      //   final visitStatus = journey['visit_status']?.toString();
      //   final status = journey['status']?.toString().toLowerCase();

      //   // Journey is completed ONLY if visit_status is 'Completed' or status is 'completed'
      //   // NOTE: 'landed' phase does NOT mean completed - user must explicitly complete
      //   if (visitStatus == 'Completed' || status == 'completed') {
      //     return true;
      //   }
      // }
      // ============================================================================
      // END OF OLD CODE
      // ============================================================================
      
      // NEW CODE - Check simple_journeys table
      final journey = await client
          .from('simple_journeys')
          .select('current_phase, visit_status, status')
          .eq('id', journeyId)
          .maybeSingle();

      if (journey != null) {
        final phase = journey['current_phase']?.toString().toLowerCase();
        final visitStatus = journey['visit_status']?.toString();
        final status = journey['status']?.toString().toLowerCase();

        // Journey is completed ONLY if visit_status is 'Completed' or status is 'completed'
        // NOTE: 'landed' phase does NOT mean completed - user must explicitly complete
        if (visitStatus == 'Completed' || status == 'completed') {
          return true;
        }
      }

      // Fallback: Check journey events for completion event
      // This handles cases where table update failed but event was created
      try {
        final completionEvent = await client
            .from('journey_events')
            .select('id')
            .eq('journey_id', journeyId)
            .eq('event_type', 'journey_completed')
            .limit(1)
            .maybeSingle();

        if (completionEvent != null) {
          debugPrint('✅ Journey completion detected via event: $journeyId');
          return true;
        }
      } catch (eventError) {
        debugPrint('⚠️ Error checking journey events: $eventError');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking journey completion status: $e');
      return false;
    }
  }

  /// Mark journey as completed (landed)
  static Future<bool> markJourneyAsCompleted({
    required String journeyId,
    String? flightId,
    bool addEvent = true,
  }) async {
    if (!isInitialized) return false;
    
    debugPrint('🔄 Starting journey completion process for: $journeyId');
    
    // First, verify the journey exists and get current user
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      debugPrint('❌ No authenticated user found');
      return false;
    }
    
    debugPrint('📋 Current user: $currentUserId');
    
    // ============================================================================
    // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
    // ============================================================================
    // // Check if journey exists and user has access
    // try {
    //   final journeyCheck = await client
    //       .from('journeys')
    //       .select('id, passenger_id, current_phase, visit_status, status')
    //       .eq('id', journeyId)
    //       .maybeSingle();
    //   
    //   if (journeyCheck == null) {
    //     debugPrint('❌ Journey not found: $journeyId');
    //     return false;
    //   }
    //   
    //   debugPrint('📋 Journey found: $journeyCheck');
    //   debugPrint('📋 Current phase: ${journeyCheck['current_phase']}');
    //   debugPrint('📋 Visit status: ${journeyCheck['visit_status']}');
    //   debugPrint('📋 Status: ${journeyCheck['status']}');
    //   debugPrint('📋 Passenger ID: ${journeyCheck['passenger_id']}');
    // } catch (e) {
    //   debugPrint('⚠️ Error checking journey: $e');
    // }
    // 
    // // Strategy 1: Try updating all fields at once with .select() to verify
    // try {
    //   final result = await client.from('journeys').update({
    //     'current_phase': 'landed',
    //     'visit_status': 'Completed',
    //     'status': 'completed',
    //     'updated_at': DateTime.now().toIso8601String(),
    //   }).eq('id', journeyId).select();
    //   
    //   if (result.isEmpty) {
    //     throw Exception('Update succeeded but no rows were modified');
    //   }
    //   
    //   debugPrint('✅ Journey marked as completed (all fields): $journeyId');
    //   debugPrint('📋 Updated data: $result');
    //   
    //   // Add journey event
    //   if (addEvent) {
    //     await _addJourneyCompletedEvent(journeyId, flightId);
    //   }
    //   
    //   return true;
    // } catch (e) {
    //   debugPrint('⚠️ Strategy 1 failed: $e');
    //   
    //   // Strategy 2: Try updating only visit_status (often works even if phase update fails)
    //   try {
    //     final result = await client.from('journeys').update({
    //       'visit_status': 'Completed',
    //       'status': 'completed',
    //       'updated_at': DateTime.now().toIso8601String(),
    //     }).eq('id', journeyId).select();
    //     
    //     if (result.isEmpty) {
    //       throw Exception('Update succeeded but no rows were modified');
    //     }
    //     
    //     debugPrint('✅ Journey marked as completed (visit_status only): $journeyId');
    //     debugPrint('📋 Updated data: $result');
    //     
    //     // Add journey event
    //     if (addEvent) {
    //       await _addJourneyCompletedEvent(journeyId, flightId);
    //     }
    //     
    //     return true;
    //   } catch (e2) {
    //     debugPrint('⚠️ Strategy 2 failed: $e2');
    //     
    //     // Strategy 3: Try updating only status field
    //     try {
    //       final result = await client.from('journeys').update({
    //         'status': 'completed',
    //         'updated_at': DateTime.now().toIso8601String(),
    //       }).eq('id', journeyId).select();
    //       
    //       if (result.isEmpty) {
    //         throw Exception('Update succeeded but no rows were modified');
    //       }
    //       
    //       debugPrint('✅ Journey marked as completed (status only): $journeyId');
    //       debugPrint('📋 Updated data: $result');
    //       
    //       // Add journey event
    //       if (addEvent) {
    //         await _addJourneyCompletedEvent(journeyId, flightId);
    //       }
    //       
    //       return true;
    //     } catch (e3) {
    //       debugPrint('⚠️ Strategy 3 failed: $e3');
    //       
    //       // Strategy 4: Just add the journey event (this marks completion in the event log)
    //       if (addEvent) {
    //         try {
    //           await _addJourneyCompletedEvent(journeyId, flightId);
    //           debugPrint('✅ Journey completion tracked via event only: $journeyId');
    //           // Return true because we've at least tracked it via events
    //           return true;
    // ============================================================================
    // END OF OLD CODE
    // ============================================================================
    
    // NEW CODE - Use simple_journeys table
    // Check if journey exists and user has access
    try {
      final journeyCheck = await client
          .from('simple_journeys')
          .select('id, passenger_id, current_phase, visit_status, status')
          .eq('id', journeyId)
          .maybeSingle();
      
      if (journeyCheck == null) {
        debugPrint('❌ Journey not found in simple_journeys: $journeyId');
        return false;
      }
      
      debugPrint('📋 Journey found in simple_journeys: $journeyCheck');
      debugPrint('📋 Current phase: ${journeyCheck['current_phase']}');
      debugPrint('📋 Visit status: ${journeyCheck['visit_status']}');
      debugPrint('📋 Status: ${journeyCheck['status']}');
      debugPrint('📋 Passenger ID: ${journeyCheck['passenger_id']}');
    } catch (e) {
      debugPrint('⚠️ Error checking journey in simple_journeys: $e');
    }
    
    // Strategy 1: Try updating all fields at once with .select() to verify
    try {
      final result = await client.from('simple_journeys').update({
        'current_phase': 'completed',
        'visit_status': 'Completed',
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', journeyId).select();
      
      if (result.isEmpty) {
        throw Exception('Update succeeded but no rows were modified');
      }
      
      debugPrint('✅ Journey marked as completed (all fields): $journeyId');
      debugPrint('📋 Updated data: $result');
      
      // Add journey event
      if (addEvent) {
        await _addJourneyCompletedEvent(journeyId, flightId);
      }
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Strategy 1 failed: $e');
      
      // Strategy 2: Try updating only visit_status and status
      try {
        final result = await client.from('simple_journeys').update({
          'visit_status': 'Completed',
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', journeyId).select();
        
        if (result.isEmpty) {
          throw Exception('Update succeeded but no rows were modified');
        }
        
        debugPrint('✅ Journey marked as completed (visit_status only): $journeyId');
        debugPrint('📋 Updated data: $result');
        
        // Add journey event
        if (addEvent) {
          await _addJourneyCompletedEvent(journeyId, flightId);
        }
        
        return true;
      } catch (e2) {
        debugPrint('⚠️ Strategy 2 failed: $e2');
        
        // Strategy 3: Try updating only status field
        try {
          final result = await client.from('simple_journeys').update({
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', journeyId).select();
          
          if (result.isEmpty) {
            throw Exception('Update succeeded but no rows were modified');
          }
          
          debugPrint('✅ Journey marked as completed (status only): $journeyId');
          debugPrint('📋 Updated data: $result');
          
          // Add journey event
          if (addEvent) {
            await _addJourneyCompletedEvent(journeyId, flightId);
          }
          
          return true;
        } catch (e3) {
          debugPrint('⚠️ Strategy 3 failed: $e3');
          
          // Strategy 4: Just add the journey event (this marks completion in the event log)
          if (addEvent) {
            try {
              await _addJourneyCompletedEvent(journeyId, flightId);
              debugPrint('✅ Journey completion tracked via event only: $journeyId');
              // Return true because we've at least tracked it via events
              return true;
            } catch (e4) {
              debugPrint('❌ All strategies failed. Last error: $e4');
              return false;
            }
          }
          
          debugPrint('❌ All update strategies failed');
          return false;
        }
      }
    }
  }
  
  /// Helper method to add journey completed event
  static Future<void> _addJourneyCompletedEvent(String journeyId, String? flightId) async {
    try {
      await client.from('journey_events').insert({
        'journey_id': journeyId,
        'event_type': 'journey_completed',
        'title': 'Journey Completed',
        'description': 'Flight has landed and journey is completed',
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'completed_by': 'system',
          'flight_id': flightId,
        },
      });
      debugPrint('✅ Journey completed event added');
    } catch (eventError) {
      debugPrint('⚠️ Failed to add journey event: $eventError');
      rethrow; // Re-throw so caller knows event creation failed
    }
  }

  /// Diagnostic method to test journey update capabilities
  /// Returns detailed information about why an update might fail
  static Future<Map<String, dynamic>> diagnoseJourneyUpdate(String journeyId) async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'journey_id': journeyId,
      'checks': <String, dynamic>{},
    };

    try {
      // Check 1: Is Supabase initialized?
      diagnostics['checks']['supabase_initialized'] = isInitialized;
      if (!isInitialized) {
        diagnostics['error'] = 'Supabase not initialized';
        return diagnostics;
      }

      // Check 2: Is user authenticated?
      final currentUser = client.auth.currentUser;
      diagnostics['checks']['user_authenticated'] = currentUser != null;
      diagnostics['current_user_id'] = currentUser?.id;
      diagnostics['current_user_email'] = currentUser?.email;
      
      if (currentUser == null) {
        diagnostics['error'] = 'No authenticated user';
        return diagnostics;
      }

      // Check 3: Does journey exist?
      try {
        final journey = await client
            .from('journeys')
            .select('*')
            .eq('id', journeyId)
            .maybeSingle();

        diagnostics['checks']['journey_exists'] = journey != null;
        if (journey != null) {
          diagnostics['journey_data'] = {
            'id': journey['id'],
            'passenger_id': journey['passenger_id'],
            'current_phase': journey['current_phase'],
            'visit_status': journey['visit_status'],
            'status': journey['status'],
            'flight_id': journey['flight_id'],
          };

          // Check 4: Does user own the journey?
          final ownsJourney = journey['passenger_id']?.toString() == currentUser.id;
          diagnostics['checks']['user_owns_journey'] = ownsJourney;
          
          if (!ownsJourney) {
            diagnostics['error'] = 'User does not own this journey';
            diagnostics['passenger_id'] = journey['passenger_id'];
          }
        } else {
          diagnostics['error'] = 'Journey not found in database';
          return diagnostics;
        }
      } catch (e) {
        diagnostics['checks']['journey_exists'] = false;
        diagnostics['journey_fetch_error'] = e.toString();
      }

      // Check 5: Test update permission
      try {
        // Try a safe test update (just updating updated_at)
        final testUpdate = await client
            .from('journeys')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', journeyId)
            .select();

        diagnostics['checks']['can_update'] = testUpdate.isNotEmpty;
        diagnostics['test_update_result'] = testUpdate.isNotEmpty ? 'Success' : 'No rows updated';
        
        if (testUpdate.isEmpty) {
          diagnostics['error'] = 'Update query succeeds but no rows are modified (likely RLS policy issue)';
        }
      } catch (e) {
        diagnostics['checks']['can_update'] = false;
        diagnostics['update_error'] = e.toString();
        diagnostics['error'] = 'Update failed: ${e.toString()}';
      }

      // Check 6: Can insert journey events?
      try {
        final testEvent = await client.from('journey_events').insert({
          'journey_id': journeyId,
          'event_type': 'diagnostic_test',
          'title': 'Diagnostic Test',
          'description': 'Testing event insertion capability',
          'event_timestamp': DateTime.now().toIso8601String(),
          'metadata': {'test': true},
        }).select();

        diagnostics['checks']['can_insert_events'] = testEvent.isNotEmpty;
      } catch (e) {
        diagnostics['checks']['can_insert_events'] = false;
        diagnostics['event_insert_error'] = e.toString();
      }

      // Final assessment
      final allChecksPassed = diagnostics['checks']['supabase_initialized'] == true &&
          diagnostics['checks']['user_authenticated'] == true &&
          diagnostics['checks']['journey_exists'] == true &&
          diagnostics['checks']['user_owns_journey'] == true &&
          diagnostics['checks']['can_update'] == true;

      diagnostics['can_complete_journey'] = allChecksPassed;
      
      if (allChecksPassed) {
        diagnostics['recommendation'] = 'All checks passed. Journey completion should work.';
      } else {
        diagnostics['recommendation'] = _getDiagnosticRecommendation(diagnostics['checks']);
      }

    } catch (e) {
      diagnostics['fatal_error'] = e.toString();
    }

    return diagnostics;
  }

  /// Get recommendation based on diagnostic results
  static String _getDiagnosticRecommendation(Map<String, dynamic> checks) {
    if (checks['supabase_initialized'] != true) {
      return 'Initialize Supabase before attempting journey operations.';
    }
    if (checks['user_authenticated'] != true) {
      return 'User must be authenticated. Please log in.';
    }
    if (checks['journey_exists'] != true) {
      return 'Journey not found in database. Ensure journey was created successfully.';
    }
    if (checks['user_owns_journey'] != true) {
      return 'User does not own this journey. Check passenger_id matches auth.uid().';
    }
    if (checks['can_update'] != true) {
      return 'Database update is blocked. Check Supabase RLS policies for UPDATE on journeys table.';
    }
    if (checks['can_insert_events'] != true) {
      return 'Cannot insert journey events. Check RLS policies for INSERT on journey_events table.';
    }
    return 'Unknown issue. Check detailed diagnostics.';
  }

  // ============================================================================
  // NEW SIMPLIFIED JOURNEY SAVE METHOD - Saves directly after scanning
  // ============================================================================
  // This method saves journey data directly to simple_journeys table
  // without Cirium verification or airline/airport table creation
  // ============================================================================
  
  /// Save journey data directly to simple_journeys table after boarding pass scan
  /// This bypasses Cirium API and airline/airport table creation
  static Future<Map<String, dynamic>?> saveSimpleJourney({
    required String userId,
    required String pnr,
    String? carrierCode,
    String? flightNumber,
    String? airlineName,
    String? departureAirportCode,
    String? departureAirportName,
    String? departureCity,
    String? departureCountry,
    String? arrivalAirportCode,
    String? arrivalAirportName,
    String? arrivalCity,
    String? arrivalCountry,
    required DateTime flightDate,
    DateTime? scheduledDeparture,
    DateTime? scheduledArrival,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? aircraftType,
    Map<String, dynamic>? boardingPassData,
  }) async {
    if (!isInitialized) {
      debugPrint('❌ Supabase not initialized');
      return null;
    }

    // Validate required fields
    if (userId.isEmpty || pnr.isEmpty) {
      debugPrint('❌ Missing required fields: userId or pnr');
      return null;
    }

    try {
      // Check for duplicate (PNR + passenger_id)
      final existingJourney = await client
          .from('simple_journeys')
          .select('id, pnr')
          .eq('pnr', pnr)
          .eq('passenger_id', userId)
          .maybeSingle();

      if (existingJourney != null) {
        debugPrint('⚠️ Duplicate journey detected: PNR=$pnr for user=$userId');
        return {'duplicate': true, 'existing_journey': existingJourney};
      }

      // Prepare journey data
      final journeyData = {
        'passenger_id': userId,
        'pnr': pnr,
        'carrier_code': carrierCode,
        'flight_number': flightNumber,
        'airline_name': airlineName,
        'departure_airport_code': departureAirportCode,
        'departure_airport_name': departureAirportName,
        'departure_city': departureCity,
        'departure_country': departureCountry,
        'arrival_airport_code': arrivalAirportCode,
        'arrival_airport_name': arrivalAirportName,
        'arrival_city': arrivalCity,
        'arrival_country': arrivalCountry,
        'flight_date': flightDate.toIso8601String().split('T')[0], // Date only
        'scheduled_departure': scheduledDeparture?.toIso8601String(),
        'scheduled_arrival': scheduledArrival?.toIso8601String(),
        'seat_number': seatNumber,
        'class_of_travel': classOfTravel,
        'terminal': terminal,
        'gate': gate,
        'aircraft_type': aircraftType,
        'visit_status': 'Upcoming',
        'status': 'active',
        'current_phase': 'pre_check_in',
        'boarding_pass_data': boardingPassData, // Store raw boarding pass data
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert journey
      final journey = await client
          .from('simple_journeys')
          .insert(journeyData)
          .select()
          .single();

      debugPrint('✅ Simple journey saved successfully: ${journey['id']}');
      return journey;
    } catch (e) {
      debugPrint('❌ Error saving simple journey: $e');
      return null;
    }
  }
}
