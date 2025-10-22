import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Dashboard service for live data ingestion and analytics
/// Provides real-time insights into airline operations and user behavior
class DashboardService {
  static DashboardService? _instance;
  static DashboardService get instance => _instance ??= DashboardService._();

  DashboardService._();

  final Map<String, StreamController<Map<String, dynamic>>> _dashboardStreams =
      {};
  final Map<String, RealtimeChannel> _dashboardChannels = {};

  /// Initialize dashboard service
  Future<void> initialize() async {
    debugPrint('🔄 Initializing DashboardService...');
    debugPrint('✅ DashboardService initialized');
  }

  /// Get real-time analytics stream
  Stream<Map<String, dynamic>> getAnalyticsStream() {
    if (_dashboardStreams.containsKey('analytics')) {
      return _dashboardStreams['analytics']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dashboardStreams['analytics'] = streamController;

    // Subscribe to all relevant tables for analytics
    final analyticsChannel = Supabase.instance.client
        .channel('dashboard_analytics')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          callback: (payload) => _handleAnalyticsUpdate(
              'journey_events', payload, streamController),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stage_feedback',
          callback: (payload) => _handleAnalyticsUpdate(
              'stage_feedback', payload, streamController),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'airline_reviews',
          callback: (payload) => _handleAnalyticsUpdate(
              'airline_reviews', payload, streamController),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'airport_reviews',
          callback: (payload) => _handleAnalyticsUpdate(
              'airport_reviews', payload, streamController),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journeys',
          callback: (payload) =>
              _handleAnalyticsUpdate('journeys', payload, streamController),
        )
        .subscribe();

    _dashboardChannels['analytics'] = analyticsChannel;

    return streamController.stream;
  }

  /// Get live flight tracking dashboard
  Stream<Map<String, dynamic>> getFlightTrackingDashboard() {
    if (_dashboardStreams.containsKey('flight_tracking')) {
      return _dashboardStreams['flight_tracking']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dashboardStreams['flight_tracking'] = streamController;

    // Subscribe to flight updates
    final flightChannel = Supabase.instance.client
        .channel('flight_tracking_dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flights',
          callback: (payload) =>
              _handleFlightTrackingUpdate(payload, streamController),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_type',
            value: 'phase_change',
          ),
          callback: (payload) =>
              _handleFlightTrackingUpdate(payload, streamController),
        )
        .subscribe();

    _dashboardChannels['flight_tracking'] = flightChannel;

    return streamController.stream;
  }

  /// Get user engagement metrics
  Future<Map<String, dynamic>> getUserEngagementMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get user activity metrics
      final userActivity = await Supabase.instance.client
          .from('journey_events')
          .select('user_id, event_type, event_timestamp')
          .gte('event_timestamp', start.toIso8601String())
          .lte('event_timestamp', end.toIso8601String());

      // Get feedback completion rates
      final feedbackCompletion = await Supabase.instance.client
          .from('stage_feedback')
          .select('stage, overall_rating, feedback_timestamp')
          .gte('feedback_timestamp', start.toIso8601String())
          .lte('feedback_timestamp', end.toIso8601String());

      // Get journey completion rates
      final journeyCompletion = await Supabase.instance.client
          .from('journeys')
          .select('current_phase, created_at')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      return {
        'user_activity': userActivity,
        'feedback_completion': feedbackCompletion,
        'journey_completion': journeyCompletion,
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting user engagement metrics: $e');
      return {};
    }
  }

  /// Get operational insights
  Future<Map<String, dynamic>> getOperationalInsights() async {
    try {
      // Get real-time flight status distribution
      final flightStatus = await Supabase.instance.client
          .from('journeys')
          .select('current_phase, created_at, updated_at');

      // Get feedback insights by phase
      final phaseFeedback = await Supabase.instance.client
          .from('stage_feedback')
          .select('stage, overall_rating, feedback_timestamp')
          .gte(
              'feedback_timestamp',
              DateTime.now()
                  .subtract(const Duration(days: 7))
                  .toIso8601String());

      // Get airline performance metrics
      final airlinePerformance = await Supabase.instance.client
          .from('airline_reviews')
          .select('airline_id, overall_score, created_at')
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String());

      // Get airport performance metrics
      final airportPerformance = await Supabase.instance.client
          .from('airport_reviews')
          .select('airport_id, overall_score, created_at')
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String());

      return {
        'flight_status_distribution': flightStatus,
        'phase_feedback_insights': phaseFeedback,
        'airline_performance': airlinePerformance,
        'airport_performance': airportPerformance,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting operational insights: $e');
      return {};
    }
  }

  /// Get real-time alerts and notifications
  Stream<Map<String, dynamic>> getAlertsStream() {
    if (_dashboardStreams.containsKey('alerts')) {
      return _dashboardStreams['alerts']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dashboardStreams['alerts'] = streamController;

    // Subscribe to critical events
    final alertsChannel = Supabase.instance.client
        .channel('dashboard_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'journey_events',
          callback: (payload) {
            final eventType = payload.newRecord?['event_type'] ?? '';
            if (['delay', 'cancellation', 'gate_change', 'terminal_change']
                .contains(eventType)) {
              _handleAlertUpdate(payload, streamController);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'stage_feedback',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.lt,
            column: 'overall_rating',
            value: 3,
          ),
          callback: (payload) => _handleAlertUpdate(payload, streamController),
        )
        .subscribe();

    _dashboardChannels['alerts'] = alertsChannel;

    return streamController.stream;
  }

  /// Get live data ingestion metrics
  Future<Map<String, dynamic>> getDataIngestionMetrics() async {
    try {
      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Get data ingestion rates
      final hourlyData = await Supabase.instance.client
          .from('journey_events')
          .select('COUNT(*) as event_count')
          .gte('event_timestamp', lastHour.toIso8601String())
          .lte('event_timestamp', now.toIso8601String());

      final dailyData = await Supabase.instance.client
          .from('journey_events')
          .select('COUNT(*) as event_count')
          .gte('event_timestamp', last24Hours.toIso8601String())
          .lte('event_timestamp', now.toIso8601String());

      // Get feedback submission rates
      final hourlyFeedback = await Supabase.instance.client
          .from('stage_feedback')
          .select('COUNT(*) as feedback_count')
          .gte('feedback_timestamp', lastHour.toIso8601String())
          .lte('feedback_timestamp', now.toIso8601String());

      final dailyFeedback = await Supabase.instance.client
          .from('stage_feedback')
          .select('COUNT(*) as feedback_count')
          .gte('feedback_timestamp', last24Hours.toIso8601String())
          .lte('feedback_timestamp', now.toIso8601String());

      return {
        'events': {
          'hourly': hourlyData.isNotEmpty ? hourlyData.first['event_count'] : 0,
          'daily': dailyData.isNotEmpty ? dailyData.first['event_count'] : 0,
        },
        'feedback': {
          'hourly': hourlyFeedback.isNotEmpty
              ? hourlyFeedback.first['feedback_count']
              : 0,
          'daily': dailyFeedback.isNotEmpty
              ? dailyFeedback.first['feedback_count']
              : 0,
        },
        'timestamp': now.toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting data ingestion metrics: $e');
      return {};
    }
  }

  /// Handle analytics updates
  void _handleAnalyticsUpdate(
    String table,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final analyticsData = {
      'type': 'analytics_update',
      'table': table,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };

    controller.add(analyticsData);
  }

  /// Handle flight tracking updates
  void _handleFlightTrackingUpdate(
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final trackingData = {
      'type': 'flight_tracking_update',
      'table': payload.table,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };

    controller.add(trackingData);
  }

  /// Handle alert updates
  void _handleAlertUpdate(
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final alertData = {
      'type': 'alert',
      'table': payload.table,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
      'priority': _getAlertPriority(payload.table, payload.newRecord),
    };

    controller.add(alertData);
  }

  /// Get alert priority based on data
  String _getAlertPriority(String table, Map<String, dynamic>? data) {
    if (table == 'stage_feedback' && data != null) {
      final rating = data['overall_rating'];
      if (rating != null && rating < 2) return 'high';
      if (rating != null && rating < 3) return 'medium';
    }

    if (table == 'journey_events' && data != null) {
      final eventType = data['event_type'];
      if (['delay', 'cancellation'].contains(eventType)) return 'high';
      if (['gate_change', 'terminal_change'].contains(eventType))
        return 'medium';
    }

    return 'low';
  }

  /// Export dashboard data for external systems
  Future<Map<String, dynamic>> exportDashboardData({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? dataTypes,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();
      final types = dataTypes ?? ['journeys', 'events', 'feedback', 'reviews'];

      final exportData = <String, dynamic>{};

      if (types.contains('journeys')) {
        exportData['journeys'] = await Supabase.instance.client
            .from('journeys')
            .select('*')
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String());
      }

      if (types.contains('events')) {
        exportData['events'] = await Supabase.instance.client
            .from('journey_events')
            .select('*')
            .gte('event_timestamp', start.toIso8601String())
            .lte('event_timestamp', end.toIso8601String());
      }

      if (types.contains('feedback')) {
        exportData['feedback'] = await Supabase.instance.client
            .from('stage_feedback')
            .select('*')
            .gte('feedback_timestamp', start.toIso8601String())
            .lte('feedback_timestamp', end.toIso8601String());
      }

      if (types.contains('reviews')) {
        exportData['airline_reviews'] = await Supabase.instance.client
            .from('airline_reviews')
            .select('*')
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String());

        exportData['airport_reviews'] = await Supabase.instance.client
            .from('airport_reviews')
            .select('*')
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String());
      }

      exportData['export_metadata'] = {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'data_types': types,
        'exported_at': DateTime.now().toIso8601String(),
      };

      return exportData;
    } catch (e) {
      debugPrint('❌ Error exporting dashboard data: $e');
      return {};
    }
  }

  /// Cleanup dashboard service
  void dispose() {
    for (final stream in _dashboardStreams.values) {
      stream.close();
    }

    for (final channel in _dashboardChannels.values) {
      channel.unsubscribe();
    }

    _dashboardStreams.clear();
    _dashboardChannels.clear();
  }
}
