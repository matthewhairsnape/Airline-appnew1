import 'dart:convert';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BoardingPassController {
  Future<bool> saveBoardingPass(BoardingPass boardingPass) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/boarding-pass'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(boardingPass.toJson()),
      );

      debugPrint('Save boarding pass response status: ${response.statusCode}');
      debugPrint('Save boarding pass response body: ${response.body}');

      if (response.statusCode == 201) {
        return true;
      } else {
        // Try to parse JSON error, but handle HTML responses gracefully
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Unknown error';
          debugPrint('API Error: $errorMessage');
        } catch (parseError) {
          debugPrint('Response is not JSON (likely HTML error page): ${response.body.substring(0, 100)}...');
        }
        return false; // Don't throw, just return false
      }
    } catch (e) {
      debugPrint('Error saving boarding pass: $e');
      return false;
    }
  }

  Future<List<BoardingPass>> getBoardingPasses(String name) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/v2/boarding-pass?name=$name'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['boardingPasses']
            .map<BoardingPass>((json) => BoardingPass.fromJson(json))
            .toList();
      } else {
        debugPrint('Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching boarding passes: $e');
      return [];
    }
  }

  Future<bool> updateBoardingPass(BoardingPass boardingPass) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/boarding-pass/update'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(boardingPass.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorMessage =
            jsonDecode(response.body)['message'] ?? 'Unknown error';
        throw Exception('Error: $errorMessage');
      }
    } catch (e) {
      debugPrint('Error updating boarding pass: $e');
      return false;
    }
  }

  Future<bool> checkPnrExists(String pnr) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/v2/boarding-pass/check-pnr?pnr=$pnr'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'];
      } else if (response.statusCode == 404) {
        // 404 is expected when PNR doesn't exist - not an error
        return false;
      } else {
        debugPrint('Error checking PNR: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking PNR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getBoardingPassDetails(
      String airlineCode, departureAirportCode, arrivalAirportCode) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$apiUrl/api/v2/boarding-pass/details?airline=$airlineCode&departure=$departureAirportCode&arrival=$arrivalAirportCode'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        debugPrint('Error: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      debugPrint('Error fetching boarding pass details: $e');
      return {};
    }
  }
}
