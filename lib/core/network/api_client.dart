import 'dart:convert';

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
  final Dio _uploadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
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

  Future<List<Map<String, dynamic>>> uploadBase64Images({
    required String type,
    required List<({String fileName, String base64Data})> images,
  }) async {
    if (images.isEmpty) return [];
    final prepared = images.map((image) {
      final comma = image.base64Data.indexOf(',');
      final header = comma < 0 ? '' : image.base64Data.substring(0, comma);
      final bytes = base64Decode(
        comma < 0 ? image.base64Data : image.base64Data.substring(comma + 1),
      );
      final contentType = RegExp(
        r'^data:(image/(?:jpeg|png|webp|gif));base64$',
      ).firstMatch(header)?.group(1);
      if (contentType == null) throw const FormatException('不支持的图片格式');
      return (fileName: image.fileName, contentType: contentType, bytes: bytes);
    }).toList();

    final response = await request(
      '/merchant/uploads/sign',
      method: 'POST',
      data: {
        'type': type,
        'files': prepared
            .map(
              (image) => {
                'fileName': image.fileName,
                'contentType': image.contentType,
                'size': image.bytes.length,
              },
            )
            .toList(),
      },
    );
    final uploads = ((response.data as Map)['uploads'] as List?) ?? const [];
    if (uploads.length != prepared.length) {
      throw StateError('图片上传凭证数量不正确');
    }

    await Future.wait(
      List.generate(prepared.length, (index) {
        final upload = Map<String, dynamic>.from(uploads[index] as Map);
        return _uploadDio.post(
          upload['uploadUrl'] as String,
          data: FormData.fromMap({
            ...Map<String, dynamic>.from(upload['fields'] as Map),
            'file': MultipartFile.fromBytes(
              prepared[index].bytes,
              filename: prepared[index].fileName,
            ),
          }),
        );
      }),
    );
    return uploads
        .map((upload) => Map<String, dynamic>.from(upload as Map))
        .toList();
  }
}
