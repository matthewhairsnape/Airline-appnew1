import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/services/supabase_leaderboard_service.dart';
import 'package:airline_app/services/realtime_feedback_service.dart';
import 'package:airline_app/models/leaderboard_category_model.dart';

/// State for leaderboard data
class LeaderboardState {
  final List<Map<String, dynamic>> airlines;
  final List<Map<String, dynamic>> issues;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final String selectedTravelClass;
  final List<String> availableCategories;
  final List<String> availableTravelClasses;
  final DateTime? lastUpdated;

  const LeaderboardState({
    required this.airlines,
    required this.issues,
    required this.isLoading,
    this.error,
    required this.selectedCategory,
    required this.selectedTravelClass,
    required this.availableCategories,
    required this.availableTravelClasses,
    this.lastUpdated,
  });

  LeaderboardState copyWith({
    List<Map<String, dynamic>>? airlines,
    List<Map<String, dynamic>>? issues,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? selectedTravelClass,
    List<String>? availableCategories,
    List<String>? availableTravelClasses,
    DateTime? lastUpdated,
  }) {
    return LeaderboardState(
      airlines: airlines ?? this.airlines,
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedTravelClass: selectedTravelClass ?? this.selectedTravelClass,
      availableCategories: availableCategories ?? this.availableCategories,
      availableTravelClasses:
          availableTravelClasses ?? this.availableTravelClasses,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Provider for leaderboard state management
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier()
      : super(
          LeaderboardState(
            airlines: [],
            issues: [],
            isLoading: true,
            selectedCategory:
                LeaderboardCategoryService.getDefaultCategory().tab,
            selectedTravelClass:
                LeaderboardCategoryService.getDefaultTravelClass().tab,
            availableCategories: LeaderboardCategoryService.getAllTabs(),
            availableTravelClasses:
                LeaderboardCategoryService.getTravelClassTabs(),
            lastUpdated: null,
          ),
        );

  /// Load initial leaderboard data
  Future<void> loadLeaderboard() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      debugPrint('🔄 Loading leaderboard data...');

      // Initialize realtime feedback service
      await RealtimeFeedbackService.initialize();

      // Load airlines and issues in parallel
      final results = await Future.wait([
        SupabaseLeaderboardService.getCategoryRankings(
          state
              .selectedCategory, // Pass category directly (now uses leaderboard_rankings table)
          travelClass: state.selectedTravelClass,
        ),
        RealtimeFeedbackService.getCombinedFeedbackStream()
            .first, // NEW: Use combined feedback
      ]);

      final airlines = results[0] as List<Map<String, dynamic>>;
      final issues = results[1] as List<Map<String, dynamic>>;

      // Format airline data with rankings
      // Use leaderboard_rank from database if available, otherwise use index
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null, // No movement calculation for initial load
        );
      }).toList();

      // Format issues data from combined feedback
      final formattedIssues = _formatIssuesData(issues);

      state = state.copyWith(
        airlines: formattedAirlines,
        issues: formattedIssues,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      debugPrint('✅ Leaderboard data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading leaderboard: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Change selected category
  Future<void> changeCategory(String category) async {
    if (category == state.selectedCategory) return;

    try {
      state = state.copyWith(
        selectedCategory: category,
        isLoading: true,
        error: null,
      );

      debugPrint('🔄 Loading $category rankings...');

      final airlines = await SupabaseLeaderboardService.getCategoryRankings(
        category, // Pass category directly (now uses leaderboard_rankings table)
        travelClass: state.selectedTravelClass,
      );

      // Format airline data with rankings
      // Use leaderboard_rank from database if available, otherwise use index
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null, // No movement calculation for category change
        );
      }).toList();
      debugPrint(
          '✅ Loaded ${formattedAirlines.length} airlines for $category (${state.selectedTravelClass})');

      state = state.copyWith(
        airlines: formattedAirlines,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      debugPrint('✅ $category rankings loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading $category rankings: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Change selected travel class filter
  Future<void> changeTravelClass(String travelClass) async {
    if (travelClass == state.selectedTravelClass) return;

    try {
      state = state.copyWith(
        selectedTravelClass: travelClass,
        isLoading: true,
        error: null,
      );

      debugPrint(
          '🔄 Loading ${state.selectedCategory} rankings for $travelClass...');

      final airlines = await SupabaseLeaderboardService.getCategoryRankings(
        state.selectedCategory,
        travelClass: travelClass,
      );

      // Format airline data with rankings
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        final rank = airlineData['leaderboard_rank'] as int? ?? (index + 1);
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          rank,
          null, // No movement calculation for travel class change
        );
      }).toList();

      state = state.copyWith(
        airlines: formattedAirlines,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      debugPrint(
          '✅ ${state.selectedCategory} rankings loaded for $travelClass');
    } catch (e) {
      debugPrint('❌ Error loading rankings for $travelClass: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
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

  /// Refresh data
  Future<void> refresh() async {
    await loadLeaderboard();
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
