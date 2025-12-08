import 'package:flutter_riverpod/flutter_riverpod.dart';

final reviewFilterButtonProvider =
    StateNotifierProvider<ReviewFilterButtonNotifier, String>((ref) {
  return ReviewFilterButtonNotifier();
});

class ReviewFilterButtonNotifier extends StateNotifier<String> {
  ReviewFilterButtonNotifier() : super('Airline'); // Default value is 'All'

  void setFilterType(String buttonText) {
    state = buttonText;
  }
}
