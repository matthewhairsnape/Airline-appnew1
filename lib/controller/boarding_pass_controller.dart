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

      if (response.statusCode == 201) {
        return true;
      } else {
        final errorMessage =
            jsonDecode(response.body)['message'] ?? 'Unknown error';
        throw Exception('Error: $errorMessage');
      }
    } catch (e) {
      debugPrint('Error saving boading pass: $e');
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
      } else {
        debugPrint('Error: ${response.statusCode}');
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
