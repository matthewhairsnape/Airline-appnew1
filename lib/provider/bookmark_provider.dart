import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookmarkDataNotifier extends StateNotifier<List<dynamic>> {
  BookmarkDataNotifier() : super([]);

  void setBookmarkData(List<dynamic> data) {
    state = data;
  }
}

final bookmarkDataProvider =
    StateNotifierProvider<BookmarkDataNotifier, List<dynamic>>((ref) {
  return BookmarkDataNotifier();
});
