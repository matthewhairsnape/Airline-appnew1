import 'dart:async';
import 'dart:convert';
import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service for real-time flight tracking using Cirium API
class CiriumFlightTrackingService {
  Timer? _pollingTimer;
  final Map<String, FlightTrackingModel> _activeFlights = {};
  final StreamController<FlightTrackingModel> _flightUpdateController =
      StreamController<FlightTrackingModel>.broadcast();

  Stream<FlightTrackingModel> get flightUpdates =>
      _flightUpdateController.stream;

  /// Verify and start tracking a flight from boarding pass data
  Future<FlightTrackingModel?> verifyAndTrackFlight({
    required String carrier,
    required String flightNumber,
    required DateTime flightDate,
    required String departureAirport,
    required String pnr,
  }) async {
    try {
      debugPrint(
          '🛫 Starting flight verification for $carrier$flightNumber on ${flightDate.toString()}');

      // Fetch initial flight data from Cirium
      final Map<String, dynamic> flightInfo = await _fetchFlightStatus(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: flightDate,
        departureAirport: departureAirport,
      );

      if (flightInfo['error'] != null) {
        debugPrint('❌ Error fetching flight data: ${flightInfo['error']}');
        return null;
      }

      if (flightInfo['flightStatuses'] == null ||
          (flightInfo['flightStatuses'] as List).isEmpty) {
        debugPrint('❌ No flight status found');
        return null;
      }

      final flightStatus = flightInfo['flightStatuses'][0];

      // Create flight tracking model
      final flightTracking = FlightTrackingModel(
        flightId: flightStatus['flightId']?.toString() ?? pnr,
        pnr: pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureTime:
            DateTime.parse(flightStatus['departureDate']['dateLocal']),
        arrivalTime: DateTime.parse(flightStatus['arrivalDate']['dateLocal']),
        departureAirport: flightStatus['departureAirportFsCode'],
        arrivalAirport: flightStatus['arrivalAirportFsCode'],
        currentPhase: _determineFlightPhase(flightStatus),
        phaseStartTime: DateTime.now(),
        ciriumData: flightStatus,
        events: _extractEvents(flightStatus),
        isVerified: true,
      );

      // Store and start tracking
      _activeFlights[pnr] = flightTracking;
      _startPolling(pnr);

      debugPrint('✅ Flight verified and tracking started');
      return flightTracking;
    } catch (e) {
      debugPrint('❌ Error in verifyAndTrackFlight: $e');
      return null;
    }
  }

  /// Fetch current flight status from Cirium API
  Future<Map<String, dynamic>> _fetchFlightStatus({
    required String carrier,
    required String flightNumber,
    required DateTime flightDate,
    required String departureAirport,
  }) async {
    try {
      final url = '$ciriumUrl/json/flight/status/$carrier/$flightNumber/dep/'
          '${flightDate.year}/${flightDate.month}/${flightDate.day}'
          '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';

      debugPrint('📡 Fetching flight status from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ API returned status code: ${response.statusCode}');
        return {'error': 'Failed to fetch flight data: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('❌ Exception in _fetchFlightStatus: $e');
      return {'error': e.toString()};
    }
  }

  /// Determine current flight phase from Cirium data
  FlightPhase _determineFlightPhase(Map<String, dynamic> flightStatus) {
    final operationalTimes = flightStatus['operationalTimes'] ?? {};
    final now = DateTime.now();
    final departureTime =
        DateTime.parse(flightStatus['departureDate']['dateLocal']);

    // Check for actual times
    if (operationalTimes['actualGateArrival'] != null) {
      final arrivalDateTime =
          DateTime.parse(operationalTimes['actualGateArrival']['dateLocal']);
      if (now.isAfter(arrivalDateTime.add(Duration(minutes: 30)))) {
        return FlightPhase.completed;
      }
      return FlightPhase.baggageClaim;
    }

    if (operationalTimes['actualRunwayArrival'] != null) {
      return FlightPhase.landed;
    }

    if (operationalTimes['actualRunwayDeparture'] != null) {
      return FlightPhase.inFlight;
    }

    if (operationalTimes['actualGateDeparture'] != null) {
      return FlightPhase.departed;
    }

    if (operationalTimes['estimatedGateDeparture'] != null ||
        operationalTimes['scheduledGateDeparture'] != null) {
      final gateTime = operationalTimes['estimatedGateDeparture'] ??
          operationalTimes['scheduledGateDeparture'];
      final gateDeparture = DateTime.parse(gateTime['dateLocal']);

      // If within 2 hours of departure, boarding likely started
      if (now.isAfter(gateDeparture.subtract(Duration(hours: 2))) &&
          now.isBefore(gateDeparture)) {
        return FlightPhase.boarding;
      }
    }

    // Check-in typically opens 24-48 hours before departure
    if (now.isAfter(departureTime.subtract(Duration(hours: 48))) &&
        now.isBefore(departureTime.subtract(Duration(hours: 2)))) {
      return FlightPhase.checkInOpen;
    }

    return FlightPhase.preCheckIn;
  }

  /// Extract flight events from Cirium data
  List<FlightEvent> _extractEvents(Map<String, dynamic> flightStatus) {
    final List<FlightEvent> events = [];
    final operationalTimes = flightStatus['operationalTimes'] ?? {};

    // Check for gate changes
    if (flightStatus['airportResources'] != null) {
      final resources = flightStatus['airportResources'];
      if (resources['departureGate'] != null) {
        events.add(FlightEvent(
          eventType: 'GATE_ASSIGNED',
          timestamp: DateTime.now(),
          description: 'Gate ${resources['departureGate']} assigned',
          metadata: {'gate': resources['departureGate']},
        ));
      }
    }

    // Add operational events
    if (operationalTimes['actualGateDeparture'] != null) {
      events.add(FlightEvent(
        eventType: 'DEPARTED',
        timestamp:
            DateTime.parse(operationalTimes['actualGateDeparture']['dateLocal']),
        description: 'Flight departed from gate',
        metadata: operationalTimes['actualGateDeparture'],
      ));
    }

    if (operationalTimes['actualRunwayDeparture'] != null) {
      events.add(FlightEvent(
        eventType: 'TAKEOFF',
        timestamp: DateTime.parse(
            operationalTimes['actualRunwayDeparture']['dateLocal']),
        description: 'Flight took off',
        metadata: operationalTimes['actualRunwayDeparture'],
      ));
    }

    if (operationalTimes['actualRunwayArrival'] != null) {
      events.add(FlightEvent(
        eventType: 'LANDING',
        timestamp:
            DateTime.parse(operationalTimes['actualRunwayArrival']['dateLocal']),
        description: 'Flight landed',
        metadata: operationalTimes['actualRunwayArrival'],
      ));
    }

    if (operationalTimes['actualGateArrival'] != null) {
      events.add(FlightEvent(
        eventType: 'ARRIVED',
        timestamp:
            DateTime.parse(operationalTimes['actualGateArrival']['dateLocal']),
        description: 'Arrived at gate',
        metadata: operationalTimes['actualGateArrival'],
      ));
    }

    // Check for delays
    if (flightStatus['delays'] != null &&
        (flightStatus['delays'] as Map).isNotEmpty) {
      final delays = flightStatus['delays'];
      events.add(FlightEvent(
        eventType: 'DELAY',
        timestamp: DateTime.now(),
        description: 'Flight delayed',
        metadata: delays,
      ));
    }

    return events;
  }

  /// Start polling for flight updates
  void _startPolling(String pnr) {
    if (_pollingTimer != null) return;

    debugPrint('📡 Starting flight tracking polling for $pnr');

    _pollingTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      final flight = _activeFlights[pnr];
      if (flight == null) {
        timer.cancel();
        return;
      }

      // Stop polling after flight is completed
      if (flight.currentPhase == FlightPhase.completed) {
        debugPrint('✅ Flight completed, stopping polling');
        timer.cancel();
        return;
      }

      try {
        final updatedInfo = await _fetchFlightStatus(
          carrier: flight.carrier,
          flightNumber: flight.flightNumber,
          flightDate: flight.departureTime,
          departureAirport: flight.departureAirport,
        );

        if (updatedInfo['error'] == null &&
            updatedInfo['flightStatuses'] != null) {
          final flightStatus = updatedInfo['flightStatuses'][0];
          final newPhase = _determineFlightPhase(flightStatus);

          // Check if phase changed
          if (newPhase != flight.currentPhase) {
            debugPrint(
                '🔄 Flight phase changed: ${flight.currentPhase} → $newPhase');

            final updatedFlight = flight.copyWith(
              currentPhase: newPhase,
              phaseStartTime: DateTime.now(),
              ciriumData: flightStatus,
              events: _extractEvents(flightStatus),
            );

            _activeFlights[pnr] = updatedFlight;
            _flightUpdateController.add(updatedFlight);
          }
        }
      } catch (e) {
        debugPrint('❌ Error polling flight status: $e');
      }
    });
  }

  /// Stop tracking a specific flight
  void stopTracking(String pnr) {
    _activeFlights.remove(pnr);
    if (_activeFlights.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
    debugPrint('🛑 Stopped tracking flight: $pnr');
  }

  /// Get current tracking status for a flight
  FlightTrackingModel? getFlightStatus(String pnr) {
    return _activeFlights[pnr];
  }

  /// Get all actively tracked flights
  List<FlightTrackingModel> getAllTrackedFlights() {
    return _activeFlights.values.toList();
  }

  /// Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
    _flightUpdateController.close();
    _activeFlights.clear();
  }
}

