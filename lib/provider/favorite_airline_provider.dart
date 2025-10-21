import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteAirlineInfoProviderNotifier
    extends StateNotifier<Map<String, dynamic>?> {
  FavoriteAirlineInfoProviderNotifier() : super(null);

  void setUserData(Map<String, dynamic> data) {
    state = data;
  }

  void clearUserData() {
    state = null;
  }
}

final favoriteAirlineInfoProvider = StateNotifierProvider<
    FavoriteAirlineInfoProviderNotifier, Map<String, dynamic>?>((ref) {
  return FavoriteAirlineInfoProviderNotifier();
});
