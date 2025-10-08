import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserDataNotifier extends StateNotifier<Map<String, dynamic>?> {
  UserDataNotifier() : super(null);

  void setUserData(Map<String, dynamic> data) {
    state = data;
  }

  void clearUserData() {
    state = null;
  }
}

final userDataProvider =
    StateNotifierProvider<UserDataNotifier, Map<String, dynamic>?>((ref) {
  return UserDataNotifier();
});
