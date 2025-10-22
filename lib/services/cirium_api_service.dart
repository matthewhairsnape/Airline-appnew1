import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CiriumApiService {
  static const String _baseUrl = 'https://api.flightstats.com/flex';
  static String? _appId;
  static String? _appKey;

  static void initialize({required String appId, required String appKey}) {
    _appId = appId;
    _appKey = appKey;
  }

  static bool get isInitialized => _appId != null && _appKey != null;

  /// Get flight status by flight number and date
  static Future<Map<String, dynamic>?> getFlightStatus({
    required String carrier,
    required String flightNumber,
    required DateTime departureDate,
  }) async {
    if (!isInitialized) {
      debugPrint('❌ Cirium API not initialized');
      return null;
    }

    try {
      final dateStr = departureDate.toIso8601String().split('T')[0];
      final url =
          '$_baseUrl/flightstatus/rest/v2/json/flight/status/$carrier/$flightNumber/dep/$dateStr?appId=$_appId&appKey=$_appKey&utc=true';

      debugPrint('🔄 Fetching flight status from Cirium: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Flight status retrieved from Cirium');
        return data;
      } else {
        debugPrint(
            '❌ Cirium API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching flight status from Cirium: $e');
      return null;
    }
  }

  /// Get flight status by flight ID (if you have it)
  static Future<Map<String, dynamic>?> getFlightStatusById({
    required String flightId,
  }) async {
    if (!isInitialized) {
      debugPrint('❌ Cirium API not initialized');
      return null;
    }

    try {
      final url =
          '$_baseUrl/flightstatus/rest/v2/json/flight/status/$flightId?appId=$_appId&appKey=$_appKey&utc=true';

      debugPrint('🔄 Fetching flight status by ID from Cirium: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Flight status by ID retrieved from Cirium');
        return data;
      } else {
        debugPrint(
            '❌ Cirium API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching flight status by ID from Cirium: $e');
      return null;
    }
  }

  /// Parse Cirium flight status and extract relevant information
  static Map<String, dynamic>? parseFlightStatus(
      Map<String, dynamic> ciriumData) {
    try {
      final flightStatuses = ciriumData['flightStatuses'] as List?;
      if (flightStatuses == null || flightStatuses.isEmpty) {
        debugPrint('❌ No flight statuses found in Cirium data');
        return null;
      }

      final status = flightStatuses.first as Map<String, dynamic>;

      // Extract basic flight info
      final flight = status['flight'] as Map<String, dynamic>?;
      final carrier = flight?['carrierFsCode'] as String?;
      final flightNumber = flight?['flightNumber'] as String?;

      // Extract status information
      final statusCode = status['status'] as String?;
      final departureDate = status['departureDate'] as Map<String, dynamic>?;
      final arrivalDate = status['arrivalDate'] as Map<String, dynamic>?;

      // Extract airport information
      final departureAirport = status['departureAirportFsCode'] as String?;
      final arrivalAirport = status['arrivalAirportFsCode'] as String?;

      // Extract gate and terminal information
      final departureGate = departureDate?['gate'] as String?;
      final arrivalGate = arrivalDate?['gate'] as String?;
      final departureTerminal = departureDate?['terminal'] as String?;
      final arrivalTerminal = arrivalDate?['terminal'] as String?;

      // Extract timing information
      final scheduledDeparture = departureDate?['dateLocal'] as String?;
      final scheduledArrival = arrivalDate?['dateLocal'] as String?;
      final actualDeparture = departureDate?['dateUtc'] as String?;
      final actualArrival = arrivalDate?['dateUtc'] as String?;

      // Extract delay information
      final departureDelay = departureDate?['delayMinutes'] as int?;
      final arrivalDelay = arrivalDate?['delayMinutes'] as int?;

      // Extract airport resources data
      final airportResources =
          status['airportResources'] as Map<String, dynamic>?;
      final departureAirportData =
          airportResources?['departure'] as Map<String, dynamic>?;
      final arrivalAirportData =
          airportResources?['arrival'] as Map<String, dynamic>?;

      return {
        'carrier': carrier,
        'flightNumber': flightNumber,
        'status': statusCode,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'departureGate': departureGate,
        'arrivalGate': arrivalGate,
        'departureTerminal': departureTerminal,
        'arrivalTerminal': arrivalTerminal,
        'scheduledDeparture': scheduledDeparture,
        'scheduledArrival': scheduledArrival,
        'actualDeparture': actualDeparture,
        'actualArrival': actualArrival,
        'departureDelay': departureDelay,
        'arrivalDelay': arrivalDelay,
        'lastUpdated': DateTime.now().toIso8601String(),
        // Airport data
        'departureAirportData': departureAirportData,
        'arrivalAirportData': arrivalAirportData,
        'airportResources': airportResources,
      };
    } catch (e) {
      debugPrint('❌ Error parsing Cirium flight status: $e');
      return null;
    }
  }

  /// Map Cirium status codes to app phases
  static String mapStatusToPhase(String? ciriumStatus) {
    if (ciriumStatus == null) return 'unknown';

    switch (ciriumStatus.toUpperCase()) {
      case 'S':
      case 'SCHEDULED':
        return 'pre_check_in';
      case 'C':
      case 'CANCELLED':
        return 'cancelled';
      case 'D':
      case 'DIVERTED':
        return 'diverted';
      case 'L':
      case 'LANDED':
        return 'landed';
      case 'A':
      case 'ARRIVED':
        return 'arrived';
      case 'R':
      case 'REDIRECTED':
        return 'redirected';
      case 'U':
      case 'UNKNOWN':
        return 'unknown';
      case 'DEP':
      case 'DEPARTED':
        return 'departed';
      case 'BOARDING':
        return 'boarding';
      case 'GATE_CLOSED':
        return 'gate_closed';
      case 'TAXIING':
        return 'taxiing';
      case 'TAKEOFF':
        return 'takeoff';
      case 'CRUISING':
        return 'in_flight';
      case 'IN_FLIGHT':
        return 'in_flight';
      case 'DESCENT':
        return 'descent';
      case 'APPROACH':
        return 'approach';
      case 'LANDING':
        return 'landing';
      default:
        return 'unknown';
    }
  }

  /// Get notification message based on phase
  static String getNotificationMessage(
      String phase, Map<String, dynamic> flightData) {
    final carrier = flightData['carrier'] ?? '';
    final flightNumber = flightData['flightNumber'] ?? '';
    final flight = '$carrier$flightNumber';

    switch (phase) {
      case 'boarding':
        return '🛫 Your flight $flight is now boarding! Please proceed to the gate.';
      case 'gate_closed':
        return '⚠️ Gate is now closed for flight $flight. Please contact airline staff.';
      case 'departed':
      case 'in_flight':
        return '✈️ Flight $flight has departed. Enjoy your journey!';
      case 'landed':
        return '🛬 Flight $flight has landed. Welcome to your destination!';
      case 'arrived':
        return '✅ Flight $flight has arrived. Thank you for flying with us!';
      case 'cancelled':
        return '❌ Flight $flight has been cancelled. Please contact airline for assistance.';
      case 'delayed':
        return '⏰ Flight $flight has been delayed. Please check for updates.';
      default:
        return '📱 Flight $flight status update available.';
    }
  }
}
