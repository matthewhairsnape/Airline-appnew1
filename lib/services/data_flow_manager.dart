import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'realtime_data_service.dart';
import 'supabase_service.dart';

/// Central data flow manager that orchestrates all data operations
/// between the Flutter app and Supabase
class DataFlowManager {
  static DataFlowManager? _instance;
  static DataFlowManager get instance => _instance ??= DataFlowManager._();

  DataFlowManager._();

  final RealtimeDataService _realtimeService = RealtimeDataService.instance;
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, dynamic> _localData = {};

  /// Initialize the data flow manager
  Future<void> initialize() async {
    debugPrint('🔄 Initializing DataFlowManager...');

    await _realtimeService.initialize();
    await _loadLocalData();
    await _realtimeService.syncPendingData();

    debugPrint('✅ DataFlowManager initialized');
  }

  /// Create a new journey with real-time tracking
  Future<Map<String, dynamic>?> createJourneyWithTracking({
    required String userId,
    required String pnr,
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? aircraftType,
  }) async {
    try {
      // Create journey in Supabase
      final journey = await SupabaseService.createJourney(
        userId: userId,
        pnr: pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        scheduledDeparture: scheduledDeparture,
        scheduledArrival: scheduledArrival,
        seatNumber: seatNumber,
        classOfTravel: classOfTravel,
        terminal: terminal,
        gate: gate,
        aircraftType: aircraftType,
      );

      if (journey != null) {
        // Start real-time tracking
        await _startJourneyTracking(journey['id'], userId);

        // Cache locally
        await _cacheJourneyLocally(journey);

        debugPrint(
            '✅ Journey created with real-time tracking: ${journey['id']}');
      }

      return journey;
    } catch (e) {
      debugPrint('❌ Error creating journey with tracking: $e');
      return null;
    }
  }

  /// Submit stage feedback with real-time updates
  Future<bool> submitStageFeedbackWithRealtime({
    required String journeyId,
    required String userId,
    required String stage,
    required Map<String, dynamic> positiveSelections,
    required Map<String, dynamic> negativeSelections,
    required Map<String, dynamic> customFeedback,
    int? overallRating,
    String? additionalComments,
  }) async {
    try {
      // Submit to Supabase
      await SupabaseService.submitStageFeedback(
        journeyId: journeyId,
        userId: userId,
        stage: stage,
        positiveSelections: positiveSelections,
        negativeSelections: negativeSelections,
        customFeedback: customFeedback,
        overallRating: overallRating,
        additionalComments: additionalComments,
      );

      // Send real-time update
      await _realtimeService.sendDataToSupabase(
        table: 'stage_feedback',
        data: {
          'journey_id': journeyId,
          'user_id': userId,
          'stage': stage,
          'positive_selections': positiveSelections,
          'negative_selections': negativeSelections,
          'custom_feedback': customFeedback,
          'overall_rating': overallRating,
          'additional_comments': additionalComments,
          'feedback_timestamp': DateTime.now().toIso8601String(),
        },
        operation: 'insert',
      );

      // Cache locally
      await _cacheFeedbackLocally({
        'journey_id': journeyId,
        'user_id': userId,
        'stage': stage,
        'positive_selections': positiveSelections,
        'negative_selections': negativeSelections,
        'custom_feedback': customFeedback,
        'overall_rating': overallRating,
        'additional_comments': additionalComments,
        'feedback_timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Stage feedback submitted with real-time updates');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting stage feedback: $e');
      return false;
    }
  }

  /// Submit complete review with real-time updates
  Future<Map<String, dynamic>?> submitCompleteReviewWithRealtime({
    required String journeyId,
    required String userId,
    required String airlineId,
    required String airportId,
    required Map<String, int> airlineRatings,
    required Map<String, int> airportRatings,
    String? airlineComment,
    String? airportComment,
    List<String>? airlineImages,
    List<String>? airportImages,
  }) async {
    try {
      // Submit to Supabase
      final result = await SupabaseService.submitCompleteReview(
        journeyId: journeyId,
        userId: userId,
        airlineId: airlineId,
        airportId: airportId,
        airlineRatings: airlineRatings,
        airportRatings: airportRatings,
        airlineComment: airlineComment,
        airportComment: airportComment,
        airlineImages: airlineImages,
        airportImages: airportImages,
      );

      if (result != null && result['success'] == true) {
        // Send real-time updates
        await _realtimeService.sendDataToSupabase(
          table: 'airline_reviews',
          data: {
            'journey_id': journeyId,
            'user_id': userId,
            'airline_id': airlineId,
            'overall_score': result['airlineScore'],
            'seat_comfort': airlineRatings['comfort'],
            'cabin_service': airlineRatings['service'],
            'food_beverage': airlineRatings['food'],
            'entertainment': airlineRatings['entertainment'],
            'comments': airlineComment,
            'created_at': DateTime.now().toIso8601String(),
          },
          operation: 'insert',
        );

        await _realtimeService.sendDataToSupabase(
          table: 'airport_reviews',
          data: {
            'journey_id': journeyId,
            'user_id': userId,
            'airport_id': airportId,
            'overall_score': result['airportScore'],
            'cleanliness': airportRatings['cleanliness'],
            'facilities': airportRatings['facilities'],
            'staff': airportRatings['staff'],
            'waiting_time': airportRatings['waitTimes'],
            'accessibility': airportRatings['accessibility'],
            'comments': airportComment,
            'created_at': DateTime.now().toIso8601String(),
          },
          operation: 'insert',
        );

        debugPrint('✅ Complete review submitted with real-time updates');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error submitting complete review: $e');
      return null;
    }
  }

  /// Get user journeys with real-time updates
  Stream<List<Map<String, dynamic>>> getUserJourneysStream(String userId) {
    return _realtimeService.subscribeToUserJourneys(userId);
  }

  /// Get journey events with real-time updates
  Stream<Map<String, dynamic>> getJourneyEventsStream(String journeyId) {
    return _realtimeService.subscribeToJourney(journeyId);
  }

  /// Get feedback stream for a journey
  Stream<List<Map<String, dynamic>>> getFeedbackStream(String journeyId) {
    return _realtimeService.subscribeToFeedback(journeyId);
  }

  /// Get flight tracking stream
  Stream<Map<String, dynamic>> getFlightTrackingStream(String flightId) {
    return _realtimeService.subscribeToFlightTracking(flightId);
  }

  /// Get dashboard analytics stream
  Stream<Map<String, dynamic>> getDashboardStream() {
    return _realtimeService.subscribeToDashboard();
  }

  /// Update journey phase with real-time notification
  Future<bool> updateJourneyPhase({
    required String journeyId,
    required String newPhase,
    String? gate,
    String? terminal,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Update in Supabase
      await SupabaseService.client.from('journeys').update({
        'current_phase': newPhase,
        'gate': gate,
        'terminal': terminal,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', journeyId);

      // Add journey event
      await SupabaseService.client.from('journey_events').insert({
        'journey_id': journeyId,
        'event_type': 'phase_change',
        'title': 'Phase Updated',
        'description': 'Journey phase changed to $newPhase',
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      });

      // Send real-time update
      await _realtimeService.sendDataToSupabase(
        table: 'journey_events',
        data: {
          'journey_id': journeyId,
          'event_type': 'phase_change',
          'title': 'Phase Updated',
          'description': 'Journey phase changed to $newPhase',
          'event_timestamp': DateTime.now().toIso8601String(),
          'metadata': metadata ?? {},
        },
        operation: 'insert',
      );

      debugPrint('✅ Journey phase updated: $newPhase');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating journey phase: $e');
      return false;
    }
  }

  /// Start journey tracking
  Future<void> _startJourneyTracking(String journeyId, String userId) async {
    // Subscribe to journey events
    final journeyStream = _realtimeService.subscribeToJourney(journeyId);
    _subscriptions['journey_$journeyId'] = journeyStream.listen((event) {
      _handleJourneyEvent(event, journeyId, userId);
    });
  }

  /// Handle journey events
  void _handleJourneyEvent(
      Map<String, dynamic> event, String journeyId, String userId) {
    debugPrint('📱 Journey event received: ${event['type']}');

    // Update local cache
    _updateLocalJourneyData(journeyId, event);

    // Trigger UI updates if needed
    _notifyJourneyUpdate(journeyId, event);
  }

  /// Update local journey data
  void _updateLocalJourneyData(String journeyId, Map<String, dynamic> event) {
    if (!_localData.containsKey('journeys')) {
      _localData['journeys'] = {};
    }

    if (!_localData['journeys'].containsKey(journeyId)) {
      _localData['journeys'][journeyId] = {
        'events': [],
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      };
    }

    _localData['journeys'][journeyId]['events'].add(event);
    _localData['journeys'][journeyId]['last_updated'] =
        DateTime.now().millisecondsSinceEpoch;
  }

  /// Notify about journey updates
  void _notifyJourneyUpdate(String journeyId, Map<String, dynamic> event) {
    // This would typically trigger UI updates through a state management solution
    debugPrint('🔔 Journey update notification: $journeyId - ${event['type']}');
  }

  /// Cache journey locally
  Future<void> _cacheJourneyLocally(Map<String, dynamic> journey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journeys = prefs.getString('cached_journeys') ?? '{}';
      final Map<String, dynamic> cachedJourneys = json.decode(journeys);

      cachedJourneys[journey['id']] = {
        ...journey,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('cached_journeys', json.encode(cachedJourneys));
    } catch (e) {
      debugPrint('❌ Error caching journey locally: $e');
    }
  }

  /// Cache feedback locally
  Future<void> _cacheFeedbackLocally(Map<String, dynamic> feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedbackList = prefs.getString('cached_feedback') ?? '[]';
      final List<dynamic> cachedFeedback = json.decode(feedbackList);

      cachedFeedback.add({
        ...feedback,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });

      await prefs.setString('cached_feedback', json.encode(cachedFeedback));
    } catch (e) {
      debugPrint('❌ Error caching feedback locally: $e');
    }
  }

  /// Load local data
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached journeys
      final journeys = prefs.getString('cached_journeys');
      if (journeys != null) {
        _localData['journeys'] = json.decode(journeys);
      }

      // Load cached feedback
      final feedback = prefs.getString('cached_feedback');
      if (feedback != null) {
        _localData['feedback'] = json.decode(feedback);
      }

      debugPrint('✅ Local data loaded');
    } catch (e) {
      debugPrint('❌ Error loading local data: $e');
    }
  }

  /// Get dashboard analytics data
  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      // Get real-time analytics from Supabase
      final analytics = await SupabaseService.client
          .from('journey_events')
          .select('event_type, event_timestamp')
          .gte(
              'event_timestamp',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String());

      // Get feedback analytics
      final feedbackAnalytics = await SupabaseService.client
          .from('stage_feedback')
          .select('stage, overall_rating, feedback_timestamp')
          .gte(
              'feedback_timestamp',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String());

      return {
        'journey_events': analytics,
        'feedback_analytics': feedbackAnalytics,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting dashboard analytics: $e');
      return {};
    }
  }

  /// Sync all data
  Future<bool> syncAllData() async {
    try {
      await _realtimeService.syncPendingData();
      debugPrint('✅ All data synced successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing all data: $e');
      return false;
    }
  }

  /// Cleanup
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _realtimeService.dispose();
  }
}
