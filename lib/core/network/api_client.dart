import 'package:dio/dio.dart';

bool hasMorePages(int loaded, int pageLength, int pageSize, int? total) =>
    pageLength > 0 && (total == null ? pageLength >= pageSize : loaded < total);

class ApiClient {
  ApiClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

  final Dio _dio;
  static String? authToken;
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://182.92.129.180:3000/api',
  );

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.request(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        method: method,
        headers: authToken == null
            ? null
            : {'Authorization': 'Bearer $authToken'},
      ),
    );
  }

  Future<List<dynamic>> requestAllPages(
    String path, {
    Map<String, dynamic>? queryParameters,
    int pageSize = 100,
    bool useTotal = true,
  }) async {
    final items = <dynamic>[];
    final limit = pageSize.clamp(1, 100);
    // ponytail: preserves the current full-list UI; switch to load-more before lists exceed 10,000 rows.
    for (var page = 1; page <= 100; page += 1) {
      final response = await request(
        path,
        queryParameters: {...?queryParameters, 'page': page, 'limit': limit},
      );
      final pageItems = response.data is List
          ? response.data as List
          : const [];
      items.addAll(pageItems);
      final total = useTotal
          ? int.tryParse(response.headers.value('x-total-count') ?? '')
          : null;
      if (!hasMorePages(items.length, pageItems.length, limit, total)) {
        break;
      }
    }
    return items;
  }
}
