import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardFilterState {
  final String airType;
  final String? flyerClass;
  final String? category;
  String? searchQuery;
  final List<String> continents;
  final int currentPage; // Add currentPage to state

  LeaderboardFilterState({
    required this.airType,
    this.flyerClass,
    this.category,
    this.searchQuery,
    required this.continents,
    this.currentPage = 1, // Default to page 1
  });
}

class LeaderboardFilterNotifier extends StateNotifier<LeaderboardFilterState> {
  LeaderboardFilterNotifier()
      : super(LeaderboardFilterState(
            airType: 'All',
            continents: ["Africa", "Asia", "Europe", "Americas", "Oceania"]));

  void setFilters({
    required String airType,
    String? flyerClass,
    String? category,
    String? searchQuery,
    required List<String> continents,
  }) {
    state = LeaderboardFilterState(
      airType: airType,
      flyerClass: flyerClass,
      category: category,
      searchQuery: searchQuery,
      continents: continents,
    );
  }

  void incrementPage() {
    state = LeaderboardFilterState(
      airType: state.airType,
      flyerClass: state.flyerClass,
      category: state.category,
      searchQuery: state.searchQuery,
      continents: state.continents,
      currentPage: state.currentPage + 1, // Increment page number
    );
  }
}

final leaderboardFilterProvider =
    StateNotifierProvider<LeaderboardFilterNotifier, LeaderboardFilterState>(
        (ref) {
  return LeaderboardFilterNotifier();
});
