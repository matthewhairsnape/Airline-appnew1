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

  static Future<void> initialize() async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

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
        'user_id': userId,
        'flight_id': flightData['id'],
        'pnr': pnr,
        'seat_number': seatNumber,
        'class_of_travel': classOfTravel,
        'terminal': terminal,
        'gate': gate,
        'boarding_pass_scanned_at': DateTime.now().toIso8601String(),
        'status': 'scheduled',
        'current_phase': 'pre_check_in',
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
          .eq('user_id', userId)
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
}

