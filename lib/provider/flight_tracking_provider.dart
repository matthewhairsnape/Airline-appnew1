import 'dart:convert';
import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/models/stage_feedback_model.dart';
import 'package:airline_app/services/cirium_flight_tracking_service.dart';
import 'package:airline_app/services/flight_notification_service.dart';
import 'package:airline_app/services/stage_question_service.dart';
import 'package:airline_app/services/journey_database_service.dart';
import 'package:airline_app/services/journey_notification_service.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/services/connectivity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing flight tracking state
final flightTrackingServiceProvider =
    Provider<CiriumFlightTrackingService>((ref) {
  return CiriumFlightTrackingService();
});

/// Provider for notification service
final notificationServiceProvider = Provider<FlightNotificationService>((ref) {
  return FlightNotificationService();
});

/// State class for flight tracking
class FlightTrackingState {
  final Map<String, FlightTrackingModel> trackedFlights;
  final Map<String, FlightTrackingModel> completedFlights;
  final bool isTracking;
  final String? error;

  FlightTrackingState({
    this.trackedFlights = const {},
    this.completedFlights = const {},
    this.isTracking = false,
    this.error,
  });

  FlightTrackingState copyWith({
    Map<String, FlightTrackingModel>? trackedFlights,
    Map<String, FlightTrackingModel>? completedFlights,
    bool? isTracking,
    String? error,
  }) {
    return FlightTrackingState(
      trackedFlights: trackedFlights ?? this.trackedFlights,
      completedFlights: completedFlights ?? this.completedFlights,
      isTracking: isTracking ?? this.isTracking,
      error: error,
    );
  }

  /// Get all flights (active + completed)
  List<FlightTrackingModel> getAllFlights() {
    return [...trackedFlights.values, ...completedFlights.values];
  }
}

/// Notifier for flight tracking
class FlightTrackingNotifier extends StateNotifier<FlightTrackingState> {
  FlightTrackingNotifier(this.trackingService, this.notificationService)
      : super(FlightTrackingState()) {
    _listenToFlightUpdates();
    _loadCompletedFlights();
  }

  final CiriumFlightTrackingService trackingService;
  final FlightNotificationService notificationService;

  /// Listen to flight updates from the tracking service
  void _listenToFlightUpdates() {
    trackingService.flightUpdates.listen((flight) {
      _handleFlightUpdate(flight);
    });
  }

  /// Handle flight phase update or landing time update
  void _handleFlightUpdate(FlightTrackingModel flight) {
    // Use journeyId as unique key (allows multiple flights with same PNR)
    final key = flight.journeyId ?? flight.pnr;
    
    // Get existing flight to compare
    final existingFlight = state.trackedFlights[key] ?? state.completedFlights[key];
    
    // Check if arrival time changed (real-time landing time update)
    final arrivalTimeChanged = existingFlight != null && 
        existingFlight.arrivalTime != flight.arrivalTime;
    
    debugPrint(
        '🔄 Flight update received: ${flight.pnr} - ${flight.currentPhase} (key: $key)');
    if (arrivalTimeChanged) {
      debugPrint('🕐 Landing time updated: ${existingFlight.arrivalTime} → ${flight.arrivalTime}');
    }

    // Send push notification for phase change
    if (existingFlight == null || existingFlight.currentPhase != flight.currentPhase) {
      _sendPhaseChangeNotification(flight);
    }

    // Check if flight is completed
    if (flight.currentPhase == FlightPhase.completed) {
      // Move to completed flights
      final updatedTrackedFlights =
          Map<String, FlightTrackingModel>.from(state.trackedFlights);
      final updatedCompletedFlights =
          Map<String, FlightTrackingModel>.from(state.completedFlights);

      updatedTrackedFlights.remove(key);
      updatedCompletedFlights[key] = flight;

      state = state.copyWith(
        trackedFlights: updatedTrackedFlights,
        completedFlights: updatedCompletedFlights,
      );

      // Save completed flight to persistent storage
      _saveCompletedFlights(updatedCompletedFlights);

      debugPrint('✅ Flight completed and moved to history: ${flight.pnr} (key: $key)');
    } else {
      // Update active flight (even if only arrival time changed)
      final updatedFlights =
          Map<String, FlightTrackingModel>.from(state.trackedFlights);
      updatedFlights[key] = flight;

      state = state.copyWith(trackedFlights: updatedFlights);

      // Send notification for phase change (only if phase actually changed)
      if (existingFlight == null || existingFlight.currentPhase != flight.currentPhase) {
        notificationService.notifyFlightPhaseChange(flight);
      }
    }
  }
  
  /// Public method to update a flight (for real-time landing time updates)
  void updateFlight(FlightTrackingModel flight) {
    _handleFlightUpdate(flight);
  }

  /// Send push notification for flight phase change
  Future<void> _sendPhaseChangeNotification(FlightTrackingModel flight) async {
    try {
      // Get current user ID
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user.id == null) return;

      final userId = session!.user.id;
      final flightInfo = '${flight.carrier}${flight.flightNumber}';

      // Send notification based on phase
      await JourneyNotificationService.sendFlightPhaseNotification(
        userId: userId,
        journeyId: flight.journeyId ?? flight.flightId,
        phase: flight.currentPhase,
        flightInfo: flightInfo,
        additionalData: {
          'pnr': flight.pnr,
          'departure_airport': flight.departureAirport,
          'arrival_airport': flight.arrivalAirport,
          'gate': flight.gate,
          'terminal': flight.terminal,
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending phase change notification: $e');
    }
  }

  /// Start tracking a new flight
  Future<bool> trackFlight({
    required String carrier,
    required String flightNumber,
    required DateTime flightDate,
    required String departureAirport,
    required String pnr,
    Map<String, dynamic>? existingFlightData,
  }) async {
    try {
      state = state.copyWith(isTracking: true, error: null);

      final flight = await trackingService.verifyAndTrackFlight(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: flightDate,
        departureAirport: departureAirport,
        pnr: pnr,
        existingFlightData: existingFlightData,
      );

      if (flight == null) {
        state = state.copyWith(
          isTracking: false,
          error: 'Failed to verify flight with Cirium',
        );
        return false;
      }

      final updatedFlights =
          Map<String, FlightTrackingModel>.from(state.trackedFlights);
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

    final updatedFlights =
        Map<String, FlightTrackingModel>.from(state.trackedFlights);
    updatedFlights.remove(pnr);

    state = state.copyWith(trackedFlights: updatedFlights);
    debugPrint('🛑 Stopped tracking flight: $pnr');
  }

  /// Get a specific tracked flight
  FlightTrackingModel? getFlight(String pnr) {
    return state.trackedFlights[pnr];
  }

  /// Get all tracked flights (active only)
  List<FlightTrackingModel> getAllActiveFlights() {
    return state.trackedFlights.values.toList();
  }

  /// Get all flights (active + completed)
  List<FlightTrackingModel> getAllFlights() {
    return state.getAllFlights();
  }

  /// Get completed flights only
  List<FlightTrackingModel> getCompletedFlights() {
    return state.completedFlights.values.toList();
  }

  /// Clear all tracked flights (but keep completed flights)
  void clearAllActiveFlights() {
    for (final pnr in state.trackedFlights.keys) {
      trackingService.stopTracking(pnr);
    }
    state = state.copyWith(trackedFlights: {});
    debugPrint('🧹 Cleared all active flights');
  }

  /// Clear all flights (active + completed)
  void clearAllFlights() {
    for (final pnr in state.trackedFlights.keys) {
      trackingService.stopTracking(pnr);
    }
    state = FlightTrackingState();
    _clearCompletedFlights();
    debugPrint('🧹 Cleared all flights');
  }

  /// Load completed flights from persistent storage
  Future<void> _loadCompletedFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedFlightsJson = prefs.getString('completed_flights');

      if (completedFlightsJson != null) {
        final Map<String, dynamic> completedFlightsMap =
            json.decode(completedFlightsJson);
        final Map<String, FlightTrackingModel> completedFlights = {};

        completedFlightsMap.forEach((pnr, flightJson) {
          try {
            completedFlights[pnr] = FlightTrackingModel.fromJson(flightJson);
          } catch (e) {
            debugPrint('❌ Error loading completed flight $pnr: $e');
          }
        });

        state = state.copyWith(completedFlights: completedFlights);
        debugPrint(
            '📚 Loaded ${completedFlights.length} completed flights from storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading completed flights: $e');
    }
  }

  /// Load active flights from persistent storage
  Future<void> _loadActiveFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeFlightsJson = prefs.getString('active_flights');

      if (activeFlightsJson != null) {
        final Map<String, dynamic> activeFlightsMap =
            json.decode(activeFlightsJson);
        final Map<String, FlightTrackingModel> activeFlights = {};

        activeFlightsMap.forEach((pnr, flightJson) {
          try {
            activeFlights[pnr] = FlightTrackingModel.fromJson(flightJson);
          } catch (e) {
            debugPrint('❌ Error loading active flight $pnr: $e');
          }
        });

        state = state.copyWith(trackedFlights: activeFlights);
        debugPrint(
            '📚 Loaded ${activeFlights.length} active flights from storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading active flights: $e');
    }
  }

  /// Save active flights to persistent storage
  Future<void> _saveActiveFlights(
      Map<String, FlightTrackingModel> activeFlights) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> activeFlightsMap = {};

      activeFlights.forEach((pnr, flight) {
        activeFlightsMap[pnr] = flight.toJson();
      });

      await prefs.setString(
          'active_flights', json.encode(activeFlightsMap));
      debugPrint(
          '💾 Saved ${activeFlights.length} active flights to storage');
    } catch (e) {
      debugPrint('❌ Error saving active flights: $e');
    }
  }

  /// Sync journeys from database for a specific user
  /// If offline, loads from local storage instead
  Future<void> syncJourneysFromDatabase(String userId, {bool forceOnline = false}) async {
    try {
      debugPrint('🔄 Syncing journeys from database for user: $userId');

      // Check connectivity
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.checkConnectivity();

      if (!isOnline && !forceOnline) {
        debugPrint('📴 Offline mode: Loading flights from local storage');
        // Load from local storage when offline
        await _loadActiveFlights();
        await _loadCompletedFlights();
        debugPrint('✅ Loaded flights from local storage (offline mode)');
        return;
      }

      debugPrint('📡 Online mode: Fetching flights from database');
      final databaseFlights =
          await JourneyDatabaseService.syncUserJourneys(userId);

      if (databaseFlights.isEmpty) {
        debugPrint('📭 No journeys found in database for user: $userId');
        // Still load from local storage as fallback
        await _loadActiveFlights();
        await _loadCompletedFlights();
        return;
      }

      // Separate active and completed flights
      // Use journeyId as key to allow multiple flights with same PNR
      final Map<String, FlightTrackingModel> activeFlights = {};
      final Map<String, FlightTrackingModel> completedFlights = {};

      for (final flight in databaseFlights) {
        // Use journeyId as unique key (allows multiple flights with same PNR)
        final key = flight.journeyId ?? flight.pnr;  // Fallback to PNR if no journeyId
        
        if (flight.currentPhase == FlightPhase.completed) {
          completedFlights[key] = flight;
          debugPrint('✅ Added completed flight: ${flight.flightNumber} (key: $key)');
        } else {
          activeFlights[key] = flight;
          debugPrint('✅ Added active flight: ${flight.flightNumber} (key: $key)');
        }
      }

      // Update state with database flights
      state = state.copyWith(
        trackedFlights: activeFlights,
        completedFlights: completedFlights,
      );

      // Save both active and completed flights to local storage for offline access
      if (activeFlights.isNotEmpty) {
        _saveActiveFlights(activeFlights);
      }
      if (completedFlights.isNotEmpty) {
        _saveCompletedFlights(completedFlights);
      }

      debugPrint(
          '✅ Synced ${activeFlights.length} active and ${completedFlights.length} completed flights from database');
    } catch (e) {
      debugPrint('❌ Error syncing journeys from database: $e');
      debugPrint('⚠️ Falling back to local storage');
      // Fallback to local storage on error
      await _loadActiveFlights();
      await _loadCompletedFlights();
    }
  }

  /// Save completed flights to persistent storage
  Future<void> _saveCompletedFlights(
      Map<String, FlightTrackingModel> completedFlights) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> completedFlightsMap = {};

      completedFlights.forEach((pnr, flight) {
        completedFlightsMap[pnr] = flight.toJson();
      });

      await prefs.setString(
          'completed_flights', json.encode(completedFlightsMap));
      debugPrint(
          '💾 Saved ${completedFlights.length} completed flights to storage');
    } catch (e) {
      debugPrint('❌ Error saving completed flights: $e');
    }
  }

  /// Clear completed flights from persistent storage
  Future<void> _clearCompletedFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('completed_flights');
      debugPrint('🗑️ Cleared completed flights from storage');
    } catch (e) {
      debugPrint('❌ Error clearing completed flights: $e');
    }
  }
}

/// Provider for flight tracking state
final flightTrackingProvider =
    StateNotifierProvider<FlightTrackingNotifier, FlightTrackingState>((ref) {
  final trackingService = ref.watch(flightTrackingServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return FlightTrackingNotifier(trackingService, notificationService);
});
