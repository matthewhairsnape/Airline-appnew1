import 'dart:async';
import 'dart:convert';
import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/models/stage_feedback_model.dart';
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
    Map<String, dynamic>? existingFlightData,
  }) async {
    try {
      debugPrint(
          '🛫 Starting flight verification for $carrier$flightNumber on ${flightDate.toString()}');

      Map<String, dynamic> flightInfo;
      
      // Use existing flight data if provided (from initial scan)
      if (existingFlightData != null) {
        debugPrint('📦 Using existing flight data from scan');
        flightInfo = existingFlightData;
      } else {
        // Fetch flight data from Cirium
        flightInfo = await _fetchFlightStatus(
          carrier: carrier,
          flightNumber: flightNumber,
          flightDate: flightDate,
          departureAirport: departureAirport,
        );
        
        if (flightInfo['error'] != null) {
          debugPrint('❌ Error fetching flight data: ${flightInfo['error']}');
          return null;
        }
      }

      if (flightInfo['flightStatuses'] == null ||
          (flightInfo['flightStatuses'] as List).isEmpty) {
        debugPrint('❌ No flight status found');
        return null;
      }

      final flightStatus = flightInfo['flightStatuses'][0];

      // Extract additional flight details
      final airportResources = flightStatus['airportResources'];
      final flightEquipment = flightStatus['flightEquipment'];
      
      // Calculate flight duration
      final departureTime = DateTime.parse(flightStatus['departureDate']['dateLocal']);
      final arrivalTime = DateTime.parse(flightStatus['arrivalDate']['dateLocal']);
      final duration = arrivalTime.difference(departureTime);
      final flightDuration = '${duration.inHours}h ${duration.inMinutes % 60}m';

      // Create flight tracking model
      final flightTracking = FlightTrackingModel(
        flightId: pnr, // Use PNR as flight ID since it's our primary key
        pnr: pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureAirport: flightStatus['departureAirportFsCode'],
        arrivalAirport: flightStatus['arrivalAirportFsCode'],
        currentPhase: _determineFlightPhase(flightStatus),
        phaseStartTime: DateTime.now(),
        ciriumData: flightStatus,
        events: _extractEvents(flightStatus),
        isVerified: true,
        // Additional details
        terminal: airportResources?['departureTerminal'],
        gate: airportResources?['departureGate'],
        aircraftType: flightEquipment?['iata'],
        flightDuration: flightDuration,
      );

      // Store and start tracking
      _activeFlights[pnr] = flightTracking;
      
      // Only start polling for current/upcoming flights (not past flights)
      final daysDifference = DateTime.now().difference(flightDate).inDays;
      if (daysDifference <= 1) {
        _startPolling(pnr);
        debugPrint('✅ Flight verified and real-time tracking started');
      } else {
        debugPrint('✅ Flight verified (historical flight - no real-time polling needed)');
      }
      
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
      // Check if this is a past flight (more than 1 day ago)
      final daysDifference = DateTime.now().difference(flightDate).inDays;
      final isPastFlight = daysDifference > 1;
      
      String url;
      if (isPastFlight) {
        // Use premium historical API for past flights (v3 has better coverage)
        url = 'https://api.flightstats.com/flex/flightstatus/historical/rest/v3/json/flight/status/$carrier/$flightNumber/dep/'
            '${flightDate.year}/${flightDate.month.toString().padLeft(2, '0')}/${flightDate.day.toString().padLeft(2, '0')}'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
        debugPrint('📡 Using PREMIUM HISTORICAL API for past flight (${daysDifference} days old)');
      } else {
        // Use real-time API for current/upcoming flights
        url = '$ciriumUrl/json/flight/status/$carrier/$flightNumber/dep/'
            '${flightDate.year}/${flightDate.month.toString().padLeft(2, '0')}/${flightDate.day.toString().padLeft(2, '0')}'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
        debugPrint('📡 Using REAL-TIME API for current/future flight');
      }

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

      // If within 1 hour of departure, boarding likely started
      if (now.isAfter(gateDeparture.subtract(Duration(hours: 1))) &&
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

    // Check for gate changes and terminal information
    if (flightStatus['airportResources'] != null) {
      final resources = flightStatus['airportResources'];
      if (resources['departureGate'] != null) {
        events.add(FlightEvent(
          eventType: 'GATE_ASSIGNED',
          timestamp: DateTime.now(),
          description: 'Gate ${resources['departureGate']} assigned',
          metadata: {
            'gate': resources['departureGate'],
            'terminal': resources['departureTerminal'],
          },
        ));
      }
      
      // Add terminal information
      if (resources['departureTerminal'] != null) {
        events.add(FlightEvent(
          eventType: 'TERMINAL_ASSIGNED',
          timestamp: DateTime.now(),
          description: 'Terminal ${resources['departureTerminal']} assigned',
          metadata: {'terminal': resources['departureTerminal']},
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

