import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedButtonNotifier extends StateNotifier<int?> {
  SelectedButtonNotifier() : super(null);

  void selectButton(int index) {
    state = index;
  }
}

final selectedButtonProvider =
    StateNotifierProvider<SelectedButtonNotifier, int?>((ref) {
  return SelectedButtonNotifier();
});
