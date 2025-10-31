import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stage_feedback_model.dart';

/// Provider to store stage feedback as the flight progresses
class StageFeedbackNotifier extends StateNotifier<Map<String, StageFeedback>> {
  StageFeedbackNotifier() : super({});

  /// Add or update stage feedback for a specific flight
  void addFeedback(String flightId, StageFeedback feedback) {
    state = {
      ...state,
      '${flightId}_${feedback.stage.toString()}': feedback,
    };
  }

  /// Get all feedback for a specific flight
  List<StageFeedback> getFeedbackForFlight(String flightId) {
    return state.entries
        .where((entry) => entry.key.startsWith(flightId))
        .map((entry) => entry.value)
        .toList();
  }

  /// Check if flight has any feedback
  bool hasFeedback(String flightId) {
    return state.keys.any((key) => key.startsWith(flightId));
  }

  /// Clear feedback for a specific flight (after submission)
  void clearFlightFeedback(String flightId) {
    state = Map.fromEntries(
      state.entries.where((entry) => !entry.key.startsWith(flightId)),
    );
  }

  /// Clear all feedback
  void clearAll() {
    state = {};
  }
}

final stageFeedbackProvider =
    StateNotifierProvider<StageFeedbackNotifier, Map<String, StageFeedback>>(
        (ref) {
  return StageFeedbackNotifier();
});
