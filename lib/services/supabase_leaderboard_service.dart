import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle leaderboard data from Supabase
class SupabaseLeaderboardService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Get leaderboard rankings from Supabase
  static Future<List<Map<String, dynamic>>> getLeaderboardRankings({
    String? scoreType,
    int limit = 10,
  }) async {
    try {
      debugPrint('📊 Fetching leaderboard rankings from Supabase...');

      var query = _client.from('leaderboard_scores').select('''
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
          ''').order('score_value', ascending: false).limit(limit);

      // Commenting out filter due to API compatibility
      // if (scoreType != null && scoreType.isNotEmpty) {
      //   query = query.filter('score_type', 'eq', scoreType);
      // }

      final response = await query;

      debugPrint('✅ Fetched ${response.length} leaderboard entries');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching leaderboard rankings: $e');
      return [];
    }
  }

  /// Get real-time leaderboard updates
  static Stream<List<Map<String, dynamic>>> subscribeToLeaderboardUpdates({
    String? scoreType,
    int limit = 10,
  }) {
    try {
      debugPrint('📡 Subscribing to leaderboard real-time updates...');

      // Build the stream query with conditional filtering
      Stream<List<Map<String, dynamic>>> stream;

      if (scoreType != null && scoreType.isNotEmpty) {
        stream = _client
            .from('leaderboard_scores')
            .stream(primaryKey: ['id'])
            .eq('score_type', scoreType)
            .order('score_value', ascending: false)
            .limit(limit);
      } else {
        stream = _client
            .from('leaderboard_scores')
            .stream(primaryKey: ['id'])
            .order('score_value', ascending: false)
            .limit(limit);
      }

      return stream.asyncMap((data) async {
        debugPrint(
            '📊 Received ${data.length} leaderboard entries via realtime');

        // Fetch airline details for each entry
        final enrichedData = <Map<String, dynamic>>[];
        for (final entry in data) {
          try {
            final airlineData = await _client
                .from('airlines')
                .select('id, name, iata_code, icao_code, logo_url')
                .eq('id', entry['airline_id'])
                .single();

            enrichedData.add({
              ...entry,
              'airlines': airlineData,
            });
          } catch (e) {
            debugPrint(
                '⚠️ Error fetching airline for ${entry['airline_id']}: $e');
            enrichedData.add(entry);
          }
        }

        return enrichedData;
      });
    } catch (e) {
      debugPrint('❌ Error subscribing to leaderboard updates: $e');
      return Stream.value([]);
    }
  }

  /// Get category-specific rankings
  /// Now uses leaderboard_rankings table for better performance and consistency
  static Future<List<Map<String, dynamic>>> getCategoryRankings(
      String category) async {
    try {
      debugPrint('📊 Fetching $category rankings from leaderboard_rankings...');

      // Try to get from leaderboard_rankings first
      try {
        final rankingsResponse = await _client
            .from('leaderboard_rankings')
            .select('''
              id,
              airline_id,
              category,
              leaderboard_rank,
              leaderboard_score,
              avg_rating,
              review_count,
              airlines!inner(
                id,
                name,
                iata_code,
                icao_code,
                logo_url
              )
            ''')
            .eq('category', category)
            .order('leaderboard_rank', ascending: true)
            .limit(10);

        if (rankingsResponse.isNotEmpty) {
          debugPrint('✅ Fetched ${rankingsResponse.length} $category rankings from leaderboard_rankings');
          // Convert to expected format
          return rankingsResponse.map((entry) => {
            'id': entry['id'],
            'airline_id': entry['airline_id'],
            'score_type': mapCategoryToScoreType(category),
            'score_value': entry['leaderboard_score'],
            'leaderboard_rank': entry['leaderboard_rank'],
            'avg_rating': entry['avg_rating'],
            'review_count': entry['review_count'],
            'airlines': entry['airlines'],
          }).toList();
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching from leaderboard_rankings, falling back to leaderboard_scores: $e');
      }

      // Fallback to leaderboard_scores if leaderboard_rankings is not available
      debugPrint('📊 Falling back to leaderboard_scores for $category...');
      final scoreType = mapCategoryToScoreType(category);

      var query = _client
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
          .eq('score_type', scoreType)
          .order('score_value', ascending: false)
          .limit(10);

      final response = await query;

      debugPrint('✅ Fetched ${response.length} $category rankings from leaderboard_scores');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching $category rankings: $e');
      return [];
    }
  }

  /// Get real-time issues from realtime_feedback_view
  static Stream<List<Map<String, dynamic>>> subscribeToIssues() {
    try {
      debugPrint(
          '📡 Subscribing to real-time feedback from realtime_feedback_view...');

      return _client
          .from('realtime_feedback_view')
          .stream(primaryKey: ['feedback_id'])
          .order('feedback_id', ascending: false)
          .limit(100);
    } catch (e) {
      debugPrint('❌ Error subscribing to real-time feedback: $e');
      return Stream.value([]);
    }
  }

  /// Get available score types/categories
  static Future<List<String>> getAvailableCategories() async {
    try {
      debugPrint('📊 Fetching available score categories...');

      // Return default categories
      return ['Overall', 'Wi-Fi Experience', 'Seat Comfort', 'Food and Drink'];
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
      return ['Overall', 'Wi-Fi Experience', 'Seat Comfort', 'Food and Drink'];
    }
  }

  /// Calculate movement indicators (up/down from previous ranking)
  static Map<String, dynamic> calculateMovement(
    List<Map<String, dynamic>> currentRankings,
    List<Map<String, dynamic>> previousRankings,
    int currentIndex,
  ) {
    final currentAirline = currentRankings[currentIndex];
    final airlineId = currentAirline['airline_id'];

    // Find previous position
    int? previousPosition;
    for (int i = 0; i < previousRankings.length; i++) {
      if (previousRankings[i]['airline_id'] == airlineId) {
        previousPosition = i + 1; // Convert to 1-based ranking
        break;
      }
    }

    final currentPosition = currentIndex + 1;

    if (previousPosition == null) {
      return {
        'movement': 'new',
        'previousRank': null,
      };
    }

    if (currentPosition < previousPosition) {
      return {
        'movement': 'up',
        'previousRank': previousPosition,
      };
    } else if (currentPosition > previousPosition) {
      return {
        'movement': 'down',
        'previousRank': previousPosition,
      };
    } else {
      return {
        'movement': null,
        'previousRank': previousPosition,
      };
    }
  }

  /// Format airline data for leaderboard display
  static Map<String, dynamic> formatAirlineData(
    Map<String, dynamic> leaderboardEntry,
    int rank,
    Map<String, dynamic>? movement,
  ) {
    final airline = leaderboardEntry['airlines'] as Map<String, dynamic>?;
    
    // Use leaderboard_rank if available (from leaderboard_rankings table)
    final displayRank = leaderboardEntry['leaderboard_rank'] ?? rank;
    
    // Use leaderboard_score if available, otherwise score_value
    final displayScore = leaderboardEntry['leaderboard_score'] ?? 
                        leaderboardEntry['score_value'];

    return {
      'id': leaderboardEntry['airline_id'],
      'name': airline?['name'] ?? 'Unknown Airline',
      'iataCode': airline?['iata_code'],
      'icaoCode': airline?['icao_code'],
      'logo': airline?['logo_url'] ?? 'assets/images/airline_logo.png',
      'score': displayScore,
      'avgRating': leaderboardEntry['avg_rating'],
      'reviewCount': leaderboardEntry['review_count'],
      'rank': displayRank,
      'movement': movement?['movement'],
      'previousRank': movement?['previousRank'],
      'color': Colors.grey.shade100,
    };
  }

  /// Map UI categories to database score types
  static String mapCategoryToScoreType(String uiCategory) {
    switch (uiCategory) {
      case 'Wi-Fi Experience':
        return 'wifi_experience';
      case 'Crew Friendliness':
        return 'crew_friendliness';
      case 'Seat Comfort':
        return 'seat_comfort';
      case 'Food & Beverage':
        return 'food_beverage';
      case 'Operations & Timeliness':
        return 'operations_timeliness';
      default:
        return 'overall';
    }
  }

  /// Map database score types to UI categories
  static String mapScoreTypeToCategory(String scoreType) {
    switch (scoreType) {
      case 'wifi_experience':
        return 'Wi-Fi Experience';
      case 'crew_friendliness':
        return 'Crew Friendliness';
      case 'seat_comfort':
        return 'Seat Comfort';
      case 'food_beverage':
        return 'Food & Beverage';
      case 'operations_timeliness':
        return 'Operations & Timeliness';
      default:
        return 'Overall';
    }
  }
}
