import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedFilterState {
  final String airType;
  final String? flyerClass;
  final String? category;
  final List<String> continents;
  final int currentPage;

  FeedFilterState({
    required this.airType,
    this.flyerClass,
    this.category,
    required this.continents,
    this.currentPage = 1,
  });
}

class FeedFilterNotifier extends StateNotifier<FeedFilterState> {
  FeedFilterNotifier()
      : super(FeedFilterState(
            airType: 'Airline',
            flyerClass: 'All',
            continents: ["Africa", "Asia", "Europe", "Americas", "Oceania"]));

  void setFilters({
    required String airType,
    String? flyerClass,
    String? category,
    required List<String> continents,
  }) {
    state = FeedFilterState(
      airType: airType,
      flyerClass: flyerClass,
      category: category,
      continents: continents,
      currentPage: 1,
    );
  }

  void incrementPage() {
    state = FeedFilterState(
      airType: state.airType,
      flyerClass: state.flyerClass,
      category: state.category,
      continents: state.continents,
      currentPage: state.currentPage + 1,
    );
  }
}

final feedFilterProvider =
    StateNotifierProvider<FeedFilterNotifier, FeedFilterState>((ref) {
  return FeedFilterNotifier();
});
