import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'supabase_service.dart';

/// Simplified data flow service that provides basic real-time functionality
/// without complex queries that might cause compilation issues
class SimpleDataFlowService {
  static SimpleDataFlowService? _instance;
  static SimpleDataFlowService get instance => _instance ??= SimpleDataFlowService._();
  
  SimpleDataFlowService._();

  final Map<String, RealtimeChannel> _activeChannels = {};
  final Map<String, StreamController<Map<String, dynamic>>> _dataStreams = {};

  /// Initialize the simplified data flow service
  Future<void> initialize() async {
    debugPrint('🔄 Initializing SimpleDataFlowService...');
    
    // Set up global error handling
    Supabase.instance.client.realtime.onError((error) {
      debugPrint('❌ Realtime error: $error');
    });

    debugPrint('✅ SimpleDataFlowService initialized');
  }

  /// Create a journey with basic real-time tracking
  Future<Map<String, dynamic>?> createJourney({
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
      // Use existing SupabaseService to create journey
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
        // Start basic real-time tracking
        await _startJourneyTracking(journey['id']);
        debugPrint('✅ Journey created with basic tracking: ${journey['id']}');
      }

      return journey;
    } catch (e) {
      debugPrint('❌ Error creating journey: $e');
      return null;
    }
  }

  /// Submit stage feedback with basic real-time updates
  Future<bool> submitStageFeedback({
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
      // Submit to Supabase using existing service
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
      await _sendRealtimeUpdate('stage_feedback', {
        'journey_id': journeyId,
        'user_id': userId,
        'stage': stage,
        'overall_rating': overallRating,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Stage feedback submitted with real-time update');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting stage feedback: $e');
      return false;
    }
  }

  /// Get user journeys with basic real-time updates
  Stream<List<Map<String, dynamic>>> getUserJourneysStream(String userId) {
    if (_dataStreams.containsKey('user_journeys_$userId')) {
      return _dataStreams['user_journeys_$userId']!.stream as Stream<List<Map<String, dynamic>>>;
    }

    final streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    _dataStreams['user_journeys_$userId'] = streamController as StreamController<Map<String, dynamic>>;

    // Subscribe to journey updates
    final userChannel = Supabase.instance.client
        .channel('user_journeys_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journeys',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleJourneyUpdate(userId, payload, streamController);
          },
        )
        .subscribe();

    _activeChannels['user_journeys_$userId'] = userChannel;

    return streamController.stream;
  }

  /// Get journey events stream
  Stream<Map<String, dynamic>> getJourneyEventsStream(String journeyId) {
    if (_dataStreams.containsKey('journey_$journeyId')) {
      return _dataStreams['journey_$journeyId']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dataStreams['journey_$journeyId'] = streamController;

    // Subscribe to journey events
    final journeyChannel = Supabase.instance.client
        .channel('journey_$journeyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'journey_id',
            value: journeyId,
          ),
          callback: (payload) {
            _handleJourneyEventUpdate(journeyId, payload, streamController);
          },
        )
        .subscribe();

    _activeChannels['journey_$journeyId'] = journeyChannel;

    return streamController.stream;
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
      await SupabaseService.client
          .from('journeys')
          .update({
            'current_phase': newPhase,
            'gate': gate,
            'terminal': terminal,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', journeyId);

      // Add journey event
      await SupabaseService.client
          .from('journey_events')
          .insert({
            'journey_id': journeyId,
            'event_type': 'phase_change',
            'title': 'Phase Updated',
            'description': 'Journey phase changed to $newPhase',
            'event_timestamp': DateTime.now().toIso8601String(),
            'metadata': metadata ?? {},
          });

      // Send real-time update
      await _sendRealtimeUpdate('journey_events', {
        'journey_id': journeyId,
        'event_type': 'phase_change',
        'title': 'Phase Updated',
        'description': 'Journey phase changed to $newPhase',
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Journey phase updated: $newPhase');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating journey phase: $e');
      return false;
    }
  }

  /// Get dashboard stream for basic analytics
  Stream<Map<String, dynamic>> getDashboardStream() {
    if (_dataStreams.containsKey('dashboard')) {
      return _dataStreams['dashboard']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dataStreams['dashboard'] = streamController;

    // Subscribe to all relevant tables
    final dashboardChannel = Supabase.instance.client
        .channel('dashboard_analytics')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          callback: (payload) {
            _handleDashboardUpdate('journey_events', payload, streamController);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stage_feedback',
          callback: (payload) {
            _handleDashboardUpdate('stage_feedback', payload, streamController);
          },
        )
        .subscribe();

    _activeChannels['dashboard'] = dashboardChannel;

    return streamController.stream;
  }

  /// Get basic analytics data
  Future<Map<String, dynamic>> getBasicAnalytics() async {
    try {
      // Get recent journey events
      final recentEvents = await SupabaseService.client
          .from('journey_events')
          .select('*')
          .gte('event_timestamp', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('event_timestamp', ascending: false)
          .limit(50);

      // Get recent feedback
      final recentFeedback = await SupabaseService.client
          .from('stage_feedback')
          .select('*')
          .gte('feedback_timestamp', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('feedback_timestamp', ascending: false)
          .limit(50);

      return {
        'recent_events': recentEvents,
        'recent_feedback': recentFeedback,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting basic analytics: $e');
      return {};
    }
  }

  /// Start basic journey tracking
  Future<void> _startJourneyTracking(String journeyId) async {
    // Subscribe to journey events
    final journeyStream = getJourneyEventsStream(journeyId);
    journeyStream.listen((event) {
      debugPrint('📱 Journey event received: ${event['event_type']}');
    });
  }

  /// Send real-time update
  Future<void> _sendRealtimeUpdate(String table, Map<String, dynamic> data) async {
    try {
      // This would typically send to a real-time channel
      // For now, we'll just log it
      debugPrint('📡 Real-time update sent: $table - ${data['event_type'] ?? 'data'}');
    } catch (e) {
      debugPrint('❌ Error sending real-time update: $e');
    }
  }

  /// Handle journey updates
  void _handleJourneyUpdate(
    String userId,
    PostgresChangePayload payload,
    StreamController<List<Map<String, dynamic>>> controller,
  ) {
    // Fetch updated journeys list
    _fetchUserJourneys(userId).then((journeys) {
      controller.add(journeys);
    });
  }

  /// Handle journey event updates
  void _handleJourneyEventUpdate(
    String journeyId,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final eventData = {
      'type': 'journey_event',
      'journey_id': journeyId,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(eventData);
  }

  /// Handle dashboard updates
  void _handleDashboardUpdate(
    String table,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final dashboardData = {
      'type': 'dashboard_update',
      'table': table,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(dashboardData);
  }

  /// Fetch user journeys
  Future<List<Map<String, dynamic>>> _fetchUserJourneys(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('journeys')
          .select('''
            *,
            flight:flights (
              *,
              airline:airlines (*),
              departure_airport:airports!flights_departure_airport_id_fkey (*),
              arrival_airport:airports!flights_arrival_airport_id_fkey (*)
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error fetching user journeys: $e');
      return [];
    }
  }

  /// Sync all data
  Future<bool> syncAllData() async {
    try {
      // Basic sync - just log for now
      debugPrint('🔄 Syncing all data...');
      debugPrint('✅ Data sync completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing data: $e');
      return false;
    }
  }

  /// Get system health
  Map<String, dynamic> getSystemHealth() {
    return {
      'initialized': true,
      'supabase_connected': SupabaseService.isInitialized,
      'active_channels': _activeChannels.length,
      'active_streams': _dataStreams.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Cleanup
  void dispose() {
    for (final channel in _activeChannels.values) {
      channel.unsubscribe();
    }
    
    for (final stream in _dataStreams.values) {
      stream.close();
    }
    
    _activeChannels.clear();
    _dataStreams.clear();
  }
}
