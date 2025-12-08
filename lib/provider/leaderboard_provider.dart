import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/services/supabase_leaderboard_service.dart';
import 'package:airline_app/services/airport_leaderboard_service.dart';
import 'package:airline_app/services/realtime_feedback_service.dart';
import 'package:airline_app/models/leaderboard_category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State for leaderboard data
class LeaderboardState {
  final List<Map<String, dynamic>> airlines;
  final List<Map<String, dynamic>> airports; // New: airport rankings
  final List<Map<String, dynamic>> issues;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final String selectedTravelClass;
  final List<String> availableCategories;
  final List<String> availableTravelClasses;
  final bool isAirportMode; // New: flag to switch between airline and airport leaderboards
  final DateTime? lastUpdated;

  const LeaderboardState({
    required this.airlines,
    required this.airports,
    required this.issues,
    required this.isLoading,
    this.error,
    required this.selectedCategory,
    required this.selectedTravelClass,
    required this.availableCategories,
    required this.availableTravelClasses,
    this.isAirportMode = false,
    this.lastUpdated,
  });

  LeaderboardState copyWith({
    List<Map<String, dynamic>>? airlines,
    List<Map<String, dynamic>>? airports,
    List<Map<String, dynamic>>? issues,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? selectedTravelClass,
    List<String>? availableCategories,
    List<String>? availableTravelClasses,
    bool? isAirportMode,
    DateTime? lastUpdated,
  }) {
    return LeaderboardState(
      airlines: airlines ?? this.airlines,
      airports: airports ?? this.airports,
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedTravelClass: selectedTravelClass ?? this.selectedTravelClass,
      availableCategories: availableCategories ?? this.availableCategories,
      availableTravelClasses:
          availableTravelClasses ?? this.availableTravelClasses,
      isAirportMode: isAirportMode ?? this.isAirportMode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Provider for leaderboard state management
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  static const String _cacheKey = 'leaderboard_cache';
  static const String _cacheTimestampKey = 'leaderboard_cache_timestamp';
  static const String _stateKey = 'leaderboard_state';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  LeaderboardNotifier() : super(_loadInitialState()) {
    // Load cached data immediately
    _loadCachedData();
  }

  static LeaderboardState _loadInitialState() {
    return LeaderboardState(
      airlines: [],
      airports: [],
      issues: [],
      isLoading: false, // Start with false - will show cached data instantly
      selectedCategory:
          LeaderboardCategoryService.getDefaultCategory().tab,
      selectedTravelClass:
          LeaderboardCategoryService.getDefaultTravelClass().tab,
      availableCategories: LeaderboardCategoryService.getAllTabs(),
      availableTravelClasses:
          LeaderboardCategoryService.getTravelClassTabs(),
      isAirportMode: false,
      lastUpdated: null,
    );
  }

  /// Load cached data instantly (offline-first)
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load cached airlines
      final cachedAirlinesJson = prefs.getString('${_cacheKey}_airlines');
      final cachedCategory = prefs.getString('${_stateKey}_category') ?? 
          LeaderboardCategoryService.getDefaultCategory().tab;
      final cachedTravelClass = prefs.getString('${_stateKey}_travelClass') ?? 
          LeaderboardCategoryService.getDefaultTravelClass().tab;
      final cacheTimestamp = prefs.getInt('${_cacheTimestampKey}_airlines');
      
      if (cachedAirlinesJson != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cacheTimestamp)
        );
        
        // Use cache if it's still valid
        if (cacheAge < _cacheValidDuration) {
          final cachedAirlines = (json.decode(cachedAirlinesJson) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          
          debugPrint('✅ Loaded ${cachedAirlines.length} airlines from cache (${cacheAge.inMinutes}m old)');
          
          state = state.copyWith(
            airlines: cachedAirlines,
            selectedCategory: cachedCategory,
            selectedTravelClass: cachedTravelClass,
            isLoading: false,
            lastUpdated: DateTime.fromMillisecondsSinceEpoch(cacheTimestamp),
          );
          
          // Update in background (non-blocking)
          _refreshInBackground();
          return;
        }
      }
      
      // No valid cache, load from local seed data instantly
      _loadFromLocalSeed();
      
      // Then refresh in background
      _refreshInBackground();
    } catch (e) {
      debugPrint('⚠️ Error loading cache: $e');
      // Fallback to local seed data
      _loadFromLocalSeed();
    }
  }

  /// Load from local seed data instantly (offline)
  void _loadFromLocalSeed() {
    try {
      final category = state.selectedCategory;
      final localData = SupabaseLeaderboardService.getCategoryRankings(
        category,
        travelClass: state.selectedTravelClass,
      );
      
      localData.then((airlines) {
        if (airlines.isNotEmpty && mounted) {
          final formattedAirlines = airlines.asMap().entries.map((entry) {
            final index = entry.key;
            final airlineData = entry.value;
            final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
            return SupabaseLeaderboardService.formatAirlineData(
              airlineData,
              rank,
              null,
            );
          }).toList();
          
          debugPrint('✅ Loaded ${formattedAirlines.length} airlines from local seed');
          
          state = state.copyWith(
            airlines: formattedAirlines,
            isLoading: false,
            lastUpdated: DateTime.now(),
          );
          
          // Cache the data
          _saveToCache(formattedAirlines);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error loading from local seed: $e');
    }
  }

  /// Refresh data in background (non-blocking)
  Future<void> _refreshInBackground() async {
    try {
      await loadLeaderboard();
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
      // Don't update state on error - keep cached data
    }
  }

  /// Save data to cache
  Future<void> _saveToCache(List<Map<String, dynamic>> airlines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_cacheKey}_airlines',
        json.encode(airlines),
      );
      await prefs.setInt(
        '${_cacheTimestampKey}_airlines',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString('${_stateKey}_category', state.selectedCategory);
      await prefs.setString('${_stateKey}_travelClass', state.selectedTravelClass);
    } catch (e) {
      debugPrint('⚠️ Error saving cache: $e');
    }
  }

  bool get mounted => true; // Always mounted for StateNotifier

  /// Load initial leaderboard data (background refresh)
  Future<void> loadLeaderboard() async {
    try {
      // Don't set loading to true if we already have cached data
      final hasData = state.airlines.isNotEmpty;
      if (!hasData) {
        state = state.copyWith(isLoading: true, error: null);
      }

      debugPrint('🔄 Refreshing leaderboard data...');

      // Load airlines (skip issues for faster loading)
      final airlines = await SupabaseLeaderboardService.getCategoryRankings(
        state.selectedCategory,
        travelClass: state.selectedTravelClass,
      );

      // Format airline data with rankings
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null,
        );
      }).toList();

      // Save to cache
      await _saveToCache(formattedAirlines);

      state = state.copyWith(
        airlines: formattedAirlines,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      debugPrint('✅ Leaderboard data refreshed successfully');
      
      // Load issues in background (non-blocking)
      _loadIssuesInBackground();
    } catch (e) {
      debugPrint('❌ Error loading leaderboard: $e');
      // Don't update state on error - keep existing data
      if (!state.airlines.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Load issues in background (non-blocking)
  Future<void> _loadIssuesInBackground() async {
    try {
      await RealtimeFeedbackService.initialize();
      final issues = await RealtimeFeedbackService.getCombinedFeedbackStream().first;
      final formattedIssues = _formatIssuesData(issues);
      
      if (mounted) {
        state = state.copyWith(issues: formattedIssues);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading issues: $e');
      // Don't update state - issues are optional
    }
  }

  /// Change selected category
  Future<void> changeCategory(String category) async {
    if (category == state.selectedCategory) return;

    // Handle airport vs airline mode
    if (state.isAirportMode) {
      await changeAirportCategory(category);
      return;
    }

    // Load from local seed instantly
    final localData = await SupabaseLeaderboardService.getCategoryRankings(
      category,
      travelClass: state.selectedTravelClass,
    );

    if (localData.isNotEmpty) {
      final formattedAirlines = localData.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null,
        );
      }).toList();

      state = state.copyWith(
        selectedCategory: category,
        airlines: formattedAirlines,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      await _saveToCache(formattedAirlines);
      debugPrint('✅ Loaded ${formattedAirlines.length} airlines for $category (instant)');
    }

    // Refresh in background
    try {
      final airlines = await SupabaseLeaderboardService.getCategoryRankings(
        category,
        travelClass: state.selectedTravelClass,
      );

      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null,
        );
      }).toList();

      state = state.copyWith(
        airlines: formattedAirlines,
        lastUpdated: DateTime.now(),
      );

      await _saveToCache(formattedAirlines);
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
    }
  }

  /// Change selected travel class filter
  Future<void> changeTravelClass(String travelClass) async {
    if (travelClass == state.selectedTravelClass) return;

    // Load from local seed instantly
    final localData = await SupabaseLeaderboardService.getCategoryRankings(
      state.selectedCategory,
      travelClass: travelClass,
    );

    if (localData.isNotEmpty) {
      final formattedAirlines = localData.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null,
        );
      }).toList();

      state = state.copyWith(
        selectedTravelClass: travelClass,
        airlines: formattedAirlines,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      await _saveToCache(formattedAirlines);
      debugPrint('✅ Loaded ${formattedAirlines.length} airlines for $travelClass (instant)');
    }

    // Refresh in background
    try {
      final airlines = await SupabaseLeaderboardService.getCategoryRankings(
        state.selectedCategory,
        travelClass: travelClass,
      );

      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null,
        );
      }).toList();

      state = state.copyWith(
        airlines: formattedAirlines,
        lastUpdated: DateTime.now(),
      );

      await _saveToCache(formattedAirlines);
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
    }
  }

  /// Format issues data for display from combined feedback (airport_reviews, airline_reviews, feedback)
  List<Map<String, dynamic>> _formatIssuesData(
      List<Map<String, dynamic>> feedbackData) {
    if (feedbackData.isEmpty) {
      // Return empty list - no sample/fake data
      return [];
    }

    return feedbackData.map((feedback) {
      // Extract data from the new combined feedback structure
      final flightNumber = feedback['flight'] as String? ?? '';
      final passengerName = feedback['passenger'] as String? ?? 'Anonymous';
      final seatNumber = feedback['seat'] as String?; // Can be null
      final phase = feedback['phase'] as String? ?? 'Unknown';
      final phaseColor = feedback['phaseColor'] as Color? ?? Colors.grey;
      final airlineName = feedback['airlineName'] as String? ??
          feedback['airline'] as String? ??
          'Unknown Airline';
      final logo =
          feedback['logo'] as String? ?? 'assets/images/airline_logo.png';
      final likes = feedback['likes'] as List<Map<String, dynamic>>? ?? [];
      final dislikes =
          feedback['dislikes'] as List<Map<String, dynamic>>? ?? [];
      final timestamp = feedback['timestamp'] as DateTime? ?? DateTime.now();
      final feedbackType = feedback['feedback_type'] as String? ?? 'overall';
      final journeyId = feedback['journey_id'] as String?; // Include journey_id

      return {
        'issue': 'Feedback Report',
        'icon': Icons.feedback,
        'flight': flightNumber,
        'phase': phase,
        'phaseColor': phaseColor,
        'reportCount': 1,
        'timestamp': timestamp,
        'airline': airlineName,
        'logo': logo,
        'likes': likes, // Real data only, no fallback
        'dislikes': dislikes, // Real data only, no fallback
        'passenger': passengerName,
        'seat': seatNumber, // Preserve null if not found
        'journey_id': journeyId, // Include journey_id for potential future use
        'feedback_type': feedbackType, // Store the type for reference
        'overall_rating': feedback['overall_rating'], // Include score/rating
        'score_value': feedback['score_value'], // For scores if available
      };
    }).toList();
  }

  /// Format phase name for display
  String _formatPhaseName(String stage) {
    switch (stage.toLowerCase()) {
      case 'pre-flight':
      case 'boarding':
        return 'Boarding';
      case 'in-flight':
      case 'during flight':
        return 'In-flight';
      case 'post-flight':
      case 'arrival':
        return 'Arrival';
      default:
        return 'Unknown';
    }
  }

  /// Format selection text for display
  String _formatSelectionText(String key) {
    switch (key.toLowerCase()) {
      case 'food':
        return 'Good meals';
      case 'entertainment':
        return 'Good entertainment';
      case 'boarding':
        return 'Smooth boarding';
      case 'wifi':
        return 'Good Wi-Fi';
      case 'baggage':
        return 'Quick baggage';
      case 'comfort':
        return 'Comfortable seats';
      case 'crew':
        return 'Crew helpful';
      case 'cleanliness':
        return 'Clean cabin';
      case 'delay':
        return 'On-time departure';
      case 'service':
        return 'Great service';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
    }
  }

  /// Switch to airport mode and load airport leaderboard
  Future<void> switchToAirportMode({String? category}) async {
    final targetCategory = category ?? 
        LeaderboardCategoryService.getAirportCategories().first.tab;
    
    state = state.copyWith(
      isAirportMode: true,
      selectedCategory: targetCategory,
      availableCategories: LeaderboardCategoryService.getAirportTabs(),
      isLoading: true,
    );

    await loadAirportLeaderboard();
  }

  /// Switch to airline mode and load airline leaderboard
  Future<void> switchToAirlineMode({String? category}) async {
    final targetCategory = category ?? 
        LeaderboardCategoryService.getDefaultCategory().tab;
    
    state = state.copyWith(
      isAirportMode: false,
      selectedCategory: targetCategory,
      availableCategories: LeaderboardCategoryService.getAllTabs(),
      isLoading: true,
    );

    await loadLeaderboard();
  }

  /// Load airport leaderboard data
  Future<void> loadAirportLeaderboard() async {
    try {
      final hasData = state.airports.isNotEmpty;
      if (!hasData) {
        state = state.copyWith(isLoading: true, error: null);
      }

      debugPrint('🔄 Refreshing airport leaderboard data for category: ${state.selectedCategory}');

      // Load airports
      final airports = await AirportLeaderboardService.getCategoryRankings(
        state.selectedCategory,
      );

      state = state.copyWith(
        airports: airports,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      debugPrint('✅ Airport leaderboard data refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error loading airport leaderboard: $e');
      if (!state.airports.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Change airport category
  Future<void> changeAirportCategory(String category) async {
    if (category == state.selectedCategory) return;

    state = state.copyWith(
      selectedCategory: category,
      isLoading: true,
    );

    await loadAirportLeaderboard();
  }

  /// Refresh data
  Future<void> refresh() async {
    if (state.isAirportMode) {
      await loadAirportLeaderboard();
    } else {
      await loadLeaderboard();
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for leaderboard state
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier();
});

/// Provider for real-time leaderboard stream
final leaderboardStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final selectedCategory = ref.watch(leaderboardProvider).selectedCategory;
  final selectedTravelClass =
      ref.watch(leaderboardProvider).selectedTravelClass;

  return SupabaseLeaderboardService.subscribeToLeaderboardUpdates(
    category: selectedCategory,
    travelClass: selectedTravelClass,
  ).map((data) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final airlineData = entry.value;
      return SupabaseLeaderboardService.formatAirlineData(
        airlineData,
        index + 1,
        null, // Real-time updates don't calculate movement
      );
    }).toList();
  });
});

/// Provider for real-time issues stream
final issuesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseLeaderboardService.subscribeToIssues().map((issues) {
    final notifier = ref.read(leaderboardProvider.notifier);
    return notifier._formatIssuesData(issues);
  });
});
