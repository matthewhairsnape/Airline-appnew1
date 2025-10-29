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
  final List<String> availableCategories;

  const LeaderboardState({
    required this.airlines,
    required this.issues,
    required this.isLoading,
    this.error,
    required this.selectedCategory,
    required this.availableCategories,
  });

  LeaderboardState copyWith({
    List<Map<String, dynamic>>? airlines,
    List<Map<String, dynamic>>? issues,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    List<String>? availableCategories,
  }) {
    return LeaderboardState(
      airlines: airlines ?? this.airlines,
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      availableCategories: availableCategories ?? this.availableCategories,
    );
  }
}

/// Provider for leaderboard state management
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier()
      : super(LeaderboardState(
          airlines: [],
          issues: [],
          isLoading: true,
          selectedCategory:
              LeaderboardCategoryService.getAllCategories().first.tab,
          availableCategories: LeaderboardCategoryService.getAllTabs(),
        ));

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
          SupabaseLeaderboardService.mapCategoryToScoreType(
              state.selectedCategory),
        ),
        RealtimeFeedbackService.getCombinedFeedbackStream().first, // NEW: Use combined feedback
      ]);

      final airlines = results[0] as List<Map<String, dynamic>>;
      final issues = results[1] as List<Map<String, dynamic>>;

      // Format airline data with rankings
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          index + 1,
          null, // No movement calculation for initial load
        );
      }).toList();

      // Format issues data from combined feedback
      final formattedIssues = _formatIssuesData(issues);

      state = state.copyWith(
        airlines: formattedAirlines,
        issues: formattedIssues,
        isLoading: false,
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
        SupabaseLeaderboardService.mapCategoryToScoreType(category),
      );

      // Format airline data with rankings
      final formattedAirlines = airlines.asMap().entries.map((entry) {
        final index = entry.key;
        final airlineData = entry.value;
        return SupabaseLeaderboardService.formatAirlineData(
          airlineData,
          index + 1,
          null, // No movement calculation for category change
        );
      }).toList();

      state = state.copyWith(
        airlines: formattedAirlines,
        isLoading: false,
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

  /// Format issues data for display from combined feedback (airport_reviews, leaderboard_scores, feedback)
  List<Map<String, dynamic>> _formatIssuesData(
      List<Map<String, dynamic>> feedbackData) {
    if (feedbackData.isEmpty) {
      // Return sample data for demonstration
      return _getSampleIssuesData();
    }

    return feedbackData.map((feedback) {
      // Extract data from the new combined feedback structure
      final flightNumber = feedback['flight'] as String? ?? 'Unknown';
      final passengerName = feedback['passenger'] as String? ?? 'Anonymous';
      final seatNumber = feedback['seat'] as String? ?? 'N/A';
      final phase = feedback['phase'] as String? ?? 'Unknown';
      final phaseColor = feedback['phaseColor'] as Color? ?? Colors.grey;
      final airlineName = feedback['airlineName'] as String? ?? feedback['airline'] as String? ?? 'Unknown Airline';
      final logo = feedback['logo'] as String? ?? 'assets/images/airline_logo.png';
      final likes = feedback['likes'] as List<Map<String, dynamic>>? ?? [];
      final dislikes = feedback['dislikes'] as List<Map<String, dynamic>>? ?? [];
      final timestamp = feedback['timestamp'] as DateTime? ?? DateTime.now();
      final feedbackType = feedback['feedback_type'] as String? ?? 'overall';

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
        'likes': likes.isNotEmpty ? likes : _generateSampleLikes(passengerName, flightNumber),
        'dislikes': dislikes.isNotEmpty ? dislikes : _generateSampleDislikes(passengerName, flightNumber),
        'passenger': passengerName,
        'seat': seatNumber,
        'feedback_type': feedbackType, // Store the type for reference
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

  /// Get sample issues data for demonstration
  List<Map<String, dynamic>> _getSampleIssuesData() {
    return [
      {
        'issue': 'Feedback Report',
        'icon': Icons.feedback,
        'flight': 'BA213',
        'phase': 'In-flight',
        'phaseColor': const Color(0xFF4A90E2),
        'reportCount': 1,
        'timestamp': DateTime.now(),
        'airline': 'British Airways',
        'logo': 'https://logo.clearbit.com/britishairways.com',
        'likes': [
          {'text': 'Comfortable seats', 'count': 12},
          {'text': 'Good entertainment', 'count': 5},
        ],
        'dislikes': [
          {'text': 'Cold meals', 'count': 8},
          {'text': 'Delayed boarding', 'count': 3},
        ],
        'passenger': 'John Smith',
        'seat': '12A',
      },
      {
        'issue': 'Feedback Report',
        'icon': Icons.feedback,
        'flight': 'EK215',
        'phase': 'Boarding',
        'phaseColor': const Color(0xFFF5A623),
        'reportCount': 1,
        'timestamp': DateTime.now(),
        'airline': 'Emirates',
        'logo': 'https://logo.clearbit.com/emirates.com',
        'likes': [
          {'text': 'Crew helpful', 'count': 15},
          {'text': 'Good Wi-Fi', 'count': 7},
        ],
        'dislikes': [
          {'text': 'Long wait', 'count': 4},
        ],
        'passenger': 'Sarah Johnson',
        'seat': '8C',
      },
    ];
  }

  /// Generate sample likes based on passenger and flight
  List<Map<String, dynamic>> _generateSampleLikes(
      String passenger, String flight) {
    final sampleLikes = [
      {'text': 'Comfortable seats', 'count': 12},
      {'text': 'Good entertainment', 'count': 5},
      {'text': 'Crew helpful', 'count': 8},
      {'text': 'Good Wi-Fi', 'count': 6},
      {'text': 'Smooth boarding', 'count': 10},
    ];

    // Return 1-3 random likes
    final count = DateTime.now().millisecond % 3 + 1;
    sampleLikes.shuffle();
    return sampleLikes.take(count).toList();
  }

  /// Generate sample dislikes based on passenger and flight
  List<Map<String, dynamic>> _generateSampleDislikes(
      String passenger, String flight) {
    final sampleDislikes = [
      {'text': 'Cold meals', 'count': 8},
      {'text': 'Delayed boarding', 'count': 3},
      {'text': 'Long wait', 'count': 4},
      {'text': 'Noisy cabin', 'count': 2},
      {'text': 'Poor service', 'count': 1},
    ];

    // Return 0-2 random dislikes
    final count = DateTime.now().millisecond % 3;
    sampleDislikes.shuffle();
    return sampleDislikes.take(count).toList();
  }

  /// Get airline name from flight number
  String _getAirlineFromFlight(String flightNumber) {
    if (flightNumber.startsWith('BA')) return 'British Airways';
    if (flightNumber.startsWith('EK')) return 'Emirates';
    if (flightNumber.startsWith('SQ')) return 'Singapore Airlines';
    if (flightNumber.startsWith('QR')) return 'Qatar Airways';
    if (flightNumber.startsWith('LH')) return 'Lufthansa';
    if (flightNumber.startsWith('AF')) return 'Air France';
    if (flightNumber.startsWith('KL')) return 'KLM';
    if (flightNumber.startsWith('UA')) return 'United Airlines';
    if (flightNumber.startsWith('AA')) return 'American Airlines';
    if (flightNumber.startsWith('DL')) return 'Delta Air Lines';
    return 'Unknown Airline';
  }

  /// Get airline logo URL from flight number
  String? _getAirlineLogoFromFlight(String flightNumber) {
    if (flightNumber.startsWith('BA'))
      return 'https://logo.clearbit.com/britishairways.com';
    if (flightNumber.startsWith('EK'))
      return 'https://logo.clearbit.com/emirates.com';
    if (flightNumber.startsWith('SQ'))
      return 'https://logo.clearbit.com/singaporeair.com';
    if (flightNumber.startsWith('QR'))
      return 'https://logo.clearbit.com/qatarairways.com';
    if (flightNumber.startsWith('LH'))
      return 'https://logo.clearbit.com/lufthansa.com';
    if (flightNumber.startsWith('AF'))
      return 'https://logo.clearbit.com/airfrance.com';
    if (flightNumber.startsWith('KL'))
      return 'https://logo.clearbit.com/klm.com';
    if (flightNumber.startsWith('UA'))
      return 'https://logo.clearbit.com/united.com';
    if (flightNumber.startsWith('AA'))
      return 'https://logo.clearbit.com/aa.com';
    if (flightNumber.startsWith('DL'))
      return 'https://logo.clearbit.com/delta.com';
    if (flightNumber.startsWith('VS'))
      return 'https://logo.clearbit.com/virgin-atlantic.com';
    if (flightNumber.startsWith('NH'))
      return 'https://logo.clearbit.com/ana.co.jp';
    if (flightNumber.startsWith('TK'))
      return 'https://logo.clearbit.com/turkishairlines.com';
    if (flightNumber.startsWith('KE'))
      return 'https://logo.clearbit.com/koreanair.com';
    if (flightNumber.startsWith('JL'))
      return 'https://logo.clearbit.com/jal.co.jp';
    if (flightNumber.startsWith('EY'))
      return 'https://logo.clearbit.com/etihad.com';
    if (flightNumber.startsWith('QF'))
      return 'https://logo.clearbit.com/qantas.com';
    if (flightNumber.startsWith('BR'))
      return 'https://logo.clearbit.com/evaair.com';
    if (flightNumber.startsWith('UL'))
      return 'https://logo.clearbit.com/srilankan.com';
    if (flightNumber.startsWith('VN'))
      return 'https://logo.clearbit.com/vietnamairlines.com';
    if (flightNumber.startsWith('NZ'))
      return 'https://logo.clearbit.com/airnewzealand.com';
    if (flightNumber.startsWith('GA'))
      return 'https://logo.clearbit.com/garuda-indonesia.com';
    if (flightNumber.startsWith('TG'))
      return 'https://logo.clearbit.com/thaiairways.com';
    if (flightNumber.startsWith('AK'))
      return 'https://logo.clearbit.com/airasia.com';
    if (flightNumber.startsWith('WN'))
      return 'https://logo.clearbit.com/southwest.com';
    if (flightNumber.startsWith('B6'))
      return 'https://logo.clearbit.com/jetblue.com';
    if (flightNumber.startsWith('AS'))
      return 'https://logo.clearbit.com/alaskaair.com';
    if (flightNumber.startsWith('AC'))
      return 'https://logo.clearbit.com/aircanada.com';
    if (flightNumber.startsWith('HA'))
      return 'https://logo.clearbit.com/hawaiianairlines.com';
    if (flightNumber.startsWith('IB'))
      return 'https://logo.clearbit.com/iberia.com';
    if (flightNumber.startsWith('OS'))
      return 'https://logo.clearbit.com/austrian.com';
    if (flightNumber.startsWith('AY'))
      return 'https://logo.clearbit.com/finnair.com';
    if (flightNumber.startsWith('SK'))
      return 'https://logo.clearbit.com/flysas.com';
    if (flightNumber.startsWith('WS'))
      return 'https://logo.clearbit.com/westjet.com';
    if (flightNumber.startsWith('FR'))
      return 'https://logo.clearbit.com/ryanair.com';
    if (flightNumber.startsWith('6E'))
      return 'https://logo.clearbit.com/goindigo.in';
    if (flightNumber.startsWith('FZ'))
      return 'https://logo.clearbit.com/flydubai.com';
    if (flightNumber.startsWith('W6'))
      return 'https://logo.clearbit.com/wizzair.com';
    if (flightNumber.startsWith('G9'))
      return 'https://logo.clearbit.com/airarabia.com';
    if (flightNumber.startsWith('TR'))
      return 'https://logo.clearbit.com/flyscoot.com';
    if (flightNumber.startsWith('U2'))
      return 'https://logo.clearbit.com/easyjet.com';
    return null; // No logo available
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

  return SupabaseLeaderboardService.subscribeToLeaderboardUpdates(
    scoreType:
        SupabaseLeaderboardService.mapCategoryToScoreType(selectedCategory),
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
