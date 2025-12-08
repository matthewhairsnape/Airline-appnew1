import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/data/local_leaderboard_seed.dart';
import 'package:airline_app/services/supabase_service.dart';

/// Service to handle leaderboard data from Supabase
class SupabaseLeaderboardService {
  static final SupabaseClient _client = SupabaseService.client;
  // Use airhex.com CDN with _512_512_s.png format (public, no auth needed)
  static const Map<String, String> _airlineLogoOverrides = {
    'EK': 'https://content.airhex.com/content/logos/airlines_EK_512_512_s.png',
    'QR': 'https://content.airhex.com/content/logos/airlines_QR_512_512_s.png',
    'AA': 'https://content.airhex.com/content/logos/airlines_AA_512_512_s.png',
    'UA': 'https://content.airhex.com/content/logos/airlines_UA_512_512_s.png',
    'DL': 'https://content.airhex.com/content/logos/airlines_DL_512_512_s.png',
    'LH': 'https://content.airhex.com/content/logos/airlines_LH_512_512_s.png',
    'BA': 'https://content.airhex.com/content/logos/airlines_BA_512_512_s.png',
    'TK': 'https://content.airhex.com/content/logos/airlines_TK_512_512_s.png',
    'EY': 'https://content.airhex.com/content/logos/airlines_EY_512_512_s.png',
    'AF': 'https://content.airhex.com/content/logos/airlines_AF_512_512_s.png',
    'SQ': 'https://content.airhex.com/content/logos/airlines_SQ_512_512_s.png',
    'CX': 'https://content.airhex.com/content/logos/airlines_CX_512_512_s.png',
    'NH': 'https://content.airhex.com/content/logos/airlines_NH_512_512_s.png',
    'QF': 'https://content.airhex.com/content/logos/airlines_QF_512_512_s.png',
    'AC': 'https://content.airhex.com/content/logos/airlines_AC_512_512_s.png',
    'WN': 'https://content.airhex.com/content/logos/airlines_WN_512_512_s.png',
    'B6': 'https://content.airhex.com/content/logos/airlines_B6_512_512_s.png',
    'VS': 'https://content.airhex.com/content/logos/airlines_VS_512_512_s.png',
    'AZ': 'https://content.airhex.com/content/logos/airlines_AZ_512_512_s.png',
    'IB': 'https://content.airhex.com/content/logos/airlines_IB_512_512_s.png',
    'AY': 'https://content.airhex.com/content/logos/airlines_AY_512_512_s.png',
    'SK': 'https://content.airhex.com/content/logos/airlines_SK_512_512_s.png',
    'KL': 'https://content.airhex.com/content/logos/airlines_KL_512_512_s.png',
    'OS': 'https://content.airhex.com/content/logos/airlines_OS_512_512_s.png',
    'SN': 'https://content.airhex.com/content/logos/airlines_SN_512_512_s.png',
    'TP': 'https://content.airhex.com/content/logos/airlines_TP_512_512_s.png',
    'ET': 'https://content.airhex.com/content/logos/airlines_ET_512_512_s.png',
    'SA': 'https://content.airhex.com/content/logos/airlines_SA_512_512_s.png',
    'MS': 'https://content.airhex.com/content/logos/airlines_MS_512_512_s.png',
    'KQ': 'https://content.airhex.com/content/logos/airlines_KQ_512_512_s.png',
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
          final entryClass = entry['travel_class']?.toString().toLowerCase();
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
    // For experience categories (non-travel-class), ignore travel class filter
    final isExperienceCategory = !_isTravelClassCategory(category);
    
    // For travel class categories, extract the travel class from the category name
    // and use that instead of the travelClass parameter
    String? effectiveTravelClass = travelClass;
    if (!isExperienceCategory) {
      // Extract travel class from category name
      final categoryLower = category.toLowerCase();
      if (categoryLower.contains('first class')) {
        effectiveTravelClass = 'first';
      } else if (categoryLower.contains('business class')) {
        effectiveTravelClass = 'business';
      } else if (categoryLower.contains('premium economy')) {
        effectiveTravelClass = 'premium';
      } else if (categoryLower == 'economy') {
        effectiveTravelClass = 'economy';
      }
    }
    
    final travelClassValues = isExperienceCategory 
        ? const <String>[] 
        : _mapTravelClassToDbValues(effectiveTravelClass);
    final travelClassMatchSet =
        travelClassValues.map((value) => value.toLowerCase()).toSet();

    // Always check local seed data first for exact rankings
    final localData = LocalLeaderboardSeed.getCategoryRankings(category);
    if (localData.isNotEmpty) {
      final filteredLocal = localData.where((entry) {
        final entryClass = entry['travel_class']?.toString().toLowerCase();
        // For experience categories, always include entries with travel_class: 'all'
        if (isExperienceCategory && (entryClass == 'all' || entryClass == null)) {
          return true;
        }
        return travelClassMatchSet.isEmpty ||
            entryClass == null ||
            entryClass == 'all' ||
            travelClassMatchSet.contains(entryClass);
      }).toList();

      if (filteredLocal.isNotEmpty) {
        debugPrint(
            '✅ Using local seed data for $category: ${filteredLocal.length} entries');
        return filteredLocal
            .map((entry) => {
                  ...entry,
                  'score_type': mapCategoryToScoreType(category),
                  'score_value':
                      entry['leaderboard_score'] ?? entry['score_value'],
                })
            .toList();
      }
    }

    try {
      debugPrint('📊 Fetching $category rankings from leaderboard_rankings...');

      // Normalize category name to match database
      final normalizedCategory = normalizeCategoryName(category);
      debugPrint(
          '📝 Normalized category: "$category" -> "$normalizedCategory"');

      // Try to get from leaderboard_rankings first
      // Try multiple category name variations
      final categoryVariations = [
        normalizedCategory,
        category, // Original category name
        // Try alternative names
        if (category == 'Airport Experience')
          'Airport Experience (Departure and Arrival)',
        if (category == 'F&B') 'Food & Beverage',
        if (category == 'IFE and Wifi') 'Entertainment and Wi-Fi',
        if (category == 'Onboard Service') 'Onboard Service',
      ];

      List<Map<String, dynamic>>? rankings;
      String? successfulCategory;

      for (final categoryVar in categoryVariations) {
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
              ''').eq('category', categoryVar).eq('is_active', true);

          final rankingsResponse = filterBuilder
              .order('leaderboard_rank', ascending: true)
              .limit(50);

          final testRankings = await rankingsResponse;
          if (testRankings.isNotEmpty) {
            rankings = testRankings;
            successfulCategory = categoryVar;
            debugPrint(
                '✅ Found ${testRankings.length} rankings using category: "$categoryVar"');
            break;
          }
        } catch (e) {
          debugPrint('⚠️ Error trying category "$categoryVar": $e');
          continue;
        }
      }

      if (rankings == null || rankings.isEmpty) {
        debugPrint(
            '⚠️ No rankings found for any category variation. Trying case-insensitive search...');
        // Try case-insensitive search as last resort
        try {
          final allRankings = await _client
              .from('leaderboard_rankings')
              .select('category')
              .eq('is_active', true)
              .limit(100);

          final availableCategories = allRankings
              .map((r) => r['category'] as String?)
              .where((c) => c != null)
              .toSet()
              .toList();

          debugPrint(
              '📋 Available categories in database: $availableCategories');
        } catch (e) {
          debugPrint('⚠️ Could not fetch available categories: $e');
        }

        throw Exception('No rankings found for category: $category');
      }

      debugPrint(
          '✅ Using category: "$successfulCategory" with ${rankings.length} rankings');

      final filteredResults = travelClassMatchSet.isEmpty
          ? rankings!
          : rankings!.where((entry) {
              final entryClass =
                  entry['travel_class']?.toString().toLowerCase();
              // For experience categories, always include entries with travel_class: 'all'
              if (isExperienceCategory && (entryClass == 'all' || entryClass == null)) {
                return true;
              }
              return entryClass == null ||
                  entryClass == 'all' ||
                  travelClassMatchSet.contains(entryClass);
            }).toList();

      debugPrint(
          '✅ Filtered to ${filteredResults.length} rankings after travel class filter');

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

      // If no results from leaderboard_rankings, return empty and let catch handle fallback
      return [];
    } catch (e) {
      debugPrint(
          '⚠️ Error fetching from leaderboard_rankings, falling back to leaderboard_scores: $e');

      // Fallback to leaderboard_scores
      try {
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
            .limit(50);

        debugPrint(
            '✅ Fetched ${response.length} $category rankings from leaderboard_scores');

        final filteredResponse = travelClassMatchSet.isEmpty
            ? response
            : response.where((entry) {
                final entryClass =
                    entry['travel_class']?.toString().toLowerCase();
                // For experience categories, always include entries with travel_class: 'all'
                if (isExperienceCategory && (entryClass == 'all' || entryClass == null)) {
                  return true;
                }
                return entryClass == null ||
                    entryClass == 'all' ||
                    travelClassMatchSet.contains(entryClass);
              }).toList();

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
      } catch (e2) {
        debugPrint('❌ Error fetching $category rankings: $e2');
      }

      // Final fallback to local seed data
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
    
    debugPrint('🔍 formatAirlineData - Entry keys: ${leaderboardEntry.keys}');
    debugPrint('🔍 formatAirlineData - Airline: ${airline?.keys}');
    if (airline != null) {
      debugPrint('🔍 formatAirlineData - Airline logo_url: ${airline['logo_url']}, logo: ${airline['logo']}, iata_code: ${airline['iata_code']}');
    }

    // Use leaderboard_rank if available (from leaderboard_rankings table)
    final displayRank = leaderboardEntry['leaderboard_rank'] ?? rank;

    // Use leaderboard_score if available, otherwise score_value
    final displayScore = leaderboardEntry['leaderboard_score'] ??
        leaderboardEntry['score_value'];

    // Resolve logo URL - prioritize logo_url from airlines object, then fallback to IATA-based URL
    String? logoUrl;
    final iataCode = airline?['iata_code']?.toString().toUpperCase();
    final icaoCode = airline?['icao_code']?.toString().toUpperCase();
    
    debugPrint('🔍 Logo resolution - IATA: $iataCode, ICAO: $icaoCode');
    
    if (airline != null) {
      // First try to use the logo_url from the airlines object
      final logoFromAirline = airline['logo_url']?.toString() ?? airline['logo']?.toString();
      debugPrint('🔍 Logo from airline object: $logoFromAirline');
      
      if (logoFromAirline != null && logoFromAirline.isNotEmpty) {
        if (_isValidHttpUrl(logoFromAirline)) {
          // If Supabase has kiwi.com URL (404 errors), replace with airhex.com
          if (logoFromAirline.contains('kiwi.com')) {
            if (iataCode != null && iataCode.length >= 2) {
              logoUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
              debugPrint('🔄 Replacing kiwi.com URL with airhex.com: $logoUrl for ${airline['name']}');
            } else {
              logoUrl = logoFromAirline; // Keep original if no IATA
            }
          } else {
            logoUrl = logoFromAirline;
            debugPrint('✅ Using logo from airlines object: $logoUrl for ${airline['name']}');
          }
        } else {
          debugPrint('⚠️ Logo from airline is not a valid URL: $logoFromAirline');
        }
      }
      
      // If no valid logo from airline object, try IATA-based fallback
      // Use airhex.com with _512_512_s.png format (working URLs)
      if (logoUrl == null && iataCode != null && iataCode.length >= 2) {
        if (_airlineLogoOverrides.containsKey(iataCode)) {
          logoUrl = _airlineLogoOverrides[iataCode];
          debugPrint('✅ Using logo from overrides for $iataCode: $logoUrl');
        } else {
          // Use airhex.com with _512_512_s.png format (public, no auth needed)
          logoUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
          debugPrint('✅ Using airhex.com CDN for $iataCode: $logoUrl');
        }
      }
      
      // If still no logo, try ICAO-based fallback
      if (logoUrl == null && icaoCode != null && icaoCode.length >= 2) {
        logoUrl = 'https://content.airhex.com/content/logos/airlines_${icaoCode}_512_512_s.png';
        debugPrint('✅ Using airhex.com CDN for ICAO $icaoCode: $logoUrl');
      }
    }
    
    // Final fallback: if we have IATA but no logo, use airhex.com CDN
    if (logoUrl == null && iataCode != null && iataCode.length >= 2) {
      logoUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
      debugPrint('⚠️ Final fallback: Using airhex.com CDN for $iataCode: $logoUrl');
    }
    
    // CRITICAL: Ensure logo is never null if we have IATA code
    // Use AirHex as primary fallback, Daisycon as secondary
    if (logoUrl == null || logoUrl.isEmpty) {
      if (iataCode != null && iataCode.length >= 2) {
        logoUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
        debugPrint('🚨 CRITICAL FIX: Setting logo from IATA $iataCode: $logoUrl');
      } else {
        debugPrint('❌ ERROR: No logo and no IATA code for ${airline?['name']}');
      }
    }
    
    debugPrint('📸 Formatting airline: ${airline?['name']}, IATA: $iataCode, Logo: $logoUrl');
    
    final result = {
      'id': leaderboardEntry['airline_id'],
      'name': airline?['name'] ?? 'Unknown Airline',
      'iataCode': iataCode,
      'iata_code': iataCode, // Also include as iata_code for UI compatibility
      'icaoCode': icaoCode,
      'icao_code': icaoCode, // Also include as icao_code for UI compatibility
      'logo': logoUrl ?? '', // Ensure it's never null
      'logo_url': logoUrl ?? '', // Ensure it's never null
      'score': displayScore,
      'avgRating': leaderboardEntry['avg_rating'],
      'reviewCount': leaderboardEntry['review_count'],
      'rank': displayRank,
      'movement': movement?['movement'],
      'previousRank': movement?['previousRank'],
      // Removed 'color' field - not JSON serializable and not needed
    };
    
    debugPrint('📦 Final formatted data - logo: ${result['logo']}, logo_url: ${result['logo_url']}');
    
    return result;
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

    final iata = airline['iata_code']?.toString().toUpperCase();
    final icao = airline['icao_code']?.toString().toUpperCase();

    if (iata != null && _airlineLogoOverrides.containsKey(iata)) {
      return _airlineLogoOverrides[iata];
    }
    if (icao != null && _airlineLogoOverrides.containsKey(icao)) {
      return _airlineLogoOverrides[icao];
    }

    if (iata != null && iata.length >= 2) {
      // Use airhex.com CDN with _512_512_s.png format (public, no auth needed)
      return 'https://content.airhex.com/content/logos/airlines_${iata}_512_512_s.png';
    }

    if (icao != null && icao.length >= 2) {
      return 'https://content.airhex.com/content/logos/airlines_${icao}_512_512_s.png';
    }

    return null;
  }

  static bool _isValidHttpUrl(String? value) {
    if (value == null) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Map UI category names to database category names
  /// This handles variations in category naming between UI and database
  static String normalizeCategoryName(String uiCategory) {
    switch (uiCategory) {
      case 'First Class':
        return 'First Class';
      case 'Business Class':
        return 'Business Class';
      case 'Premium Economy':
        return 'Premium Economy';
      case 'Economy':
      case 'Economy Class':
        return 'Economy';
      case 'Airport Experience':
        return 'Airport Experience';
      case 'F&B':
      case 'Food & Beverage':
        return 'F&B';
      case 'Seat Comfort':
        return 'Seat Comfort';
      case 'IFE and Wifi':
      case 'IFE and Wifi':
      case 'Wi-Fi Experience':
        return 'IFE and Wifi';
      case 'Onboard Service':
        return 'Onboard Service';
      case 'Cleanliness':
        return 'Cleanliness';
      default:
        return uiCategory; // Return as-is if no mapping found
    }
  }

  /// Map UI categories to database score types
  static String mapCategoryToScoreType(String uiCategory) {
    switch (uiCategory) {
      case 'First Class':
        return 'first_class';
      case 'Business Class':
        return 'business_class';
      case 'Premium Economy':
        return 'premium_economy';
      case 'Economy':
      case 'Economy Class':
        return 'economy_class';
      case 'Airport Experience':
        return 'airport_experience';
      case 'F&B':
      case 'Food & Beverage':
        return 'food_beverage';
      case 'Seat Comfort':
        return 'seat_comfort';
      case 'IFE and Wifi':
      case 'Wi-Fi Experience':
        return 'wifi_experience';
      case 'Onboard Service':
        return 'onboard_service';
      case 'Cleanliness':
        return 'cleanliness';
      case 'Crew Friendliness':
        return 'crew_friendliness';
      case 'Operations & Timeliness':
        return 'operations_timeliness';
      case 'Inflight Entertainment':
        return 'inflight_entertainment';
      case 'Arrival Experience':
        return 'arrival_experience';
      case 'Booking Experience':
        return 'booking_experience';
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
    if (normalized.contains('premium')) {
      return const [
        'premium',
        'premium economy',
        'premium_economy',
        'economy plus',
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

  /// Check if a category is a travel class category (First Class, Business Class, etc.)
  /// vs an experience category (Airport Experience, F&B, etc.)
  static bool _isTravelClassCategory(String category) {
    final normalized = category.toLowerCase();
    return normalized.contains('first class') ||
        normalized.contains('business class') ||
        normalized.contains('premium economy') ||
        normalized == 'economy';
  }
}
