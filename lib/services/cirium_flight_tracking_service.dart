import 'dart:async';
import 'dart:convert';
import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/models/stage_feedback_model.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:airline_app/services/supabase_service.dart';
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
      // CRITICAL: Always use UTC times to ensure correct landing time regardless of user's location
      // Cirium provides both dateUtc (UTC) and dateLocal (airport timezone)
      // We MUST use dateUtc to avoid timezone conversion errors when user is in different timezone
      final departureDate = flightStatus['departureDate'] as Map<String, dynamic>;
      final arrivalDate = flightStatus['arrivalDate'] as Map<String, dynamic>;
      
      // CRITICAL: Always prefer dateUtc (UTC time) over dateLocal
      // dateLocal is in airport timezone, which can cause incorrect conversion
      // when user is in different timezone (e.g., Dubai vs New York)
      DateTime departureTimeUtc;
      if (departureDate['dateUtc'] != null) {
        departureTimeUtc = DateTime.parse(departureDate['dateUtc']);
        debugPrint('✅ Using departure dateUtc: $departureTimeUtc (UTC=${departureTimeUtc.isUtc})');
      } else {
        // FALLBACK: If dateUtc not available (shouldn't happen, but handle it)
        debugPrint('⚠️ WARNING: departureDate missing dateUtc, using dateLocal (may be inaccurate)');
        final departureTimeLocal = DateTime.parse(departureDate['dateLocal']);
        departureTimeUtc = departureTimeLocal.toUtc();
        debugPrint('   dateLocal: ${departureDate['dateLocal']}, converted to UTC: $departureTimeUtc');
      }
      
      DateTime arrivalTimeUtc;
      if (arrivalDate['dateUtc'] != null) {
        arrivalTimeUtc = DateTime.parse(arrivalDate['dateUtc']);
        debugPrint('✅ Using arrival dateUtc: $arrivalTimeUtc (UTC=${arrivalTimeUtc.isUtc})');
      } else {
        // FALLBACK: If dateUtc not available (shouldn't happen, but handle it)
        debugPrint('⚠️ WARNING: arrivalDate missing dateUtc, using dateLocal (may be inaccurate)');
        final arrivalTimeLocal = DateTime.parse(arrivalDate['dateLocal']);
        arrivalTimeUtc = arrivalTimeLocal.toUtc();
        debugPrint('   dateLocal: ${arrivalDate['dateLocal']}, converted to UTC: $arrivalTimeUtc');
      }
      
      // Calculate duration using UTC times to get accurate flight duration
      final duration = arrivalTimeUtc.difference(departureTimeUtc);
      final flightDuration = '${duration.inHours}h ${duration.inMinutes % 60}m';
      
      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🕐 FLIGHT TIME PROCESSING OUTPUT');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📅 Departure Time (UTC): $departureTimeUtc');
      debugPrint('   Source: ${departureDate['dateUtc'] != null ? 'dateUtc' : 'dateLocal (converted)'}');
      debugPrint('📅 Arrival Time (UTC): $arrivalTimeUtc');
      debugPrint('   Source: ${arrivalDate['dateUtc'] != null ? 'dateUtc' : 'dateLocal (converted)'}');
      debugPrint('⏱️  Flight Duration: ${duration.inHours}h ${duration.inMinutes % 60}m');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      // Create flight tracking model
      // Use UTC times for consistency with database storage
      final flightTracking = FlightTrackingModel(
        flightId: pnr, // Use PNR as flight ID since it's our primary key
        pnr: pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureTime: departureTimeUtc,
        arrivalTime: arrivalTimeUtc,
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
        debugPrint(
            '✅ Flight verified (historical flight - no real-time polling needed)');
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
        url =
            'https://api.flightstats.com/flex/flightstatus/historical/rest/v3/json/flight/status/$carrier/$flightNumber/dep/'
            '${flightDate.year}/${flightDate.month.toString().padLeft(2, '0')}/${flightDate.day.toString().padLeft(2, '0')}'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
        debugPrint(
            '📡 Using PREMIUM HISTORICAL API for past flight (${daysDifference} days old)');
      } else {
        // Use real-time API for current/upcoming flights
        url = '$ciriumUrl/json/flight/status/$carrier/$flightNumber/dep/'
            '${flightDate.year}/${flightDate.month.toString().padLeft(2, '0')}/${flightDate.day.toString().padLeft(2, '0')}'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
        debugPrint('📡 Using REAL-TIME API for current/future flight');
      }

      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 CIRIUM API REQUEST');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔗 URL: $url');
      debugPrint('📋 Request Parameters:');
      debugPrint('   Carrier: $carrier');
      debugPrint('   Flight Number: $flightNumber');
      debugPrint('   Flight Date: $flightDate');
      debugPrint('   Departure Airport: $departureAirport');
      debugPrint('   API Type: ${isPastFlight ? "PREMIUM HISTORICAL" : "REAL-TIME"}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      final response = await http.get(Uri.parse(url));

      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 CIRIUM API RESPONSE');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📏 Response Size: ${response.body.length} bytes');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Log full response payload
        debugPrint('');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📦 FULL CIRIUM API RESPONSE PAYLOAD');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint(json.encode(responseData));
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('');
        
        // Parse and log structured response
        if (responseData['flightStatuses'] != null) {
          final flightStatuses = responseData['flightStatuses'] as List;
          debugPrint('📊 Flight Statuses Count: ${flightStatuses.length}');
          
          if (flightStatuses.isNotEmpty) {
            final flightStatus = flightStatuses[0] as Map<String, dynamic>;
            
            // Log flight basic info
            final flight = flightStatus['flight'] as Map<String, dynamic>?;
            debugPrint('');
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            debugPrint('✈️  FLIGHT INFORMATION');
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            if (flight != null) {
              debugPrint('   Carrier: ${flight['carrierFsCode']}');
              debugPrint('   Flight Number: ${flight['flightNumber']}');
              debugPrint('   Aircraft Type: ${flight['aircraftType']}');
            }
            debugPrint('   Departure Airport: ${flightStatus['departureAirportFsCode']}');
            debugPrint('   Arrival Airport: ${flightStatus['arrivalAirportFsCode']}');
            debugPrint('   Status: ${flightStatus['status']}');
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            debugPrint('');
            
            // Log departure date
            final departureDate = flightStatus['departureDate'] as Map<String, dynamic>?;
            if (departureDate != null) {
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('🛫 DEPARTURE DATE INFORMATION');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('   dateLocal: ${departureDate['dateLocal'] ?? 'null'}');
              debugPrint('   dateUtc: ${departureDate['dateUtc'] ?? 'null'} ⚠️ PREFERRED FOR UTC');
              debugPrint('   Gate: ${departureDate['gate'] ?? 'null'}');
              debugPrint('   Terminal: ${departureDate['terminal'] ?? 'null'}');
              debugPrint('   Delay Minutes: ${departureDate['delayMinutes'] ?? 'null'}');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('');
            }
            
            // Log arrival date
            final arrivalDate = flightStatus['arrivalDate'] as Map<String, dynamic>?;
            if (arrivalDate != null) {
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('🛬 ARRIVAL DATE INFORMATION');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('   dateLocal: ${arrivalDate['dateLocal'] ?? 'null'}');
              debugPrint('   dateUtc: ${arrivalDate['dateUtc'] ?? 'null'} ⚠️ PREFERRED FOR UTC');
              debugPrint('   Gate: ${arrivalDate['gate'] ?? 'null'}');
              debugPrint('   Terminal: ${arrivalDate['terminal'] ?? 'null'}');
              debugPrint('   Delay Minutes: ${arrivalDate['delayMinutes'] ?? 'null'}');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('');
            }
            
            // Log operational times (CRITICAL for landing time)
            final operationalTimes = flightStatus['operationalTimes'] as Map<String, dynamic>? ?? {};
            if (operationalTimes.isNotEmpty) {
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('🕐 OPERATIONAL TIMES (CRITICAL FOR LANDING TIME CALCULATION)');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              
              // Departure times
              if (operationalTimes['actualGateDeparture'] != null) {
                final agd = operationalTimes['actualGateDeparture'] as Map<String, dynamic>;
                debugPrint('   actualGateDeparture:');
                debugPrint('      dateLocal: ${agd['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${agd['dateUtc'] ?? 'null'} ⚠️ PREFERRED');
              }
              if (operationalTimes['actualRunwayDeparture'] != null) {
                final ard = operationalTimes['actualRunwayDeparture'] as Map<String, dynamic>;
                debugPrint('   actualRunwayDeparture:');
                debugPrint('      dateLocal: ${ard['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${ard['dateUtc'] ?? 'null'} ⚠️ PREFERRED');
              }
              if (operationalTimes['estimatedGateDeparture'] != null) {
                final egd = operationalTimes['estimatedGateDeparture'] as Map<String, dynamic>;
                debugPrint('   estimatedGateDeparture:');
                debugPrint('      dateLocal: ${egd['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${egd['dateUtc'] ?? 'null'} ⚠️ PREFERRED');
              }
              if (operationalTimes['scheduledGateDeparture'] != null) {
                final sgd = operationalTimes['scheduledGateDeparture'] as Map<String, dynamic>;
                debugPrint('   scheduledGateDeparture:');
                debugPrint('      dateLocal: ${sgd['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${sgd['dateUtc'] ?? 'null'} ⚠️ PREFERRED');
              }
              
              // Arrival times (CRITICAL FOR LANDING TIME)
              if (operationalTimes['actualGateArrival'] != null) {
                final aga = operationalTimes['actualGateArrival'] as Map<String, dynamic>;
                debugPrint('   actualGateArrival: ⚠️ HIGHEST PRIORITY FOR LANDING TIME');
                debugPrint('      dateLocal: ${aga['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${aga['dateUtc'] ?? 'null'} ✅ WILL USE THIS');
              }
              if (operationalTimes['actualRunwayArrival'] != null) {
                final ara = operationalTimes['actualRunwayArrival'] as Map<String, dynamic>;
                debugPrint('   actualRunwayArrival: ⚠️ SECOND PRIORITY FOR LANDING TIME');
                debugPrint('      dateLocal: ${ara['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${ara['dateUtc'] ?? 'null'} ✅ WILL USE THIS');
              }
              if (operationalTimes['estimatedGateArrival'] != null) {
                final ega = operationalTimes['estimatedGateArrival'] as Map<String, dynamic>;
                debugPrint('   estimatedGateArrival: ⚠️ THIRD PRIORITY FOR LANDING TIME');
                debugPrint('      dateLocal: ${ega['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${ega['dateUtc'] ?? 'null'} ✅ WILL USE THIS');
              }
              if (operationalTimes['scheduledGateArrival'] != null) {
                final sga = operationalTimes['scheduledGateArrival'] as Map<String, dynamic>;
                debugPrint('   scheduledGateArrival:');
                debugPrint('      dateLocal: ${sga['dateLocal'] ?? 'null'}');
                debugPrint('      dateUtc: ${sga['dateUtc'] ?? 'null'} ⚠️ PREFERRED');
              }
              
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('');
            }
            
            // Log airport resources
            final airportResources = flightStatus['airportResources'] as Map<String, dynamic>?;
            if (airportResources != null) {
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('🏢 AIRPORT RESOURCES');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('   departureGate: ${airportResources['departureGate'] ?? 'null'}');
              debugPrint('   departureTerminal: ${airportResources['departureTerminal'] ?? 'null'}');
              debugPrint('   arrivalGate: ${airportResources['arrivalGate'] ?? 'null'}');
              debugPrint('   arrivalTerminal: ${airportResources['arrivalTerminal'] ?? 'null'}');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('');
            }
            
            // Log delays
            final delays = flightStatus['delays'] as Map<String, dynamic>?;
            if (delays != null && delays.isNotEmpty) {
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('⏱️  DELAYS');
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint(json.encode(delays));
              debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              debugPrint('');
            }
          }
        }
        
        return responseData;
      } else {
        debugPrint('❌ API returned status code: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('');
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
        timestamp: DateTime.parse(
            operationalTimes['actualGateDeparture']['dateLocal']),
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
        timestamp: DateTime.parse(
            operationalTimes['actualRunwayArrival']['dateLocal']),
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

      // Continue polling even after landing to get actual gate arrival time
      // Only stop after flight is completed (user marked it as complete)
      if (flight.currentPhase == FlightPhase.completed) {
        debugPrint('✅ Flight completed, stopping polling');
        timer.cancel();
        return;
      }
      
      // Continue polling if flight has landed but not completed
      // This ensures we get actual gate arrival time updates

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
          
          // Extract actual arrival time if available (real-time landing time)
          DateTime? actualArrivalTime = _extractActualArrivalTime(flightStatus);
          
          // Extract gate and terminal information from airport resources
          final airportResources = flightStatus['airportResources'] ?? {};
          final newGate = airportResources['departureGate']?.toString();
          final newTerminal = airportResources['departureTerminal']?.toString();
          
          // Check if phase changed, arrival time updated, or gate/terminal updated
          final phaseChanged = newPhase != flight.currentPhase;
          final arrivalTimeChanged = actualArrivalTime != null && 
              actualArrivalTime != flight.arrivalTime;
          final gateChanged = newGate != null && newGate.isNotEmpty && 
              newGate != flight.gate;
          final terminalChanged = newTerminal != null && newTerminal.isNotEmpty && 
              newTerminal != flight.terminal;
          
          if (phaseChanged || arrivalTimeChanged || gateChanged || terminalChanged) {
            if (phaseChanged) {
              debugPrint(
                  '🔄 Flight phase changed: ${flight.currentPhase} → $newPhase');
            }
            if (arrivalTimeChanged) {
              debugPrint(
                  '🕐 Landing time updated: ${flight.arrivalTime} → $actualArrivalTime');
            }
            if (gateChanged) {
              debugPrint(
                  '🛫 Gate updated: ${flight.gate ?? 'None'} → $newGate');
            }
            if (terminalChanged) {
              debugPrint(
                  '🛫 Terminal updated: ${flight.terminal ?? 'None'} → $newTerminal');
            }

            final updatedFlight = flight.copyWith(
              currentPhase: newPhase,
              phaseStartTime: DateTime.now(),
              arrivalTime: actualArrivalTime ?? flight.arrivalTime, // Use actual if available
              gate: newGate ?? flight.gate, // Update gate if available
              terminal: newTerminal ?? flight.terminal, // Update terminal if available
              ciriumData: flightStatus,
              events: _extractEvents(flightStatus),
            );

            _activeFlights[pnr] = updatedFlight;
            _flightUpdateController.add(updatedFlight);
            
            // Update database with gate/terminal information
            if ((gateChanged || terminalChanged) && flight.journeyId != null) {
              await _updateJourneyGateTerminal(
                journeyId: flight.journeyId!,
                gate: newGate,
                terminal: newTerminal,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error polling flight status: $e');
      }
    });
  }

  /// Extract actual arrival time from Cirium flight status
  /// Priority: actualGateArrival > actualRunwayArrival > estimatedGateArrival
  /// CRITICAL: Always use UTC times to ensure correct landing time regardless of user's location
  DateTime? _extractActualArrivalTime(Map<String, dynamic> flightStatus) {
    debugPrint('');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 EXTRACTING ACTUAL ARRIVAL TIME (LANDING TIME)');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    final operationalTimes = flightStatus['operationalTimes'] ?? {};
    
    // Check for actual gate arrival (most accurate)
    if (operationalTimes['actualGateArrival'] != null) {
      try {
        final gateArrival = operationalTimes['actualGateArrival'] as Map<String, dynamic>;
        
        // CRITICAL: Always prefer dateUtc (UTC time) over dateLocal
        // dateLocal is in airport timezone, which can cause incorrect conversion
        // when user is in different timezone (e.g., Dubai vs New York)
        debugPrint('🔍 Checking actualGateArrival (HIGHEST PRIORITY)...');
        if (gateArrival['dateUtc'] != null) {
          final arrivalTime = DateTime.parse(gateArrival['dateUtc']);
          debugPrint('✅ Found actual gate arrival time (UTC): $arrivalTime');
          debugPrint('   dateUtc: ${gateArrival['dateUtc']}');
          debugPrint('   Is UTC: ${arrivalTime.isUtc}');
          debugPrint('   ✅ SELECTED AS LANDING TIME');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          // Ensure it's UTC (should already be, but double-check)
          return arrivalTime.isUtc ? arrivalTime : DateTime.parse(gateArrival['dateUtc'] + 'Z');
        } else if (gateArrival['dateLocal'] != null) {
          // FALLBACK: If dateUtc not available, parse dateLocal but warn
          // NOTE: This is not ideal as dateLocal is in airport timezone, not device timezone
          // But we have no way to know airport timezone, so we parse as-is and hope Cirium provides UTC
          debugPrint('⚠️ WARNING: actualGateArrival missing dateUtc, using dateLocal (may be inaccurate)');
          debugPrint('   dateLocal: ${gateArrival['dateLocal']}');
          final arrivalTime = DateTime.parse(gateArrival['dateLocal']);
          debugPrint('   Parsed as: $arrivalTime');
          debugPrint('   Converted to UTC: ${arrivalTime.toUtc()}');
          debugPrint('   ⚠️ SELECTED AS LANDING TIME (FALLBACK)');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          // This is a fallback - ideally Cirium should always provide dateUtc
          return arrivalTime.toUtc();
        } else {
          debugPrint('❌ actualGateArrival exists but has no dateUtc or dateLocal');
        }
      } catch (e) {
        debugPrint('❌ Error parsing actualGateArrival: $e');
      }
    }
    
    // Check for actual runway arrival (landing time)
    if (operationalTimes['actualRunwayArrival'] != null) {
      try {
        final runwayArrival = operationalTimes['actualRunwayArrival'] as Map<String, dynamic>;
        
        // CRITICAL: Always prefer dateUtc (UTC time) over dateLocal
        debugPrint('🔍 Checking actualRunwayArrival (SECOND PRIORITY)...');
        if (runwayArrival['dateUtc'] != null) {
          final arrivalTime = DateTime.parse(runwayArrival['dateUtc']);
          debugPrint('✅ Found actual runway arrival time (UTC): $arrivalTime');
          debugPrint('   dateUtc: ${runwayArrival['dateUtc']}');
          debugPrint('   Is UTC: ${arrivalTime.isUtc}');
          debugPrint('   ✅ SELECTED AS LANDING TIME');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          return arrivalTime.isUtc ? arrivalTime : DateTime.parse(runwayArrival['dateUtc'] + 'Z');
        } else if (runwayArrival['dateLocal'] != null) {
          debugPrint('⚠️ WARNING: actualRunwayArrival missing dateUtc, using dateLocal (may be inaccurate)');
          debugPrint('   dateLocal: ${runwayArrival['dateLocal']}');
          final arrivalTime = DateTime.parse(runwayArrival['dateLocal']);
          debugPrint('   Parsed as: $arrivalTime');
          debugPrint('   Converted to UTC: ${arrivalTime.toUtc()}');
          debugPrint('   ⚠️ SELECTED AS LANDING TIME (FALLBACK)');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          return arrivalTime.toUtc();
        } else {
          debugPrint('❌ actualRunwayArrival exists but has no dateUtc or dateLocal');
        }
      } catch (e) {
        debugPrint('❌ Error parsing actualRunwayArrival: $e');
      }
    } else {
      debugPrint('⏭️  actualRunwayArrival not available');
    }
    
    // Check for estimated gate arrival
    if (operationalTimes['estimatedGateArrival'] != null) {
      try {
        final estimatedArrival = operationalTimes['estimatedGateArrival'] as Map<String, dynamic>;
        
        // CRITICAL: Always prefer dateUtc (UTC time) over dateLocal
        debugPrint('🔍 Checking estimatedGateArrival (THIRD PRIORITY)...');
        if (estimatedArrival['dateUtc'] != null) {
          final arrivalTime = DateTime.parse(estimatedArrival['dateUtc']);
          debugPrint('✅ Found estimated gate arrival time (UTC): $arrivalTime');
          debugPrint('   dateUtc: ${estimatedArrival['dateUtc']}');
          debugPrint('   Is UTC: ${arrivalTime.isUtc}');
          debugPrint('   ✅ SELECTED AS LANDING TIME');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          return arrivalTime.isUtc ? arrivalTime : DateTime.parse(estimatedArrival['dateUtc'] + 'Z');
        } else if (estimatedArrival['dateLocal'] != null) {
          debugPrint('⚠️ WARNING: estimatedGateArrival missing dateUtc, using dateLocal (may be inaccurate)');
          debugPrint('   dateLocal: ${estimatedArrival['dateLocal']}');
          final arrivalTime = DateTime.parse(estimatedArrival['dateLocal']);
          debugPrint('   Parsed as: $arrivalTime');
          debugPrint('   Converted to UTC: ${arrivalTime.toUtc()}');
          debugPrint('   ⚠️ SELECTED AS LANDING TIME (FALLBACK)');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('');
          return arrivalTime.toUtc();
        } else {
          debugPrint('❌ estimatedGateArrival exists but has no dateUtc or dateLocal');
        }
      } catch (e) {
        debugPrint('❌ Error parsing estimatedGateArrival: $e');
      }
    } else {
      debugPrint('⏭️  estimatedGateArrival not available');
    }
    
    // Return null if no actual/estimated time available (use scheduled)
    debugPrint('⚠️ No actual/estimated arrival time found in operationalTimes');
    debugPrint('   Will use scheduled arrival time from arrivalDate');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('');
    return null;
  }

  /// Update journey gate and terminal in database
  Future<void> _updateJourneyGateTerminal({
    required String journeyId,
    String? gate,
    String? terminal,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (gate != null && gate.isNotEmpty) {
        updateData['gate'] = gate;
      }
      if (terminal != null && terminal.isNotEmpty) {
        updateData['terminal'] = terminal;
      }
      
      if (updateData.isEmpty) {
        return; // Nothing to update
      }
      
      // Update journeys table
      await SupabaseService.client
          .from('journeys')
          .update(updateData)
          .eq('id', journeyId);
      
      debugPrint('✅ Updated journey $journeyId with gate=$gate, terminal=$terminal');
      
      // Also try to update flights table if journey has flight_id
      try {
        final journeyData = await SupabaseService.client
            .from('journeys')
            .select('flight_id')
            .eq('id', journeyId)
            .maybeSingle();
            
        if (journeyData != null && journeyData['flight_id'] != null) {
          await SupabaseService.client
              .from('flights')
              .update(updateData)
              .eq('id', journeyData['flight_id']);
          debugPrint('✅ Updated flight ${journeyData['flight_id']} with gate=$gate, terminal=$terminal');
        }
      } catch (e) {
        debugPrint('⚠️ Could not update flights table: $e');
      }
    } catch (e) {
      debugPrint('❌ Error updating journey gate/terminal: $e');
    }
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
