import 'package:flutter/material.dart';
import 'supabase_service.dart';

class PhaseFeedbackService {
  static final _client = SupabaseService.client;

  /// Submit feedback based on the phase to the correct table
  static Future<bool> submitPhaseFeedback({
    required String userId,
    required String journeyId, // This could be PNR or actual journey UUID
    required String flightId, // This could be PNR or actual flight UUID
    required String seat,
    required String phase,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('🔍 Processing phase: "$phase" for journey: $journeyId');

      // Determine if journeyId is a UUID or PNR
      final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(journeyId);
      
      Map<String, dynamic>? journeyData;
      String actualJourneyId;
      String? actualFlightId;

      if (isUuid) {
        // journeyId is already a UUID, use it directly
        debugPrint('🔍 Journey ID is UUID, using directly');
        actualJourneyId = journeyId;
        
        // ============================================================================
        // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
        // ============================================================================
        // // Get flight_id from journey record
        // try {
        //   journeyData = await _client
        //       .from('journeys')
        //       .select('flight_id')
        //       .eq('id', journeyId)
        //       .maybeSingle();
        //   
        //   if (journeyData == null) {
        //     debugPrint('❌ Journey not found in database for UUID: $journeyId');
        //     // Still proceed - the journey might be created later or the UUID might be valid but not yet in DB
        //     debugPrint('⚠️ Proceeding with journeyId as-is, flightId will be null');
        //   } else {
        //     actualFlightId = journeyData['flight_id'] as String?;
        //     debugPrint('✅ Found journey in database, flight ID: $actualFlightId');
        //   }
        // } catch (e) {
        //   debugPrint('⚠️ Error looking up journey: $e');
        //   debugPrint('⚠️ Proceeding with journeyId as-is');
        // }
        // ============================================================================
        // END OF OLD CODE
        // ============================================================================
        
        // NEW CODE - Check simple_journeys table
        try {
          journeyData = await _client
              .from('simple_journeys')
              .select('id')
              .eq('id', journeyId)
              .maybeSingle();
          
          if (journeyData == null) {
            debugPrint('❌ Journey not found in simple_journeys for UUID: $journeyId');
            debugPrint('⚠️ Proceeding with journeyId as-is, flightId will be null');
          } else {
            debugPrint('✅ Found journey in simple_journeys table');
            // simple_journeys doesn't have flight_id, so actualFlightId stays null
            actualFlightId = null;
          }
        } catch (e) {
          debugPrint('⚠️ Error looking up journey in simple_journeys: $e');
          debugPrint('⚠️ Proceeding with journeyId as-is');
        }
      } else {
        // journeyId is PNR, need to look up the actual journey
        debugPrint('🔍 Journey ID is PNR, looking up journey');
        journeyData = await _getJourneyData(journeyId);
        if (journeyData == null) {
          debugPrint('❌ No journey found for PNR: $journeyId');
          debugPrint('💡 Journey may not exist in database yet. Cannot submit feedback without journey record.');
          return false;
        }
        
        actualJourneyId = journeyData['id'] as String;
        actualFlightId = journeyData['flight_id'] as String?;
        debugPrint('✅ Found journey for PNR, journey ID: $actualJourneyId, flight ID: $actualFlightId');
      }

      debugPrint('✅ Using journey ID: $actualJourneyId, flight ID: $actualFlightId');

      // Normalize phase names for better matching
      final normalizedPhase = phase.toLowerCase().trim();

      // Check post-flight FIRST (before in-flight) since "post-flight" contains "flight"
      if (normalizedPhase == 'post-flight' ||
          normalizedPhase.contains('post') ||
          normalizedPhase.contains('overall') ||
          normalizedPhase.contains('experience')) {
        debugPrint('📝 Routing to overall feedback...');
        return await _submitFeedback(
          userId: userId,
          journeyId: actualJourneyId,
          flightId:
              actualFlightId ?? actualJourneyId, // Use journey ID as fallback
          seat: seat,
          overallRating: overallRating,
          likes: likes,
          dislikes: dislikes,
        );
      } else if (normalizedPhase == 'pre-flight' ||
          normalizedPhase.contains('pre') ||
          normalizedPhase.contains('airport') ||
          normalizedPhase.contains('at the airport')) {
        debugPrint('🏢 Routing to airport review...');
        return await _submitAirportReview(
          userId: userId,
          journeyId: actualJourneyId,
          flightId:
              actualFlightId ?? actualJourneyId, // Use journey ID as fallback
          seat: seat,
          overallRating: overallRating,
          likes: likes,
          dislikes: dislikes,
        );
      } else if (normalizedPhase == 'in-flight' ||
          normalizedPhase.contains('in') ||
          (normalizedPhase.contains('flight') && !normalizedPhase.contains('post')) ||
          normalizedPhase.contains('during the flight')) {
        debugPrint('✈️ Routing to airline review...');
        return await _submitAirlineReview(
          userId: userId,
          journeyId: actualJourneyId,
          flightId:
              actualFlightId ?? actualJourneyId, // Use journey ID as fallback
          seat: seat,
          overallRating: overallRating,
          likes: likes,
          dislikes: dislikes,
        );
      } else {
        debugPrint('❌ Unknown phase: $phase');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error submitting phase feedback: $e');
      return false;
    }
  }

  /// Get journey data by PNR
  static Future<Map<String, dynamic>?> _getJourneyData(String pnr) async {
    try {
      // ============================================================================
      // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
      // ============================================================================
      // final response = await _client
      //     .from('journeys')
      //     .select('id, flight_id, pnr')
      //     .eq('pnr', pnr)
      //     .maybeSingle();

      // if (response == null) {
      //   debugPrint('❌ No journey found for PNR: $pnr');
      //   return null;
      // }

      // debugPrint('✅ Found journey data: $response');
      // return response;
      // ============================================================================
      // END OF OLD CODE
      // ============================================================================
      
      // NEW CODE - Check simple_journeys table
      final response = await _client
          .from('simple_journeys')
          .select('id, pnr')
          .eq('pnr', pnr)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ No journey found for PNR in simple_journeys: $pnr');
        return null;
      }

      debugPrint('✅ Found journey data in simple_journeys: $response');
      // Return with id only (simple_journeys doesn't have flight_id)
      return {
        'id': response['id'],
        'pnr': response['pnr'],
        'flight_id': null, // simple_journeys doesn't have flight_id
      };
    } catch (e) {
      debugPrint('❌ Error getting journey data for PNR $pnr: $e');
      return null;
    }
  }

  /// Submit airport review for Pre-Flight phase
  static Future<bool> _submitAirportReview({
    required String userId,
    required String journeyId, // This is now the actual database UUID
    required String flightId, // This is now the actual database UUID
    required String seat,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('🏢 Submitting airport review...');

      // Get airport info from flight using the actual flight ID
      final flightData = await _client
          .from('flights')
          .select('departure_airport_id, arrival_airport_id')
          .eq('id', flightId)
          .single();

      final departureAirportId = flightData['departure_airport_id'];
      final arrivalAirportId = flightData['arrival_airport_id'];

      // For "At the Airport" feedback, we typically want the departure airport
      final airportId = departureAirportId ?? arrivalAirportId;
      if (airportId == null) {
        debugPrint('❌ No airport ID found for flight');
        return false;
      }

      debugPrint('✅ Found airport ID: $airportId');

      // Map feedback selections to airport review scores
      final scores = _mapToAirportScores(likes, dislikes, overallRating);

      // Check if review already exists for this journey-airport combination
      final existingReview = await _client
          .from('airport_reviews')
          .select('id')
          .eq('journey_id', journeyId)
          .eq('airport_id', airportId)
          .maybeSingle();

      if (existingReview != null) {
        // Update existing review
        debugPrint('🔄 Updating existing airport review');
        await _client.from('airport_reviews').update({
          'overall_score': (overallRating / 5.0).toStringAsFixed(2),
          'cleanliness': scores['cleanliness'],
          'facilities': scores['facilities'],
          'staff': scores['staff'],
          'waiting_time': scores['waiting_time'],
          'accessibility': scores['accessibility'],
          'comments': _createCommentFromSelections(likes, dislikes),
          'would_recommend': overallRating >= 4,
        }).eq('id', existingReview['id']);
        
        debugPrint('✅ Airport review updated successfully');
      } else {
        // Insert new review
        debugPrint('➕ Creating new airport review');
        await _client.from('airport_reviews').insert({
          'journey_id': journeyId,
          'user_id': userId,
          'airport_id': airportId,
          'overall_score': (overallRating / 5.0).toStringAsFixed(2),
          'cleanliness': scores['cleanliness'],
          'facilities': scores['facilities'],
          'staff': scores['staff'],
          'waiting_time': scores['waiting_time'],
          'accessibility': scores['accessibility'],
          'comments': _createCommentFromSelections(likes, dislikes),
          'would_recommend': overallRating >= 4,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        debugPrint('✅ Airport review created successfully');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting airport review: $e');
      return false;
    }
  }

  /// Submit airline review for In-Flight phase
  static Future<bool> _submitAirlineReview({
    required String userId,
    required String journeyId, // This is now the actual database UUID
    required String flightId, // This is now the actual database UUID
    required String seat,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('✈️ Submitting airline review...');

      // Get airline info from flight using the actual flight ID
      String? airlineId;

              try {
                // Try to get airline_id directly, or get carrier info to find airline
                final flightData = await _client
                    .from('flights')
                    .select('airline_id, carrier_code, flight_number')
                    .eq('id', flightId)
                    .maybeSingle();

                if (flightData == null) {
                  debugPrint('❌ Flight not found: $flightId');
                  return false;
                }

                // Try airline_id first
                airlineId = flightData['airline_id'];

                // If no airline_id, try to find airline by carrier_code
                if (airlineId == null) {
                  final carrierCode = flightData['carrier_code'];
                  
                  // ============================================================================
                  // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
                  // ============================================================================
                  // // Get Cirium data from journeys table (stored in media column)
                  // Map<String, dynamic>? apiData;
                  // try {
                  //   final journeyData = await _client
                  //       .from('journeys')
                  //       .select('media')
                  //       .eq('id', journeyId)
                  //       .maybeSingle();
                  //   apiData = journeyData?['media'] as Map<String, dynamic>?;
                  //   if (apiData != null) {
                  //     debugPrint('✅ Found Cirium API data in journey');
                  //   }
                  // } catch (e) {
                  //   debugPrint('⚠️ Could not fetch API data from journey: $e');
                  // }
                  // ============================================================================
                  // END OF OLD CODE
                  // ============================================================================
                  
                  // NEW CODE - Get boarding pass data from simple_journeys table
                  Map<String, dynamic>? apiData;
                  try {
                    final journeyData = await _client
                        .from('simple_journeys')
                        .select('boarding_pass_data')
                        .eq('id', journeyId)
                        .maybeSingle();
                    apiData = journeyData?['boarding_pass_data'] as Map<String, dynamic>?;
                    if (apiData != null) {
                      debugPrint('✅ Found boarding pass data in simple_journey');
                    }
                  } catch (e) {
                    debugPrint('⚠️ Could not fetch boarding pass data from simple_journey: $e');
                  }
                  
                  debugPrint('🔍 No airline_id in flight, looking up by carrier_code: $carrierCode');

                  if (carrierCode != null && carrierCode.toString().isNotEmpty) {
                    final airlineData = await _client
                        .from('airlines')
                        .select('id')
                        .eq('iata_code', carrierCode)
                        .maybeSingle();

                    airlineId = airlineData?['id'];

                    // If airline not found, create it with full details
                    if (airlineId == null) {
                      debugPrint('🔄 Airline not found for $carrierCode, creating...');
                      try {
                        // Get airline details from API data first, then fall back to local
                        final airlineDetails = _getAirlineDetailsFromApiOrCode(carrierCode, apiData);
                        
                        final newAirline = await _client
                            .from('airlines')
                            .insert({
                              'iata_code': carrierCode,
                              'name': airlineDetails['name'] ?? 'Airline $carrierCode',
                              'icao_code': airlineDetails['icao_code'],
                              'country': airlineDetails['country'],
                              'logo_url': 'https://www.gstatic.com/flights/airline_logos/70px/$carrierCode.png',
                              'created_at': DateTime.now().toIso8601String(),
                              'updated_at': DateTime.now().toIso8601String(),
                            })
                            .select('id')
                            .single();

                        airlineId = newAirline['id'];
                        debugPrint('✅ Created airline: $airlineId for $carrierCode');
                        if (airlineDetails['icao_code'] != null) {
                          debugPrint('   ICAO: ${airlineDetails['icao_code']}, Country: ${airlineDetails['country']}');
                        }
                        if (apiData != null) {
                          debugPrint('   ✅ Used API data for airline details');
                        }
                      } catch (insertError) {
                        debugPrint('⚠️ Failed to create airline: $insertError');
                        // Try to fetch again in case it was created by another request
                        final retryAirline = await _client
                            .from('airlines')
                            .select('id')
                            .eq('iata_code', carrierCode)
                            .maybeSingle();
                        airlineId = retryAirline?['id'];
                      }
                    }
                  }
                }
      } catch (e) {
        debugPrint('❌ Error getting airline info: $e');
        return false;
      }

      if (airlineId == null) {
        debugPrint('❌ No airline ID found for flight $flightId');
        debugPrint('💡 Flight may not have airline_id or carrier_code set');
        return false;
      }

      debugPrint('✅ Found airline ID: $airlineId');

      // Map feedback selections to airline review scores
      final scores = _mapToAirlineScores(likes, dislikes, overallRating);

      try {
        // Check if review already exists for this journey-airline combination
        final existingReview = await _client
            .from('airline_reviews')
            .select('id')
            .eq('journey_id', journeyId)
            .eq('airline_id', airlineId)
            .maybeSingle();

        if (existingReview != null) {
          // Update existing review
          debugPrint('🔄 Updating existing airline review');
          await _client.from('airline_reviews').update({
            'overall_score': (overallRating / 5.0).toStringAsFixed(2),
            'seat_comfort': scores['seat_comfort'],
            'cabin_service': scores['cabin_service'],
            'food_beverage': scores['food_beverage'],
            'entertainment': scores['entertainment'],
            'value_for_money': scores['value_for_money'],
            'comments': _createCommentFromSelections(likes, dislikes),
            'would_recommend': overallRating >= 4,
          }).eq('id', existingReview['id']);
          
          debugPrint('✅ Airline review updated successfully');
        } else {
          // Insert new review
          debugPrint('➕ Creating new airline review');
          await _client.from('airline_reviews').insert({
            'journey_id': journeyId,
            'user_id': userId,
            'airline_id': airlineId,
            'overall_score': (overallRating / 5.0).toStringAsFixed(2),
            'seat_comfort': scores['seat_comfort'],
            'cabin_service': scores['cabin_service'],
            'food_beverage': scores['food_beverage'],
            'entertainment': scores['entertainment'],
            'value_for_money': scores['value_for_money'],
            'comments': _createCommentFromSelections(likes, dislikes),
            'would_recommend': overallRating >= 4,
            'created_at': DateTime.now().toIso8601String(),
          });
          
          debugPrint('✅ Airline review created successfully');
        }

        // Update leaderboard_scores for in-flight feedback categories
        await _updateLeaderboardScores(
          airlineId: airlineId,
          overallRating: overallRating,
          categoryScores: scores,
        );
      } catch (insertError) {
        // Check if the error is related to leaderboard_scores RLS policy
        // This is a known issue where the trigger fails but the review should still be accepted
        if (insertError.toString().contains('leaderboard_scores') ||
            insertError.toString().contains('row-level security')) {
          debugPrint(
              '⚠️ Leaderboard update failed due to RLS policy, but review was submitted: $insertError');
          debugPrint('✅ Airline review submitted (leaderboard update skipped)');
          return true;
        } else {
          // Re-throw if it's a different error
          rethrow;
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error submitting airline review: $e');
      return false;
    }
  }

  /// Submit feedback for Post-Flight phase
  static Future<bool> _submitFeedback({
    required String userId,
    required String journeyId, // This could be UUID or PNR
    required String flightId, // This could be UUID or PNR
    required String seat,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('📝 Submitting overall feedback...');
      debugPrint('   Input journeyId: $journeyId');
      debugPrint('   Input flightId: $flightId');

      // Resolve journeyId and flightId to actual UUIDs (same logic as submitPhaseFeedback)
      final isJourneyUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(journeyId);
      
      String actualJourneyId;
      String? actualFlightId;
      
      if (isJourneyUuid) {
        actualJourneyId = journeyId;
        // ============================================================================
        // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
        // ============================================================================
        // // Get flight_id from journey record
        // final journeyLookup = await _client
        //     .from('journeys')
        //     .select('flight_id')
        //     .eq('id', journeyId)
        //     .maybeSingle();
        // actualFlightId = journeyLookup?['flight_id'] as String?;
        // ============================================================================
        // END OF OLD CODE
        // ============================================================================
        
        // NEW CODE - Check simple_journeys table
        final journeyLookup = await _client
            .from('simple_journeys')
            .select('id')
            .eq('id', journeyId)
            .maybeSingle();
        // simple_journeys doesn't have flight_id
        actualFlightId = null;
      } else {
        // journeyId is PNR, need to look up the actual journey
        debugPrint('🔍 Journey ID is PNR, looking up journey');
        final journeyLookup = await _getJourneyData(journeyId);
        if (journeyLookup == null) {
          debugPrint('❌ No journey found for PNR: $journeyId');
          return false;
        }
        actualJourneyId = journeyLookup['id'] as String;
        actualFlightId = journeyLookup['flight_id'] as String?;
      }
      
      debugPrint('✅ Resolved journey ID: $actualJourneyId, flight ID: $actualFlightId');

      // ============================================================================
      // OLD CODE - COMMENTED OUT (Uses old 'journeys' table)
      // ============================================================================
      // // First check if journey is actually completed
      // final journeyStatusData = await _client
      //     .from('journeys')
      //     .select('current_phase, visit_status, status')
      //     .eq('id', actualJourneyId)
      //     .maybeSingle();
      // ============================================================================
      // END OF OLD CODE
      // ============================================================================
      
      // NEW CODE - Check simple_journeys table
      final journeyStatusData = await _client
          .from('simple_journeys')
          .select('current_phase, visit_status, status')
          .eq('id', actualJourneyId)
          .maybeSingle();

      String? currentPhase;
      String? visitStatus;
      String? status;

      if (journeyStatusData == null) {
        debugPrint('❌ Journey not found: $actualJourneyId');
        debugPrint('💡 This might happen if the journey was deleted or the ID is incorrect.');
        // For Post-Flight feedback, we can still try to insert even if journey lookup fails
        // The database foreign key constraint will handle validation
        debugPrint('⚠️ Attempting to submit feedback anyway - database will validate');
      } else {
        currentPhase = journeyStatusData['current_phase'] as String?;
        visitStatus = journeyStatusData['visit_status'] as String?;
        status = journeyStatusData['status'] as String?;
        debugPrint('🔍 Journey status - phase: $currentPhase, visit_status: $visitStatus, status: $status');
      }

      // Note: Removed auto-completion functionality - journey completion is now manual only
      // Users must explicitly complete the journey, submitting overall review does not auto-complete
      debugPrint('ℹ️ Journey status will not be changed by feedback submission');

      // ============================================================================
      // OLD CODE - COMMENTED OUT (Uses 'feedback' table with foreign key to 'journeys')
      // ============================================================================
      // // Use feedback table for overall experience
      // // Try different phase values that might be valid
      // // Note: 'completed' phase violates database constraint, using alternatives
      // final validPhases = [
      //   'landed',      // Most common valid phase
      //   'post-flight',
      //   'arrival',
      //   'overall',
      //   'final'
      // ];
      // String? successfulPhase;

      // for (final phase in validPhases) {
      //   try {
      //     debugPrint('🔄 Attempting to insert feedback with phase: $phase');
      //     debugPrint('   journey_id: $actualJourneyId');
      //     debugPrint('   flight_id: ${actualFlightId ?? actualJourneyId}');
      //     debugPrint('   rating: $overallRating');
      //     
      //     // Try with all fields first
      //     final insertData = {
      //       'journey_id': actualJourneyId,
      //       'flight_id': actualFlightId ?? actualJourneyId, // Use journey ID as fallback if flight_id is null
      //       'phase': phase,
      //       'rating': overallRating.toDouble(),
      //       'comment': _createCommentFromSelections(likes, dislikes),
      //       'created_at': DateTime.now().toIso8601String(),
      //     };
      //     
      //     // Add optional fields if they exist in schema
      //     try {
      //       insertData['category'] = 'overall_experience';
      //       insertData['sentiment'] = _getSentiment(overallRating);
      //       insertData['timestamp'] = DateTime.now().toIso8601String();
      //       final tags = _extractTags(likes, dislikes);
      //       if (tags.isNotEmpty) {
      //         insertData['tags'] = tags;
      //       }
      //     } catch (e) {
      //       debugPrint('⚠️ Error adding optional fields: $e');
      //       // Continue without optional fields
      //     }
      //     
      //     await _client.from('feedback').insert(insertData);
      //     successfulPhase = phase;
      //     debugPrint('✅ Successfully inserted feedback with phase: $phase');
      //     break;
      //   } catch (e, stackTrace) {
      //     debugPrint('⚠️ Phase "$phase" failed: $e');
      //     debugPrint('   Stack trace: $stackTrace');
      //     
      //     // If it's a foreign key constraint error, the journey/flight might not exist
      //     if (e.toString().contains('foreign key') || 
      //         e.toString().contains('violates foreign key constraint')) {
      //       debugPrint('❌ Foreign key constraint violation - journey or flight may not exist');
      //       debugPrint('   This might mean the journey_id or flight_id is invalid');
      //       // Don't try other phases if it's a foreign key issue
      //       throw Exception('Journey or flight not found in database: $e');
      //     }
      //     
      //     // If it's a schema error, try minimal fields only
      //     if (e.toString().contains('schema') || 
      //         e.toString().contains('does not exist') ||
      //         e.toString().contains('column') ||
      //         e.toString().contains('unknown')) {
      //       debugPrint('🔄 Schema error detected, trying minimal fields only...');
      //       try {
      //         await _client.from('feedback').insert({
      //           'journey_id': actualJourneyId,
      //           'flight_id': actualFlightId ?? actualJourneyId, // Use journey ID as fallback if flight_id is null
      //           'phase': phase,
      //           'rating': overallRating.toDouble(),
      //           'comment': _createCommentFromSelections(likes, dislikes),
      //         });
      //         successfulPhase = phase;
      //         debugPrint('✅ Minimal fields insert successful for phase: $phase');
      //         break;
      //       } catch (fallbackError) {
      //         debugPrint('⚠️ Minimal fields also failed: $fallbackError');
      //         continue;
      //       }
      //     }
      //     continue;
      //   }
      // }

      // if (successfulPhase == null) {
      //   debugPrint('❌ All phase attempts failed for feedback submission');
      //   throw Exception('No valid phase found for feedback table. All attempts failed.');
      // }

      // debugPrint('✅ Used phase: $successfulPhase');
      // ============================================================================
      // END OF OLD CODE
      // ============================================================================
      
      // NEW CODE - Use stage_feedback table instead (works with simple_journeys)
      debugPrint('📝 Submitting overall feedback to stage_feedback table...');
      try {
        // Get current user
        final session = SupabaseService.client.auth.currentSession;
        final userId = session?.user.id ?? '';
        
        if (userId.isEmpty) {
          debugPrint('❌ No authenticated user found');
          return false;
        }
        
        // Extract tags from likes/dislikes
        final tags = _extractTags(likes, dislikes);
        
        // Submit to stage_feedback table with 'overall' stage
        await _client.from('stage_feedback').upsert({
          'journey_id': actualJourneyId,
          'user_id': userId,
          'stage': 'overall',
          'positive_selections': _convertLikesToMap(likes),
          'negative_selections': _convertDislikesToMap(dislikes),
          'overall_rating': overallRating,
          'additional_comments': _createCommentFromSelections(likes, dislikes),
          'feedback_timestamp': DateTime.now().toIso8601String(),
        });
        
        debugPrint('✅ Successfully submitted overall feedback to stage_feedback table');
      } catch (e) {
        debugPrint('❌ Error submitting to stage_feedback: $e');
        throw Exception('Failed to submit overall feedback: $e');
      }

      debugPrint('✅ Overall feedback submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting overall feedback: $e');
      return false;
    }
  }

  /// Map feedback selections to airport review scores
  static Map<String, int> _mapToAirportScores(
    Map<String, Set<String>> likes,
    Map<String, Set<String>> dislikes,
    int overallRating,
  ) {
    // Default scores based on overall rating
    final baseScore = overallRating;

    return {
      'cleanliness':
          _getCategoryScore(likes, dislikes, 'cleanliness', baseScore),
      'facilities': _getCategoryScore(likes, dislikes, 'facilities', baseScore),
      'staff': _getCategoryScore(likes, dislikes, 'staff', baseScore),
      'waiting_time': _getCategoryScore(likes, dislikes, 'waiting', baseScore),
      'accessibility':
          _getCategoryScore(likes, dislikes, 'accessibility', baseScore),
    };
  }

  /// Map feedback selections to airline review scores
  static Map<String, int> _mapToAirlineScores(
    Map<String, Set<String>> likes,
    Map<String, Set<String>> dislikes,
    int overallRating,
  ) {
    // Default scores based on overall rating
    final baseScore = overallRating;

    return {
      'seat_comfort': _getCategoryScore(likes, dislikes, 'seat', baseScore),
      'cabin_service': _getCategoryScore(likes, dislikes, 'service', baseScore),
      'food_beverage': _getCategoryScore(likes, dislikes, 'food', baseScore),
      'entertainment':
          _getCategoryScore(likes, dislikes, 'entertainment', baseScore),
      'value_for_money': _getCategoryScore(likes, dislikes, 'value', baseScore),
    };
  }

  /// Get score for a specific category based on likes/dislikes
  static int _getCategoryScore(
    Map<String, Set<String>> likes,
    Map<String, Set<String>> dislikes,
    String category,
    int baseScore,
  ) {
    // Count positive mentions
    int positiveCount = 0;
    int negativeCount = 0;

    for (final categoryLikes in likes.values) {
      for (final like in categoryLikes) {
        if (like.toLowerCase().contains(category.toLowerCase())) {
          positiveCount++;
        }
      }
    }

    for (final categoryDislikes in dislikes.values) {
      for (final dislike in categoryDislikes) {
        if (dislike.toLowerCase().contains(category.toLowerCase())) {
          negativeCount++;
        }
      }
    }

    // Adjust score based on mentions
    if (positiveCount > negativeCount) {
      return (baseScore + 1).clamp(1, 5);
    } else if (negativeCount > positiveCount) {
      return (baseScore - 1).clamp(1, 5);
    }

    return baseScore;
  }

  /// Create comment from user selections
  static String _createCommentFromSelections(
    Map<String, Set<String>> likes,
    Map<String, Set<String>> dislikes,
  ) {
    final comments = <String>[];

    // Add positive feedback
    for (final category in likes.keys) {
      final selections = likes[category];
      if (selections?.isNotEmpty == true) {
        comments.add('$category: ${selections!.join(', ')}');
      }
    }

    // Add negative feedback
    for (final category in dislikes.keys) {
      final selections = dislikes[category];
      if (selections?.isNotEmpty == true) {
        comments.add('$category issues: ${selections!.join(', ')}');
      }
    }

    return comments.join('; ');
  }

  /// Convert selections to JSON format for database storage
  static Map<String, dynamic> _convertSelectionsToJson(
      Map<String, Set<String>> selections) {
    final result = <String, dynamic>{};
    for (final entry in selections.entries) {
      result[entry.key] = entry.value.toList();
    }
    return result;
  }

  /// Get sentiment based on overall rating
  static String _getSentiment(int rating) {
    if (rating >= 4) {
      return 'positive';
    } else if (rating <= 2) {
      return 'negative';
    } else {
      return 'neutral';
    }
  }

  /// Extract tags from selections
  static List<String> _extractTags(
    Map<String, Set<String>> likes,
    Map<String, Set<String>> dislikes,
  ) {
    final tags = <String>[];

    for (final selections in likes.values) {
      tags.addAll(selections);
    }

    for (final selections in dislikes.values) {
      tags.addAll(selections);
    }

    return tags.take(10).toList(); // Limit to 10 tags
  }

  /// Convert likes Map<String, Set<String>> to Map<String, dynamic> for JSONB storage
  static Map<String, dynamic> _convertLikesToMap(Map<String, Set<String>> likes) {
    final result = <String, dynamic>{};
    for (final entry in likes.entries) {
      result[entry.key] = entry.value.toList();
    }
    return result;
  }

  /// Convert dislikes Map<String, Set<String>> to Map<String, dynamic> for JSONB storage
  static Map<String, dynamic> _convertDislikesToMap(Map<String, Set<String>> dislikes) {
    final result = <String, dynamic>{};
    for (final entry in dislikes.entries) {
      result[entry.key] = entry.value.toList();
    }
    return result;
  }

  /// Update leaderboard_scores table with in-flight feedback scores
  static Future<void> _updateLeaderboardScores({
    required String airlineId,
    required int overallRating,
    required Map<String, int> categoryScores,
  }) async {
    try {
      debugPrint('📊 Updating leaderboard_scores for airline: $airlineId');

      // Map of score types to their values (for in-flight feedback)
      final scoreTypes = {
        'overall': (overallRating / 5.0),
        'seat_comfort': (categoryScores['seat_comfort'] ?? overallRating) / 5.0,
        'cabin_service': (categoryScores['cabin_service'] ?? overallRating) / 5.0,
        'food_beverage': (categoryScores['food_beverage'] ?? overallRating) / 5.0,
        'entertainment': (categoryScores['entertainment'] ?? overallRating) / 5.0,
      };

      // Update/insert scores for each category using database function
      for (final entry in scoreTypes.entries) {
        final scoreType = entry.key;
        final newScore = entry.value;

        try {
          // Calculate Bayesian score for first-time insert
          const double C = 30.0; // Confidence parameter
          const double m = 3.5; // Prior mean
          final initialBayesianScore = (1.0 / 31.0) * newScore + (30.0 / 31.0) * m;

          // Use database function instead of direct INSERT/UPDATE
          // This bypasses RLS policy issues
          final result = await _client.rpc(
            'update_leaderboard_score',
            params: {
              'p_airline_id': airlineId,
              'p_score_type': scoreType,
              'p_score_value': newScore.clamp(0.0, 5.0),
              'p_review_count': 1, // Will be accumulated by the function
              'p_raw_score': newScore.clamp(0.0, 5.0),
              'p_bayesian_score': initialBayesianScore.clamp(0.0, 5.0),
              'p_confidence_level': 'low',
              'p_phases_completed': 1,
            },
          );

          if (result != null && result is List && result.isNotEmpty) {
            final reviewCount = result[0]['review_count'] ?? 1;
            final scoreValue = result[0]['score_value'] ?? newScore;
            debugPrint(
                '✅ Updated leaderboard_scores: $scoreType = $scoreValue ($reviewCount reviews)');
          } else {
            debugPrint('✅ Leaderboard score updated for: $scoreType');
          }
        } catch (categoryError) {
          debugPrint(
              '⚠️ Error updating leaderboard_scores for $scoreType: $categoryError');
          
          // Check if it's a "function doesn't exist" error
          if (categoryError.toString().contains('function') || 
              categoryError.toString().contains('does not exist') ||
              categoryError.toString().contains('update_leaderboard_score')) {
            debugPrint('💡 Database function not found. Please run LEADERBOARD_RLS_FIX.sql');
            debugPrint('   The function update_leaderboard_score() needs to be created in Supabase.');
            debugPrint('   File location: LEADERBOARD_RLS_FIX.sql in project root');
          }
          
          // Continue with other categories even if one fails
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error updating leaderboard_scores: $e');
      // Don't throw - leaderboard update failure shouldn't prevent review submission
    }
  }

  /// Get airline details from API data (Cirium) or IATA code
  /// Prioritizes API data over local hardcoded values
  static Map<String, String?> _getAirlineDetailsFromApiOrCode(
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
    return _getAirlineDetailsFromCode(iataCode);
  }

  /// Get airline details from IATA code (local database - fallback only)
  /// Returns name, ICAO code, and country for the airline
  static Map<String, String?> _getAirlineDetailsFromCode(String iataCode) {
    // Use the same mapping as in SupabaseService
    // This is a subset of major airlines - expand as needed
    final airlines = <String, Map<String, String>>{
      'AA': {'name': 'American Airlines', 'icao': 'AAL', 'country': 'United States'},
      'UA': {'name': 'United Airlines', 'icao': 'UAL', 'country': 'United States'},
      'DL': {'name': 'Delta Air Lines', 'icao': 'DAL', 'country': 'United States'},
      'BA': {'name': 'British Airways', 'icao': 'BAW', 'country': 'United Kingdom'},
      'LH': {'name': 'Lufthansa', 'icao': 'DLH', 'country': 'Germany'},
      'AF': {'name': 'Air France', 'icao': 'AFR', 'country': 'France'},
      'EK': {'name': 'Emirates', 'icao': 'UAE', 'country': 'United Arab Emirates'},
      'QR': {'name': 'Qatar Airways', 'icao': 'QTR', 'country': 'Qatar'},
      'SQ': {'name': 'Singapore Airlines', 'icao': 'SIA', 'country': 'Singapore'},
      'CX': {'name': 'Cathay Pacific', 'icao': 'CPA', 'country': 'Hong Kong'},
      'QF': {'name': 'Qantas', 'icao': 'QFA', 'country': 'Australia'},
      'VA': {'name': 'Virgin Australia', 'icao': 'VOZ', 'country': 'Australia'},
      'NZ': {'name': 'Air New Zealand', 'icao': 'ANZ', 'country': 'New Zealand'},
      'AC': {'name': 'Air Canada', 'icao': 'ACA', 'country': 'Canada'},
      'NH': {'name': 'All Nippon Airways', 'icao': 'ANA', 'country': 'Japan'},
      'JL': {'name': 'Japan Airlines', 'icao': 'JAL', 'country': 'Japan'},
      // Add more as needed - see supabase_service.dart for complete list
    };

    final details = airlines[iataCode.toUpperCase()];
    return {
      'name': details?['name'],
      'icao_code': details?['icao'],
      'country': details?['country'],
    };
  }
}
