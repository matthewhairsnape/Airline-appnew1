import 'package:dio/dio.dart';
import 'package:airline_app/utils/global_variable.dart';

class FeedService {
  final Dio _dio = Dio();

  Future<dynamic> getFilteredFeed({
    required String airType,
    required String? flyerClass,
    required String? category,
    String? searchQuery,
    required List<String> continents,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '$apiUrl/api/v2/feed-list',
        queryParameters: {
          'airType': airType,
          'flyerClass': flyerClass,
          'category': category,
          'searchQuery': searchQuery,
          'continents': continents.join(','),
          'page': page,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch filtered feed data');
    }
  }
}
