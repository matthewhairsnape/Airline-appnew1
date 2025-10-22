import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/services/data_sync_service.dart';

class UserDataNotifier extends StateNotifier<Map<String, dynamic>?> {
  UserDataNotifier() : super(null);

  void setUserData(Map<String, dynamic> data) {
    state = data;
    // Automatically save to Supabase when user data is updated
    _saveToSupabase(data);
  }

  void clearUserData() {
    state = null;
  }

  Future<void> _saveToSupabase(Map<String, dynamic> userData) async {
    // Use DataSyncService for comprehensive data saving
    await DataSyncService.saveUserData(userData);
  }

  Future<void> updateUserData(Map<String, dynamic> updates) async {
    if (state != null) {
      final updatedData = Map<String, dynamic>.from(state!);
      updatedData.addAll(updates);
      updatedData['updated_at'] = DateTime.now().toIso8601String();

      setUserData(updatedData);
    }
  }

  Future<void> syncFromSupabase(String userId) async {
    final success = await DataSyncService.syncUserDataFromSupabase(userId);
    if (success) {
      // Data has been synced to local storage, now get it
      final userData = await SupabaseService.getUserProfile(userId);
      if (userData != null) {
        setUserData(userData);
      }
    }
  }

  Future<void> forceSync(String userId) async {
    await DataSyncService.forceSyncAll();
    await syncFromSupabase(userId);
  }
}

final userDataProvider =
    StateNotifierProvider<UserDataNotifier, Map<String, dynamic>?>((ref) {
  return UserDataNotifier();
});
