import 'package:dio/dio.dart';
import 'package:airline_app/utils/global_variable.dart';

class TopReviewService {
  final Dio _dio = Dio();

  Future<dynamic> getTopReviews() async {
    try {
      final response = await _dio.get(
        '$apiUrl/api/v2/top-reviews',
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch top reviews data');
    }
  }
}
