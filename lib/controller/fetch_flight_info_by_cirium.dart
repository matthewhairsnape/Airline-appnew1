import 'dart:convert';
import 'package:airline_app/utils/global_variable.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FetchFlightInforByCirium {
  Future<Map<String, dynamic>> fetchFlightInfo({
    required String carrier,
    required String flightNumber,
    required DateTime flightDate,
    required String departureAirport,
  }) async {
    try {
      // Ensure carrier code is trimmed and clean
      final cleanCarrier = carrier.trim();
      final cleanFlightNumber = flightNumber.trim();
      
      // Format date components with leading zeros
      final year = flightDate.year;
      final month = flightDate.month.toString().padLeft(2, '0');
      final day = flightDate.day.toString().padLeft(2, '0');
      
      // Determine if this is a historical flight (more than 1 day in the past)
      final now = DateTime.now();
      final daysDifference = now.difference(flightDate).inDays;
      final isHistorical = daysDifference > 1;
      
      String url;
      if (isHistorical) {
        // Use premium historical API for past flights (v3 has better coverage)
        url = 'https://api.flightstats.com/flex/flightstatus/historical/rest/v3/json/flight/status/$cleanCarrier/$cleanFlightNumber/dep/'
            '$year/$month/$day'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
      } else {
        // Use real-time API for current/future flights
        url = '$ciriumUrl/json/flight/status/$cleanCarrier/$cleanFlightNumber/dep/'
            '$year/$month/$day'
            '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport&extendedOptions=useHttpErrors';
      }
      
      debugPrint('🌐 Cirium API URL (${isHistorical ? "HISTORICAL" : "REAL-TIME"}): $url');
      
      final response = await http.get(Uri.parse(url));
      
      debugPrint('📡 Cirium response status: ${response.statusCode}');
      debugPrint('📦 Cirium response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Cirium data parsed successfully. FlightStatuses count: ${data['flightStatuses']?.length ?? 0}');
        
        // Log flight details if found
        if (data['flightStatuses']?.isNotEmpty ?? false) {
          final flight = data['flightStatuses'][0];
          debugPrint('   Flight: ${flight['carrierFsCode']} ${flight['flightNumber']}');
          debugPrint('   Route: ${flight['departureAirportFsCode']} → ${flight['arrivalAirportFsCode']}');
          debugPrint('   Status: ${flight['status']}');
        }
        
        return data;
      } else {
        debugPrint('❌ Cirium API error: ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = json.decode(response.body);
          debugPrint('   Error message: ${errorData['error']?['errorMessage']}');
          
          return {
            'error': 'Failed to fetch flight data', 
            'statusCode': response.statusCode, 
            'errorMessage': errorData['error']?['errorMessage'],
            'flightStatuses': [], // Empty array to prevent null issues
          };
        } catch (e) {
          return {
            'error': 'Failed to fetch flight data', 
            'statusCode': response.statusCode, 
            'errorMessage': response.body,
            'flightStatuses': [], // Empty array to prevent null issues
          };
        }
      }
    } catch (e) {
      // Handle any errors that occur during the API call
      debugPrint('❌ Error confirming flight: $e');
      return {'error': e.toString(), 'flightStatuses': []};
    }
  }
}
