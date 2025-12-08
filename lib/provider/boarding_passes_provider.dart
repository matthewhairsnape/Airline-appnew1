import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/boarding_pass.dart';

final boardingPassesProvider =
    StateNotifierProvider<BoardingPassesNotifier, List<BoardingPass>>((ref) {
  return BoardingPassesNotifier();
});

class BoardingPassesNotifier extends StateNotifier<List<BoardingPass>> {
  BoardingPassesNotifier() : super([]);

  void setData(List<BoardingPass> boardingPasses) {
    state = boardingPasses;
  }

  BoardingPass markFlightAsReviewed(int index) {
    final updatedPass = state[index].copyWith(isReviewed: true);
    state = [
      ...state.sublist(0, index),
      updatedPass,
      ...state.sublist(index + 1)
    ];
    return updatedPass;
  }

  bool hasFlightNumber(String flightNumber) {
    return state.any((pass) => pass.flightNumber == flightNumber);
  }
}
