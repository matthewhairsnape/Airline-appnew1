import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle leaderboard rankings from the leaderboard_rankings table
class LeaderboardRankingsService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Get leaderboard rankings for a specific category
  static Future<List<Map<String, dynamic>>> getRankingsByCategory(
    String category, {
    int limit = 100,
  }) async {
    try {
      debugPrint('📊 Fetching leaderboard rankings for category: $category');

      final response = await _client
          .from('leaderboard_rankings')
          .select('''
            id,
            airline_id,
            category,
            leaderboard_rank,
            leaderboard_score,
            avg_rating,
            review_count,
            created_at,
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
          .limit(limit);

      debugPrint('✅ Fetched ${response.length} rankings for $category');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching rankings for $category: $e');
      return [];
    }
  }

  /// Get real-time leaderboard rankings updates
  static Stream<List<Map<String, dynamic>>> subscribeToRankings({
    String? category,
    int limit = 100,
  }) {
    try {
      debugPrint('📡 Subscribing to leaderboard rankings updates...');

      var stream = _client
          .from('leaderboard_rankings')
          .stream(primaryKey: ['id']);

      if (category != null && category.isNotEmpty) {
        stream = stream.eq('category', category);
      }

      return stream
          .order('leaderboard_rank', ascending: true)
          .limit(limit)
          .asyncMap((data) async {
        debugPrint('📊 Received ${data.length} rankings via realtime');

        // Enrich with airline details
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
      debugPrint('❌ Error subscribing to rankings updates: $e');
      return Stream.value([]);
    }
  }

  /// Calculate and save rankings for a specific category (calls database function)
  static Future<bool> calculateRankingsForCategory(String category) async {
    try {
      debugPrint('🔄 Calculating rankings for category: $category');

      final response = await _client.rpc(
        'calculate_and_save_rankings',
        params: {'p_category': category},
      );

      debugPrint('✅ Rankings calculated for $category');
      return true;
    } catch (e) {
      debugPrint('❌ Error calculating rankings for $category: $e');
      return false;
    }
  }

  /// Calculate and save rankings for all categories
  static Future<bool> calculateAllRankings() async {
    try {
      debugPrint('🔄 Calculating rankings for all categories...');

      await _client.rpc('calculate_all_rankings');

      debugPrint('✅ All rankings calculated');
      return true;
    } catch (e) {
      debugPrint('❌ Error calculating all rankings: $e');
      return false;
    }
  }

  /// Get ranking for a specific airline in a category
  static Future<Map<String, dynamic>?> getAirlineRanking(
    String airlineId,
    String category,
  ) async {
    try {
      debugPrint('📊 Fetching ranking for airline: $airlineId, category: $category');

      final response = await _client
          .from('leaderboard_rankings')
          .select('''
            *,
            airlines!inner(*)
          ''')
          .eq('airline_id', airlineId)
          .eq('category', category)
          .maybeSingle();

      if (response != null) {
        debugPrint('✅ Found ranking: rank ${response['leaderboard_rank']}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching airline ranking: $e');
      return null;
    }
  }

  /// Get previous rankings for comparison (movement calculation)
  static Future<List<Map<String, dynamic>>> getPreviousRankings(
    String category,
  ) async {
    try {
      // Get rankings ordered by created_at DESC to find previous snapshot
      final response = await _client
          .from('leaderboard_rankings')
          .select('*')
          .eq('category', category)
          .order('created_at', ascending: false)
          .limit(200); // Get more to find previous snapshot

      // Group by airline_id and get the second most recent for each
      final Map<String, Map<String, dynamic>> previousRankings = {};
      final Map<String, int> seen = {};

      for (final ranking in response) {
        final airlineId = ranking['airline_id'] as String;
        seen[airlineId] = (seen[airlineId] ?? 0) + 1;

        // Get the second occurrence as previous ranking
        if (seen[airlineId] == 2 && !previousRankings.containsKey(airlineId)) {
          previousRankings[airlineId] = ranking;
        }
      }

      return previousRankings.values.toList();
    } catch (e) {
      debugPrint('❌ Error fetching previous rankings: $e');
      return [];
    }
  }

  /// Format ranking data for display
  static Map<String, dynamic> formatRankingData(
    Map<String, dynamic> rankingEntry,
    int? previousRank,
  ) {
    final airline = rankingEntry['airlines'] as Map<String, dynamic>?;
    final currentRank = rankingEntry['leaderboard_rank'] as int? ?? 0;

    // Calculate movement
    String? movement;
    if (previousRank != null) {
      if (currentRank < previousRank) {
        movement = 'up';
      } else if (currentRank > previousRank) {
        movement = 'down';
      }
    } else if (currentRank > 0) {
      movement = 'new';
    }

    return {
      'id': rankingEntry['airline_id'],
      'name': airline?['name'] ?? 'Unknown Airline',
      'iataCode': airline?['iata_code'],
      'icaoCode': airline?['icao_code'],
      'logo': airline?['logo_url'] ?? 'assets/images/airline_logo.png',
      'score': rankingEntry['leaderboard_score'],
      'avgRating': rankingEntry['avg_rating'],
      'reviewCount': rankingEntry['review_count'],
      'rank': currentRank,
      'movement': movement,
      'previousRank': previousRank,
      'category': rankingEntry['category'],
      'color': Colors.grey.shade100,
    };
  }

  /// Map UI categories to database categories
  static String mapCategory(String uiCategory) {
    return uiCategory; // Categories match directly in leaderboard_rankings
  }
}

