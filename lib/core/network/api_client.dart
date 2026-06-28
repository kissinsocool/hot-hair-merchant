import 'package:dio/dio.dart';

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
    defaultValue: 'http://localhost:3000/api',
  );

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    dynamic data,
  }) {
    return _dio.request(
      path,
      data: data,
      options: Options(
        method: method,
        headers: authToken == null
            ? null
            : {'Authorization': 'Bearer $authToken'},
      ),
    );
  }
}
