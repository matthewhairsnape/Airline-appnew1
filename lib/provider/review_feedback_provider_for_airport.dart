import 'package:airline_app/utils/airport_list_json.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reviewFeedBackProviderForAirport = StateNotifierProvider<
    ReviewFeedBackForAirportNotifier, List<Map<String, dynamic>>>((ref) {
  return ReviewFeedBackForAirportNotifier();
});

class ReviewFeedBackForAirportNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  ReviewFeedBackForAirportNotifier()
      : super(mainCategoryAndSubcategoryForAirport
            .map((category) => {
                  ...category,
                  'subCategory': category['subCategory']
                      .map((key, value) => MapEntry(key, value))
                      .cast<String, bool?>()
                })
            .toList());

  void selectLike(int categoryIndex, String item) {
    if (state[categoryIndex]['subCategory'].containsKey(item)) {
      final currentValue = state[categoryIndex]['subCategory'][item];
      state[categoryIndex]['subCategory'][item] =
          _getNextStateOfLike(currentValue);
      state = [...state]; // Trigger state change
    }
  }

  bool? _getNextStateOfLike(bool? currentState) {
    if (currentState == null) {
      return true;
    } else if (currentState == true) {
      return null;
    } else {
      return null;
    }
  }

  void selectDislike(int categoryIndex, String item) {
    if (state[categoryIndex]['subCategory'].containsKey(item)) {
      final currentValue = state[categoryIndex]['subCategory'][item];
      state[categoryIndex]['subCategory'][item] =
          _getNextStateOfDislike(currentValue);
      state = [...state]; // Trigger state change
    }
  }

  bool? _getNextStateOfDislike(bool? currentState) {
    if (currentState == null) {
      return false;
    } else if (currentState == false) {
      return null;
    } else {
      return null;
    }
  }

  int selectedNumberOfSubcategoryForLike(int categoryIndex) {
    int selection = 0;
    for (var item in state[categoryIndex]['subCategory'].values) {
      if (item == true) {
        // Check for true
        selection++;
      }
    }
    return selection;
  }

  int selectedNumberOfSubcategoryForDislike(int categoryIndex) {
    int selection = 0;
    for (var item in state[categoryIndex]['subCategory'].values) {
      if (item == false) {
        // Check for true
        selection++;
      }
    }
    return selection;
  }

  (int, int) numberOfSelectedAspects() {
    int likeCount = 0;
    int dislikeCount = 0;

    // Iterate through each category in the state
    for (var category in state) {
      if (category['subCategory'].values.any((value) => value == true)) {
        likeCount++;
      }
      if (category['subCategory'].values.any((value) => value == false)) {
        dislikeCount++;
      }
    }

    return (likeCount, dislikeCount);
  }

  void resetState() {
    state = mainCategoryAndSubcategoryForAirport
        .map((category) => {
              ...category,
              'subCategory': category['subCategory']
                  .map((key, value) => MapEntry(key, value))
                  .cast<String, bool?>()
            })
        .toList();
  }
}
