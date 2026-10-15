import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/booking/data/order_repository.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/data/merchant_salon_repository.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';

BookingOrder order(String id, String status) => BookingOrder.fromJson({
  'id': id,
  'userId': 'client',
  'userName': '顾客$id',
  'salonName': 'Salon',
  'staffId': 'staff-1',
  'staffName': 'Stylist',
  'serviceName': '剪发',
  'status': status,
  'startTime': DateTime.now().toIso8601String(),
  'createdAt': DateTime.now().toIso8601String(),
  'updatedAt': DateTime.now().toIso8601String(),
});

class SalonRepository extends MerchantSalonRepository {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> fetchSalon() async {
    calls++;
    return {
      'staff': [
        {'id': 'staff-1', 'name': 'Stylist'},
      ],
    };
  }
}

class OrdersRepository extends OrderRepository {
  final requests = <({int page, Map<String, dynamic> filters})>[];
  Completer<MerchantBookingPage>? first;
  @override
  Future<MerchantBookingPage> fetchMerchantBookingPage({
    required int page,
    Map<String, dynamic>? filters,
  }) async {
    requests.add((page: page, filters: {...?filters}));
    if (first != null && requests.length == 1) return first!.future;
    final status = filters?['statuses'] == 'pending' ? 'pending' : 'accepted';
    return MerchantBookingPage([
      order('page-$page-$status', status),
    ], page == 1);
  }

  @override
  Future<Map<String, int>> fetchMerchantBookingCounts(
    Map<String, dynamic> filters,
  ) async => {'pending': 25, 'accepted': 1};
  @override
  Future<List<BookingOrder>> fetchMerchantBookings({
    String? status,
    DateTime? date,
  }) => throw StateError('Full history must not be loaded by page refresh');
}

void main() {
  testWidgets(
    'merchant loads scoped pages and counts; load more reuses staff configuration',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = OrdersRepository();
      final salon = SalonRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantOrdersScreen(
            repository: repository,
            salonRepository: salon,
            enableRealtime: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requests.length, 1);
      expect(repository.requests.single.filters['includePending'], 'true');
      expect(repository.requests.single.filters['statuses'], 'pending');
      expect(
        repository.requests.single.filters.containsKey('fromDate'),
        isTrue,
      );
      expect(find.text('新预约待接单（25）'), findsOneWidget);
      final more = find.byKey(const ValueKey('merchant-orders-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repository.requests.length, 2);
      expect(repository.requests.last.page, 2);
      expect(salon.calls, 1);
      expect(find.text('加载更多订单'), findsNothing);
    },
  );

  testWidgets(
    'changing status while a query is running discards old data and catches up',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = Completer<MerchantBookingPage>();
      final repository = OrdersRepository()..first = first;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantOrdersScreen(
            repository: repository,
            salonRepository: SalonRepository(),
            enableRealtime: false,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('已接单（0）'));
      await tester.pump();
      expect(repository.requests.length, 1, reason: 'queries must not overlap');
      first.complete(MerchantBookingPage([order('stale', 'pending')], false));
      await tester.pumpAndSettle();
      expect(repository.requests.length, 2);
      expect(
        repository.requests.last.filters['statuses'],
        'accepted,completed',
      );
      expect(find.textContaining('顾客stale'), findsNothing);
      expect(find.text('已接单（1）'), findsOneWidget);
    },
  );
}
