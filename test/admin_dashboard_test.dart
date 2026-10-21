import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

class _AdminRepository extends AdminRepository {
  final calls = <String>[];
  Object? merchantsError;
  Completer<Map<String, dynamic>>? overviewRequest;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> merchants = [];
  List<Map<String, dynamic>> appeals = [];
  List<Map<String, dynamic>> images = [];
  Object? appealError;

  @override
  Future<Map<String, dynamic>> fetchOverview() async {
    calls.add('overview');
    return overviewRequest == null ? {} : await overviewRequest!.future;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMerchants() async {
    calls.add('merchants');
    if (merchantsError != null) throw merchantsError!;
    return merchants;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    calls.add('users');
    return users;
  }

  @override
  Future<Map<String, dynamic>> reviewUserAvatar({
    required String id,
    required bool approve,
    String reason = '',
  }) async {
    calls.add('review-avatar');
    users = [
      {...users.single, 'avatarReviewStatus': 'approved'},
    ];
    return users.single;
  }

  @override
  Future<List<BookingOrder>> fetchBookings() async {
    calls.add('bookings');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUserImages() async {
    calls.add('images');
    return images;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookingAppeals() async {
    calls.add('appeals');
    return appeals;
  }

  @override
  Future<void> handleBookingAppeal(
    String bookingId,
    String response, {
    required String decision,
  }) async {
    calls.add('handle-appeal');
    if (appealError != null) throw appealError!;
    appeals = [
      {
        ...appeals.single,
        'status': 'handled',
        'response': response,
        'decision': decision,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSalonPosts() async {
    calls.add('posts');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSupportMessages() async {
    calls.add('support');
    return [];
  }

  @override
  Future<Map<String, dynamic>> fetchAd() async {
    calls.add('ad');
    return {'imageUrl': '', 'link': 'https://example.com', 'enabled': true};
  }

  @override
  Future<Map<String, dynamic>> fetchCouponCampaign() async {
    calls.add('campaign');
    return {};
  }
}

Future<void> _open(WidgetTester tester, String title) async {
  final tab = find.widgetWithText(Tab, title);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _AdminRepository repository, {
  VoidCallback? onLogout,
}) async {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AdminDashboardScreen(
        repository: repository,
        onLogout: onLogout ?? () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'complaints tabs switch between separate user and merchant lists',
    (tester) async {
      final repository = _AdminRepository()
        ..images = [
          {'type': 'complaint', 'bookingId': 'user-order', 'content': '用户投诉说明'},
        ]
        ..appeals = [
          {
            'bookingId': 'merchant-order',
            'description': '商家申诉说明',
            'status': 'pending',
          },
        ];
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      await _open(tester, '投诉管理');
      expect(find.text('用户投诉说明').hitTestable(), findsOneWidget);
      expect(find.text('商家申诉说明').hitTestable(), findsNothing);
      await tester.tap(find.widgetWithText(Tab, '商家申诉'));
      await tester.pumpAndSettle();
      expect(find.text('商家申诉说明').hitTestable(), findsOneWidget);
      expect(find.text('用户投诉说明').hitTestable(), findsNothing);
      await tester.tap(find.widgetWithText(Tab, '用户投诉'));
      await tester.pumpAndSettle();
      expect(find.text('用户投诉说明').hitTestable(), findsOneWidget);
      expect(repository.calls.where((call) => call == 'appeals'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (decision, label) in [('approved', '审核通过'), ('rejected', '未通过')]) {
    testWidgets(
      'complaints page handles $decision appeals and preserves a failed response for retry',
      (tester) async {
        final repository = _AdminRepository()
          ..appealError = Exception('处理失败，请重试')
          ..appeals = [
            {
              'bookingId': 'BK-appeal',
              'salonName': '测试商家',
              'userName': '顾客',
              'reason': 'no_show',
              'description': '用户没有到店，请核实',
              'status': 'pending',
            },
          ];
        await _mount(tester, repository);
        await tester.pumpAndSettle();
        await _open(tester, '投诉管理');
        await tester.tap(find.widgetWithText(Tab, '商家申诉'));
        await tester.pumpAndSettle();
        final handle = find.text('处理申诉');
        await tester.ensureVisible(handle);
        await tester.tap(handle);
        await tester.pumpAndSettle();
        await tester.tap(find.text('提交处理意见'));
        await tester.pumpAndSettle();
        expect(find.text('请填写处理意见'), findsOneWidget);
        expect(find.text('请选择审核结果'), findsOneWidget);
        expect(repository.calls, isNot(contains('handle-appeal')));
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '平台核实情况后予以记录');
        await tester.tap(find.text('提交处理意见'));
        await tester.pumpAndSettle();
        expect(find.text('处理失败，请重试'), findsOneWidget);
        expect(find.text('平台核实情况后予以记录'), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        repository.appealError = null;
        await tester.tap(find.text('提交处理意见'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('已处理'), findsOneWidget);
        expect(find.text('处理申诉'), findsNothing);
        expect(repository.appeals.single['response'], '平台核实情况后予以记录');
        expect(repository.appeals.single['decision'], decision);
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'merchant name search sits above tabs at 80% width and filters each category',
    (tester) async {
      final repository = _AdminRepository()
        ..merchants = [
          {
            'displayName': '小林造型',
            'licenseStatus': 'approved',
            'contentReviewStatus': 'approved',
            'publishStatus': 'online',
          },
          {
            'displayName': '账号二',
            'salonName': '小林 Hair',
            'licenseStatus': 'approved',
            'contentReviewStatus': 'approved',
            'publishStatus': 'online',
          },
          {
            'displayName': '账号三',
            'salon': {'name': '小林理发'},
            'licenseStatus': 'pending',
          },
          {
            'displayName': '账号四',
            'salonName': '小林精选',
            'licenseStatus': 'approved',
            'contentReviewStatus': 'approved',
            'publishStatus': 'offline',
          },
          {
            'displayName': '其他店',
            'licenseStatus': 'approved',
            'contentReviewStatus': 'approved',
            'publishStatus': 'online',
          },
        ];
      await _mount(tester, repository);
      await _open(tester, '商家账号');
      final search = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '按商家名称搜索',
      );
      final tabs = find.widgetWithText(Tab, '已上架');
      expect(
        tester.getSize(search).width,
        closeTo(
          tester.getSize(find.byType(AdminDashboardScreen)).width * 0.8,
          0.1,
        ),
      );
      expect(
        tester.getBottomLeft(search).dy,
        lessThan(tester.getTopLeft(tabs).dy),
      );

      await tester.enterText(search, ' 小林 ');
      await tester.pumpAndSettle();
      expect(find.text('小林造型'), findsOneWidget);
      expect(find.text('账号二'), findsOneWidget);
      expect(find.text('其他店'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, '待审核'));
      await tester.pumpAndSettle();
      expect(find.text('账号三'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, '未上架'));
      await tester.pumpAndSettle();
      expect(find.text('账号四'), findsOneWidget);
      await tester.enterText(search, '不存在的名字');
      await tester.pumpAndSettle();
      expect(find.text('未找到匹配的商家'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, '已上架'));
      await tester.enterText(search, ' hAiR ');
      await tester.pumpAndSettle();
      expect(find.text('账号二'), findsOneWidget);
      expect(find.text('小林造型'), findsNothing);
      await _open(tester, '概览');
      await _open(tester, '商家账号');
      expect(tester.widget<TextField>(search).controller!.text, ' hAiR ');
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(find.text('其他店'), findsOneWidget);
      expect(repository.calls.where((call) => call == 'merchants').length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loads each page on demand and refreshes only the selected page',
    (tester) async {
      final repository = _AdminRepository();
      await _mount(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.calls, ['overview']);
      await _open(tester, '商家账号');
      expect(repository.calls, ['overview', 'merchants']);
      await _open(tester, '客户端用户');
      await _open(tester, '评论管理');
      await _open(tester, '动态审核');
      await _open(tester, '套餐推广');
      await _open(tester, '投诉管理');
      await _open(tester, '客服消息');
      await _open(tester, '广告位');
      await _open(tester, '活动管理');
      expect(repository.calls, [
        'overview',
        'merchants',
        'users',
        'images',
        'posts',
        'merchants',
        'images',
        'users',
        'appeals',
        'support',
        'ad',
        'campaign',
      ]);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(repository.calls.last, 'campaign');
      expect(repository.calls.where((call) => call == 'campaign').length, 2);
      await _open(tester, '概览');
      expect(repository.calls.where((call) => call == 'overview').length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a page failure does not block other pages and can be retried', (
    tester,
  ) async {
    final repository = _AdminRepository()..merchantsError = Exception('商家加载失败');
    await _mount(tester, repository);
    await _open(tester, '商家账号');
    expect(find.text('商家加载失败'), findsOneWidget);
    await _open(tester, '概览');
    expect(find.text('昨日首页曝光'), findsOneWidget);
    await _open(tester, '商家账号');
    repository.merchantsError = null;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('商家加载失败'), findsNothing);
    expect(repository.calls.where((call) => call == 'merchants').length, 3);
  });

  testWidgets('an expired session on any page returns to login', (
    tester,
  ) async {
    final request = RequestOptions(path: '/admin/merchants');
    final repository = _AdminRepository()
      ..merchantsError = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
    var loggedOut = false;
    await _mount(tester, repository, onLogout: () => loggedOut = true);
    await _open(tester, '商家账号');
    expect(loggedOut, isTrue);
  });

  testWidgets('switching pages preserves an unsaved ad form', (tester) async {
    final repository = _AdminRepository()
      ..users = [
        {
          'id': 'user-1',
          'displayName': '测试用户',
          'avatarReviewStatus': 'pending',
        },
      ];
    await _mount(tester, repository);
    await _open(tester, '广告位');
    await tester.enterText(
      find.byType(TextField).first,
      'https://draft.example.com',
    );
    await _open(tester, '客户端用户');
    await tester.tap(find.widgetWithText(FilledButton, '通过'));
    await tester.pumpAndSettle();
    await _open(tester, '广告位');
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'https://draft.example.com');
    expect(repository.calls.where((call) => call == 'ad').length, 1);
  });

  testWidgets('review updates its page and invalidates cached related pages', (
    tester,
  ) async {
    final repository = _AdminRepository()
      ..users = [
        {
          'id': 'user-1',
          'displayName': '测试用户',
          'avatarReviewStatus': 'pending',
        },
      ];
    await _mount(tester, repository);
    await _open(tester, '客户端用户');
    await tester.tap(find.widgetWithText(FilledButton, '通过'));
    await tester.pumpAndSettle();
    expect(repository.calls, ['overview', 'users', 'review-avatar', 'users']);
    expect(find.text('暂无待审核头像'), findsOneWidget);
    await _open(tester, '概览');
    expect(repository.calls.last, 'overview');
    expect(repository.calls.where((call) => call == 'overview').length, 2);
  });

  testWidgets(
    'order datasets are fetched only when opening the order summary',
    (tester) async {
      final repository = _AdminRepository();
      await _mount(tester, repository);
      await tester.tap(find.text('全部订单'));
      await tester.pumpAndSettle();
      expect(repository.calls, ['overview', 'bookings', 'merchants', 'users']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an older refresh cannot overwrite a newer refresh result', (
    tester,
  ) async {
    final oldRequest = Completer<Map<String, dynamic>>();
    final newRequest = Completer<Map<String, dynamic>>();
    final repository = _AdminRepository()..overviewRequest = oldRequest;
    await _mount(tester, repository);
    repository.overviewRequest = newRequest;
    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();
    newRequest.complete({'merchantCount': 222});
    await tester.pumpAndSettle();
    expect(find.text('222'), findsOneWidget);
    oldRequest.complete({'merchantCount': 111});
    await tester.pumpAndSettle();
    expect(find.text('222'), findsOneWidget);
    expect(find.text('111'), findsNothing);
  });
}
