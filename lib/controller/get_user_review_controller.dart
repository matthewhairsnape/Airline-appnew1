import 'package:dio/dio.dart';
import 'package:airline_app/utils/global_variable.dart';

class UserReviewService {
  final Dio _dio = Dio();

  Future<dynamic> getUserReviews(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final response = await _dio.get(
        '$apiUrl/api/v2/user-reviews',
        queryParameters: {
          'userId': userId,
        },
      );

      if (response.data['success']) {
        return response.data['data'];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
