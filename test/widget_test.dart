import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/theme/app_theme.dart';
import 'package:hot_pepper_merchant/features/booking/data/order_repository.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';

class FakeOrderRepository extends OrderRepository {
  @override
  Future<List<BookingOrder>> fetchMerchantBookings({String? status}) async {
    return [];
  }
}

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

    expect(order.startTime, DateTime.parse('2026-06-21T03:30:00.000Z').toLocal());
  });

  testWidgets('renders merchant orders home screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MerchantOrdersScreen(
          repository: FakeOrderRepository(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('商家订单'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('暂无订单'), findsOneWidget);
  });
}
