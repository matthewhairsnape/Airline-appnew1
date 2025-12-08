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
  
  // Cache for airline logos to ensure same airline always shows same logo
  static final Map<String, String> _logoCache = {};

  /// Initialize realtime feedback listener
  static Future<void> initialize() async {
    if (_isSubscribed) return;

    try {
      _channel = _client.channel('realtime_feedback');

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'airport_reviews',
        callback: (_) {},
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'airline_reviews',
        callback: (_) {},
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'feedback',
        callback: (_) {},
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'airport_reviews',
        callback: (_) {},
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'airline_reviews',
        callback: (_) {},
      );

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'feedback',
        callback: (_) {},
      );

      await _channel!.subscribe();
      _isSubscribed = true;
    } catch (_) {
      _isSubscribed = false;
    }
  }

  /// Get combined realtime feedback stream
  /// Priority: 1) Airport Reviews (Pre-flight), 2) Airline Reviews (In-flight), 3) Feedback (Overall)
  static Stream<List<Map<String, dynamic>>> getCombinedFeedbackStream() {
    try {

      return _client
          .from('airport_reviews')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .asyncMap((airportReviews) async {

            // Fetch airline reviews (In-flight reviews)
            final airlineReviews = await _client
                .from('airline_reviews')
                .select('''
                  id,
                  journey_id,
                  airline_id,
                  comments,
                  media_urls,
                  created_at
                ''')
                .order('created_at', ascending: false)
                .limit(30);

            // Fetch feedback (Overall feedback)
            final feedbackData = await _client
                .from('feedback')
                .select('''
                  id,
                  journey_id,
                  flight_id,
                  phase,
                  category,
                  rating,
                  sentiment,
                  comment,
                  timestamp,
                  tags,
                  created_at,
                  media
                ''')
                .order('created_at', ascending: false)
                .limit(30);

            // Combine and format all feedback (set aggregate to false for individual entries)
            final combined = await _formatCombinedFeedback(
              airportReviews,
              airlineReviews,
              feedbackData,
              aggregate: false, // Don't aggregate - show individual passenger feedback
            );
            
            debugPrint('   Combined feedback total: ${combined.length}');
            
            
            return combined;
          });
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Format combined feedback from all three sources
  static Future<List<Map<String, dynamic>>> _formatCombinedFeedback(
    List<dynamic> airportReviews,
    List<dynamic> airlineReviews,
    List<dynamic> feedbackData,
    {bool aggregate = true}
  ) async {
    List<Map<String, dynamic>> combinedFeedback = [];

    // Process airport reviews (Priority 1 - Pre-flight) - REAL user feedback
    for (final review in airportReviews) {
      final formatted = await _formatAirportReview(review);
      combinedFeedback.add(formatted);
    }

    // Process airline reviews (Priority 2 - In-flight) - REAL user feedback
    for (final review in airlineReviews) {
      final formatted = await _formatAirlineReview(review);
      combinedFeedback.add(formatted);
    }

    // Process feedback entries (Priority 3 - Overall) - REAL user feedback
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

    return combinedFeedback;
  }

  /// Format airport review data
  static Future<Map<String, dynamic>> _formatAirportReview(dynamic review) async {
    final comments = review['comments'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);


    // Try to get flight number and airline logo from journey
    final journeyId = review['journey_id'] as String?;
    String flightNumber = 'Airport Experience';
    String seat = 'N/A';
    String airline = _getAirportName(review['airport_id']);
    String logo = 'assets/images/airport.png'; // Default to airport icon
    
    if (journeyId != null) {
      try {
        final journey = await _client
            .from('journeys')
            .select('''
              seat_number,
              flight:flights(
                flight_number,
                airline:airlines(
                  id,
                  name,
                  iata_code,
                  logo_url
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
              final airlineId = airlineData['id'] as String?;
              final airlineName = airlineData['name'] as String?;
              final iataCode = airlineData['iata_code'] as String? ?? '';
              final logoUrl = airlineData['logo_url'] as String?;
              
              if (airlineName != null && airlineName.isNotEmpty) {
                airline = airlineName;
              }
              
              if (iataCode.isNotEmpty && flightNum.isNotEmpty) {
                flightNumber = '$iataCode$flightNum';
              } else if (flightNum.isNotEmpty) {
                flightNumber = flightNum;
              }
              
              // Use airline logo if available (cached for consistency)
              if (logoUrl != null && logoUrl.isNotEmpty) {
                logo = logoUrl;
                // Cache it for consistency
                if (airlineId != null) {
                  _logoCache['airline_$airlineId'] = logoUrl;
                }
                if (airlineName != null) {
                  _logoCache['airline_name_$airlineName'] = logoUrl;
                }
              }
            }
          }
        }
      } catch (e) {
      }
    }

    // Extract media URLs
    final mediaUrls = review['media_urls'] as List?;
    final imageUrls = (mediaUrls != null && mediaUrls.isNotEmpty)
        ? mediaUrls.map((url) => url.toString()).toList()
        : <String>[];

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
      'logo': logo, // Use airline logo if available, otherwise airport icon
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
      'imageUrls': imageUrls, // Add media URLs for display
      'timestamp': _parseTimestamp(review['created_at']),
    };
  }

  /// Format airline review data (In-flight reviews)
  static Future<Map<String, dynamic>> _formatAirlineReview(dynamic review) async {
    final comments = review['comments'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Try to get flight number, seat, and logo from journey
    final journeyId = review['journey_id'] as String?;
    String flightNumber = 'Flight';
    String seat = 'N/A';
    String airline = 'Unknown Airline';
    String logo = 'assets/images/airline.png'; // Default to airline icon
    
    if (journeyId != null) {
      try {
        final journey = await _client
            .from('journeys')
            .select('''
              seat_number,
              flight:flights(
                flight_number,
                airline:airlines(
                  id,
                  name,
                  iata_code,
                  logo_url
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
              final airlineId = airlineData['id'] as String?;
              final airlineName = airlineData['name'] as String?;
              final iataCode = airlineData['iata_code'] as String? ?? '';
              final logoUrl = airlineData['logo_url'] as String?;
              
              if (airlineName != null && airlineName.isNotEmpty) {
                airline = airlineName;
              }
              
              if (iataCode.isNotEmpty && flightNum.isNotEmpty) {
                flightNumber = '$iataCode$flightNum';
              } else if (flightNum.isNotEmpty) {
                flightNumber = flightNum;
              }
              
              // Use airline logo if available (cached for consistency)
              if (logoUrl != null && logoUrl.isNotEmpty) {
                logo = logoUrl;
                // Cache it for consistency
                if (airlineId != null) {
                  _logoCache['airline_$airlineId'] = logoUrl;
                }
                if (airlineName != null) {
                  _logoCache['airline_name_$airlineName'] = logoUrl;
                }
              }
            }
          }
        }
      } catch (e) {
        // Silent error handling
      }
    }

    // Extract media URLs
    final mediaUrls = review['media_urls'] as List?;
    final imageUrls = (mediaUrls != null && mediaUrls.isNotEmpty)
        ? mediaUrls.map((url) => url.toString()).toList()
        : <String>[];

    return {
      'feedback_type': 'airline',
      'id': review['id'],
      'journey_id': review['journey_id'],
      'airline_id': review['airline_id'],
      'flight': flightNumber,
      'phase': 'In-flight', // Airline reviews are during flight
      'phaseColor': const Color(0xFF4A90E2), // Blue
      'airline': airline,
      'airlineName': airline,
      'logo': logo, // Use airline logo
      'passenger': 'Anonymous',
      'seat': seat,
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'imageUrls': imageUrls, // Add media URLs for display
      'timestamp': _parseTimestamp(review['created_at']),
    };
  }

  /// Format leaderboard score data
  /// Fetches flight_number and seat_number by:
  /// 1. Get airline_id from leaderboard_scores
  /// 2. Match airline_id in flights table to get flight_number and flights.id
  /// 3. Match flights.id (as flight_id) in journeys table to get seat_number
  static Future<Map<String, dynamic>> _formatLeaderboardScore(dynamic score) async {
    final airline = score['airlines'] as Map<String, dynamic>?;
    final airlineId = score['airline_id'] as String?;
    final scoreType = score['score_type'] as String? ?? 'overall';
    final scoreValue = score['score_value'] as double? ?? 0.0;

    String flightNumber = '';
    String? seatNumber;
    String? journeyId;

    if (airlineId != null) {
      try {
        // Fetch most recent flight for this airline
        final flights = await _client
            .from('flights')
            .select('''
              id,
              flight_number,
              airline:airlines!inner(
                id,
                iata_code
              )
            ''')
            .eq('airline_id', airlineId)
            .order('created_at', ascending: false)
            .limit(5); // Reduced from 10 to 5 for better performance

        // Process flights sequentially, stop at first match
        for (final flight in flights) {
          final flightId = flight['id'] as String?;
          final flightNum = flight['flight_number'] as String? ?? '';
          final airlineData = flight['airline'] as Map?;
          final iataCode = airlineData?['iata_code'] as String? ?? '';

          if (flightId == null || flightNum.isEmpty) continue;

          // Build flight number
          if (iataCode.isNotEmpty && flightNum.isNotEmpty) {
            flightNumber = '$iataCode$flightNum';
          } else if (flightNum.isNotEmpty) {
            flightNumber = flightNum;
          }

          // Query journeys for this flight
          try {
            final journeys = await _client
                .from('journeys')
                .select('id, seat_number')
                .eq('flight_id', flightId)
                .limit(50); // Limit to reduce data transfer

            // Find first journey with valid seat number
            for (final journey in journeys) {
              final rawSeat = journey['seat_number'];
              if (rawSeat != null) {
                final seatStr = rawSeat.toString().trim();
                if (seatStr.isNotEmpty) {
                  final lowerSeat = seatStr.toLowerCase();
                  if (lowerSeat != 'null' && lowerSeat != 'na' && lowerSeat != 'n/a') {
                    seatNumber = seatStr;
                    journeyId = journey['id'] as String?;
                    break;
                  }
                }
              }
            }

            // If no seat found but we have journeys, use first one for journeyId
            if (seatNumber == null && journeys.isNotEmpty) {
              journeyId = journeys.first['id'] as String?;
            }

            // If we found a flight number, break (even without seat)
            if (flightNumber.isNotEmpty) break;
          } catch (_) {
            // Continue to next flight on error
            continue;
          }
        }
      } catch (_) {
        // Silent fail - use empty values
      }
    }

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

    final result = {
      'feedback_type': 'leaderboard',
      'id': score['id'],
      'airline_id': airlineId,
      'journey_id': journeyId, // Set if we found a journey
      'flight': flightNumber.isEmpty ? '' : flightNumber, // Set if we found a flight
      'phase': displayPhase,
      'phaseColor': phaseColor,
      'airline': airline?['name'] ?? 'Unknown Airline',
      'airlineName': airline?['name'] ?? 'Unknown Airline',
      'logo': airline?['logo_url'] ?? 'assets/images/airline_logo.png',
      'passenger': 'System',
      'seat': seatNumber, // Set if we found a seat (can be null)
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'score_type': scoreType,
      'score_value': scoreValue,
      'overall_rating': scoreValue,
      'timestamp': DateTime.now(), // Leaderboard scores don't have timestamps, use current time
    };

    return result;
  }

  /// Format feedback data (using actual schema)
  static Future<Map<String, dynamic>> _formatFeedback(dynamic feedback) async {
    final comments = feedback['comment'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Get rating from actual schema
    final rating = feedback['rating'] as num?;
    
    // Get category and sentiment from actual schema
    final category = feedback['category'] as String? ?? '';
    final sentiment = feedback['sentiment'] as String?;

    // Determine phase from feedback data - map actual schema values
    final phaseStr = feedback['phase'] as String? ?? 'landed';
    String phase;
    // Actual schema: 'on_ground', 'in_air', 'landed'
    if (phaseStr == 'landed') {
      phase = 'After Flight';
    } else if (phaseStr == 'in_air') {
      phase = 'In-flight';
    } else if (phaseStr == 'on_ground') {
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


    // Extract media URLs from media field (can be array or single value)
    final mediaData = feedback['media'];
    List<String> imageUrls = [];
    if (mediaData != null) {
      if (mediaData is List) {
        imageUrls = mediaData.map((url) => url.toString()).toList();
      } else if (mediaData is String && mediaData.isNotEmpty) {
        imageUrls = [mediaData];
      }
    }

    final result = {
      'feedback_type': 'overall',
      'id': feedback['id'],
      'journey_id': feedback['journey_id'],
      'flight_id': feedback['flight_id'],
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
      // Use actual schema columns
      'overall_rating': rating,
      'rating': rating,
      'category': category,
      'sentiment': sentiment,
      'tags': feedback['tags'],
      'media': feedback['media'],
      'imageUrls': imageUrls, // Add media URLs for display
      'timestamp': _parseTimestamp(feedback['created_at'] ?? feedback['timestamp']),
    };
    
    return result;
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

  /// Extract likes from structured comments
  /// Format: "likes: item1, item2, item3; dislikes issues: item4, item5"
  static List<Map<String, dynamic>> _extractPositiveFromComments(
      String comments) {
    if (comments.isEmpty) {
      return [];
    }

    try {
      // Split by "likes:" and get the content before "dislikes issues:"
      final likesSection = comments.split('likes:');
      if (likesSection.length < 2) {
        return [];
      }

      // Get the part after "likes:" and before "dislikes issues:"
      String likesContent = likesSection[1];
      if (likesContent.contains('; dislikes issues:')) {
        likesContent = likesContent.split('; dislikes issues:')[0];
      } else if (likesContent.contains(';dislikes issues:')) {
        likesContent = likesContent.split(';dislikes issues:')[0];
      }

      // Split by comma and trim each item
      final likeItems = likesContent
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (likeItems.isEmpty) {
        return [];
      }

      return likeItems
          .map((item) => {
                'text': item,
                'count': 1,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Extract dislikes from structured comments
  /// Format: "likes: item1, item2, item3; dislikes issues: item4, item5"
  static List<Map<String, dynamic>> _extractNegativeFromComments(
      String comments) {
    if (comments.isEmpty) {
      return [];
    }

    try {
      // Split by "dislikes issues:" and get the content after it
      final dislikesSection = comments.split('dislikes issues:');
      if (dislikesSection.length < 2) {
        return [];
      }

      // Get the part after "dislikes issues:"
      String dislikesContent = dislikesSection[1].trim();

      // Split by comma and trim each item
      final dislikeItems = dislikesContent
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (dislikeItems.isEmpty) {
        return [];
      }

      return dislikeItems
          .map((item) => {
                'text': item,
                'count': 1,
              })
          .toList();
    } catch (e) {
      return [];
    }
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
    }
    return 'Unknown Airline';
  }

  /// Get airline logo from feedback data (with caching)
  static Future<String> _getAirlineLogoFromFeedback(dynamic feedback) async {
    try {
      final journeyId = feedback['journey_id'] as String?;
      if (journeyId == null) {
        return 'assets/images/airline_logo.png';
      }

      // Check cache first
      if (_logoCache.containsKey(journeyId)) {
        return _logoCache[journeyId]!;
      }

      final journey = await _client
          .from('journeys')
          .select('''
            flight:flights(
              airline:airlines(
                id,
                name,
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
            final airlineId = airline['id'] as String?;
            final airlineName = airline['name'] as String?;
            final logoUrl = airline['logo_url'] as String?;
            
            if (logoUrl != null && logoUrl.isNotEmpty) {
              // Cache by journey_id AND airline_id for consistency
              _logoCache[journeyId] = logoUrl;
              if (airlineId != null) {
                _logoCache['airline_$airlineId'] = logoUrl;
              }
              if (airlineName != null) {
                _logoCache['airline_name_$airlineName'] = logoUrl;
              }
              
              return logoUrl;
            }
          }
        }
      }
      
      // Cache the fallback too to avoid repeated queries
      _logoCache[journeyId] = 'assets/images/airline_logo.png';
    } catch (e) {
      // Silent error handling
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
      }
    } catch (e) {
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
                enrichedScores.add(score);
              }
            }
            return await Future.wait(
              enrichedScores.map((score) => _formatLeaderboardScore(score))
            );
          });
    } catch (e) {
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

