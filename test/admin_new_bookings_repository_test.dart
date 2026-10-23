import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';

Map<String, dynamic> _order(int id) => {
  'id': '$id',
  'userId': 'user',
  'userName': '用户',
  'salonName': '店铺',
  'staffName': '',
  'serviceName': '剪发',
  'status': 'pending',
  'startTime': '2026-10-25T01:00:00.000Z',
  'createdAt': '2026-10-23T01:00:00.000Z',
  'updatedAt': '2026-10-23T01:00:00.000Z',
};

void main() {
  test(
    'loads every page with one snapshot then marks only that snapshot viewed',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final calls = <RequestOptions>[];
      const before = '2026-10-23T02:00:00.000Z';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            if (options.method == 'POST') {
              handler.resolve(
                Response(requestOptions: options, data: {'ok': true}),
              );
              return;
            }
            final page = options.queryParameters['page'] as int;
            handler.resolve(
              Response(
                requestOptions: options,
                data: List.generate(
                  page == 1 ? 100 : 1,
                  (i) => _order((page - 1) * 100 + i),
                ),
                headers: Headers.fromMap({
                  'x-total-count': ['101'],
                }),
              ),
            );
          },
        ),
      );
      final repository = AdminRepository(apiClient: ApiClient(dio: dio));
      final orders = await repository.fetchNewBookings(before);
      expect(orders.length, 101);
      expect(orders.map((order) => order.id).toSet().length, 101);
      expect(calls.length, 2);
      for (final call in calls) {
        expect(call.path, '/admin/new-bookings');
        expect(call.queryParameters['before'], before);
      }
      await repository.markNewBookingsViewed(before);
      expect(calls.last.path, '/admin/new-bookings/viewed');
      expect(calls.last.method, 'POST');
      expect(calls.last.data, {'before': before});
    },
  );

  test(
    'page failure propagates without marking unread bookings as viewed',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final calls = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            if (calls.length == 1) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: List.generate(100, _order),
                ),
              );
            } else {
              handler.reject(DioException(requestOptions: options));
            }
          },
        ),
      );
      final repository = AdminRepository(apiClient: ApiClient(dio: dio));
      await expectLater(
        repository.fetchNewBookings('2026-10-23T02:00:00.000Z'),
        throwsA(isA<DioException>()),
      );
      expect(calls.map((call) => call.method), everyElement('GET'));
    },
  );
}
