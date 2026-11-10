import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

void main() {
  test('completed order source remains optional for released responses', () {
    final json = <String, dynamic>{
      'id': 'B1',
      'userId': 'u',
      'userName': '顾客',
      'salonName': '店铺',
      'staffName': '理发师',
      'serviceName': '剪发',
      'status': 'completed',
      'startTime': '2030-01-01T01:00:00Z',
      'createdAt': '2030-01-01T00:00:00Z',
      'updatedAt': '2030-01-01T02:00:00Z',
    };
    expect(BookingOrder.fromJson(json).completionSource, '');
    expect(
      BookingOrder.fromJson({
        ...json,
        'completionSource': 'automatic',
      }).completionSource,
      'automatic',
    );
    final manual = BookingOrder.fromJson({
      ...json,
      'completionSource': 'merchant',
      'completedAt': '2030-01-01T02:00:00Z',
    });
    expect(manual.completionSource, 'merchant');
    expect(manual.completedAt, isNotNull);
    expect(manual.canCorrectCompletedStatus, isTrue);
    expect(
      BookingOrder.fromJson({
        ...json,
        'complaint': {'status': 'handled'},
      }).canCorrectCompletedStatus,
      isFalse,
    );
  });

  test(
    'admin loads complaint pages and sends only the processing response',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final calls = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: options.method == 'PATCH'
                    ? {'ok': true}
                    : [
                        {
                          'bookingId': 'B1',
                          'type': 'complaint',
                          'handlingStatus': 'handled',
                          'response': '已核实',
                        },
                      ],
                headers: Headers.fromMap({
                  'x-total-count': ['1'],
                }),
              ),
            );
          },
        ),
      );
      final repository = AdminRepository(apiClient: ApiClient(dio: dio));
      final complaints = await repository.fetchUserComplaints();
      expect(complaints.single['response'], '已核实');
      expect(calls.single.path, '/admin/complaints');
      await repository.handleUserComplaint('B1', '已核实');
      expect(calls.last.path, '/admin/complaints/B1');
      expect(calls.last.method, 'PATCH');
      expect(calls.last.data, {'response': '已核实'});
      await repository.handleUserComplaint('B2', '误判', decision: 'approved');
      expect(calls.last.path, '/admin/complaints/B2');
      expect(calls.last.data, {'response': '误判', 'decision': 'approved'});
    },
  );
}
