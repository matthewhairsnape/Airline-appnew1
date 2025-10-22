import 'package:flutter/material.dart';
import 'supabase_service.dart';

class PhaseFeedbackService {
  static final _client = SupabaseService.client;

  /// Submit feedback based on the phase to the correct table
  static Future<bool> submitPhaseFeedback({
    required String userId,
    required String journeyId, // This is actually PNR
    required String flightId, // This is also PNR
    required String seat,
    required String phase,
    required int overallRating,
    required Map<String, Set<String>> likes,
    required Map<String, Set<String>> dislikes,
  }) async {
    try {
      debugPrint('🔍 Processing phase: "$phase" for PNR: $journeyId');

      // First, get the actual database IDs from the journey record
      final journeyData = await _getJourneyData(journeyId);
      if (journeyData == null) {
        debugPrint('❌ No journey found for PNR: $journeyId');
        return false;
      }

      final actualJourneyId = journeyData['id'] as String;
      final actualFlightId = journeyData['flight_id'] as String?;

      debugPrint(
          '✅ Found journey ID: $actualJourneyId, flight ID: $actualFlightId');

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

      // Use feedback table for overall experience
      // Try different phase values that might be valid
      final validPhases = [
        'completed',
        'landed',
        'post-flight',
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
}
