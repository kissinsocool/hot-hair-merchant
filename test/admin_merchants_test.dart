import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/pages/admin_merchants_page.dart';

void main() {
  for (final detailFails in [false, true]) {
    testWidgets(
      detailFails
          ? 'failed merchant detail request shows an error without a dialog'
          : 'merchant page loads summaries and fetches full content on demand',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const salon = {'id': 'salon-1', 'name': '摘要店铺'};
        const summary = {
          'id': 'merchant-1',
          'username': 'merchant',
          'displayName': '测试商家',
          'salonId': 'salon-1',
          'salonName': '摘要店铺',
          'publishStatus': 'online',
          'licenseStatus': 'approved',
          'contentReviewStatus': 'approved',
          'salon': salon,
        };
        final calls = <RequestOptions>[];
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              calls.add(options);
              switch (options.path) {
                case '/admin/merchants':
                  handler.resolve(
                    Response(requestOptions: options, data: [summary]),
                  );
                case '/admin/merchants/merchant-1' when !detailFails:
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'merchant': {
                          ...summary,
                          'salon': {
                            ...salon,
                            'description': '完整短介绍',
                            'fullDescription': '完整店铺介绍',
                            'services': [
                              {'name': '洗剪吹', 'note': '含造型'},
                            ],
                            'staff': [
                              {'name': '小林', 'bio': '擅长短发'},
                            ],
                          },
                        },
                      },
                    ),
                  );
                default:
                  handler.reject(DioException(requestOptions: options));
              }
            },
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminMerchantsPage(
                repository: AdminRepository(apiClient: ApiClient(dio: dio)),
                onLogout: () {},
                active: true,
                refreshVersion: 0,
                onChanged: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('测试商家'), findsOneWidget);
        expect(calls.single.method, 'GET');
        expect(calls.single.path, '/admin/merchants');
        expect(calls.single.queryParameters, {
          'view': 'summary',
          'page': 1,
          'limit': 100,
        });
        expect(find.byType(AlertDialog), findsNothing);

        await tester.tap(find.text('查看内容'));
        await tester.pumpAndSettle();
        expect(calls, hasLength(2));
        expect(calls.last.method, 'GET');
        expect(calls.last.path, '/admin/merchants/merchant-1');
        expect(calls.last.queryParameters, isEmpty);

        if (detailFails) {
          expect(find.text('店铺内容加载失败，请重试'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
        } else {
          expect(find.text('测试商家 店铺内容'), findsOneWidget);
          expect(find.text('短介绍：完整短介绍'), findsOneWidget);
          expect(find.text('关于我们：完整店铺介绍'), findsOneWidget);
          expect(find.text('套餐：洗剪吹 含造型'), findsOneWidget);
          expect(find.text('理发师：小林 擅长短发'), findsOneWidget);
        }
      },
    );
  }
}
