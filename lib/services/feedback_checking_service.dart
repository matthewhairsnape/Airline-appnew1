import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class FeedbackCheckingService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Check if feedback exists for a completed flight
  static Future<Map<String, bool>> checkFeedbackStatus(String journeyId) async {
    try {
      debugPrint('🔍 Checking feedback status for journey: $journeyId');

      // Check stage_feedback table for general feedback
      final stageResponse = await _client
          .from('stage_feedback')
          .select('stage, id')
          .eq('journey_id', journeyId);

      // Check airline_reviews table
      final airlineResponse = await _client
          .from('airline_reviews')
          .select('id')
          .eq('journey_id', journeyId)
          .limit(1);

      // Check airport_reviews table
      final airportResponse = await _client
          .from('airport_reviews')
          .select('id')
          .eq('journey_id', journeyId)
          .limit(1);

      final feedbackStages = <String, bool>{
        'pre_flight': false,
        'in_flight': false,
        'post_flight': false,
        'overall': false, // Overall experience from feedback table
        'airline_review': airlineResponse.isNotEmpty,
        'airport_review': airportResponse.isNotEmpty,
      };

      // Check stage feedback
      for (final feedback in stageResponse) {
        final stage = feedback['stage'] as String?;
        if (stage != null) {
          if (feedbackStages.containsKey(stage)) {
            feedbackStages[stage] = true;
          }
          // Map 'post_flight' to 'overall' for backward compatibility
          if (stage == 'post_flight') {
            feedbackStages['overall'] = true;
          }
          // Map 'overall' to 'post_flight' for backward compatibility
          if (stage == 'overall') {
            feedbackStages['post_flight'] = true;
          }
        }
      }

      debugPrint('✅ Feedback status: $feedbackStages');
      return feedbackStages;
    } catch (e) {
      debugPrint('❌ Error checking feedback status: $e');
      return {
        'pre_flight': false,
        'in_flight': false,
        'post_flight': false,
        'overall': false,
        'airline_review': false,
        'airport_review': false,
      };
    }
  }

  /// Get existing feedback for a journey
  static Future<Map<String, dynamic>?> getExistingFeedback(
      String journeyId, String stage) async {
    try {
      debugPrint(
          '🔍 Getting existing feedback for journey: $journeyId, stage: $stage');

      // Handle different feedback types
      if (stage == 'airline_review') {
        final response = await _client
            .from('airline_reviews')
            .select('*')
            .eq('journey_id', journeyId)
            .maybeSingle();

        if (response != null) {
          debugPrint('✅ Found existing airline review');
          return response;
        }
      } else if (stage == 'airport_review') {
        final response = await _client
            .from('airport_reviews')
            .select('*')
            .eq('journey_id', journeyId)
            .maybeSingle();

        if (response != null) {
          debugPrint('✅ Found existing airport review');
          return response;
        }
      } else {
        // Handle stage feedback (pre_flight, in_flight, post_flight)
        final response = await _client
            .from('stage_feedback')
            .select('*')
            .eq('journey_id', journeyId)
            .eq('stage', stage)
            .maybeSingle();

        if (response != null) {
          debugPrint('✅ Found existing stage feedback for $stage');
          return response;
        }
      }

      debugPrint('📭 No existing feedback found for $stage');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting existing feedback: $e');
      return null;
    }
  }

  /// Update existing feedback
  static Future<bool> updateFeedback({
    required String feedbackId,
    required String stage,
    required Map<String, dynamic> positiveSelections,
    required Map<String, dynamic> negativeSelections,
    required Map<String, dynamic> customFeedback,
    int? overallRating,
    String? additionalComments,
  }) async {
    try {
      debugPrint('🔄 Updating feedback: $feedbackId for stage: $stage');

      final updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle different feedback types
      if (stage == 'airline_review') {
        final airlineData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (overallRating != null) {
          airlineData['overall_score'] = overallRating.toDouble();
        }
        if (additionalComments != null) {
          airlineData['comments'] = additionalComments;
        }
        await _client
            .from('airline_reviews')
            .update(airlineData)
            .eq('id', feedbackId);
      } else if (stage == 'airport_review') {
        final airportData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (overallRating != null) {
          airportData['overall_score'] = overallRating.toDouble();
        }
        if (additionalComments != null) {
          airportData['comments'] = additionalComments;
        }
        await _client
            .from('airport_reviews')
            .update(airportData)
            .eq('id', feedbackId);
      } else {
        // Handle stage feedback
        final stageData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
          'positive_selections': positiveSelections,
          'negative_selections': negativeSelections,
          'custom_feedback': customFeedback,
        };
        if (overallRating != null) {
          stageData['overall_rating'] = overallRating;
        }
        if (additionalComments != null) {
          stageData['additional_comments'] = additionalComments;
        }
        await _client
            .from('stage_feedback')
            .update(stageData)
            .eq('id', feedbackId);
      }

      debugPrint('✅ Feedback updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating feedback: $e');
      return false;
    }
  }

  /// Get all feedback for a journey (all stages)
  static Future<Map<String, Map<String, dynamic>?>> getAllFeedbackForJourney(
      String journeyId) async {
    try {
      debugPrint('🔍 Getting all feedback for journey: $journeyId');

      final feedbackMap = <String, Map<String, dynamic>?>{};

      // Get stage feedback
      final stageResponse = await _client
          .from('stage_feedback')
          .select('*')
          .eq('journey_id', journeyId);

      for (final feedback in stageResponse) {
        final stage = feedback['stage'] as String?;
        if (stage != null) {
          feedbackMap[stage] = feedback;
          // Map 'post_flight' to 'overall' for backward compatibility
          if (stage == 'post_flight') {
            feedbackMap['overall'] = feedback;
          }
          // Map 'overall' to 'post_flight' for backward compatibility
          if (stage == 'overall') {
            feedbackMap['post_flight'] = feedback;
          }
        }
      }

      // Get airline review
      final airlineResponse = await _client
          .from('airline_reviews')
          .select('*')
          .eq('journey_id', journeyId)
          .maybeSingle();

      if (airlineResponse != null) {
        feedbackMap['airline_review'] = airlineResponse;
      }

      // Get airport review
      final airportResponse = await _client
          .from('airport_reviews')
          .select('*')
          .eq('journey_id', journeyId)
          .maybeSingle();

      if (airportResponse != null) {
        feedbackMap['airport_review'] = airportResponse;
      }

      debugPrint('✅ Retrieved feedback for ${feedbackMap.length} stages');
      return feedbackMap;
    } catch (e) {
      debugPrint('❌ Error getting all feedback: $e');
      return {};
    }
  }

  /// Check if journey has any feedback at all
  static Future<bool> hasAnyFeedback(String journeyId) async {
    try {
      // Check stage feedback
      final stageResponse = await _client
          .from('stage_feedback')
          .select('id')
          .eq('journey_id', journeyId)
          .limit(1);

      if (stageResponse.isNotEmpty) return true;

      // Check airline review
      final airlineResponse = await _client
          .from('airline_reviews')
          .select('id')
          .eq('journey_id', journeyId)
          .limit(1);

      if (airlineResponse.isNotEmpty) return true;

      // Check airport review
      final airportResponse = await _client
          .from('airport_reviews')
          .select('id')
          .eq('journey_id', journeyId)
          .limit(1);

      return airportResponse.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking if journey has feedback: $e');
      return false;
    }
  }

  /// Get feedback completion percentage
  static Future<int> getFeedbackCompletionPercentage(String journeyId) async {
    try {
      final feedbackStatus = await checkFeedbackStatus(journeyId);
      final completedStages =
          feedbackStatus.values.where((hasFeedback) => hasFeedback).length;
      final totalStages = feedbackStatus.length;

      return ((completedStages / totalStages) * 100).round();
    } catch (e) {
      debugPrint('❌ Error calculating feedback completion: $e');
      return 0;
    }
  }
}
