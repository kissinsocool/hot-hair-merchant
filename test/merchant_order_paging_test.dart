import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/booking/data/order_repository.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/data/merchant_salon_repository.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';

BookingOrder order(String id, String status, {String phone = ''}) =>
    BookingOrder.fromJson({
      'id': id,
      'userId': 'client',
      'userName': '顾客$id',
      'userPhone': phone,
      'salonName': 'Salon',
      'staffId': 'staff-1',
      'staffName': 'Stylist',
      'serviceName': '剪发',
      'servicePrice': '¥100',
      'serviceDuration': '30分钟',
      'status': status,
      'merchantMessage': status == 'pending'
          ? '您有一条新的预约申请，请及时处理。'
          : '用户已取消该预约。',
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

class CardOrdersRepository extends OrdersRepository {
  CardOrdersRepository(this.booking);
  final BookingOrder booking;

  @override
  Future<MerchantBookingPage> fetchMerchantBookingPage({
    required int page,
    Map<String, dynamic>? filters,
  }) async => MerchantBookingPage([booking], false);
}

void main() {
  for (final status in [
    'pending',
    'accepted',
    'completed',
    'canceled',
    'rejected',
  ]) {
    for (final phone in ['', '13800138000']) {
      testWidgets('$status card shows ordered details with phone "$phone"', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MerchantOrdersScreen(
              repository: CardOrdersRepository(
                order('BK1', status, phone: phone),
              ),
              salonRepository: SalonRepository(),
              enableRealtime: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (status != 'pending') {
          final tabIndex = status == 'accepted' || status == 'completed'
              ? 1
              : 2;
          await tester.tap(
            find.textContaining('${merchantOrderStatusTabs[tabIndex].$1}（'),
          );
          await tester.pumpAndSettle();
        }

        final details = [
          find.text('剪发'),
          find.text('指定理发师'),
          find.text('预约时间'),
          find.text('客户名称'),
          find.text('联系方式'),
          find.text('消费金额'),
          find.text('订单号'),
        ];
        for (var i = 0; i < details.length; i++) {
          expect(details[i], findsOneWidget);
          if (i > 0) {
            expect(
              tester.getTopLeft(details[i]).dy,
              greaterThan(tester.getTopLeft(details[i - 1]).dy),
            );
          }
        }
        expect(
          find.text('接单'),
          status == 'pending' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('拒单'),
          status == 'pending' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('预约变更'),
          status == 'pending' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('更改预约日期'),
          status == 'accepted' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('取消预约'),
          status == 'accepted' ? findsOneWidget : findsNothing,
        );
        for (final value in [
          'Stylist',
          '顾客BK1',
          phone.isEmpty ? '未提供' : phone,
          '¥100',
          'BK1',
        ]) {
          expect(
            tester.widget<Text>(find.text(value)).textAlign,
            TextAlign.right,
          );
          expect(
            tester.getTopRight(find.text(value)).dx,
            closeTo(tester.getTopRight(find.text('BK1')).dx, 0.1),
          );
        }
        expect(find.textContaining('您有一条'), findsNothing);
        if (status != 'pending') {
          expect(find.text('用户已取消该预约。'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

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
