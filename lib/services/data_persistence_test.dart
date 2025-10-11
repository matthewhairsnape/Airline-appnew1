import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/services/data_sync_service.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test class to verify data persistence to Supabase
class DataPersistenceTest {
  static Future<void> runTests() async {
    print('🧪 Starting Data Persistence Tests...\n');

    // Test 1: User Profile Creation
    await _testUserProfileCreation();

    // Test 2: User Data Saving
    await _testUserDataSaving();

    // Test 3: Data Synchronization
    await _testDataSynchronization();

    // Test 4: User Data Updates
    await _testUserDataUpdates();

    print('\n✅ All data persistence tests completed!');
  }

  static Future<void> _testUserProfileCreation() async {
    print('📝 Test 1: User Profile Creation');
    
    try {
      // Test data
      final testUserId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
      final testEmail = 'test@example.com';
      final testName = 'Test User';

      // Create user profile
      final result = await SupabaseService.createUserProfile(
        userId: testUserId,
        email: testEmail,
        fullName: testName,
      );

      if (result != null) {
        print('✅ User profile created successfully');
        print('   - User ID: ${result['id']}');
        print('   - Email: ${result['email']}');
        print('   - Display Name: ${result['display_name']}');
      } else {
        print('❌ Failed to create user profile');
      }
    } catch (e) {
      print('❌ Error in user profile creation test: $e');
    }
    print('');
  }

  static Future<void> _testUserDataSaving() async {
    print('💾 Test 2: User Data Saving');
    
    try {
      final testUserId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
      final testData = {
        'id': testUserId,
        'email': 'test@example.com',
        'display_name': 'Test User',
        'phone': '+1234567890',
        'avatar_url': 'https://example.com/avatar.jpg',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save user data
      final success = await SupabaseService.saveUserDataToSupabase(
        userId: testUserId,
        userData: testData,
      );

      if (success) {
        print('✅ User data saved successfully to Supabase');
        
        // Verify data was saved by retrieving it
        final retrievedData = await SupabaseService.getUserProfile(testUserId);
        if (retrievedData != null) {
          print('✅ User data retrieved successfully from Supabase');
          print('   - Retrieved Email: ${retrievedData['email']}');
          print('   - Retrieved Name: ${retrievedData['display_name']}');
        } else {
          print('❌ Failed to retrieve user data from Supabase');
        }
      } else {
        print('❌ Failed to save user data to Supabase');
      }
    } catch (e) {
      print('❌ Error in user data saving test: $e');
    }
    print('');
  }

  static Future<void> _testDataSynchronization() async {
    print('🔄 Test 3: Data Synchronization');
    
    try {
      final testUserId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Test data sync to Supabase
      final syncToSupabase = await DataSyncService.syncUserDataToSupabase();
      print('Sync to Supabase: ${syncToSupabase ? "✅ Success" : "❌ Failed"}');

      // Test data sync from Supabase
      final syncFromSupabase = await DataSyncService.syncUserDataFromSupabase(testUserId);
      print('Sync from Supabase: ${syncFromSupabase ? "✅ Success" : "❌ Failed"}');

      // Test force sync
      final forceSync = await DataSyncService.forceSyncAll();
      print('Force sync all: ${forceSync ? "✅ Success" : "❌ Failed"}');

    } catch (e) {
      print('❌ Error in data synchronization test: $e');
    }
    print('');
  }

  static Future<void> _testUserDataUpdates() async {
    print('🔄 Test 4: User Data Updates');
    
    try {
      final testUserId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create initial user data
      final initialData = {
        'id': testUserId,
        'email': 'initial@example.com',
        'display_name': 'Initial User',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save initial data
      await DataSyncService.saveUserData(initialData);
      print('✅ Initial user data saved');

      // Update user data
      final updatedData = {
        'id': testUserId,
        'email': 'updated@example.com',
        'display_name': 'Updated User',
        'phone': '+1234567890',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save updated data
      final updateSuccess = await DataSyncService.saveUserData(updatedData);
      print('Update user data: ${updateSuccess ? "✅ Success" : "❌ Failed"}');

      // Verify update
      final retrievedData = await SupabaseService.getUserProfile(testUserId);
      if (retrievedData != null) {
        print('✅ Updated data retrieved successfully');
        print('   - Updated Email: ${retrievedData['email']}');
        print('   - Updated Name: ${retrievedData['display_name']}');
        print('   - Phone: ${retrievedData['phone']}');
      } else {
        print('❌ Failed to retrieve updated data');
      }

    } catch (e) {
      print('❌ Error in user data updates test: $e');
    }
    print('');
  }

  /// Test the complete authentication flow with data persistence
  static Future<void> testAuthFlowWithDataPersistence() async {
    print('🔐 Testing Authentication Flow with Data Persistence\n');

    try {
      // Simulate user signup
      print('1. Testing user signup...');
      final signupResponse = await SupabaseService.signUp(
        email: 'testuser@example.com',
        password: 'testpassword123',
        fullName: 'Test User',
      );

      if (signupResponse?.user != null) {
        print('✅ User signup successful');
        final userId = signupResponse!.user!.id;

        // Test user profile creation
        print('2. Testing user profile creation...');
        final userProfile = await SupabaseService.createUserProfile(
          userId: userId,
          email: signupResponse.user!.email!,
          fullName: 'Test User',
        );

        if (userProfile != null) {
          print('✅ User profile created in Supabase');
          print('   - Profile ID: ${userProfile['id']}');
          print('   - Email: ${userProfile['email']}');
          print('   - Display Name: ${userProfile['display_name']}');
        } else {
          print('❌ Failed to create user profile');
        }

        // Test data synchronization
        print('3. Testing data synchronization...');
        final syncSuccess = await DataSyncService.saveUserData(userProfile ?? {
          'id': userId,
          'email': signupResponse.user!.email,
          'display_name': 'Test User',
        });

        print('Data sync: ${syncSuccess ? "✅ Success" : "❌ Failed"}');

        // Test data retrieval
        print('4. Testing data retrieval...');
        final retrievedProfile = await SupabaseService.getUserProfile(userId);
        if (retrievedProfile != null) {
          print('✅ User profile retrieved from Supabase');
          print('   - Retrieved Email: ${retrievedProfile['email']}');
          print('   - Retrieved Name: ${retrievedProfile['display_name']}');
        } else {
          print('❌ Failed to retrieve user profile');
        }

      } else {
        print('❌ User signup failed');
      }

    } catch (e) {
      print('❌ Error in authentication flow test: $e');
    }

    print('\n✅ Authentication flow with data persistence test completed!');
  }
}



