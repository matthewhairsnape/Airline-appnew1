import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Test service to directly test Supabase data saving
class SupabaseTestService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Test basic connection to Supabase
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔄 Testing Supabase connection...');
      
      // Test basic connection by trying to select from a simple table
      final response = await client
          .from('users')
          .select('count')
          .limit(1);
      
      debugPrint('✅ Supabase connection successful');
      debugPrint('Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Test saving a simple user record
  static Future<bool> testSaveUser() async {
    try {
      debugPrint('🔄 Testing user save...');
      
      final testUser = {
        'id': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('users')
          .insert(testUser)
          .select();

      debugPrint('✅ User saved successfully');
      debugPrint('Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ User save failed: $e');
      return false;
    }
  }

  /// Test saving a journey record
  static Future<bool> testSaveJourney() async {
    try {
      debugPrint('🔄 Testing journey save...');
      
      // First, let's check if we have any airlines and airports
      final airlines = await client.from('airlines').select('id, iata_code').limit(1);
      final airports = await client.from('airports').select('id, iata_code').limit(2);
      
      debugPrint('Airlines found: ${airlines.length}');
      debugPrint('Airports found: ${airports.length}');
      
      if (airlines.isEmpty || airports.length < 2) {
        debugPrint('❌ Missing required data (airlines or airports)');
        return false;
      }

      final testJourney = {
        'id': 'test-journey-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
        'pnr': 'TEST123',
        'seat_number': '12A',
        'class_of_travel': 'Economy',
        'terminal': 'T1',
        'gate': 'A12',
        'status': 'scheduled',
        'current_phase': 'pre_check_in',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('journeys')
          .insert(testJourney)
          .select();

      debugPrint('✅ Journey saved successfully');
      debugPrint('Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Journey save failed: $e');
      return false;
    }
  }

  /// Test saving stage feedback
  static Future<bool> testSaveFeedback() async {
    try {
      debugPrint('🔄 Testing feedback save...');
      
      final testFeedback = {
        'id': 'test-feedback-${DateTime.now().millisecondsSinceEpoch}',
        'journey_id': 'test-journey-${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
        'stage': 'pre_check_in',
        'positive_selections': {'service': ['friendly_staff']},
        'negative_selections': {'service': ['long_wait']},
        'custom_feedback': {'comments': 'Test feedback'},
        'overall_rating': 4,
        'additional_comments': 'Test comment',
        'feedback_timestamp': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('stage_feedback')
          .insert(testFeedback)
          .select();

      debugPrint('✅ Feedback saved successfully');
      debugPrint('Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Feedback save failed: $e');
      return false;
    }
  }

  /// Test saving journey event
  static Future<bool> testSaveEvent() async {
    try {
      debugPrint('🔄 Testing event save...');
      
      final testEvent = {
        'id': 'test-event-${DateTime.now().millisecondsSinceEpoch}',
        'journey_id': 'test-journey-${DateTime.now().millisecondsSinceEpoch}',
        'event_type': 'test_event',
        'title': 'Test Event',
        'description': 'This is a test event',
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': {'test': true},
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('journey_events')
          .insert(testEvent)
          .select();

      debugPrint('✅ Event saved successfully');
      debugPrint('Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Event save failed: $e');
      return false;
    }
  }

  /// Run all tests
  static Future<Map<String, bool>> runAllTests() async {
    debugPrint('🚀 Running all Supabase tests...');
    
    final results = <String, bool>{};
    
    results['connection'] = await testConnection();
    results['user_save'] = await testSaveUser();
    results['journey_save'] = await testSaveJourney();
    results['feedback_save'] = await testSaveFeedback();
    results['event_save'] = await testSaveEvent();
    
    debugPrint('📊 Test Results:');
    results.forEach((test, passed) {
      debugPrint('  $test: ${passed ? "✅ PASS" : "❌ FAIL"}');
    });
    
    return results;
  }

  /// Get table information
  static Future<Map<String, dynamic>> getTableInfo() async {
    try {
      final tables = ['users', 'journeys', 'stage_feedback', 'journey_events', 'airlines', 'airports'];
      final info = <String, dynamic>{};
      
      for (final table in tables) {
        try {
          final count = await client.from(table).select('count').limit(1);
          info[table] = {'exists': true, 'count': count.length};
        } catch (e) {
          info[table] = {'exists': false, 'error': e.toString()};
        }
      }
      
      return info;
    } catch (e) {
      debugPrint('❌ Error getting table info: $e');
      return {};
    }
  }
}
