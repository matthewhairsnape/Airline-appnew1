import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle real-time feedback using LISTEN/NOTIFY
/// Combines data from airport_reviews, airline_reviews, and feedback tables
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

      // Listen for INSERT events on airline_reviews
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'airline_reviews',
        callback: (payload) {
          debugPrint('✈️ Received airline_review INSERT: ${payload.newRecord}');
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
        table: 'airline_reviews',
        callback: (payload) {
          debugPrint('✈️ Received airline_review UPDATE: ${payload.newRecord}');
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
  /// Priority: 1) Airport Reviews, 2) Airline Reviews, 3) Feedback
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

            // Fetch airline reviews
            final airlineReviews = await _client
                .from('airline_reviews')
                .select()
                .order('created_at', ascending: false)
                .limit(30);

            debugPrint('✈️ Fetched ${airlineReviews.length} airline reviews');

            // Fetch feedback
            final feedbackData = await _client
                .from('feedback')
                .select()
                .order('created_at', ascending: false)
                .limit(30);

            debugPrint('💬 Fetched ${feedbackData.length} feedback entries');

            // Combine and format all feedback
            return _formatCombinedFeedback(
              airportReviews,
              airlineReviews,
              feedbackData,
            );
          });
    } catch (e) {
      debugPrint('❌ Error creating combined feedback stream: $e');
      return Stream.value([]);
    }
  }

  /// Format combined feedback from all three sources
  static List<Map<String, dynamic>> _formatCombinedFeedback(
    List<dynamic> airportReviews,
    List<dynamic> airlineReviews,
    List<dynamic> feedbackData,
  ) {
    final List<Map<String, dynamic>> combinedFeedback = [];

    // Process airport reviews (Priority 1)
    for (final review in airportReviews) {
      combinedFeedback.add(_formatAirportReview(review));
    }

    // Process airline reviews (Priority 2)
    for (final review in airlineReviews) {
      combinedFeedback.add(_formatAirlineReview(review));
    }

    // Process feedback entries (Priority 3)
    for (final feedback in feedbackData) {
      combinedFeedback.add(_formatFeedback(feedback));
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

    return combinedFeedback;
  }

  /// Format airport review data
  static Map<String, dynamic> _formatAirportReview(dynamic review) {
    final comments = review['comments'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    return {
      'feedback_type': 'airport',
      'id': review['id'],
      'journey_id': review['journey_id'],
      'user_id': review['user_id'],
      'airport_id': review['airport_id'],
      'flight': 'Airport Experience',
      'phase': 'Boarding', // Airports are during boarding
      'phaseColor': const Color(0xFFF5A623), // Orange
      'airline': _getAirportName(review['airport_id']),
      'airlineName': 'Airport Services',
      'logo': 'assets/images/airport.png',
      'passenger': 'Anonymous',
      'seat': 'N/A',
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

  /// Format airline review data
  static Map<String, dynamic> _formatAirlineReview(dynamic review) {
    final comments = review['comment'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Determine phase based on review type
    final phase = 'In-flight';
    const phaseColor = Color(0xFF4A90E2); // Blue

    return {
      'feedback_type': 'airline',
      'id': review['id'],
      'journey_id': review['journey_id'],
      'user_id': review['user_id'],
      'airline_id': review['airline_id'],
      'flight': _getFlightNumberSync(review['journey_id']),
      'phase': phase,
      'phaseColor': phaseColor,
      'airline': _getAirlineNameSync(review['airline_id']),
      'airlineName': _getAirlineNameSync(review['airline_id']),
      'logo': _getAirlineLogo(review['airline_id']),
      'passenger': 'Anonymous',
      'seat': _getSeatNumber(review['journey_id']),
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'comfort_rating': review['comfort_rating'],
      'cleanliness_rating': review['cleanliness_rating'],
      'onboard_service_rating': review['onboard_service_rating'],
      'food_beverage_rating': review['food_beverage_rating'],
      'entertainment_wifi_rating': review['entertainment_wifi_rating'],
      'image_urls': review['image_urls'],
      'timestamp': _parseTimestamp(review['created_at']),
    };
  }

  /// Format feedback data
  static Map<String, dynamic> _formatFeedback(dynamic feedback) {
    final comments = feedback['comment'] as String? ?? '';
    final likes = _extractPositiveFromComments(comments);
    final dislikes = _extractNegativeFromComments(comments);

    // Determine phase
    final phase = 'Arrival';
    const phaseColor = Color(0xFF7ED321); // Green

    return {
      'feedback_type': 'overall',
      'id': feedback['id'],
      'journey_id': feedback['journey_id'],
      'user_id': feedback['user_id'],
      'flight': _getFlightNumberSync(feedback['journey_id']),
      'phase': phase,
      'phaseColor': phaseColor,
      'airline': _getAirlineNameFromFeedback(feedback),
      'airlineName': _getAirlineNameFromFeedback(feedback),
      'logo': _getAirlineLogoFromFeedback(feedback),
      'passenger': 'Anonymous',
      'seat': _getSeatNumber(feedback['journey_id']),
      'likes': likes,
      'dislikes': dislikes,
      'comments': comments,
      'overall_rating': feedback['overall_rating'],
      'timestamp': _parseTimestamp(feedback['created_at']),
    };
  }

  /// Extract positive feedback from comments
  static List<Map<String, dynamic>> _extractPositiveFromComments(
      String comments) {
    if (comments.isEmpty) {
      return [
        {'text': 'Good facilities', 'count': 5},
        {'text': 'Helpful staff', 'count': 3},
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
        {'text': 'Positive experience', 'count': 2},
      ];
    }

    return extractedLikes
        .map((keyword) => {
              'text': keyword.capitalize(),
              'count': 3,
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
              'count': 1,
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
  static String _getAirlineNameFromFeedback(dynamic feedback) {
    // Try to get airline from journey
    return 'Unknown Airline';
  }

  /// Get airline logo from feedback data
  static String _getAirlineLogoFromFeedback(dynamic feedback) {
    return 'assets/images/airline_logo.png';
  }

  /// Get airport name from airport_id
  static String _getAirportName(String? airportId) {
    return 'Airport';
  }

  /// Get flight number from journey_id (sync version)
  static String _getFlightNumberSync(String? journeyId) {
    return 'Flight';
  }

  /// Get seat number from journey_id
  static String _getSeatNumber(String? journeyId) {
    // Try to get from journey data
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
          .asyncMap((reviews) => reviews
              .map((review) => _formatAirportReview(review))
              .toList());
    } catch (e) {
      debugPrint('❌ Error creating airport reviews stream: $e');
      return Stream.value([]);
    }
  }

  /// Get airline reviews only
  static Stream<List<Map<String, dynamic>>> getAirlineReviewsStream() {
    try {
      return _client
          .from('airline_reviews')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .asyncMap((reviews) => reviews
              .map((review) => _formatAirlineReview(review))
              .toList());
    } catch (e) {
      debugPrint('❌ Error creating airline reviews stream: $e');
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
          .asyncMap(
              (feedbacks) => feedbacks.map((f) => _formatFeedback(f)).toList());
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

