import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/data/local_leaderboard_seed.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle leaderboard data from Supabase
class SupabaseLeaderboardService {
  static final SupabaseClient _client = SupabaseService.client;
  static const Map<String, String> _airlineLogoOverrides = {
    'EK': 'https://images.kiwi.com/airlines/256/EK.png',
    'QR': 'https://images.kiwi.com/airlines/256/QR.png',
    'AA': 'https://images.kiwi.com/airlines/256/AA.png',
    'UA': 'https://images.kiwi.com/airlines/256/UA.png',
    'DL': 'https://images.kiwi.com/airlines/256/DL.png',
    'LH': 'https://images.kiwi.com/airlines/256/LH.png',
    'BA': 'https://images.kiwi.com/airlines/256/BA.png',
    'TK': 'https://images.kiwi.com/airlines/256/TK.png',
    'EY': 'https://images.kiwi.com/airlines/256/EY.png',
    'AF': 'https://images.kiwi.com/airlines/256/AF.png',
    'SQ': 'https://images.kiwi.com/airlines/256/SQ.png',
    'CX': 'https://images.kiwi.com/airlines/256/CX.png',
    'NH': 'https://images.kiwi.com/airlines/256/NH.png',
    'QF': 'https://images.kiwi.com/airlines/256/QF.png',
    'AC': 'https://images.kiwi.com/airlines/256/AC.png',
    'WN': 'https://images.kiwi.com/airlines/256/WN.png',
    'B6': 'https://images.kiwi.com/airlines/256/B6.png',
    'VS': 'https://images.kiwi.com/airlines/256/VS.png',
    'AZ': 'https://images.kiwi.com/airlines/256/AZ.png',
    'IB': 'https://images.kiwi.com/airlines/256/IB.png',
    'AY': 'https://images.kiwi.com/airlines/256/AY.png',
    'SK': 'https://images.kiwi.com/airlines/256/SK.png',
    'KL': 'https://images.kiwi.com/airlines/256/KL.png',
    'OS': 'https://images.kiwi.com/airlines/256/OS.png',
    'SN': 'https://images.kiwi.com/airlines/256/SN.png',
    'TP': 'https://images.kiwi.com/airlines/256/TP.png',
    'ET': 'https://images.kiwi.com/airlines/256/ET.png',
    'SA': 'https://images.kiwi.com/airlines/256/SA.png',
    'MS': 'https://images.kiwi.com/airlines/256/MS.png',
    'KQ': 'https://images.kiwi.com/airlines/256/KQ.png',
  };

  /// Get leaderboard rankings from Supabase
  static Future<List<Map<String, dynamic>>> getLeaderboardRankings({
    String? scoreType,
    int limit = 50, // Increased default from 10 to 50
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
    required String category,
    String? travelClass,
    int limit = 50, // Increased default from 10 to 50
  }) {
    try {
      debugPrint('📡 Subscribing to leaderboard real-time updates...');

      final streamQuery = _client
          .from('leaderboard_rankings')
          .stream(primaryKey: ['id'])
          .order('leaderboard_rank', ascending: true)
          .limit(limit);

      final travelClassMatches = _mapTravelClassToDbValues(travelClass)
          .map((v) => v.toLowerCase())
          .toSet();

      return streamQuery.asyncMap((rows) async {
        // Apply filters client-side because Supabase stream builder no longer exposes eq/filter helpers.
        final filteredRows = rows.where((entry) {
          final matchesActive = entry['is_active'] == true;
          final matchesCategory = entry['category'] == category;
          final entryClass =
              entry['travel_class']?.toString().toLowerCase();
          final matchesTravelClass = travelClassMatches.isEmpty ||
              entryClass == null ||
              entryClass == 'all' ||
              travelClassMatches.contains(entryClass);
          return matchesActive && matchesCategory && matchesTravelClass;
        }).toList()
          ..sort((a, b) {
            final rankA = (a['leaderboard_rank'] as int?) ?? 0;
            final rankB = (b['leaderboard_rank'] as int?) ?? 0;
            return rankA.compareTo(rankB);
          });

        debugPrint(
            '📊 Received ${filteredRows.length} leaderboard entries via realtime');

        if (filteredRows.isEmpty) {
          final localFallback = LocalLeaderboardSeed.getCategoryRankings(
            category,
          )
              .where((entry) {
                final entryClass =
                    entry['travel_class']?.toString().toLowerCase();
                return travelClassMatches.isEmpty ||
                    entryClass == null ||
                    entryClass == 'all' ||
                    travelClassMatches.contains(entryClass);
              })
              .map((entry) => {
                    ...entry,
                    'score_type': mapCategoryToScoreType(category),
                    'score_value':
                        entry['leaderboard_score'] ?? entry['score_value'],
                  })
              .toList();
          if (localFallback.isNotEmpty) {
            return localFallback;
          }
        }

        // Fetch airline details for each entry
        final enrichedData = <Map<String, dynamic>>[];
        for (final entry in filteredRows) {
          try {
            final airlineData = await _client
                .from('airlines')
                .select('id, name, iata_code, icao_code, logo_url')
                .eq('id', entry['airline_id'])
                .single();
            final resolvedLogo = _resolveLogoUrl(airlineData);
            final airlineWithLogo = {
              ...airlineData,
              'logo': resolvedLogo,
              'logo_url': airlineData['logo_url'] ?? resolvedLogo,
            };

            enrichedData.add({
              ...entry,
              'airlines': airlineWithLogo,
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
      final localFallback = LocalLeaderboardSeed.getCategoryRankings(category)
          .map((entry) => {
                ...entry,
                'score_type': mapCategoryToScoreType(category),
                'score_value':
                    entry['leaderboard_score'] ?? entry['score_value'],
              })
          .toList();
      if (localFallback.isNotEmpty) {
        return Stream.value(localFallback);
      }
      return Stream.value([]);
    }
  }

  /// Get category-specific rankings
  /// Now uses leaderboard_rankings table for better performance and consistency
  static Future<List<Map<String, dynamic>>> getCategoryRankings(String category,
      {String? travelClass}) async {
    final travelClassValues = _mapTravelClassToDbValues(travelClass);
    final travelClassMatchSet =
        travelClassValues.map((value) => value.toLowerCase()).toSet();

    try {
      debugPrint('📊 Fetching $category rankings from leaderboard_rankings...');

      // Try to get from leaderboard_rankings first
      try {
        final queryBuilder = _client.from('leaderboard_rankings');
        var filterBuilder = queryBuilder.select('''
              id,
              airline_id,
              category,
              travel_class,
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
            ''').eq('category', category).eq('is_active', true);

        final rankingsResponse =
            filterBuilder.order('leaderboard_rank', ascending: true).limit(50);

        final rankings = await rankingsResponse;

        final filteredResults = travelClassMatchSet.isEmpty
            ? rankings
            : rankings
                .where((entry) {
                  final entryClass =
                      entry['travel_class']?.toString().toLowerCase();
                  return entryClass == null ||
                      entryClass == 'all' ||
                      travelClassMatchSet.contains(entryClass);
                })
                .toList();

        if (filteredResults.isNotEmpty) {
          // Convert to expected format
          return filteredResults
              .map((entry) => {
                    'id': entry['id'],
                    'airline_id': entry['airline_id'],
                    'score_type': mapCategoryToScoreType(category),
                    'score_value': entry['leaderboard_score'],
                    'leaderboard_rank': entry['leaderboard_rank'],
                    'avg_rating': entry['avg_rating'],
                    'review_count': entry['review_count'],
                    'airlines': {
                      ...entry['airlines'],
                      'logo': _resolveLogoUrl(
                        entry['airlines'] as Map<String, dynamic>?,
                      ),
                      'logo_url': (entry['airlines'] as Map?)?['logo_url'] ??
                          _resolveLogoUrl(
                            entry['airlines'] as Map<String, dynamic>?,
                          ),
                    },
                    'travel_class': entry['travel_class'],
                  })
              .toList();
        }
      } catch (e) {
        debugPrint(
            '⚠️ Error fetching from leaderboard_rankings, falling back to leaderboard_scores: $e');
      }

      // Fallback to leaderboard_scores if leaderboard_rankings is not available
      debugPrint('📊 Falling back to leaderboard_scores for $category...');
      final scoreType = mapCategoryToScoreType(category);
      var filterBuilder = _client.from('leaderboard_scores').select('''
            id,
            airline_id,
            score_type,
            travel_class,
            score_value,
            airlines!inner(
              id,
              name,
              iata_code,
              icao_code,
              logo_url
            )
          ''').eq('score_type', scoreType);

      final response = await filterBuilder
          .order('score_value', ascending: false)
          .limit(50); // Increased from 10 to 50 to show more airlines

      debugPrint(
          '✅ Fetched ${response.length} $category rankings from leaderboard_scores');

      // Debug: Log first entry to see structure
      if (response.isNotEmpty) {
        final firstEntry = response.first;
        debugPrint('🔍 First leaderboard_scores entry structure:');
        debugPrint('   airline_id: ${firstEntry['airline_id']}');
        debugPrint('   airlines: ${firstEntry['airlines']}');
        if (firstEntry['airlines'] != null) {
          final airlines = firstEntry['airlines'] as Map?;
          debugPrint('   airlines.logo_url: ${airlines?['logo_url']}');
        }
      }

      final filteredResponse = travelClassMatchSet.isEmpty
          ? response
          : response
              .where((entry) {
                final entryClass =
                    entry['travel_class']?.toString().toLowerCase();
                return entryClass == null ||
                    entryClass == 'all' ||
                    travelClassMatchSet.contains(entryClass);
              })
              .toList();

      if (filteredResponse.isNotEmpty) {
        return filteredResponse
            .map((entry) {
              final airlines = entry['airlines'] as Map<String, dynamic>?;
              final resolvedLogo = _resolveLogoUrl(airlines);
              return {
                ...entry,
                'airlines': {
                  if (airlines != null) ...airlines,
                  'logo': resolvedLogo,
                  'logo_url': airlines?['logo_url'] ?? resolvedLogo,
                },
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();
      }

      final localFallback = LocalLeaderboardSeed.getCategoryRankings(category)
          .where((entry) {
            final entryClass = entry['travel_class']?.toString().toLowerCase();
            return travelClassMatchSet.isEmpty ||
                entryClass == null ||
                entryClass == 'all' ||
                travelClassMatchSet.contains(entryClass);
          })
          .map((entry) => {
                ...entry,
                'score_type': mapCategoryToScoreType(category),
                'score_value':
                    entry['leaderboard_score'] ?? entry['score_value'],
              })
          .toList();
      if (localFallback.isNotEmpty) {
        debugPrint('ℹ️ Using local leaderboard seed data for $category');
        return localFallback;
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error fetching $category rankings: $e');
      final localFallback = LocalLeaderboardSeed.getCategoryRankings(category)
          .where((entry) {
            final entryClass = entry['travel_class']?.toString().toLowerCase();
            return travelClassMatchSet.isEmpty ||
                entryClass == null ||
                entryClass == 'all' ||
                travelClassMatchSet.contains(entryClass);
          })
          .map((entry) => {
                ...entry,
                'score_type': mapCategoryToScoreType(category),
                'score_value':
                    entry['leaderboard_score'] ?? entry['score_value'],
              })
          .toList();
      if (localFallback.isNotEmpty) {
        debugPrint(
            'ℹ️ Using local leaderboard seed data for $category after error');
        return localFallback;
      }
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
      return [
        'Wi-Fi Experience',
        'Crew Friendliness',
        'Seat Comfort',
        'Food & Beverage',
        'Operations & Timeliness',
        'Inflight Entertainment',
        'Aircraft Condition',
        'Arrival Experience',
        'Booking Experience',
        'Cleanliness',
      ];
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
      return [
        'Wi-Fi Experience',
        'Crew Friendliness',
        'Seat Comfort',
        'Food & Beverage',
        'Operations & Timeliness',
        'Inflight Entertainment',
        'Aircraft Condition',
        'Arrival Experience',
        'Booking Experience',
        'Cleanliness',
      ];
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

    final logoUrl = _resolveLogoUrl(airline);

    return {
      'id': leaderboardEntry['airline_id'],
      'name': airline?['name'] ?? 'Unknown Airline',
      'iataCode': airline?['iata_code'],
      'icaoCode': airline?['icao_code'],
      'logo': logoUrl ?? 'assets/images/airline_logo.png',
      'score': displayScore,
      'avgRating': leaderboardEntry['avg_rating'],
      'reviewCount': leaderboardEntry['review_count'],
      'rank': displayRank,
      'movement': movement?['movement'],
      'previousRank': movement?['previousRank'],
      'color': Colors.grey.shade100,
    };
  }

  static String? _resolveLogoUrl(Map<String, dynamic>? airline) {
    if (airline == null) return null;
    final logo = airline['logo']?.toString();
    final logoUrl = airline['logo_url']?.toString();
    if (_isValidHttpUrl(logo)) {
      return logo;
    }
    if (_isValidHttpUrl(logoUrl)) {
      return logoUrl;
    }

    final iata =
        airline['iata_code']?.toString().toUpperCase();
    final icao =
        airline['icao_code']?.toString().toUpperCase();

    if (iata != null && _airlineLogoOverrides.containsKey(iata)) {
      return _airlineLogoOverrides[iata];
    }
    if (icao != null && _airlineLogoOverrides.containsKey(icao)) {
      return _airlineLogoOverrides[icao];
    }

    if (iata != null && iata.length >= 2) {
      return 'https://images.kiwi.com/airlines/256/$iata.png';
    }

    if (icao != null && icao.length >= 2) {
      return 'https://images.kiwi.com/airlines/256/$icao.png';
    }

    return null;
  }

  static bool _isValidHttpUrl(String? value) {
    if (value == null) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Map UI categories to database score types
  static String mapCategoryToScoreType(String uiCategory) {
    switch (uiCategory) {
      case 'Business Class':
        return 'business_class';
      case 'Economy Class':
        return 'economy_class';
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
      case 'Inflight Entertainment':
        return 'inflight_entertainment';
      case 'Arrival Experience':
        return 'arrival_experience';
      case 'Booking Experience':
        return 'booking_experience';
      case 'Cleanliness':
        return 'cleanliness';
      case 'Aircraft Condition':
        return 'aircraft_condition';
      default:
        return 'overall';
    }
  }

  /// Map database score types to UI categories
  static String mapScoreTypeToCategory(String scoreType) {
    switch (scoreType) {
      case 'business_class':
        return 'Business Class';
      case 'economy_class':
        return 'Economy Class';
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
      case 'inflight_entertainment':
        return 'Inflight Entertainment';
      case 'arrival_experience':
        return 'Arrival Experience';
      case 'booking_experience':
        return 'Booking Experience';
      case 'cleanliness':
        return 'Cleanliness';
      case 'aircraft_condition':
        return 'Aircraft Condition';
      default:
        return 'Overall';
    }
  }

  static List<String> _mapTravelClassToDbValues(String? travelClass) {
    if (travelClass == null || travelClass.isEmpty) return const [];
    final normalized = travelClass.toLowerCase();
    if (normalized.contains('business')) {
      return const [
        'business',
        'business class',
        'business_class',
        'premium business',
      ];
    }
    if (normalized.contains('economy')) {
      return const [
        'economy',
        'economy class',
        'economy_class',
        'main cabin',
        'coach',
      ];
    }
    if (normalized.contains('first')) {
      return const [
        'first',
        'first class',
        'first_class',
      ];
    }
    return [travelClass];
  }
}
