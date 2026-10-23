import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/pages/admin_overview_page.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

class _Repository extends AdminRepository {
  int total = 3;
  int unread = 2;
  int marks = 0;
  int reads = 0;
  bool loadFails = false;
  bool markFails = false;
  bool supported = true;
  bool listWasBuilt = false;
  final before = '2026-10-23T02:00:00.000Z';

  @override
  Future<Map<String, dynamic>> fetchOverview() async {
    reads++;
    return {
      if (supported) ...{
        'todayBookingCount': total,
        'unviewedBookingCount': unread,
        'bookingsSnapshotBefore': before,
      },
    };
  }

  @override
  Future<List<BookingOrder>> fetchNewBookings(String snapshot) async {
    expect(snapshot, before);
    if (loadFails) throw Exception('今日新订单加载失败');
    return [
      BookingOrder(
        id: 'today-1',
        userId: 'user-1',
        userName: '今日下单用户',
        salonName: '今日预约店铺',
        staffId: '',
        staffName: '',
        serviceName: '剪发',
        servicePrice: '¥100',
        serviceDuration: '30分钟',
        startTime: DateTime(2026, 10, 25),
        status: 'pending',
        statusLabel: '待确认',
        userMessage: '',
        merchantMessage: '',
        createdAt: DateTime(2026, 10, 23, 9),
        updatedAt: DateTime(2026, 10, 23, 9),
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMerchants() async => [];
  @override
  Future<List<Map<String, dynamic>>> fetchUsers() async => [];

  @override
  Future<void> markNewBookingsViewed(String snapshot) async {
    expect(snapshot, before);
    marks++;
    listWasBuilt = find
        .text('今日新预约订单', skipOffstage: false)
        .evaluate()
        .isNotEmpty;
    if (markFails) throw Exception('已查看状态保存失败');
    unread = 0;
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  bool active = true,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminOverviewPage(
          repository: repository,
          onLogout: () {},
          active: active,
          refreshVersion: 0,
          onChanged: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'new orders card shows total and top-right unread badge; entry opens today orders before marking',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      expect(find.text('今日新订单'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(repository.marks, 0);
      await tester.tap(find.text('今日新订单'));
      await tester.pumpAndSettle();
      expect(find.text('今日新预约订单'), findsOneWidget);
      expect(find.textContaining('今日下单用户'), findsOneWidget);
      expect(repository.listWasBuilt, isTrue);
      expect(repository.marks, 1);
      // Orders arriving after the viewed snapshot remain unread on return.
      repository.unread = 1;
      repository.total = 4;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets(
    'successful viewing hides zero unread badge but keeps daily total',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.tap(find.text('今日新订单'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Badge), findsNothing);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('list load failure does not mark viewed or open empty screen', (
    tester,
  ) async {
    final repository = _Repository()..loadFails = true;
    await _mount(tester, repository);
    await tester.tap(find.text('今日新订单'));
    await tester.pumpAndSettle();
    expect(repository.marks, 0);
    expect(find.text('今日新预约订单'), findsNothing);
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('mark failure keeps unread badge on return and permits retry', (
    tester,
  ) async {
    final repository = _Repository()..markFails = true;
    await _mount(tester, repository);
    await tester.tap(find.text('今日新订单'));
    await tester.pumpAndSettle();
    expect(find.text('今日新预约订单'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.unread, 2);
    expect(find.byType(Badge), findsOneWidget);
    repository.markFails = false;
    await tester.tap(find.text('今日新订单'));
    await tester.pumpAndSettle();
    expect(repository.marks, 2);
  });

  testWidgets('old overview response disables new entry and omits badge', (
    tester,
  ) async {
    final repository = _Repository()..supported = false;
    await _mount(tester, repository);
    await tester.tap(find.text('今日新订单'));
    await tester.pumpAndSettle();
    expect(repository.marks, 0);
    expect(find.byType(Badge), findsNothing);
    expect(find.text('今日新预约订单'), findsNothing);
  });

  testWidgets(
    'active overview refreshes counts after 30 seconds without marking read',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      repository.unread = 5;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
      expect(find.text('5'), findsOneWidget);
      expect(repository.marks, 0);
    },
  );
}
