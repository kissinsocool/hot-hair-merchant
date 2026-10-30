import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_session_store.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';
import 'package:hot_pepper_merchant/main.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

import 'merchant_order_paging_test.dart'
    show OrdersRepository, SalonRepository, order;

class BadgeOrdersRepository extends OrdersRepository {
  int pending = 25;
  bool fail = false;
  final countFilters = <Map<String, dynamic>>[];

  @override
  Future<BookingOrder> updateMerchantBookingStatus(
    String bookingId, {
    required String action,
    String reason = '',
    String assignedStaffId = '',
    DateTime? startTime,
  }) async {
    pending--;
    return order(bookingId, action == 'accept' ? 'accepted' : 'rejected');
  }

  @override
  Future<Map<String, int>> fetchMerchantBookingCounts(
    Map<String, dynamic> filters,
  ) async {
    countFilters.add({...filters});
    if (fail) throw Exception('加载失败');
    return {'pending': filters.containsKey('staffId') ? 1 : pending};
  }
}

void main() {
  testWidgets('existing pending orders show a count on both navigation icons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = BadgeOrdersRepository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        home: MerchantHomeShell(
          session: const MerchantSession(token: 'test', user: {}),
          onLogout: () {},
          onSessionChanged: (_) {},
          orderRepository: repository,
          salonRepository: SalonRepository(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final destination = tester.widget<NavigationDestination>(
      find.widgetWithText(NavigationDestination, '订单'),
    );
    expect(destination.icon, isA<Badge>());
    expect((destination.icon as Badge).isLabelVisible, isTrue);
    expect(((destination.icon as Badge).label as Text).data, '25');

    await tester.tap(find.text('订单'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final selected = tester.widget<NavigationDestination>(
      find.widgetWithText(NavigationDestination, '订单'),
    );
    expect(selected.selectedIcon, isA<Badge>());
    expect((selected.selectedIcon as Badge).isLabelVisible, isTrue);
    expect(((selected.selectedIcon as Badge).label as Text).data, '25');
    await tester.ensureVisible(find.text('拒单'));
    await tester.tap(find.text('拒单'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.pending, 24);
    expect(find.text('24'), findsWidgets);

    // The badge counts the whole salon even when viewing one staff member.
    await tester.ensureVisible(find.text('全部理发师'));
    await tester.tap(find.text('全部理发师'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Stylist').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.countFilters.last, isEmpty);
    expect(find.text('新预约待接单（1）'), findsOneWidget);
    expect(find.text('24'), findsWidgets);

    // Resuming catches up with changes made while in the background.
    for (final count in [1000, 0, 3]) {
      repository.pending = count;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final current = tester.widget<NavigationDestination>(
        find.widgetWithText(NavigationDestination, '订单'),
      );
      final badge = current.selectedIcon as Badge;
      expect(badge.isLabelVisible, count > 0);
      expect((badge.label as Text).data, count > 999 ? '999+' : '$count');
    }
    repository.fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3'), findsWidgets);
    expect(find.byType(MerchantOrdersScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });
}
