import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedFilterButtonProvider =
    StateNotifierProvider<FeedFilterButtonNotifier, String>((ref) {
  return FeedFilterButtonNotifier();
});

class FeedFilterButtonNotifier extends StateNotifier<String> {
  FeedFilterButtonNotifier() : super('Airline'); // Default value is 'Airline'

  void setFilterType(String buttonText) {
    state = buttonText;
  }
}
