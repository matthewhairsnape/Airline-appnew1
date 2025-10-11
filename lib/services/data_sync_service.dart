import 'package:airline_app/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DataSyncService {
  static const String _userDataKey = 'userData';
  static const String _lastSyncKey = 'lastSyncTime';

  /// Sync all user data to Supabase
  static Future<bool> syncUserDataToSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString == null) {
        print('⚠️ No user data found in SharedPreferences');
        return false;
      }

      final userData = json.decode(userDataString);
      final userId = userData['id'];

      if (userId == null) {
        print('⚠️ No user ID found in user data');
        return false;
      }

      // Save to Supabase
      final success = await SupabaseService.saveUserDataToSupabase(userData);

      if (success) {
        // Update last sync time
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        print('✅ User data synced to Supabase successfully');
      }

      return success;
    } catch (e) {
      print('❌ Error syncing user data to Supabase: $e');
      return false;
    }
  }

  /// Sync user data from Supabase to local storage
  static Future<bool> syncUserDataFromSupabase(String userId) async {
    try {
      final userData = await SupabaseService.syncUserDataFromSupabase(userId);
      
      if (userData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userDataKey, json.encode(userData));
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        print('✅ User data synced from Supabase successfully');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error syncing user data from Supabase: $e');
      return false;
    }
  }

  /// Check if data needs syncing (if last sync was more than 1 hour ago)
  static Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey);
      
      if (lastSync == null) return true;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHour = 60 * 60 * 1000; // 1 hour in milliseconds
      
      return (now - lastSync) > oneHour;
    } catch (e) {
      print('❌ Error checking sync status: $e');
      return true; // Default to needing sync if there's an error
    }
  }

  /// Force sync all data
  static Future<bool> forceSyncAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString == null) {
        print('⚠️ No user data to sync');
        return false;
      }

      final userData = json.decode(userDataString);
      final userId = userData['id'];

      if (userId == null) {
        print('⚠️ No user ID found');
        return false;
      }

      // Sync to Supabase
      final syncToSupabase = await syncUserDataToSupabase();
      
      // Also sync from Supabase to ensure we have the latest data
      final syncFromSupabase = await syncUserDataFromSupabase(userId);
      
      return syncToSupabase || syncFromSupabase;
    } catch (e) {
      print('❌ Error in force sync: $e');
      return false;
    }
  }

  /// Save user data both locally and to Supabase
  static Future<bool> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save locally first
      await prefs.setString(_userDataKey, json.encode(userData));
      
      // Then save to Supabase
      final userId = userData['id'];
      if (userId != null) {
            final success = await SupabaseService.saveUserDataToSupabase(userData);
        
        if (success) {
          await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        }
        
        return success;
      }
      
      return false;
    } catch (e) {
      print('❌ Error saving user data: $e');
      return false;
    }
  }

  /// Get user data with automatic sync
  static Future<Map<String, dynamic>?> getUserDataWithSync(String userId) async {
    try {
      // Check if we need to sync
      if (await needsSync()) {
        print('🔄 Data needs sync, syncing from Supabase...');
        await syncUserDataFromSupabase(userId);
      }

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString != null) {
        return json.decode(userDataString);
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting user data with sync: $e');
      return null;
    }
  }
}

