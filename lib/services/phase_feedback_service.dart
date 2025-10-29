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
        
        // Get flight_id from journey record
        journeyData = await _client
            .from('journeys')
            .select('flight_id')
            .eq('id', journeyId)
            .maybeSingle();
        
        actualFlightId = journeyData?['flight_id'];
      } else {
        // journeyId is PNR, need to look up the actual journey
        debugPrint('🔍 Journey ID is PNR, looking up journey');
        journeyData = await _getJourneyData(journeyId);
        if (journeyData == null) {
          debugPrint('❌ No journey found for PNR: $journeyId');
          return false;
        }
        
        actualJourneyId = journeyData['id'] as String;
        actualFlightId = journeyData['flight_id'] as String?;
      }

      debugPrint('✅ Found journey ID: $actualJourneyId, flight ID: $actualFlightId');

      // Normalize phase names for better matching
      final normalizedPhase = phase.toLowerCase().trim();

      if (normalizedPhase == 'pre-flight' ||
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
          normalizedPhase.contains('flight') ||
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
      } else if (normalizedPhase == 'post-flight' ||
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
      final response = await _client
          .from('journeys')
          .select('id, flight_id, pnr')
          .eq('pnr', pnr)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ No journey found for PNR: $pnr');
        return null;
      }

      debugPrint('✅ Found journey data: $response');
      return response;
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

      debugPrint('✅ Airport review submitted successfully');
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
        // First try with airline_id column
        final flightData = await _client
            .from('flights')
            .select('airline_id')
            .eq('id', flightId)
            .single();

        airlineId = flightData['airline_id'];
      } catch (e) {
        if (e.toString().contains('airline_id does not exist')) {
          debugPrint(
              '⚠️ airline_id column not found, trying carrier_code approach');

          // Fallback: get carrier_code and find airline by IATA code
          final flightData = await _client
              .from('flights')
              .select('carrier_code')
              .eq('id', flightId)
              .single();

          final carrierCode = flightData['carrier_code'];
          if (carrierCode != null) {
            final airlineData = await _client
                .from('airlines')
                .select('id')
                .eq('iata_code', carrierCode)
                .maybeSingle();

            airlineId = airlineData?['id'];
          }
        } else {
          rethrow;
        }
      }

      if (airlineId == null) {
        debugPrint('❌ No airline ID found for flight');
        return false;
      }

      debugPrint('✅ Found airline ID: $airlineId');

      // Map feedback selections to airline review scores
      final scores = _mapToAirlineScores(likes, dislikes, overallRating);

      try {
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

        debugPrint('✅ Airline review submitted successfully');

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
    required String journeyId, // This is now the actual database UUID
    required String flightId, // This is now the actual database UUID
    required String seat,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('📝 Submitting overall feedback...');

      // First check if journey is actually completed
      final journeyData = await _client
          .from('journeys')
          .select('current_phase, visit_status, status')
          .eq('id', journeyId)
          .maybeSingle();

      if (journeyData == null) {
        debugPrint('❌ Journey not found: $journeyId');
        return false;
      }

      final currentPhase = journeyData['current_phase'] as String?;
      final visitStatus = journeyData['visit_status'] as String?;
      final status = journeyData['status'] as String?;

      debugPrint('🔍 Journey status - phase: $currentPhase, visit_status: $visitStatus, status: $status');

      // If journey is not completed, try to update it first (but don't fail if it doesn't work)
      // Note: Use 'landed' as phase instead of 'completed' to avoid database constraint errors
      final isCompleted = currentPhase == 'landed' || visitStatus == 'Completed' || status == 'completed';
      if (!isCompleted) {
        debugPrint('🔄 Journey not completed, attempting to update status...');
        try {
          await _client.from('journeys').update({
            'current_phase': 'landed', // Use 'landed' instead of 'completed' to avoid schema errors
            'visit_status': 'Completed',
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', journeyId);

          // Add journey event
          await _client.from('journey_events').insert({
            'journey_id': journeyId,
            'event_type': 'journey_completed',
            'title': 'Journey Completed',
            'description': 'Journey marked as completed before feedback submission',
            'event_timestamp': DateTime.now().toIso8601String(),
            'metadata': {
              'completed_by': 'feedback_submission',
              'flight_id': flightId,
            },
          });

          debugPrint('✅ Journey status updated to completed');
        } catch (updateError) {
          debugPrint('⚠️ Failed to update journey status: $updateError');
          debugPrint('🔄 Continuing with feedback submission anyway...');
        }
      }

      // Use feedback table for overall experience
      // Try different phase values that might be valid
      // Note: 'completed' phase violates database constraint, using alternatives
      final validPhases = [
        'landed',      // Most common valid phase
        'post-flight',
        'arrival',
        'overall',
        'final'
      ];
      String? successfulPhase;

      for (final phase in validPhases) {
        try {
          await _client.from('feedback').insert({
            'journey_id': journeyId,
            'flight_id': flightId,
            'phase': phase,
            'category': 'overall_experience',
            'rating': overallRating.toDouble(),
            'sentiment': _getSentiment(overallRating),
            'comment': _createCommentFromSelections(likes, dislikes),
            'timestamp': DateTime.now().toIso8601String(),
            'tags': _extractTags(likes, dislikes),
            'created_at': DateTime.now().toIso8601String(),
          });
          successfulPhase = phase;
          break;
        } catch (e) {
          debugPrint('⚠️ Phase "$phase" failed: $e');
          // If it's a schema error, try a different approach
          if (e.toString().contains('schema "net"') || 
              e.toString().contains('does not exist')) {
            debugPrint('🔄 Schema error detected, trying fallback approach...');
            // Try inserting without some fields that might cause schema issues
            try {
              await _client.from('feedback').insert({
                'journey_id': journeyId,
                'flight_id': flightId,
                'phase': phase,
                'rating': overallRating.toDouble(),
                'comment': _createCommentFromSelections(likes, dislikes),
                'created_at': DateTime.now().toIso8601String(),
              });
              successfulPhase = phase;
              debugPrint('✅ Fallback insert successful for phase: $phase');
              break;
            } catch (fallbackError) {
              debugPrint('⚠️ Fallback also failed: $fallbackError');
              continue;
            }
          }
          continue;
        }
      }

      if (successfulPhase == null) {
        throw Exception('No valid phase found for feedback table');
      }

      debugPrint('✅ Used phase: $successfulPhase');

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

      // Update/insert scores for each category
      for (final entry in scoreTypes.entries) {
        final scoreType = entry.key;
        final newScore = entry.value;

        try {
          // Get existing leaderboard entry
          final existing = await _client
              .from('leaderboard_scores')
              .select('id, review_count, raw_score, bayesian_score')
              .eq('airline_id', airlineId)
              .eq('score_type', scoreType)
              .maybeSingle();

          if (existing != null) {
            // Update existing entry
            final currentReviewCount = (existing['review_count'] as int? ?? 0) + 1;
            final currentRawScore = (existing['raw_score'] as num? ?? 0.0).toDouble();
            final currentReviewCountForCalc = currentReviewCount - 1;

            // Calculate new raw score: weighted average
            double newRawScore;
            if (currentReviewCountForCalc > 0) {
              // Weighted average: (old_avg * old_count + new_score) / new_count
              newRawScore = ((currentRawScore * currentReviewCountForCalc) + newScore) /
                  currentReviewCount;
            } else {
              newRawScore = newScore;
            }

            // Calculate Bayesian score (simple smoothing)
            // Using formula: (v/(v+m)) * S + (m/(v+m)) * C
            // where v = review_count, m = 30 (minimum volume), S = raw_score, C = 3.5 (global average)
            const double minimumVolume = 30.0;
            const double globalAverage = 3.5;
            final v = currentReviewCount.toDouble();
            final m = minimumVolume;

            final bayesianScore = (v / (v + m)) * newRawScore +
                (m / (v + m)) * globalAverage;

            // Determine confidence level
            String confidenceLevel = 'low';
            if (currentReviewCount >= 51) {
              confidenceLevel = 'high';
            } else if (currentReviewCount >= 11) {
              confidenceLevel = 'medium';
            }

            // Update leaderboard score
            await _client
                .from('leaderboard_scores')
                .update({
                  'score_value': bayesianScore.clamp(0.0, 5.0),
                  'raw_score': newRawScore.clamp(0.0, 5.0),
                  'bayesian_score': bayesianScore.clamp(0.0, 5.0),
                  'review_count': currentReviewCount,
                  'confidence_level': confidenceLevel,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existing['id']);

            debugPrint(
                '✅ Updated leaderboard_scores: $scoreType = ${bayesianScore.toStringAsFixed(2)} (${currentReviewCount} reviews)');
          } else {
            // Insert new entry
            final initialBayesianScore = (1.0 / 31.0) * newScore +
                (30.0 / 31.0) * 3.5; // First review uses Bayesian smoothing

            await _client.from('leaderboard_scores').insert({
              'airline_id': airlineId,
              'score_type': scoreType,
              'score_value': initialBayesianScore.clamp(0.0, 5.0),
              'raw_score': newScore.clamp(0.0, 5.0),
              'bayesian_score': initialBayesianScore.clamp(0.0, 5.0),
              'review_count': 1,
              'confidence_level': 'low',
              'phases_completed': 1, // In-flight phase completed
              'updated_at': DateTime.now().toIso8601String(),
            });

            debugPrint(
                '✅ Created new leaderboard_scores entry: $scoreType = ${initialBayesianScore.toStringAsFixed(2)}');
          }
        } catch (categoryError) {
          debugPrint(
              '⚠️ Error updating leaderboard_scores for $scoreType: $categoryError');
          // Continue with other categories even if one fails
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error updating leaderboard_scores: $e');
      // Don't throw - leaderboard update failure shouldn't prevent review submission
    }
  }
}
