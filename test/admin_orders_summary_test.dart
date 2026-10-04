import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/admin_orders_summary_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

void main() {
  final julyOrder = _order('july', DateTime(2026, 7, 31, 23, 59), '甲店');
  final augustOrder = _order('august', DateTime(2026, 8, 1), '乙店');

  test('filters order creation time by month and day with shop search', () {
    final orders = [julyOrder, augustOrder];
    expect(
      filterAdminOrders(orders, dateFilter: OrderDateFilter.all).length,
      2,
    );
    expect(
      filterAdminOrders(
        orders,
        dateFilter: OrderDateFilter.month,
        selectedDate: DateTime(2026, 7),
      ).single.id,
      'july',
    );
    expect(
      filterAdminOrders(
        orders,
        dateFilter: OrderDateFilter.day,
        selectedDate: DateTime(2026, 8, 1),
        shopQuery: '乙',
      ).single.id,
      'august',
    );
  });

  test('status filter combines with date and shop filters', () {
    final orders = [
      julyOrder,
      _order('canceled', DateTime(2026, 8, 1), '乙店', status: 'canceled'),
      _order('completed', DateTime(2026, 8, 1), '乙店', status: 'completed'),
    ];
    for (final status in ['pending', 'canceled', 'completed']) {
      expect(
        filterAdminOrders(
          orders,
          dateFilter: OrderDateFilter.all,
          status: status,
        ).single.status,
        status,
      );
    }
    expect(
      filterAdminOrders(
        orders,
        dateFilter: OrderDateFilter.day,
        selectedDate: DateTime(2026, 8, 1),
        shopQuery: '乙',
        status: 'pending',
      ),
      isEmpty,
    );
  });

  testWidgets('shows merchant details and coupon in order summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOrdersSummaryScreen(
          orders: [julyOrder],
          merchants: [
            {
              'salonId': 'salon-1',
              'salon': {'phone': '123456', 'address': '测试路1号'},
            },
          ],
          users: const [],
        ),
      ),
    );

    expect(find.text('用户名称'), findsOneWidget);
    expect(find.text('订单状态'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
    expect(find.text('甲店\n电话：123456\n地址：测试路1号'), findsOneWidget);
    expect(find.text('满减券\n券码：SAVE10\n优惠 ¥10 · 实付 ¥90'), findsOneWidget);
    await tester.tap(find.text('全部状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无符合条件的订单'), findsOneWidget);
  });
}

BookingOrder _order(
  String id,
  DateTime createdAt,
  String salonName, {
  String status = 'pending',
}) => BookingOrder(
  id: id,
  userId: 'user-1',
  userName: '用户',
  userPhone: '18800000000',
  salonId: 'salon-1',
  salonName: salonName,
  staffId: '',
  staffName: '',
  serviceName: '剪发套餐',
  servicePrice: '¥100',
  serviceDuration: '30分钟',
  startTime: createdAt,
  status: status,
  statusLabel: '待确认',
  userMessage: '',
  merchantMessage: '',
  couponId: 'coupon-1',
  couponCode: 'SAVE10',
  couponTitle: '满减券',
  couponDiscountFen: 1000,
  payableAmountFen: 9000,
  createdAt: createdAt,
  updatedAt: createdAt,
);
