import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle real-time feedback using LISTEN/NOTIFY
/// Combines data from airport_reviews, leaderboard_scores, and feedback tables
class RealtimeFeedbackService {
  static final SupabaseClient _client = SupabaseService.client;
  static RealtimeChannel? _channel;
  static bool _isSubscribed = false;

  /// Initialize realtime feedback listener
  static Future<void> initialize() async {
    if (_isSubscribed) {
      debugPrint('📡 Already subscribed to realtime feedback');
      return;
    }

    try {
      debugPrint('🔊 Initializing LISTEN/NOTIFY for realtime feedback...');

      // Create a single channel for all feedback types
      _channel = _client.channel('realtime_feedback');

      // Listen for INSERT events on airport_reviews
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'airport_reviews',
        callback: (payload) {
          debugPrint('🏢 Received airport_review INSERT: ${payload.newRecord}');
        },
      );

      // Listen for INSERT events on leaderboard_scores
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'leaderboard_scores',
        callback: (payload) {
          debugPrint('📊 Received leaderboard_score INSERT: ${payload.newRecord}');
        },
      );

      // Listen for INSERT events on feedback
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'feedback',
        callback: (payload) {
          debugPrint('💬 Received feedback INSERT: ${payload.newRecord}');
        },
      );

      // Listen for UPDATE events on all tables
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'airport_reviews',
        callback: (payload) {
          debugPrint('🏢 Received airport_review UPDATE: ${payload.newRecord}');
        },
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'leaderboard_scores',
        callback: (payload) {
          debugPrint('📊 Received leaderboard_score UPDATE: ${payload.newRecord}');
        },
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'feedback',
        callback: (payload) {
          debugPrint('💬 Received feedback UPDATE: ${payload.newRecord}');
        },
      );

      // Subscribe to the channel
      await _channel!.subscribe();
      _isSubscribed = true;

      debugPrint('✅ Successfully subscribed to realtime feedback');
    } catch (e) {
      debugPrint('❌ Error initializing realtime feedback: $e');
      _isSubscribed = false;
    }
  }

  /// Get combined realtime feedback stream
  /// Priority: 1) Airport Reviews, 2) Leaderboard Scores, 3) Feedback
  static Stream<List<Map<String, dynamic>>> getCombinedFeedbackStream() {
    try {
      debugPrint('📡 Starting combined feedback stream...');

      return _client
          .from('airport_reviews')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .asyncMap((airportReviews) async {
            debugPrint('🏢 Fetched ${airportReviews.length} airport reviews');

            // Fetch leaderboard scores
            final leaderboardScores = await _client
                .from('leaderboard_scores')
                .select('''
                  id,
                  airline_id,
                  score_type,
                  score_value,
                  airlines!inner(
                    id,
                    name,
                    iata_code,
                    icao_code,
                    logo_url
                  )
                ''')
                .order('score_value', ascending: false)
                .limit(30);

            debugPrint('📊 Fetched ${leaderboardScores.length} leaderboard scores');

            // Fetch feedback
            final feedbackData = await _client
                .from('feedback')
                .select()
                .order('created_at', ascending: false)
                .limit(30);

            debugPrint('💬 Fetched ${feedbackData.length} feedback entries');

            // Combine and format all feedback (set aggregate to false for individual entries)
            return await _formatCombinedFeedback(
              airportReviews,
              leaderboardScores,
              feedbackData,
              aggregate: false, // Don't aggregate - show individual passenger feedback
            );
          });
    } catch (e) {
      debugPrint('❌ Error creating combined feedback stream: $e');
      return Stream.value([]);
    }
  }

  /// Format combined feedback from all three sources
  static Future<List<Map<String, dynamic>>> _formatCombinedFeedback(
    List<dynamic> airportReviews,
    List<dynamic> leaderboardScores,
    List<dynamic> feedbackData,
    {bool aggregate = true}
  ) async {
    List<Map<String, dynamic>> combinedFeedback = [];

    // Process airport reviews (Priority 1)
    for (final review in airportReviews) {
      final formatted = await _formatAirportReview(review);
      combinedFeedback.add(formatted);
    }

    // Process leaderboard scores (Priority 2)
    for (final score in leaderboardScores) {
      combinedFeedback.add(_formatLeaderboardScore(score));
    }

    // Process feedback entries (Priority 3) - need to await async formatting
    for (final feedback in feedbackData) {
      final formatted = await _formatFeedback(feedback);
      combinedFeedback.add(formatted);
    }

    // Aggregate likes/dislikes counts by flight before sorting (only if aggregate is true)
    if (aggregate) {
      combinedFeedback = _aggregateFeedbackCounts(combinedFeedback);
    } else {
        // For individual entries, ensure counts are set to 1 for each like/dislike
        combinedFeedback = combinedFeedback.map((feedback) {
          final likesList = feedback['likes'];
          final likes = (likesList is List)
              ? likesList.map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                }).toList()
              : <Map<String, dynamic>>[];
          
          final dislikesList = feedback['dislikes'];
          final dislikes = (dislikesList is List)
              ? dislikesList.map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                }).toList()
              : <Map<String, dynamic>>[];
          
          // Update counts to reflect actual passenger count (1 passenger per feedback)
          for (var like in likes) {
            like['count'] = 1;
          }
          for (var dislike in dislikes) {
            dislike['count'] = 1;
          }
          
          final updatedFeedback = Map<String, dynamic>.from(feedback);
          updatedFeedback['likes'] = likes;
          updatedFeedback['dislikes'] = dislikes;
          
          return updatedFeedback;
        }).toList();
    }

    // Sort by timestamp (most recent first)
    combinedFeedback.sort((a, b) {
      final timeA = a['timestamp'] as DateTime?;
      final timeB = b['timestamp'] as DateTime?;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });

    debugPrint('✅ Combined ${combinedFeedback.length} feedback items');

    // Log the first 2 data items with score calculation details
    if (combinedFeedback.length >= 1) {
      debugPrint('📋 FIRST DATA ITEM:');
      debugPrint('   Type: ${combinedFeedback[0]['feedback_type']}');
      debugPrint('   ID: ${combinedFeedback[0]['id']}');
      debugPrint('   Flight: ${combinedFeedback[0]['flight']}');
      debugPrint('   Phase: ${combinedFeedback[0]['phase']}');
      debugPrint('   Airline: ${combinedFeedback[0]['airline']}');
      debugPrint('   Rating/Score: ${combinedFeedback[0]['overall_rating']}');
      
      // Show detailed score breakdown based on feedback type
      if (combinedFeedback[0]['feedback_type'] == 'airport') {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Overall Score: ${combinedFeedback[0]['overall_rating']}');
        debugPrint('     - Cleanliness: ${combinedFeedback[0]['cleanliness']}');
        debugPrint('     - Facilities: ${combinedFeedback[0]['facilities']}');
        debugPrint('     - Staff: ${combinedFeedback[0]['staff']}');
        debugPrint('     - Waiting Time: ${combinedFeedback[0]['waiting_time']}');
        debugPrint('     - Accessibility: ${combinedFeedback[0]['accessibility']}');
        debugPrint('     Note: Overall score comes directly from airport_reviews.overall_score');
      } else if (combinedFeedback[0]['feedback_type'] == 'leaderboard') {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Score Type: ${combinedFeedback[0]['score_type']}');
        debugPrint('     - Score Value: ${combinedFeedback[0]['score_value']}');
        debugPrint('     - Overall Rating (same as score_value): ${combinedFeedback[0]['overall_rating']}');
        debugPrint('     Note: Score is pre-calculated in leaderboard_scores table');
      } else {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Overall Rating: ${combinedFeedback[0]['overall_rating']}');
        debugPrint('     Note: Overall rating comes directly from feedback.overall_rating');
      }
      
      debugPrint('   Timestamp: ${combinedFeedback[0]['timestamp']}');
      debugPrint('   Full Data: ${combinedFeedback[0]}');
    }

    if (combinedFeedback.length >= 2) {
      debugPrint('📋 SECOND DATA ITEM:');
      debugPrint('   Type: ${combinedFeedback[1]['feedback_type']}');
      debugPrint('   ID: ${combinedFeedback[1]['id']}');
      debugPrint('   Flight: ${combinedFeedback[1]['flight']}');
      debugPrint('   Phase: ${combinedFeedback[1]['phase']}');
      debugPrint('   Airline: ${combinedFeedback[1]['airline']}');
      debugPrint('   Rating/Score: ${combinedFeedback[1]['overall_rating']}');
      
      // Show detailed score breakdown based on feedback type
      if (combinedFeedback[1]['feedback_type'] == 'airport') {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Overall Score: ${combinedFeedback[1]['overall_rating']}');
        debugPrint('     - Cleanliness: ${combinedFeedback[1]['cleanliness']}');
        debugPrint('     - Facilities: ${combinedFeedback[1]['facilities']}');
        debugPrint('     - Staff: ${combinedFeedback[1]['staff']}');
        debugPrint('     - Waiting Time: ${combinedFeedback[1]['waiting_time']}');
        debugPrint('     - Accessibility: ${combinedFeedback[1]['accessibility']}');
        debugPrint('     Note: Overall score comes directly from airport_reviews.overall_score');
      } else if (combinedFeedback[1]['feedback_type'] == 'leaderboard') {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Score Type: ${combinedFeedback[1]['score_type']}');
        debugPrint('     - Score Value: ${combinedFeedback[1]['score_value']}');
        debugPrint('     - Overall Rating (same as score_value): ${combinedFeedback[1]['overall_rating']}');
        debugPrint('     Note: Score is pre-calculated in leaderboard_scores table');
      } else {
        debugPrint('   Score Breakdown:');
        debugPrint('     - Overall Rating: ${combinedFeedback[1]['overall_rating']}');
        debugPrint('     Note: Overall rating comes directly from feedback.overall_rating');
      }
      
      debugPrint('   Timestamp: ${combinedFeedback[1]['timestamp']}');
      debugPrint('   Full Data: ${combinedFeedback[1]}');
    }

    return combinedFeedback;
  }

  /// Format airport review data
  static Future<Map<String, dynamic>> _formatAirportReview(dynamic review) async {
    final comments = review['comments'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Extract score components for logging
    final overallScore = review['overall_score'] as num?;
    final cleanliness = review['cleanliness'] as num?;
    final facilities = review['facilities'] as num?;
    final staff = review['staff'] as num?;
    final waitingTime = review['waiting_time'] as num?;
    final accessibility = review['accessibility'] as num?;

    debugPrint('🏢 AIRPORT REVIEW SCORE CALCULATION:');
    debugPrint('   Review ID: ${review['id']}');
    debugPrint('   Overall Score (direct from DB): $overallScore');
    debugPrint('   Individual Scores:');
    debugPrint('     - Cleanliness: $cleanliness');
    debugPrint('     - Facilities: $facilities');
    debugPrint('     - Staff: $staff');
    debugPrint('     - Waiting Time: $waitingTime');
    debugPrint('     - Accessibility: $accessibility');

    // Try to get flight number from journey
    final journeyId = review['journey_id'] as String?;
    String flightNumber = 'Airport Experience';
    String seat = 'N/A';
    String airline = _getAirportName(review['airport_id']);
    
    if (journeyId != null) {
      try {
        final journey = await _client
            .from('journeys')
            .select('''
              seat_number,
              flight:flights(
                flight_number,
                airline:airlines(
                  name,
                  iata_code
                )
              )
            ''')
            .eq('id', journeyId)
            .maybeSingle();
        
        if (journey != null) {
          // Get seat number
          final seatNum = journey['seat_number'] as String?;
          if (seatNum != null && seatNum.isNotEmpty && seatNum != 'null') {
            seat = seatNum;
          }
          
          // Get flight info
          final flight = journey['flight'];
          if (flight != null && flight is Map) {
            final flightNum = flight['flight_number'] as String? ?? '';
            final airlineData = flight['airline'] as Map?;
            
            if (airlineData != null) {
              final airlineName = airlineData['name'] as String?;
              final iataCode = airlineData['iata_code'] as String? ?? '';
              
              if (airlineName != null && airlineName.isNotEmpty) {
                airline = airlineName;
              }
              
              if (iataCode.isNotEmpty && flightNum.isNotEmpty) {
                flightNumber = '$iataCode$flightNum';
              } else if (flightNum.isNotEmpty) {
                flightNumber = flightNum;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error getting journey data for airport review: $e');
      }
    }

    return {
      'feedback_type': 'airport',
      'id': review['id'],
      'journey_id': review['journey_id'],
      'user_id': review['user_id'],
      'airport_id': review['airport_id'],
      'flight': flightNumber,
      'phase': 'Pre-flight', // Airports are during boarding/pre-flight
      'phaseColor': const Color(0xFFF5A623), // Orange
      'airline': airline,
      'airlineName': airline,
      'logo': 'assets/images/airport.png',
      'passenger': 'Anonymous',
      'seat': seat,
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'overall_rating': review['overall_score'],
      'cleanliness': review['cleanliness'],
      'facilities': review['facilities'],
      'staff': review['staff'],
      'waiting_time': review['waiting_time'],
      'accessibility': review['accessibility'],
      'timestamp': _parseTimestamp(review['created_at']),
    };
  }

  /// Format leaderboard score data
  static Map<String, dynamic> _formatLeaderboardScore(dynamic score) {
    final airline = score['airlines'] as Map<String, dynamic>?;
    final scoreType = score['score_type'] as String? ?? 'overall';
    final scoreValue = score['score_value'] as double? ?? 0.0;

    debugPrint('📊 LEADERBOARD SCORE CALCULATION:');
    debugPrint('   Score ID: ${score['id']}');
    debugPrint('   Airline ID: ${score['airline_id']}');
    debugPrint('   Airline Name: ${airline?['name'] ?? 'Unknown'}');
    debugPrint('   Score Type: $scoreType');
    debugPrint('   Score Value (calculated by DB/backend): $scoreValue');
    debugPrint('   Note: This score is pre-calculated and comes directly from leaderboard_scores table');

    // Determine phase based on score type
    String phase;
    Color phaseColor;
    
    switch (scoreType) {
      case 'wifi_experience':
        phase = 'Wi-Fi Experience';
        phaseColor = const Color(0xFF9B59B6); // Purple
        break;
      case 'seat_comfort':
        phase = 'Seat Comfort';
        phaseColor = const Color(0xFFE67E22); // Orange
        break;
      case 'food_beverage':
        phase = 'Food & Beverage';
        phaseColor = const Color(0xFFE74C3C); // Red
        break;
      case 'crew_friendliness':
        phase = 'Crew Service';
        phaseColor = const Color(0xFF2ECC71); // Green
        break;
      case 'operations_timeliness':
        phase = 'Operations';
        phaseColor = const Color(0xFF3498DB); // Blue
        break;
      default:
        phase = 'Overall Rating';
        phaseColor = const Color(0xFF4A90E2); // Blue
    }
    
    // Map to display phase format
    String displayPhase;
    switch (phase.toLowerCase()) {
      case 'operations':
      case 'overall rating':
        displayPhase = 'In-flight'; // Default for leaderboard scores
        break;
      default:
        displayPhase = phase;
    }

    // Generate comments based on score
    final comments = _generateCommentsFromScore(scoreValue, scoreType);
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    return {
      'feedback_type': 'leaderboard',
      'id': score['id'],
      'airline_id': score['airline_id'],
      'flight': 'Performance Update',
      'phase': displayPhase,
      'phaseColor': phaseColor,
      'airline': airline?['name'] ?? 'Unknown Airline',
      'airlineName': airline?['name'] ?? 'Unknown Airline',
      'logo': airline?['logo_url'] ?? 'assets/images/airline_logo.png',
      'passenger': 'System',
      'seat': 'N/A',
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'score_type': scoreType,
      'score_value': scoreValue,
      'overall_rating': scoreValue,
      'timestamp': DateTime.now(), // Leaderboard scores don't have timestamps, use current time
    };
  }

  /// Format feedback data
  static Future<Map<String, dynamic>> _formatFeedback(dynamic feedback) async {
    final comments = feedback['comment'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Extract overall rating - check both 'rating' and 'overall_rating' fields
    final overallRating = feedback['overall_rating'] as num? ?? feedback['rating'] as num?;

    debugPrint('💬 FEEDBACK SCORE CALCULATION:');
    debugPrint('   Feedback ID: ${feedback['id']}');
    debugPrint('   Journey ID: ${feedback['journey_id']}');
    debugPrint('   Overall Rating (from DB): $overallRating');
    debugPrint('   Note: Rating extracted from feedback table (rating or overall_rating field)');

    // Determine phase from feedback data - map to journey parts
    final phaseStr = feedback['phase'] as String? ?? 'arrival';
    String phase;
    if (phaseStr == 'landed' || phaseStr == 'post-flight' || phaseStr == 'arrival' || phaseStr == 'overall') {
      phase = 'After Flight';
    } else if (phaseStr == 'in-flight' || phaseStr == 'in_flight') {
      phase = 'In-flight';
    } else if (phaseStr == 'pre-flight' || phaseStr == 'pre_flight' || phaseStr == 'boarding') {
      phase = 'Pre-flight';
    } else {
      phase = 'After Flight'; // Default
    }
    
    // Get phase color based on phase
    Color phaseColor;
    switch (phase.toLowerCase()) {
      case 'pre-flight':
        phaseColor = const Color(0xFFF5A623); // Orange
        break;
      case 'in-flight':
        phaseColor = const Color(0xFF4A90E2); // Blue
        break;
      case 'after flight':
        phaseColor = const Color(0xFF7ED321); // Green
        break;
      default:
        phaseColor = Colors.grey;
    }

    // Get flight number, airline, logo, and seat asynchronously
    final flightNumber = await _getFlightNumberAsync(feedback['journey_id']);
    final airline = await _getAirlineNameFromFeedback(feedback);
    final logo = await _getAirlineLogoFromFeedback(feedback);
    final seat = await _getSeatNumberAsync(feedback['journey_id']);

    debugPrint('📋 Formatted feedback card:');
    debugPrint('   Flight: $flightNumber');
    debugPrint('   Airline: $airline');
    debugPrint('   Seat: $seat');
    debugPrint('   Phase: $phase');

    return {
      'feedback_type': 'overall',
      'id': feedback['id'],
      'journey_id': feedback['journey_id'],
      'user_id': feedback['user_id'],
      'flight': flightNumber,
      'phase': phase,
      'phaseColor': phaseColor,
      'airline': airline,
      'airlineName': airline,
      'logo': logo,
      'passenger': 'Anonymous',
      'seat': seat,
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'overall_rating': overallRating,
      'timestamp': _parseTimestamp(feedback['created_at'] ?? feedback['timestamp']),
    };
  }

  /// Generate comments based on score value and type
  static String _generateCommentsFromScore(double scoreValue, String scoreType) {
    final score = scoreValue;
    String baseComment = '';
    
    if (score >= 4.5) {
      baseComment = 'Excellent performance in ';
    } else if (score >= 4.0) {
      baseComment = 'Great performance in ';
    } else if (score >= 3.5) {
      baseComment = 'Good performance in ';
    } else if (score >= 3.0) {
      baseComment = 'Average performance in ';
    } else if (score >= 2.5) {
      baseComment = 'Below average performance in ';
    } else {
      baseComment = 'Poor performance in ';
    }

    String categoryName;
    switch (scoreType) {
      case 'wifi_experience':
        categoryName = 'Wi-Fi and entertainment services';
        break;
      case 'seat_comfort':
        categoryName = 'seat comfort and legroom';
        break;
      case 'food_beverage':
        categoryName = 'food and beverage quality';
        break;
      case 'crew_friendliness':
        categoryName = 'crew service and friendliness';
        break;
      case 'operations_timeliness':
        categoryName = 'flight operations and timeliness';
        break;
      default:
        categoryName = 'overall service quality';
    }

    return '$baseComment$categoryName. Score: ${score.toStringAsFixed(1)}/5.0';
  }
  /// Aggregate feedback counts by flight (count actual passengers)
  static List<Map<String, dynamic>> _aggregateFeedbackCounts(
      List<Map<String, dynamic>> feedbackList) {
    // Group feedback by flight
    final Map<String, List<Map<String, dynamic>>> flightGroups = {};
    
    for (final feedback in feedbackList) {
      final flightKey = '${feedback['flight']}_${feedback['airline']}';
      if (!flightGroups.containsKey(flightKey)) {
        flightGroups[flightKey] = [];
      }
      flightGroups[flightKey]!.add(feedback);
    }

    // Aggregate likes/dislikes counts for each flight group
    final aggregatedFeedback = <Map<String, dynamic>>[];
    
    for (final group in flightGroups.values) {
      if (group.length == 1) {
        // Single feedback - use as is, but set count to 1
        final singleFeedback = Map<String, dynamic>.from(group.first);
        
        // Safely convert likes
        final likesList = singleFeedback['likes'];
        final likes = (likesList is List)
            ? likesList.map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else if (item is Map) {
                  return Map<String, dynamic>.from(item);
                } else {
                  return <String, dynamic>{};
                }
              }).toList()
            : <Map<String, dynamic>>[];
        
        // Safely convert dislikes
        final dislikesList = singleFeedback['dislikes'];
        final dislikes = (dislikesList is List)
            ? dislikesList.map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else if (item is Map) {
                  return Map<String, dynamic>.from(item);
                } else {
                  return <String, dynamic>{};
                }
              }).toList()
            : <Map<String, dynamic>>[];
        
        // Update counts to reflect actual passenger count (1 passenger)
        for (var like in likes) {
          like['count'] = 1;
        }
        for (var dislike in dislikes) {
          dislike['count'] = 1;
        }
        
        final updatedFeedback = Map<String, dynamic>.from(singleFeedback);
        updatedFeedback['likes'] = likes;
        updatedFeedback['dislikes'] = dislikes;
        
        aggregatedFeedback.add(updatedFeedback);
      } else {
        // Multiple feedbacks for same flight - aggregate counts
        final Map<String, int> likesCount = {};
        final Map<String, int> dislikesCount = {};
        
        for (final feedback in group) {
          // Safely convert likes
          final likesList = feedback['likes'];
          final likes = (likesList is List)
              ? likesList.map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                }).toList()
              : <Map<String, dynamic>>[];
          
          // Safely convert dislikes
          final dislikesList = feedback['dislikes'];
          final dislikes = (dislikesList is List)
              ? dislikesList.map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                }).toList()
              : <Map<String, dynamic>>[];
          
          for (final like in likes) {
            final text = like['text'] as String? ?? '';
            likesCount[text] = (likesCount[text] ?? 0) + 1;
          }
          
          for (final dislike in dislikes) {
            final text = dislike['text'] as String? ?? '';
            dislikesCount[text] = (dislikesCount[text] ?? 0) + 1;
          }
        }
        
        // Use the most recent feedback as base, but update aggregated counts
        final mostRecent = group.first;
        final aggregated = Map<String, dynamic>.from(mostRecent);
        
        aggregated['likes'] = likesCount.entries
            .map((e) => {'text': e.key, 'count': e.value})
            .toList();
        aggregated['dislikes'] = dislikesCount.entries
            .map((e) => {'text': e.key, 'count': e.value})
            .toList();
        
        aggregatedFeedback.add(aggregated);
      }
    }
    
    return aggregatedFeedback;
  }

  /// Extract positive feedback from comments
  static List<Map<String, dynamic>> _extractPositiveFromComments(
      String comments) {
    if (comments.isEmpty) {
      return [
        {'text': 'Good facilities', 'count': 1}, // Changed to 1 (actual passenger count)
        {'text': 'Helpful staff', 'count': 1},   // Changed to 1 (actual passenger count)
      ];
    }

    // Simple keyword matching for positive feedback
    final positiveKeywords = [
      'excellent',
      'great',
      'good',
      'clean',
      'helpful',
      'comfortable',
      'fast',
      'smooth',
      'amazing',
      'wonderful',
    ];

    final extractedLikes = <String>[];
    final lowercaseComments = comments.toLowerCase();

    for (final keyword in positiveKeywords) {
      if (lowercaseComments.contains(keyword)) {
        extractedLikes.add(keyword);
      }
    }

    if (extractedLikes.isEmpty) {
      return [
        {'text': 'Positive experience', 'count': 1}, // Changed to 1 (actual passenger count)
      ];
    }

    return extractedLikes
        .map((keyword) => {
              'text': keyword.capitalize(),
              'count': 1, // Changed to 1 (actual passenger count - will be aggregated later)
            })
        .toList();
  }

  /// Extract negative feedback from comments
  static List<Map<String, dynamic>> _extractNegativeFromComments(
      String comments) {
    if (comments.isEmpty) return [];

    // Simple keyword matching for negative feedback
    final negativeKeywords = [
      'slow',
      'dirty',
      'rude',
      'delayed',
      'broken',
      'poor',
      'disappointed',
      'uncomfortable',
      'bad',
      'terrible',
    ];

    final extractedDislikes = <String>[];
    final lowercaseComments = comments.toLowerCase();

    for (final keyword in negativeKeywords) {
      if (lowercaseComments.contains(keyword)) {
        extractedDislikes.add(keyword);
      }
    }

    return extractedDislikes
        .map((keyword) => {
              'text': keyword.capitalize(),
              'count': 1, // Actual passenger count - will be aggregated later
            })
        .toList();
  }

  /// Get airline name from airline_id (sync version)
  static String _getAirlineNameSync(String? airlineId) {
    return 'Unknown Airline';
  }

  /// Get airline logo from airline_id
  static String _getAirlineLogo(String? airlineId) {
    return 'assets/images/airline_logo.png';
  }

  /// Get airline name from feedback data
  static Future<String> _getAirlineNameFromFeedback(dynamic feedback) async {
    try {
      final journeyId = feedback['journey_id'] as String?;
      if (journeyId == null) return 'Unknown Airline';

      final journey = await _client
          .from('journeys')
          .select('''
            flight:flights(
              airline:airlines(
                name,
                iata_code
              )
            )
          ''')
          .eq('id', journeyId)
          .maybeSingle();

      if (journey != null) {
        final flight = journey['flight'];
        if (flight != null && flight is Map) {
          final airline = flight['airline'] as Map?;
          if (airline != null) {
            final airlineName = airline['name'] as String?;
            if (airlineName != null && airlineName.isNotEmpty) {
              return airlineName;
            }
            final iataCode = airline['iata_code'] as String?;
            if (iataCode != null && iataCode.isNotEmpty) {
              return iataCode;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting airline name: $e');
    }
    return 'Unknown Airline';
  }

  /// Get airline logo from feedback data
  static Future<String> _getAirlineLogoFromFeedback(dynamic feedback) async {
    try {
      final journeyId = feedback['journey_id'] as String?;
      if (journeyId == null) return 'assets/images/airline_logo.png';

      final journey = await _client
          .from('journeys')
          .select('''
            flight:flights(
              airline:airlines(
                logo_url
              )
            )
          ''')
          .eq('id', journeyId)
          .maybeSingle();

      if (journey != null) {
        final flight = journey['flight'];
        if (flight != null && flight is Map) {
          final airline = flight['airline'] as Map?;
          if (airline != null) {
            final logoUrl = airline['logo_url'] as String?;
            if (logoUrl != null && logoUrl.isNotEmpty) {
              return logoUrl;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting airline logo: $e');
    }
    return 'assets/images/airline_logo.png';
  }

  /// Get airport name from airport_id
  static String _getAirportName(String? airportId) {
    return 'Airport';
  }

  /// Get flight number from journey_id (async version)
  static Future<String> _getFlightNumberAsync(String? journeyId) async {
    try {
      if (journeyId == null) return 'Flight';

      final journey = await _client
          .from('journeys')
          .select('''
            flight:flights(
              flight_number,
              airline:airlines(
                iata_code
              )
            )
          ''')
          .eq('id', journeyId)
          .maybeSingle();

      if (journey != null) {
        final flight = journey['flight'];
        if (flight != null && flight is Map) {
          final flightNumber = flight['flight_number'] as String? ?? '';
          final airline = flight['airline'] as Map?;
          final iataCode = airline?['iata_code'] as String? ?? '';
          
          if (iataCode.isNotEmpty && flightNumber.isNotEmpty) {
            return '$iataCode$flightNumber';
          } else if (flightNumber.isNotEmpty) {
            return flightNumber;
          }
        }
        
        // Fallback: Try direct fields if they exist
        final carrier = journey['carrier'] as String? ?? '';
        final flightNumber = journey['flight_number'] as String? ?? '';
        if (carrier.isNotEmpty && flightNumber.isNotEmpty) {
          return '$carrier$flightNumber';
        } else if (flightNumber.isNotEmpty) {
          return flightNumber;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting flight number: $e');
    }
    return 'Flight';
  }

  /// Get flight number from journey_id (sync version - returns placeholder)
  static String _getFlightNumberSync(String? journeyId) {
    return 'Flight';
  }

  /// Get seat number from journey_id (async version)
  static Future<String> _getSeatNumberAsync(String? journeyId) async {
    try {
      if (journeyId == null) return 'N/A';

      final journey = await _client
          .from('journeys')
          .select('seat_number')
          .eq('id', journeyId)
          .maybeSingle();

      if (journey != null) {
        final seatNumber = journey['seat_number'] as String?;
        if (seatNumber != null && seatNumber.isNotEmpty && seatNumber != 'null') {
          return seatNumber;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting seat number: $e');
    }
    return 'N/A';
  }

  /// Get seat number from journey_id (sync version - returns placeholder)
  static String _getSeatNumber(String? journeyId) {
    return 'N/A';
  }

  /// Parse timestamp from various formats
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is DateTime) {
      return timestamp;
    }

    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        debugPrint('⚠️ Error parsing timestamp: $e');
      }
    }

    return DateTime.now();
  }

  /// Clean up subscriptions
  static Future<void> dispose() async {
    try {
      if (_channel != null) {
        await _client.removeChannel(_channel!);
        _isSubscribed = false;
        debugPrint('✅ Disposed realtime feedback subscriptions');
      }
    } catch (e) {
      debugPrint('❌ Error disposing realtime feedback: $e');
    }
  }

  /// Get airport reviews only
  static Stream<List<Map<String, dynamic>>> getAirportReviewsStream() {
    try {
      return _client
          .from('airport_reviews')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .asyncMap((reviews) async {
            final formattedList = <Map<String, dynamic>>[];
            for (final review in reviews) {
              final formatted = await _formatAirportReview(review);
              formattedList.add(formatted);
            }
            return formattedList;
          });
    } catch (e) {
      debugPrint('❌ Error creating airport reviews stream: $e');
      return Stream.value([]);
    }
  }

  /// Get leaderboard scores only
  static Stream<List<Map<String, dynamic>>> getLeaderboardScoresStream() {
    try {
      return _client
          .from('leaderboard_scores')
          .stream(primaryKey: ['id'])
          .order('score_value', ascending: false)
          .limit(50)
          .asyncMap((scores) async {
            // Enrich with airline data
            final enrichedScores = <Map<String, dynamic>>[];
            for (final score in scores) {
              try {
                final airlineData = await _client
                    .from('airlines')
                    .select('id, name, iata_code, icao_code, logo_url')
                    .eq('id', score['airline_id'])
                    .single();

                enrichedScores.add({
                  ...score,
                  'airlines': airlineData,
                });
              } catch (e) {
                debugPrint('⚠️ Error fetching airline for ${score['airline_id']}: $e');
                enrichedScores.add(score);
              }
            }
            return enrichedScores
                .map((score) => _formatLeaderboardScore(score))
                .toList();
          });
    } catch (e) {
      debugPrint('❌ Error creating leaderboard scores stream: $e');
      return Stream.value([]);
    }
  }

  /// Get feedback stream only
  static Stream<List<Map<String, dynamic>>> getFeedbackStream() {
    try {
      return _client
          .from('feedback')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .asyncMap((feedbacks) async {
            final formattedList = <Map<String, dynamic>>[];
            for (final f in feedbacks) {
              final formatted = await _formatFeedback(f);
              formattedList.add(formatted);
            }
            return formattedList;
          });
    } catch (e) {
      debugPrint('❌ Error creating feedback stream: $e');
      return Stream.value([]);
    }
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

