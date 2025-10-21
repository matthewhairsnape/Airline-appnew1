import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cirium_api_service.dart';
import 'supabase_service.dart';
import 'push_notification_service.dart';

class FlightStatusMonitor {
  static final Map<String, Timer> _activeMonitors = {};
  static final Map<String, String> _lastKnownStatus = {};

  /// Start monitoring a flight for status changes
  static void startMonitoring({
    required String journeyId,
    required String carrier,
    required String flightNumber,
    required DateTime departureDate,
    required String userId,
    Duration checkInterval = const Duration(minutes: 5),
  }) {
    // Stop existing monitor if any
    stopMonitoring(journeyId);

    debugPrint('🔄 Starting flight status monitoring for journey: $journeyId');

    _activeMonitors[journeyId] = Timer.periodic(checkInterval, (timer) async {
      await _checkFlightStatus(
        journeyId: journeyId,
        carrier: carrier,
        flightNumber: flightNumber,
        departureDate: departureDate,
        userId: userId,
      );
    });

    // Check immediately
    _checkFlightStatus(
      journeyId: journeyId,
      carrier: carrier,
      flightNumber: flightNumber,
      departureDate: departureDate,
      userId: userId,
    );
  }

  /// Stop monitoring a specific flight
  static void stopMonitoring(String journeyId) {
    _activeMonitors[journeyId]?.cancel();
    _activeMonitors.remove(journeyId);
    _lastKnownStatus.remove(journeyId);
    debugPrint('⏹️ Stopped monitoring journey: $journeyId');
  }

  /// Stop all active monitors
  static void stopAllMonitoring() {
    for (final timer in _activeMonitors.values) {
      timer.cancel();
    }
    _activeMonitors.clear();
    _lastKnownStatus.clear();
    debugPrint('⏹️ Stopped all flight monitoring');
  }

  /// Check flight status and update if changed
  static Future<void> _checkFlightStatus({
    required String journeyId,
    required String carrier,
    required String flightNumber,
    required DateTime departureDate,
    required String userId,
  }) async {
    try {
      // Get flight status from Cirium
      final ciriumData = await CiriumApiService.getFlightStatus(
        carrier: carrier,
        flightNumber: flightNumber,
        departureDate: departureDate,
      );

      if (ciriumData == null) {
        debugPrint('❌ No data received from Cirium for journey: $journeyId');
        return;
      }

      // Parse the flight status
      final flightData = CiriumApiService.parseFlightStatus(ciriumData);
      if (flightData == null) {
        debugPrint('❌ Failed to parse Cirium data for journey: $journeyId');
        return;
      }

      final currentStatus = flightData['status'] as String?;
      final currentPhase = CiriumApiService.mapStatusToPhase(currentStatus);

      // Check if status has changed
      final lastStatus = _lastKnownStatus[journeyId];
      if (lastStatus == currentPhase) {
        debugPrint('📊 No status change for journey: $journeyId (still $currentPhase)');
        return;
      }

      debugPrint('🔄 Status changed for journey: $journeyId from $lastStatus to $currentPhase');

      // Update the journey in Supabase
      await _updateJourneyStatus(journeyId, currentPhase, flightData);

      // Send push notification if status changed
      if (lastStatus != null) {
        await _sendStatusNotification(userId, currentPhase, flightData);
      }

      // Update last known status
      _lastKnownStatus[journeyId] = currentPhase;

      // Stop monitoring if flight has ended
      if (_shouldStopMonitoring(currentPhase)) {
        stopMonitoring(journeyId);
      }

    } catch (e) {
      debugPrint('❌ Error checking flight status for journey $journeyId: $e');
    }
  }

  /// Update journey status in Supabase
  static Future<void> _updateJourneyStatus(
    String journeyId,
    String newPhase,
    Map<String, dynamic> flightData,
  ) async {
    try {
      // Update journey phase
      await SupabaseService.client
          .from('journeys')
          .update({
            'current_phase': newPhase,
            'status': _mapPhaseToStatus(newPhase),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', journeyId);

      // Add journey event
      await SupabaseService.client
          .from('journey_events')
          .insert({
            'journey_id': journeyId,
            'event_type': 'status_change',
            'title': _getEventTitle(newPhase),
            'description': _getEventDescription(newPhase, flightData),
            'event_timestamp': DateTime.now().toIso8601String(),
            'metadata': flightData,
          });

      debugPrint('✅ Updated journey status in Supabase: $journeyId -> $newPhase');
    } catch (e) {
      debugPrint('❌ Error updating journey status in Supabase: $e');
    }
  }

  /// Send push notification for status change
  static Future<void> _sendStatusNotification(
    String userId,
    String phase,
    Map<String, dynamic> flightData,
  ) async {
    try {
      final message = CiriumApiService.getNotificationMessage(phase, flightData);
      
      await PushNotificationService.sendNotificationToUser(
        userId: userId,
        title: 'Flight Status Update',
        body: message,
        data: {
          'type': 'flight_status_update',
          'phase': phase,
          'flight_data': jsonEncode(flightData),
        },
      );

      debugPrint('✅ Sent push notification for phase: $phase');
    } catch (e) {
      debugPrint('❌ Error sending push notification: $e');
    }
  }

  /// Check if monitoring should stop for this phase
  static bool _shouldStopMonitoring(String phase) {
    return [
      'arrived',
      'cancelled',
      'diverted',
      'unknown',
    ].contains(phase);
  }

  /// Map phase to status
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

  /// Get event title for phase
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

  /// Get event description for phase
  static String _getEventDescription(String phase, Map<String, dynamic> flightData) {
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

  /// Get active monitoring count
  static int get activeMonitorCount => _activeMonitors.length;

  /// Check if journey is being monitored
  static bool isMonitoring(String journeyId) => _activeMonitors.containsKey(journeyId);
}
