import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_auth_repository.dart';
import 'package:hot_pepper_merchant/features/auth/presentation/merchant_login_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';
import 'package:hot_pepper_merchant/main.dart';

void main() {
  testWidgets('keeps the admin entry off the merchant login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantLoginScreen(
          repository: MerchantAuthRepository(),
          onLoggedIn: (_) {},
        ),
      ),
    );

    expect(find.text('商家登录'), findsOneWidget);
    expect(find.text('后台'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('shows admin login only for the admin portal', (tester) async {
    await tester.pumpWidget(const MerchantApp());
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/admin');
    await tester.pumpAndSettle();

    expect(find.text('后台登录'), findsOneWidget);
    expect(find.text('商家登录'), findsNothing);
  });

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

  test('filters out pending and accepted staff in the same time slot', () {
    final slot = DateTime(2026, 6, 21, 11, 30);
    final visibleStaff = availableStaffForOrder(
      [
        {'id': 'S1', 'name': '已占用'},
        {'id': 'S2', 'name': '空闲'},
      ],
      [
        _bookingOrder(id: 'BK1', staffId: 'S1', startTime: slot),
        _bookingOrder(
          id: 'BK2',
          staffId: 'S2',
          startTime: slot,
          status: 'pending',
        ),
      ],
      _bookingOrder(
        id: 'BK3',
        staffId: '',
        staffName: '无需指定',
        startTime: slot,
        status: 'pending',
      ),
    );

    expect(visibleStaff, isEmpty);
  });
}

BookingOrder _bookingOrder({
  required String id,
  String staffId = 'S1',
  String staffName = '测试发型师',
  required DateTime startTime,
  String status = 'accepted',
}) {
  return BookingOrder(
    id: id,
    userId: 'U1',
    userName: '测试用户',
    salonName: '测试门店',
    staffId: staffId,
    staffName: staffName,
    serviceName: '剪发',
    servicePrice: '¥600',
    serviceDuration: '30分钟',
    startTime: startTime,
    status: status,
    statusLabel: status,
    userMessage: '',
    merchantMessage: '',
    createdAt: startTime,
    updatedAt: startTime,
  );
}
