import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/services/cirium_flight_tracking_service.dart';
import 'package:airline_app/services/flight_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Provider for managing flight tracking state
final flightTrackingServiceProvider = Provider<CiriumFlightTrackingService>((ref) {
  return CiriumFlightTrackingService();
});

/// Provider for notification service
final notificationServiceProvider = Provider<FlightNotificationService>((ref) {
  return FlightNotificationService();
});

/// State class for flight tracking
class FlightTrackingState {
  final Map<String, FlightTrackingModel> trackedFlights;
  final bool isTracking;
  final String? error;

  FlightTrackingState({
    this.trackedFlights = const {},
    this.isTracking = false,
    this.error,
  });

  FlightTrackingState copyWith({
    Map<String, FlightTrackingModel>? trackedFlights,
    bool? isTracking,
    String? error,
  }) {
    return FlightTrackingState(
      trackedFlights: trackedFlights ?? this.trackedFlights,
      isTracking: isTracking ?? this.isTracking,
      error: error,
    );
  }
}

/// Notifier for flight tracking
class FlightTrackingNotifier extends StateNotifier<FlightTrackingState> {
  FlightTrackingNotifier(this.trackingService, this.notificationService)
      : super(FlightTrackingState()) {
    _listenToFlightUpdates();
  }

  final CiriumFlightTrackingService trackingService;
  final FlightNotificationService notificationService;

  /// Listen to flight updates from the tracking service
  void _listenToFlightUpdates() {
    trackingService.flightUpdates.listen((flight) {
      _handleFlightUpdate(flight);
    });
  }

  /// Handle flight phase update
  void _handleFlightUpdate(FlightTrackingModel flight) {
    debugPrint('🔄 Flight update received: ${flight.pnr} - ${flight.currentPhase}');

    // Update state
    final updatedFlights = Map<String, FlightTrackingModel>.from(state.trackedFlights);
    updatedFlights[flight.pnr] = flight;

    state = state.copyWith(trackedFlights: updatedFlights);

    // Send notification for phase change
    notificationService.notifyFlightPhaseChange(flight);
  }

  /// Start tracking a new flight
  Future<bool> trackFlight({
    required String carrier,
    required String flightNumber,
    required DateTime flightDate,
    required String departureAirport,
    required String pnr,
  }) async {
    try {
      state = state.copyWith(isTracking: true, error: null);

      final flight = await trackingService.verifyAndTrackFlight(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: flightDate,
        departureAirport: departureAirport,
        pnr: pnr,
      );

      if (flight == null) {
        state = state.copyWith(
          isTracking: false,
          error: 'Failed to verify flight with Cirium',
        );
        return false;
      }

      final updatedFlights = Map<String, FlightTrackingModel>.from(state.trackedFlights);
      updatedFlights[pnr] = flight;

      state = state.copyWith(
        trackedFlights: updatedFlights,
        isTracking: false,
        error: null,
      );

      debugPrint('✅ Flight tracking started for $pnr');
      return true;
    } catch (e) {
      debugPrint('❌ Error tracking flight: $e');
      state = state.copyWith(
        isTracking: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Stop tracking a flight
  void stopTrackingFlight(String pnr) {
    trackingService.stopTracking(pnr);

    final updatedFlights = Map<String, FlightTrackingModel>.from(state.trackedFlights);
    updatedFlights.remove(pnr);

    state = state.copyWith(trackedFlights: updatedFlights);
    debugPrint('🛑 Stopped tracking flight: $pnr');
  }

  /// Get a specific tracked flight
  FlightTrackingModel? getFlight(String pnr) {
    return state.trackedFlights[pnr];
  }

  /// Get all tracked flights
  List<FlightTrackingModel> getAllFlights() {
    return state.trackedFlights.values.toList();
  }

  /// Clear all tracked flights
  void clearAllFlights() {
    for (final pnr in state.trackedFlights.keys) {
      trackingService.stopTracking(pnr);
    }
    state = FlightTrackingState();
    debugPrint('🧹 Cleared all tracked flights');
  }
}

/// Provider for flight tracking state
final flightTrackingProvider =
    StateNotifierProvider<FlightTrackingNotifier, FlightTrackingState>((ref) {
  final trackingService = ref.watch(flightTrackingServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return FlightTrackingNotifier(trackingService, notificationService);
});

