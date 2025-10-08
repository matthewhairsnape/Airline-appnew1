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
      final response = await http.get(
        Uri.parse(
          '$ciriumUrl/json/flight/status/$carrier/$flightNumber/dep/'
          '${flightDate.year}/${flightDate.month}/${flightDate.day}'
          '?appId=$ciriumAppId&appKey=$ciriumAppKey&airport=$departureAirport',
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      }
      return {'error': 'Failed to fetch flight data'};
    } catch (e) {
      // Handle any errors that occur during the API call
      debugPrint('Error confirming flight: $e');
      return {'error': e.toString()};
    }
  }
}
