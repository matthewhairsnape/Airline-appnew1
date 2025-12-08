import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cirium_api_service.dart';
import 'flight_status_monitor.dart';
import 'supabase_service.dart';
import 'push_notification_service.dart';

class FlightStatusIntegration {
  static final Map<String, StreamSubscription> _subscriptions = {};

  /// Initialize the flight status integration
  static Future<void> initialize({
    required String ciriumAppId,
    required String ciriumAppKey,
  }) async {
    // Initialize Cirium API
    CiriumApiService.initialize(
      appId: ciriumAppId,
      appKey: ciriumAppKey,
    );

    // Initialize push notifications
    await PushNotificationService.initialize();

    debugPrint('✅ Flight status integration initialized');
  }

  /// Start monitoring a journey for real-time updates
  static Future<void> startJourneyMonitoring({
    required String journeyId,
    required String userId,
    Duration checkInterval = const Duration(minutes: 5),
  }) async {
    try {
      // Get journey details from Supabase
      final journeyData =
          await SupabaseService.client.from('journeys').select('''
            *,
            flight:flights (
              *,
              airline:airlines (*)
            )
          ''').eq('id', journeyId).single();

      if (journeyData == null) {
        debugPrint('❌ Journey not found: $journeyId');
        return;
      }

      final flight = journeyData['flight'] as Map<String, dynamic>;
      final airline = flight['airline'] as Map<String, dynamic>;
      final carrier = airline['iata_code'] as String;
      final flightNumber = flight['flight_number'] as String;
      final scheduledDeparture =
          DateTime.parse(flight['scheduled_departure'] as String);

      // Start monitoring
      FlightStatusMonitor.startMonitoring(
        journeyId: journeyId,
        carrier: carrier,
        flightNumber: flightNumber,
        departureDate: scheduledDeparture,
        userId: userId,
        checkInterval: checkInterval,
      );

      debugPrint('✅ Started monitoring journey: $journeyId');
    } catch (e) {
      debugPrint('❌ Error starting journey monitoring: $e');
    }
  }

  /// Stop monitoring a specific journey
  static void stopJourneyMonitoring(String journeyId) {
    FlightStatusMonitor.stopMonitoring(journeyId);
    debugPrint('⏹️ Stopped monitoring journey: $journeyId');
  }

  /// Stop all journey monitoring
  static void stopAllJourneyMonitoring() {
    FlightStatusMonitor.stopAllMonitoring();
    debugPrint('⏹️ Stopped all journey monitoring');
  }

  /// Manually check flight status and update
  static Future<Map<String, dynamic>?> checkFlightStatus({
    required String journeyId,
    required String carrier,
    required String flightNumber,
    required DateTime departureDate,
  }) async {
    try {
      // Get flight status from Cirium
      final ciriumData = await CiriumApiService.getFlightStatus(
        carrier: carrier,
        flightNumber: flightNumber,
        departureDate: departureDate,
      );

      if (ciriumData == null) {
        debugPrint('❌ No data received from Cirium');
        return null;
      }

      // Parse the flight status
      final flightData = CiriumApiService.parseFlightStatus(ciriumData);
      if (flightData == null) {
        debugPrint('❌ Failed to parse Cirium data');
        return null;
      }

      final currentStatus = flightData['status'] as String?;
      final currentPhase = CiriumApiService.mapStatusToPhase(currentStatus);

      // Update journey in Supabase
      await SupabaseService.client.from('journeys').update({
        'current_phase': currentPhase,
        'status': _mapPhaseToStatus(currentPhase),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', journeyId);

      // Add journey event
      await SupabaseService.client.from('journey_events').insert({
        'journey_id': journeyId,
        'event_type': 'status_change',
        'title': _getEventTitle(currentPhase),
        'description': _getEventDescription(currentPhase, flightData),
        'event_timestamp': DateTime.now().toIso8601String(),
        'metadata': flightData,
      });

      debugPrint('✅ Flight status updated: $currentPhase');
      return flightData;
    } catch (e) {
      debugPrint('❌ Error checking flight status: $e');
      return null;
    }
  }

  /// Subscribe to real-time journey updates
  static StreamSubscription<Map<String, dynamic>> subscribeToJourneyUpdates(
    String journeyId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    final subscription = SupabaseService.client
        .channel('journey_updates:$journeyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'journeys',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: journeyId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'journey_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'journey_id',
            value: journeyId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();

    _subscriptions[journeyId] = subscription;
    return subscription;
  }

  /// Unsubscribe from journey updates
  static void unsubscribeFromJourneyUpdates(String journeyId) {
    _subscriptions[journeyId]?.cancel();
    _subscriptions.remove(journeyId);
  }

  /// Get journey status history
  static Future<List<Map<String, dynamic>>> getJourneyStatusHistory(
    String journeyId,
  ) async {
    try {
      final data = await SupabaseService.client
          .from('journey_events')
          .select('*')
          .eq('journey_id', journeyId)
          .order('event_timestamp', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error getting journey status history: $e');
      return [];
    }
  }

  /// Get active monitoring count
  static int get activeMonitoringCount =>
      FlightStatusMonitor.activeMonitorCount;

  /// Check if journey is being monitored
  static bool isJourneyMonitored(String journeyId) =>
      FlightStatusMonitor.isMonitoring(journeyId);

  /// Send test notification
  static Future<void> sendTestNotification(String userId) async {
    await PushNotificationService.sendNotificationToUser(
      userId: userId,
      title: 'Test Notification',
      body: 'This is a test notification from your airline app!',
      data: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Helper function to map phase to status
  static String _mapPhaseToStatus(String phase) {
    switch (phase) {
      case 'pre_check_in':
      case 'boarding':
      case 'gate_closed':
        return 'scheduled';
      case 'departed':
      case 'in_flight':
      case 'landing':
        return 'in_progress';
      case 'landed':
      case 'arrived':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      case 'diverted':
        return 'diverted';
      default:
        return 'unknown';
    }
  }

  /// Helper function to get event title
  static String _getEventTitle(String phase) {
    switch (phase) {
      case 'boarding':
        return 'Flight Boarding';
      case 'gate_closed':
        return 'Gate Closed';
      case 'departed':
        return 'Flight Departed';
      case 'in_flight':
        return 'In Flight';
      case 'landed':
        return 'Flight Landed';
      case 'arrived':
        return 'Flight Arrived';
      case 'cancelled':
        return 'Flight Cancelled';
      case 'delayed':
        return 'Flight Delayed';
      default:
        return 'Status Update';
    }
  }

  /// Helper function to get event description
  static String _getEventDescription(
      String phase, Map<String, dynamic> flightData) {
    final carrier = flightData['carrier'] ?? '';
    final flightNumber = flightData['flightNumber'] ?? '';
    final flight = '$carrier$flightNumber';

    switch (phase) {
      case 'boarding':
        return 'Flight $flight is now boarding. Please proceed to the gate.';
      case 'gate_closed':
        return 'Gate is now closed for flight $flight. Please contact airline staff.';
      case 'departed':
        return 'Flight $flight has departed. Enjoy your journey!';
      case 'in_flight':
        return 'Flight $flight is in progress.';
      case 'landed':
        return 'Flight $flight has landed.';
      case 'arrived':
        return 'Flight $flight has arrived. Welcome to your destination!';
      case 'cancelled':
        return 'Flight $flight has been cancelled. Please contact airline for assistance.';
      case 'delayed':
        return 'Flight $flight has been delayed. Please check for updates.';
      default:
        return 'Flight $flight status has been updated.';
    }
  }
}
