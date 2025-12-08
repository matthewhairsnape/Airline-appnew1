import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/models/leaderboard_category_model.dart';

/// Service to handle airport leaderboard data from Supabase
class AirportLeaderboardService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Get airport leaderboard rankings from Supabase
  static Future<List<Map<String, dynamic>>> getAirportLeaderboardRankings({
    required String category,
    int limit = 50,
  }) async {
    try {
      debugPrint('📊 Fetching airport leaderboard rankings from Supabase for category: $category');

      // Map category to score_type
      final scoreType = LeaderboardCategoryService.mapAirportCategoryToScoreType(category);

      // Query airport_leaderboard_rankings table
      var query = _client
          .from('airport_leaderboard_rankings')
          .select('''
            id,
            airport_id,
            category,
            leaderboard_rank,
            leaderboard_score,
            avg_rating,
            review_count,
            positive_count,
            negative_count,
            positive_ratio,
            airports!inner(
              id,
              name,
              iata_code,
              icao_code,
              city,
              country
            )
          ''')
          .eq('category', category)
          .eq('is_active', true)
          .order('leaderboard_rank', ascending: true)
          .limit(limit);

      final response = await query;

      debugPrint('✅ Fetched ${response.length} airport leaderboard entries for $category');

      // Format the data similar to airline leaderboard
      return response.map((entry) {
        final airport = entry['airports'] as Map<String, dynamic>? ?? {};
        return {
          'id': entry['id'],
          'airport_id': entry['airport_id'],
          'category': entry['category'],
          'leaderboard_rank': entry['leaderboard_rank'] ?? 0,
          'leaderboard_score': entry['leaderboard_score'] ?? 0.0,
          'avg_rating': entry['avg_rating'] ?? 0.0,
          'review_count': entry['review_count'] ?? 0,
          'positive_count': entry['positive_count'] ?? 0,
          'negative_count': entry['negative_count'] ?? 0,
          'positive_ratio': entry['positive_ratio'] ?? 0.0,
          'airports': {
            'id': airport['id'],
            'name': airport['name'] ?? 'Unknown Airport',
            'iata_code': airport['iata_code'] ?? '',
            'icao_code': airport['icao_code'] ?? '',
            'city': airport['city'] ?? '',
            'country': airport['country'] ?? '',
            'logo': _getAirportLogoUrl(airport['iata_code'] ?? ''),
            'logo_url': _getAirportLogoUrl(airport['iata_code'] ?? ''),
          },
          'score_type': scoreType,
          'score_value': entry['leaderboard_score'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching airport leaderboard rankings: $e');
      return [];
    }
  }

  /// Get real-time airport leaderboard updates
  static Stream<List<Map<String, dynamic>>> subscribeToAirportLeaderboardUpdates({
    required String category,
    int limit = 50,
  }) {
    try {
      debugPrint('📡 Subscribing to airport leaderboard real-time updates for category: $category');

      final streamQuery = _client
          .from('airport_leaderboard_rankings')
          .stream(primaryKey: ['id'])
          .order('leaderboard_rank', ascending: true)
          .limit(limit);

      return streamQuery.asyncMap((rows) async {
        // Filter by category and active status
        final filteredRows = rows.where((entry) {
          return entry['category'] == category && entry['is_active'] == true;
        }).toList()
          ..sort((a, b) {
            final rankA = (a['leaderboard_rank'] as int?) ?? 0;
            final rankB = (b['leaderboard_rank'] as int?) ?? 0;
            return rankA.compareTo(rankB);
          });

        debugPrint('📊 Received ${filteredRows.length} airport leaderboard entries via realtime');

        // Fetch airport details for each entry
        final enrichedData = <Map<String, dynamic>>[];
        for (final entry in filteredRows) {
          try {
            final airportData = await _client
                .from('airports')
                .select('id, name, iata_code, icao_code, city, country')
                .eq('id', entry['airport_id'])
                .maybeSingle();

            if (airportData != null) {
              final resolvedLogo = _getAirportLogoUrl(airportData['iata_code'] ?? '');
              final airportWithLogo = {
                ...airportData,
                'logo': resolvedLogo,
                'logo_url': resolvedLogo,
              };

              enrichedData.add({
                ...entry,
                'airports': airportWithLogo,
                'score_type': LeaderboardCategoryService.mapAirportCategoryToScoreType(category),
                'score_value': entry['leaderboard_score'] ?? 0.0,
              });
            }
          } catch (e) {
            debugPrint('⚠️ Error fetching airport for ${entry['airport_id']}: $e');
          }
        }

        return enrichedData;
      });
    } catch (e) {
      debugPrint('❌ Error subscribing to airport leaderboard updates: $e');
      return Stream.value([]);
    }
  }

  /// Format airport data for display (similar to airline formatting)
  static Map<String, dynamic> formatAirportData(
    Map<String, dynamic> airportData,
    int rank,
    Map<String, dynamic>? issues,
  ) {
    final airport = airportData['airports'] as Map<String, dynamic>? ?? {};
    final airportName = airport['name'] ?? 'Unknown Airport';
    final iataCode = airport['iata_code'] ?? '';
    final city = airport['city'] ?? '';
    final country = airport['country'] ?? '';
    
    return {
      'id': airportData['airport_id'] ?? airportData['id'],
      'name': airportName,
      'iata_code': iataCode,
      'icao_code': airport['icao_code'] ?? '',
      'city': city,
      'country': country,
      'rank': rank,
      'score': airportData['leaderboard_score'] ?? airportData['score_value'] ?? 0.0,
      'rating': airportData['avg_rating'] ?? 0.0,
      'review_count': airportData['review_count'] ?? 0,
      'positive_count': airportData['positive_count'] ?? 0,
      'negative_count': airportData['negative_count'] ?? 0,
      'positive_ratio': airportData['positive_ratio'] ?? 0.0,
      'logo': airport['logo'] ?? airport['logo_url'] ?? _getAirportLogoUrl(iataCode),
      'logo_url': airport['logo_url'] ?? _getAirportLogoUrl(iataCode),
      'issues': issues ?? {},
      'display_name': '$airportName ($iataCode)',
      'location': city.isNotEmpty && country.isNotEmpty ? '$city, $country' : (city.isNotEmpty ? city : country),
    };
  }

  /// Get airport logo URL (placeholder - can be enhanced with actual logo service)
  static String _getAirportLogoUrl(String iataCode) {
    if (iataCode.isEmpty) {
      return '';
    }
    // Placeholder - you can integrate with an airport logo API/CDN
    // For now, return empty string or a default logo URL
    return '';
  }

  /// Get category-specific airport rankings
  static Future<List<Map<String, dynamic>>> getCategoryRankings(
    String category, {
    int limit = 50,
  }) async {
    try {
      debugPrint('📊 Fetching airport rankings for category: $category');

      final rankings = await getAirportLeaderboardRankings(
        category: category,
        limit: limit,
      );

      // Format the data
      return rankings.asMap().entries.map((entry) {
        final index = entry.key;
        final airportData = entry.value;
        final rank = airportData['leaderboard_rank'] as int? ?? (index + 1);
        return formatAirportData(airportData, rank, null);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting category rankings: $e');
      return [];
    }
  }
}

