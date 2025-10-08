import 'dart:convert';
import 'package:airline_app/models/airline_review_model.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:http/http.dart' as http;

class GetReviewAirlineController {
  Future<Map<String, dynamic>> saveAirlineReview(AirlineReviewModel review) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/airline-review'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(review.toJson()),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final errorMessage =
            jsonDecode(response.body)['message'] ?? 'Unknown error';
        throw Exception('Error: $errorMessage');
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
   Future<Map<String, dynamic>> getAirlineReviews() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/v2/airline-reviews'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch reviews data');
      }

      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    } catch (error) {
      return {'success': false, 'message': error.toString()};
    }
  }
  
  Future<Map<String, dynamic>> increaseUserPoints(String userId, int pointsToAdd) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/increase-user-points'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          '_id': userId,
          'pointsToAdd': pointsToAdd,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final errorMessage = jsonDecode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Error: $errorMessage');
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
