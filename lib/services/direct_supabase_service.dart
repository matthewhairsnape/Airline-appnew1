import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Direct Supabase service for immediate data saving
/// This bypasses complex data flow and directly saves to Supabase
class DirectSupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Save user data directly to Supabase
  static Future<bool> saveUser({
    required String userId,
    required String email,
    String? displayName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      debugPrint('🔄 Saving user directly to Supabase...');
      
      final userData = {
        'id': userId,
        'email': email,
        'display_name': displayName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('users')
          .upsert(userData)
          .select();

      debugPrint('✅ User saved successfully: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving user: $e');
      return false;
    }
  }

  /// Save journey data directly to Supabase
  static Future<bool> saveJourney({
    required String journeyId,
    required String userId,
    required String pnr,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? status,
    String? currentPhase,
  }) async {
    try {
      debugPrint('🔄 Saving journey directly to Supabase...');
      
      final journeyData = {
        'id': journeyId,
        'user_id': userId,
        'pnr': pnr,
        'seat_number': seatNumber,
        'class_of_travel': classOfTravel,
        'terminal': terminal,
        'gate': gate,
        'status': status ?? 'scheduled',
        'current_phase': currentPhase ?? 'pre_check_in',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('journeys')
          .upsert(journeyData)
          .select();

      debugPrint('✅ Journey saved successfully: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving journey: $e');
      return false;
    }
  }

  /// Save stage feedback directly to Supabase
  static Future<bool> saveStageFeedback({
    required String feedbackId,
    required String journeyId,
    required String userId,
    required String stage,
    Map<String, dynamic>? positiveSelections,
    Map<String, dynamic>? negativeSelections,
    Map<String, dynamic>? customFeedback,
    int? overallRating,
    String? additionalComments,
  }) async {
    try {
      debugPrint('🔄 Saving stage feedback directly to Supabase...');
      
      final feedbackData = {
        'id': feedbackId,
        'journey_id': journeyId,
        'user_id': userId,
        'stage': stage,
        'positive_selections': positiveSelections ?? {},
        'negative_selections': negativeSelections ?? {},
        'custom_feedback': customFeedback ?? {},
        'overall_rating': overallRating,
        'additional_comments': additionalComments,
        'feedback_timestamp': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('stage_feedback')
          .upsert(feedbackData)
          .select();

      debugPrint('✅ Stage feedback saved successfully: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving stage feedback: $e');
      return false;
    }
  }

  /// Save journey event directly to Supabase
  static Future<bool> saveJourneyEvent({
    required String eventId,
    required String journeyId,
    required String eventType,
    required String title,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔄 Saving journey event directly to Supabase...');
      
      final eventData = {
        'id': eventId,
        'journey_id': journeyId,
        'event_type': eventType,
        'title': title,
        'description': description,
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('journey_events')
          .upsert(eventData)
          .select();

      debugPrint('✅ Journey event saved successfully: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving journey event: $e');
      return false;
    }
  }

  /// Get user data from Supabase
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      debugPrint('🔄 Getting user from Supabase...');
      
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      debugPrint('✅ User retrieved: $response');
      return response;
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      return null;
    }
  }

  /// Get user journeys from Supabase
  static Future<List<Map<String, dynamic>>> getUserJourneys(String userId) async {
    try {
      debugPrint('🔄 Getting user journeys from Supabase...');
      
      final response = await client
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint('✅ User journeys retrieved: ${response.length} journeys');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting user journeys: $e');
      return [];
    }
  }

  /// Get journey events from Supabase
  static Future<List<Map<String, dynamic>>> getJourneyEvents(String journeyId) async {
    try {
      debugPrint('🔄 Getting journey events from Supabase...');
      
      final response = await client
          .from('journey_events')
          .select()
          .eq('journey_id', journeyId)
          .order('event_timestamp', ascending: false);

      debugPrint('✅ Journey events retrieved: ${response.length} events');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting journey events: $e');
      return [];
    }
  }

  /// Test basic connection
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔄 Testing Supabase connection...');
      
      final response = await client
          .from('users')
          .select('count')
          .limit(1);

      debugPrint('✅ Supabase connection successful');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Get all data for a user (for testing)
  static Future<Map<String, dynamic>> getAllUserData(String userId) async {
    try {
      debugPrint('🔄 Getting all user data from Supabase...');
      
      final user = await getUser(userId);
      final journeys = await getUserJourneys(userId);
      
      // Get events for all journeys
      final allEvents = <Map<String, dynamic>>[];
      for (final journey in journeys) {
        final events = await getJourneyEvents(journey['id']);
        allEvents.addAll(events);
      }

      final result = {
        'user': user,
        'journeys': journeys,
        'events': allEvents,
        'total_journeys': journeys.length,
        'total_events': allEvents.length,
        'retrieved_at': DateTime.now().toIso8601String(),
      };

      debugPrint('✅ All user data retrieved successfully');
      return result;
    } catch (e) {
      debugPrint('❌ Error getting all user data: $e');
      return {};
    }
  }
}
