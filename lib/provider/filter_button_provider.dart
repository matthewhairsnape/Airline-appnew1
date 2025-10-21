import 'package:flutter_riverpod/flutter_riverpod.dart';

final filterButtonProvider =
    StateNotifierProvider<FilterButtonNotifier, String>((ref) {
  return FilterButtonNotifier();
});

class FilterButtonNotifier extends StateNotifier<String> {
  FilterButtonNotifier() : super('Airline'); // Default value is 'All'

  void setFilterType(String buttonText) {
    state = buttonText;
  }
}
