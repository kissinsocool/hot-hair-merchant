import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

void main() {
  test('parses booking timestamps as local time', () {
    final order = BookingOrder.fromJson({
      'id': 'BK1',
      'userId': 'U1',
      'userName': '测试用户',
      'salonName': '测试门店',
      'staffId': 'S1',
      'staffName': '测试发型师',
      'serviceName': '剪发',
      'servicePrice': '¥600',
      'serviceDuration': '30分钟',
      'startTime': '2026-06-21T03:30:00.000Z',
      'status': 'pending',
      'statusLabel': '等待商家确认',
      'userMessage': '',
      'merchantMessage': '',
      'createdAt': '2026-06-19T11:16:56.663Z',
      'updatedAt': '2026-06-19T11:18:03.466Z',
    });

    expect(
      order.startTime,
      DateTime.parse('2026-06-21T03:30:00.000Z').toLocal(),
    );
  });
}
