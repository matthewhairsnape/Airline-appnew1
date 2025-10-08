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
      // Format date components with leading zeros
      final year = flightDate.year;
      final month = flightDate.month.toString().padLeft(2, '0');
      final day = flightDate.day.toString().padLeft(2, '0');
      
      // Determine if this is a historical flight (more than 2 days in the past)
      final now = DateTime.now();
      final daysDifference = now.difference(flightDate).inDays;
      final isHistorical = daysDifference > 2;
      
      // Use historical API for past flights, real-time API for recent/future flights
      final baseUrl = isHistorical 
          ? 'https://api.flightstats.com/flex/flightstatus/historical/rest/v3'
          : ciriumUrl;
      
      final url = '$baseUrl/json/flight/status/$carrier/$flightNumber/dep/'
          '$year/$month/$day'
          '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport';
      
      debugPrint('🌐 Cirium API URL (${isHistorical ? "HISTORICAL" : "REAL-TIME"}): $url');
      
      final response = await http.get(Uri.parse(url));
      
      debugPrint('📡 Cirium response status: ${response.statusCode}');
      debugPrint('📦 Cirium response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Cirium data parsed successfully. FlightStatuses count: ${data['flightStatuses']?.length ?? 0}');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('❌ Cirium API error: ${response.statusCode}');
        debugPrint('   Error message: ${errorData['error']?['errorMessage']}');
        
        // Return the error data so we can handle it in the scanner
        return {
          'error': 'Failed to fetch flight data', 
          'statusCode': response.statusCode, 
          'errorMessage': errorData['error']?['errorMessage'],
          'flightStatuses': [], // Empty array to prevent null issues
        };
      }
    } catch (e) {
      // Handle any errors that occur during the API call
      debugPrint('❌ Error confirming flight: $e');
      return {'error': e.toString(), 'flightStatuses': []};
    }
  }
}
