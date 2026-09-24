import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/core/theme/app_theme.dart';
import 'package:hot_pepper_merchant/features/account/data/merchant_account_repository.dart';
import 'package:hot_pepper_merchant/features/account/presentation/merchant_account_screen.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_auth_repository.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_session_store.dart';
import 'package:hot_pepper_merchant/features/auth/presentation/merchant_login_screen.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/data/image_upload_picker.dart';
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
        'promotionEnabled': false,
        'promotionReviewStatus': 'unsubmitted',
        'tagIds': ['wash_cut_blow'],
        'priceFen': 10000,
        'durationMinutes': 60,
        'note': '已有简介',
        'imageUrl': '',
      },
    ],
    'staff': [
      {
        'name': '已有理发师',
        'roleId': 'senior_barber',
        'experience': '5年',
        'extraServiceFeeFen': 1000,
        'imageUrl': '',
        'bio': '已有简介',
        'unavailableSlots': <String>[],
      },
    ],
  };
}

class _SuccessfulSalonRepository extends MerchantSalonRepository {
  Map<String, dynamic>? savedPayload;

  @override
  Future<Map<String, dynamic>> fetchSalon() async => {
    'name': '测试店铺',
    'address': '测试地址',
    'openingHours': '09:00-18:00',
    'phone': '13800138000',
    'description': '首页介绍',
    'fullDescription': '关于我们',
    'image': 'image',
    'promoImages': ['promo'],
    'services': [
      {
        'name': '套餐',
        'tagIds': ['wash_cut_blow'],
        'priceFen': 10000,
        'durationMinutes': 60,
        'note': '套餐介绍',
        'imageUrl': 'service-image',
      },
    ],
    'staff': [
      {
        'name': '理发师',
        'roleId': 'senior_barber',
        'experience': '5年',
        'extraServiceFeeFen': 1000,
        'imageUrl': 'staff-image',
        'bio': '理发师介绍',
        'unavailableSlots': <String>[],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> saveSalon(Map<String, dynamic> payload) async {
    savedPayload = payload;
    return {...payload, 'contentReviewStatus': 'approved'};
  }
}

class _LicenseOnlyAccountRepository extends MerchantAccountRepository {
  @override
  Future<Map<String, dynamic>> fetchQualification() async => {
    'licenseStatus': 'unsubmitted',
    'publishStatus': 'offline',
    'licenseUrl': '',
  };
}

void main() {
  test('后台待审核商家只按最后内容提交时间倒序排列，未提交的排最后', () {
    final merchants = [
      {'id': 'unsubmitted', 'contentReviewStatus': 'pending'},
      {
        'id': 'content-newest',
        'contentReviewStatus': 'pending',
        'contentSubmittedAt': '2026-09-14T12:00:00Z',
      },
      {
        'id': 'content-older',
        'contentReviewStatus': 'pending',
        'contentSubmittedAt': '2026-09-14T11:00:00Z',
      },
      {
        'id': 'license-only',
        'licenseStatus': 'pending',
        'licenseSubmittedAt': '2026-09-14T13:00:00Z',
        'contentSubmittedAt': '2026-09-14T12:30:00Z',
      },
    ];

    final sorted = sortMerchantsByContentSubmission(
      merchants.map((merchant) => Map<String, dynamic>.from(merchant)),
    ).map((merchant) => merchant['id']).toList();
    expect(sorted.take(3), ['license-only', 'content-newest', 'content-older']);
    expect(sorted.last, 'unsubmitted');
  });

  test('后台所有商家卡片标出最后内容提交时间', () {
    expect(
      merchantContentSubmissionText({
        'contentReviewStatus': 'pending',
        'contentSubmittedAt': '2026-09-14T12:34:00',
      }),
      '最后一次内容提交时间：2026-09-14 12:34',
    );
    expect(
      merchantContentSubmissionText({'contentReviewStatus': 'pending'}),
      '最后一次内容提交时间：暂无记录',
    );
    expect(
      merchantContentSubmissionText({
        'contentReviewStatus': 'approved',
        'contentSubmittedAt': '2026-09-13T08:00:00',
      }),
      '最后一次内容提交时间：2026-09-13 08:00',
    );
  });

  testWidgets('商家资质认证只要求上传营业执照', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantAccountScreen(
          session: const MerchantSession(
            token: 'token',
            user: {
              'username': 'merchant-test',
              'displayName': '测试商家',
              'salonId': 'salon-test',
            },
          ),
          onSessionChanged: (_) {},
          repository: _LicenseOnlyAccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('营业执照'), findsOneWidget);
    expect(find.text('法人身份证'), findsNothing);
    expect(find.text('地址证明'), findsNothing);
    expect(find.text('提交营业执照审核'), findsOneWidget);
  });

  testWidgets('店铺表单未填完时显示黑底红色叉号', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并提交审核'));
    await tester.pump();

    final message = tester.widget<Container>(
      find.byKey(const ValueKey('top-message')),
    );
    final decoration = message.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xff323232));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('top-message')),
        matching: find.byIcon(Icons.cancel_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('店铺表单提交成功使用指定绿色背景和文字', (tester) async {
    final repository = _SuccessfulSalonRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: repository,
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并提交审核'));
    await tester.pump();
    await tester.pump();

    final message = tester.widget<Container>(
      find.byKey(const ValueKey('top-message')),
    );
    final decoration = message.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xffc5e9cb));
    final savedStaff = (repository.savedPayload?['staff'] as List).single;
    expect(savedStaff, containsPair('roleId', 'senior_barber'));
    expect(savedStaff, isNot(contains('role')));
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('top-message')),
              matching: find.text('免审核内容已保存并直接生效'),
            ),
          )
          .style
          ?.color,
      const Color(0xff214623),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('top-message')),
        matching: find.byIcon(Icons.check_circle_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('店铺信息未提交时滑到套餐页再返回仍保留', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final salonName = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '店铺名称',
    );
    tester
        .widget<TextField>(salonName)
        .controller!
        .value = const TextEditingValue(
      text: 'Draft Salon Name',
      selection: TextSelection.collapsed(offset: 16),
      composing: TextRange(start: 0, end: 16),
    );
    await tester.pump();
    await tester.tap(find.text('服务套餐'));
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      1,
    );
    await tester.tap(find.text('店铺信息'));
    await tester.pumpAndSettle();

    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      0,
    );
    expect(find.text('Draft Salon Name'), findsOneWidget);
  });

  testWidgets('文本框输入后点击页面其他区域会失去焦点', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
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

    final salonName = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '店铺名称',
    );
    await tester.tap(salonName);
    await tester.pump();
    final editableText = tester.widget<EditableText>(
      find.descendant(of: salonName, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('店铺简介'));
    await tester.pump();

    expect(editableText.focusNode.hasFocus, isFalse);

    final shortDescription = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '首页短介绍',
    );
    await tester.tap(salonName);
    await tester.ensureVisible(shortDescription);
    await tester.pumpAndSettle();
    await tester.tap(shortDescription);
    await tester.pump();

    expect(editableText.focusNode.hasFocus, isFalse);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: shortDescription,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('点击文本框外部时不在 pointer down 阶段同步断开输入', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final salonName = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '店铺名称',
    );
    await tester.tap(salonName);
    await tester.pump();
    expect(tester.widget<TextField>(salonName).onTapOutside, isNull);
  });

  test('multi-image cropping skips one image but closes only from X', () async {
    final images = [
      for (var index = 0; index < 3; index++)
        PickedImage(
          fileName: '$index.jpg',
          base64Data: '',
          width: 1,
          height: 1,
        ),
    ];
    var calls = 0;

    final cropped = await cropPickedImageBatch(images, (
      image,
      index,
      total,
    ) async {
      calls++;
      return index == 1
          ? (image: null, closeBatch: false)
          : (image: Uint8List.fromList([index]), closeBatch: false);
    });

    expect(calls, 3);
    expect(cropped, [
      Uint8List.fromList([0]),
      Uint8List.fromList([2]),
    ]);

    final lastCanceled = await cropPickedImageBatch(images, (
      image,
      index,
      total,
    ) async {
      return index == total - 1
          ? (image: null, closeBatch: false)
          : (image: Uint8List.fromList([index]), closeBatch: false);
    });
    expect(lastCanceled, [
      Uint8List.fromList([0]),
      Uint8List.fromList([1]),
    ]);

    calls = 0;
    final closed = await cropPickedImageBatch(images, (
      image,
      index,
      total,
    ) async {
      calls++;
      return (image: null, closeBatch: true);
    });
    expect(calls, 1);
    expect(closed, isNull);
  });

  test('套餐标签使用稳定 ID 和前端展示文案', () {
    expect(serviceTagOptions.map((tag) => tag.id), [
      'wash_cut_blow',
      'color',
      'perm',
      'care',
      'styling',
      'scalp_care',
      'men',
      'women',
      'straight',
      'curly',
      'nutrition',
    ]);
    expect(serviceTagOptions.map((tag) => tag.label), [
      '洗剪吹',
      '染发',
      '烫发',
      '护理',
      '发型设计',
      '头皮护理',
      '男士',
      '女士',
      '直发',
      '卷发',
      '营养',
    ]);
  });

  test('理发师职级使用稳定 ID 且不保留展示文案', () {
    expect(staffRoleOptions.map((role) => role.id).toSet().length, 12);
    expect(
      staffRoleOptions.map((role) => role.label),
      containsAll(['主理人', '设计师', '资深设计师', '技术总监', '艺术总监', '技术店长']),
    );
    final profile = <String, dynamic>{
      'roleId': 'senior_designer',
      'role': '资深设计师',
    };
    normalizeStaffRole(profile);
    expect(profile, {'roleId': 'senior_designer'});
  });

  test('service gallery supports legacy covers, ordering and clearing', () {
    final service = <String, dynamic>{'imageUrl': 'first.jpg'};
    expect(serviceImageUrls(service), ['first.jpg']);
    setServiceImages(service, ['second.jpg', 'first.jpg']);
    expect(serviceImageUrls(service), ['second.jpg', 'first.jpg']);
    expect(service['imageUrl'], 'second.jpg');
    setServiceImages(service, []);
    expect(serviceImageUrls(service), isEmpty);
    expect(service['imageUrl'], '');
  });

  test('promotion requests stay switched on and populate the admin table', () {
    final service = <String, dynamic>{
      'id': 'service-1',
      'promotionEnabled': false,
      'promotionReviewStatus': 'pending',
    };
    normalizeServicePromotionRequest(service);
    expect(service['promotionEnabled'], isTrue);

    final rows = servicePromotionRows([
      {
        'id': 'merchant-1',
        'salon': {
          'name': '测试店铺',
          'services': [
            {...service, 'name': '男士精剪'},
            {
              'id': 'service-2',
              'name': '普通套餐',
              'promotionReviewStatus': 'unsubmitted',
            },
          ],
        },
      },
    ]);

    expect(rows, hasLength(1));
    expect(rows.single['merchantId'], 'merchant-1');
    expect(rows.single['salonName'], '测试店铺');
    expect(rows.single['name'], '男士精剪');
  });

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

  testWidgets('选择套餐图片时不会显示上传中或锁住其他套餐，取消后可以重选', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    final selection = Completer<List<String>>();
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) {
      if (call.method == 'pickMultiImage') {
        calls++;
        return selection.future;
      }
      return Future.value(null);
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
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
    final buttons = find.widgetWithText(OutlinedButton, '上传并裁剪');
    tester.widget<OutlinedButton>(buttons.first).onPressed!();
    await tester.pump();
    expect(calls, 1);
    expect(find.text('上传中'), findsNothing);
    expect(
      tester
          .widgetList<OutlinedButton>(buttons)
          .every((button) => button.onPressed != null),
      isTrue,
    );
    selection.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('上传中'), findsNothing);
    tester.widget<OutlinedButton>(buttons.first).onPressed!();
    await tester.pumpAndSettle();
    expect(calls, 2);
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

    final promotionSwitches = find.descendant(
      of: find.byTooltip('审核通过后展示在小程序分类推广页'),
      matching: find.byType(Switch),
    );
    expect(
      tester.widgetList<Switch>(promotionSwitches).every((item) => !item.value),
      isTrue,
    );
    expect(find.text('推广'), findsNWidgets(2));

    for (final tag in ['男士', '女士', '直发', '卷发', '营养']) {
      expect(find.widgetWithText(FilterChip, tag), findsWidgets);
    }

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

    final roleFields = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == '职位',
    );
    final roles = tester
        .widgetList<DropdownButtonFormField<String>>(roleFields)
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
    expect(roles, containsAll(<String?>[null, 'senior_barber']));
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

  testWidgets('套餐简介在窄屏和大字体下仍显示内容', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: MerchantSalonScreen(
          repository: _SalonRepositoryWithExistingItems(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务套餐'));
    await tester.pumpAndSettle();

    final introduction = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '简介',
    );
    expect(introduction, findsOneWidget);
    expect(
      find.descendant(of: introduction, matching: find.text('已有简介')),
      findsOneWidget,
    );
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

    final monday = find.byKey(const ValueKey('salon-weekly-closed-day-1'));
    final wednesday = find.byKey(const ValueKey('salon-weekly-closed-day-3'));
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

  testWidgets('理发师缺勤设置下方可设置每周定休日', (tester) async {
    final repository = _SuccessfulSalonRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSalonScreen(
          repository: repository,
          enableRealtime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('理发师').first);
    await tester.pumpAndSettle();

    final monday = find.byKey(const ValueKey('staff-0-weekly-closed-day-1'));
    expect(find.text('可选择该理发师每周固定休息的日期'), findsOneWidget);
    await tester.ensureVisible(monday);
    await tester.pumpAndSettle();
    await tester.tap(monday);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(monday).selected, isTrue);

    await tester.tap(find.text('保存并提交审核'));
    await tester.pump();
    await tester.pump();
    final savedStaff = (repository.savedPayload?['staff'] as List).single;
    expect(savedStaff['weeklyClosedDays'], [1]);
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
