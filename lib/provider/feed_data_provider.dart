import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedDataState {
  final List<Map<String, dynamic>> allData;
  final bool hasMore;
  final int currentPage;

  const FeedDataState({
    this.allData = const [],
    this.hasMore = true,
    this.currentPage = 1,
  });
}

class FeedDataNotifier extends StateNotifier<FeedDataState> {
  FeedDataNotifier() : super(const FeedDataState());

  void setData(Map<String, dynamic> value) {
    state = FeedDataState(
      allData: List<Map<String, dynamic>>.from(value["data"] as List),
      hasMore: value["hasMore"],
      currentPage: value["currentPage"],
    );
  }

  void appendData(Map<String, dynamic> value) {
    final newData = List<Map<String, dynamic>>.from(value["data"] as List);
    state = FeedDataState(
      allData: [...state.allData, ...newData],
      hasMore: value["hasMore"],
      currentPage: value["currentPage"],
    );
  }
}

final feedDataProvider =
    StateNotifierProvider<FeedDataNotifier, FeedDataState>((ref) {
  return FeedDataNotifier();
});
