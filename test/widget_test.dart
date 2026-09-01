import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/core/theme/app_theme.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_auth_repository.dart';
import 'package:hot_pepper_merchant/features/auth/presentation/merchant_login_screen.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/data/merchant_salon_repository.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_salon_screen.dart';
import 'package:hot_pepper_merchant/main.dart';

class _SalonRepositoryWithExistingItems extends MerchantSalonRepository {
  @override
  Future<Map<String, dynamic>> fetchSalon() async => {
    'address': '已有地址',
    'services': [
      {
        'name': '已有套餐',
        'tags': ['洗剪吹'],
        'priceFen': 10000,
        'durationMinutes': 60,
        'note': '已有简介',
        'imageUrl': '',
      },
    ],
    'staff': [
      {
        'name': '已有理发师',
        'role': '高级理发师',
        'experience': '5年',
        'extraServiceFeeFen': 1000,
        'imageUrl': '',
        'bio': '已有简介',
        'unavailableSlots': <String>[],
      },
    ],
  };
}

void main() {
  test('API errors are converted to user-facing text without status codes', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/admin/merchants/1/publish'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/admin/merchants/1/publish'),
        statusCode: 409,
        data: {'message': 'Conflict'},
      ),
      type: DioExceptionType.badResponse,
    );

    final message = userFacingApiError(error);

    expect(message, '当前状态已发生变化，请刷新后重试');
    expect(message, isNot(contains('409')));
    expect(message, isNot(contains('DioException')));
  });

  test(
    'expired merchant sessions show a login prompt instead of Dio details',
    () {
      final request = RequestOptions(path: '/merchant/uploads/sign');
      final error = DioException(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 401,
          data: {'message': 'Merchant login expired'},
        ),
        type: DioExceptionType.badResponse,
      );

      final message = userFacingApiError(error);

      expect(message, '登录已失效，请重新登录');
      expect(message, isNot(contains('DioException')));
    },
  );

  test(
    'API errors keep readable backend messages and explain network failures',
    () {
      final request = RequestOptions(path: '/admin/merchants/1/publish');
      final backendMessage = DioException(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 409,
          data: {'message': '店铺内容审核通过后才能上架'},
        ),
        type: DioExceptionType.badResponse,
      );
      final networkError = DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );

      expect(userFacingApiError(backendMessage), '店铺内容审核通过后才能上架');
      expect(userFacingApiError(networkError), '网络连接失败，请检查网络后重试');
    },
  );

  test('merchant service prices use priceFen as the only value', () {
    expect(parsePriceFen('800'), 80000);
    expect(parsePriceFen('199.50'), 19950);
    expect(parsePriceFen(''), isNull);
    expect(formatPriceFenForInput(80000), '800');
    expect(formatPriceFenForInput(19950), '199.50');
  });

  test('merchant salon numeric fields use canonical API values', () {
    final service = <String, dynamic>{'durationMinutes': 90};
    final staff = <String, dynamic>{'extraServiceFeeFen': 20000};

    setServiceDuration(service, 120);
    setStaffExtraServiceFee(staff, 201);

    expect(service, {'durationMinutes': 120});
    expect(staff, {'extraServiceFeeFen': 20100});
  });

  testWidgets('新增套餐和理发师时表单不预选内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('服务套餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加套餐'));
    await tester.pump();

    final durations = tester
        .widgetList<DropdownButtonFormField<int>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<int> &&
                widget.decoration.labelText == '时长',
          ),
        )
        .map((field) => field.initialValue);
    expect(durations, containsAll(<int?>[null, 60]));

    await tester.tap(find.text('理发师').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加理发师'));
    await tester.pump();

    final roles = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<String> &&
                widget.decoration.labelText == '职位',
          ),
        )
        .map((field) => field.initialValue);
    final experienceYears = tester
        .widgetList<DropdownButtonFormField<int>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<int> &&
                widget.decoration.labelText == '经验',
          ),
        )
        .map((field) => field.initialValue);
    expect(roles, containsAll(<String?>[null, '高级理发师']));
    expect(experienceYears, containsAll(<int?>[null, 5]));
  });

  testWidgets('套餐图片上传按钮在 iPhone 14 宽度下不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务套餐'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('店铺资料区分定休日和其它休息日', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('定休日'), findsOneWidget);
    expect(find.text('其它休息日'), findsOneWidget);
    expect(find.text('休息日'), findsNothing);
    expect(find.textContaining('一个月内'), findsOneWidget);

    final monday = find.byKey(const ValueKey('weekly-closed-day-1'));
    final wednesday = find.byKey(const ValueKey('weekly-closed-day-3'));
    expect(tester.widget<ChoiceChip>(monday).selected, isFalse);
    expect(tester.widget<ChoiceChip>(monday).backgroundColor, Colors.grey[200]);

    await tester.ensureVisible(monday);
    await tester.pumpAndSettle();
    await tester.tap(monday);
    await tester.pump();
    await tester.tap(wednesday);
    await tester.pump();

    expect(tester.widget<ChoiceChip>(monday).selected, isTrue);
    expect(tester.widget<ChoiceChip>(wednesday).selected, isTrue);
    expect(
      tester.widget<ChoiceChip>(monday).selectedColor,
      AppTheme.primaryPink,
    );

    await tester.tap(monday);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(monday).selected, isFalse);
    expect(tester.widget<ChoiceChip>(wednesday).selected, isTrue);
  });

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
    expect(find.text('我已阅读并同意'), findsOneWidget);
    expect(find.text('靓丝商家服务协议'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('靓丝商家服务规范'), findsNothing);
    expect(find.byKey(const ValueKey('terms-unselected')), findsOneWidget);
  });

  testWidgets('shows admin login only for the admin portal', (tester) async {
    await tester.pumpWidget(const MerchantApp());
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/admin');
    await tester.pumpAndSettle();

    expect(find.text('后台登录'), findsOneWidget);
    expect(find.text('商家登录'), findsNothing);
    expect(find.text('靓丝商家服务协议'), findsNothing);
    expect(find.text('隐私政策'), findsNothing);
    expect(find.byKey(const ValueKey('terms-selection')), findsNothing);
  });

  testWidgets('handles a document launch failure without an uncaught error', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) => throw PlatformException(code: 'unavailable'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantLoginScreen(
          repository: MerchantAuthRepository(),
          onLoggedIn: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('靓丝商家服务协议'));
    await tester.pumpAndSettle();

    expect(find.text('无法打开协议，请稍后重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('parses booking timestamps as local time', () {
    final order = BookingOrder.fromJson({
      'id': 'BK1',
      'userId': 'U1',
      'userName': '测试用户',
      'userPhone': '13800138000',
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
    expect(order.userPhone, '13800138000');
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

  test('keeps the current booking slot enabled while disabling conflicts', () {
    final startTime = DateTime.now().add(const Duration(days: 1));
    final order = _bookingOrder(id: 'BK1', staffId: 'S1', startTime: startTime);
    expect(
      isBookingSlotEnabled(
        {'startTime': startTime.toIso8601String(), 'isAvailable': false},
        order,
        startTime,
      ),
      isTrue,
    );
    expect(
      isBookingSlotEnabled(
        {
          'startTime': startTime
              .add(const Duration(minutes: 30))
              .toIso8601String(),
          'isAvailable': false,
        },
        order,
        startTime,
      ),
      isFalse,
    );
  });

  test('groups canceled and rejected orders in the canceled tab', () {
    final canceledStatuses = merchantOrderStatusTabs[3].$2;

    expect(merchantOrderStatusTabs[3].$1, '已取消');
    expect(canceledStatuses, containsAll(['canceled', 'rejected']));
    expect(canceledStatuses, isNot(contains('completed')));
  });

  test('date filtering does not hide pending merchant orders', () {
    final selectedDate = DateTime(2026, 7, 25);
    final oldPending = _bookingOrder(
      id: 'pending',
      startTime: DateTime(2026, 7, 20),
      status: 'pending',
    );
    final oldCompleted = _bookingOrder(
      id: 'completed',
      startTime: DateTime(2026, 7, 20),
      status: 'completed',
    );

    expect(isMerchantOrderVisible(oldPending, selectedDate, ''), isTrue);
    expect(isMerchantOrderVisible(oldCompleted, selectedDate, ''), isFalse);
    expect(isMerchantOrderVisible(oldCompleted, null, ''), isTrue);
  });

  test('accounting deducts unfinished and canceled orders', () {
    final startTime = DateTime(2026, 7, 1);
    final totals = calculateOrderAccounting([
      for (final status in [
        'completed',
        'pending',
        'accepted',
        'canceled',
        'rejected',
      ])
        _bookingOrder(id: status, startTime: startTime, status: status),
    ]);

    expect(totals.total, 3000);
    expect(totals.unfinished, 1200);
    expect(totals.canceled, 1200);
    expect(totals.result, 600);
    expect(totals.unfinishedCount, 2);
    expect(totals.canceledCount, 2);
    expect(totals.resultCount, 1);
  });

  test('matches support messages to user orders across id prefixes', () {
    final order = _bookingOrder(
      id: 'BK1',
      staffId: 'S1',
      startTime: DateTime(2026, 7, 24),
    );

    expect(supportOrdersForUser([order], 'user-${order.userId}'), [order]);
    expect(supportOrdersForUser([order], 'another-user'), isEmpty);
  });

  test('recognizes final comment audit statuses', () {
    expect(isAuditedReviewStatus('pending'), isFalse);
    expect(isAuditedReviewStatus('approved'), isTrue);
    expect(isAuditedReviewStatus('rejected'), isTrue);
  });

  test('labels every avatar review state for the admin user table', () {
    expect(avatarReviewStatusLabel('pending'), '待审核');
    expect(avatarReviewStatusLabel('approved'), '已通过');
    expect(avatarReviewStatusLabel('rejected'), '已驳回');
    expect(avatarReviewStatusLabel(null), '未提交');
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
