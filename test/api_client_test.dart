import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';

void main() {
  test('canceling an image upload interrupts the signing request', () async {
    final dio = Dio();
    final started = Completer<RequestOptions>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          started.complete(options);
        },
      ),
    );
    final token = CancelToken();
    final future = ApiClient(dio: dio).uploadBase64Images(
      type: 'public',
      images: [
        (fileName: 'test.png', base64Data: 'data:image/png;base64,AA=='),
      ],
      cancelToken: token,
    );
    final expectation = expectLater(
      future,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect((await started.future).cancelToken, same(token));
    token.cancel();
    await expectation;
    dio.close(force: true);
  });

  test('pagination stops at the reported total', () {
    expect(hasMorePages(100, 100, 100, 250), isTrue);
    expect(hasMorePages(250, 50, 100, 250), isFalse);
    expect(hasMorePages(100, 100, 100, null), isTrue);
    expect(hasMorePages(50, 50, 100, null), isFalse);
  });
}
