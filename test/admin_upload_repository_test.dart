import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late AdminRepository repository;
  late List<RequestOptions> calls;
  late List<String> uploads;
  late bool failUpload;
  const imageData = 'data:image/png;base64,iVBORw0KGgo=';
  const imageUrl = 'https://media.example.com/uploads/new.png';

  setUp(() async {
    calls = [];
    uploads = [];
    failUpload = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.headers.value('authorization'), isNull);
      final bytes = await request.fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      uploads.add(latin1.decode(bytes));
      request.response.statusCode = failUpload ? 500 : 200;
      await request.response.close();
    });
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              data: options.method == 'POST'
                  ? {
                      'uploads': [
                        {
                          'url': imageUrl,
                          'uploadUrl': 'http://127.0.0.1:${server.port}/',
                          'fields': {
                            'key': 'uploads/new.png',
                            'policy': 'test-policy',
                          },
                        },
                      ],
                    }
                  : options.data,
            ),
          );
        },
      ),
    );
    repository = AdminRepository(apiClient: ApiClient(dio: dio));
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
  });

  for (final campaign in [false, true]) {
    Future<Map<String, dynamic>> save(AdminRepository repository) => campaign
        ? repository.saveCouponCampaign({
            'enabled': true,
            'promotionImageUrl': 'old',
            'promotionImageFileName': 'gift.png',
            'promotionImageData': imageData,
          })
        : repository.saveAd(
            imageUrl: 'old',
            link: '/pages/home/home',
            enabled: true,
            fileName: 'ad.png',
            base64Data: imageData,
          );

    test(
      '${campaign ? 'campaign' : 'ad'} uploads bytes before saving only the URL',
      () async {
        final result = await save(repository);
        expect(calls.map((c) => c.method), ['POST', 'PATCH']);
        expect(calls.first.path, '/admin/uploads/sign');
        expect(calls.first.data['files'], [
          {
            'fileName': campaign ? 'gift.png' : 'ad.png',
            'contentType': 'image/png',
            'size': 8,
          },
        ]);
        expect(uploads.single, contains('name="file"'));
        expect(
          uploads.single,
          contains(latin1.decode(base64Decode('iVBORw0KGgo='))),
        );
        expect(result[campaign ? 'promotionImageUrl' : 'imageUrl'], imageUrl);
        expect(result.keys, isNot(contains('data')));
        expect(result.keys, isNot(contains('fileName')));
        expect(result.keys, isNot(contains('promotionImageData')));
        expect(result.keys, isNot(contains('promotionImageFileName')));
      },
    );

    test(
      '${campaign ? 'campaign' : 'ad'} upload failure prevents saving',
      () async {
        failUpload = true;
        await expectLater(save(repository), throwsA(isA<DioException>()));
        expect(calls.map((c) => c.method), ['POST']);
      },
    );
  }

  test(
    'editing without a new image preserves URLs without uploading',
    () async {
      await repository.saveAd(
        imageUrl: imageUrl,
        link: '/pages/home/home',
        enabled: false,
      );
      final campaign = {
        'enabled': false,
        'promotionImageUrl': imageUrl,
        'promotionImageData': null,
        'promotionImageFileName': null,
      };
      final result = await repository.saveCouponCampaign(campaign);
      expect(calls.map((c) => c.method), ['PATCH', 'PATCH']);
      expect(uploads, isEmpty);
      expect(result['promotionImageUrl'], imageUrl);
      expect(campaign, contains('promotionImageData'));
    },
  );
}
