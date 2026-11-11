import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/pages/admin_merchants_page.dart';

class _Repository extends AdminRepository {
  String district = '';
  String? savedDistrict;
  String? savedInitialPassword;
  List<String> districts = ['国贸', '林肯公园', '龙湖天街'];
  Object? districtsError;

  @override
  Future<List<String>> fetchBusinessDistricts() async {
    if (districtsError != null) throw districtsError!;
    return districts;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMerchants() async => [
    {
      'id': 'merchant-1',
      'username': 'merchant',
      'displayName': '测试商家',
      'salonId': 'salon-1',
      'salonName': '测试店铺',
      'licenseStatus': 'approved',
      'contentReviewStatus': 'approved',
      'publishStatus': 'online',
      'salon': {
        'id': 'salon-1',
        'name': '测试店铺',
        'tags': ['人气店铺'],
        'businessDistrict': district,
      },
    },
  ];

  @override
  Future<Map<String, dynamic>> updateMerchant({
    required String id,
    required String username,
    required String displayName,
    required String salonId,
    required String deposit,
    required List<String> tags,
    String? businessDistrict,
    String password = '',
  }) async {
    savedDistrict = businessDistrict;
    district = businessDistrict ?? district;
    return {};
  }

  @override
  Future<Map<String, dynamic>> createMerchant({
    required String username,
    required String displayName,
    required String password,
    required String salonId,
    required String deposit,
    required List<String> tags,
    String? businessDistrict,
  }) async {
    savedInitialPassword = password;
    savedDistrict = businessDistrict;
    district = businessDistrict ?? district;
    return {};
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminMerchantsPage(
          repository: repository,
          onLogout: () {},
          active: true,
          refreshVersion: 0,
          onChanged: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectDistrict(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _enterInitialPassword(WidgetTester tester, String password) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == '初始密码',
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, password);
}

void main() {
  testWidgets(
    'edit saves, displays, restores and clears the district below tags',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      expect(find.text('商圈：-'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('商圈：-')).dy,
        greaterThan(tester.getTopLeft(find.text('标签：人气店铺')).dy),
      );
      await tester.tap(find.byTooltip('编辑账号'));
      await tester.pumpAndSettle();
      await _selectDistrict(tester, '国贸');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repository.savedDistrict, '国贸');
      expect(find.text('商圈：国贸'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑账号'));
      await tester.pumpAndSettle();
      expect(find.text('国贸'), findsOneWidget);
      await _selectDistrict(tester, '未设置');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repository.savedDistrict, '');
      expect(find.text('商圈：-'), findsOneWidget);
    },
  );

  testWidgets('create selects a server district; cancel does not save', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await tester.tap(find.text('新增商家账号'));
    await tester.pumpAndSettle();
    await _selectDistrict(tester, '林肯公园');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, isNull);
    await tester.tap(find.text('新增商家账号'));
    await tester.pumpAndSettle();
    await _selectDistrict(tester, '龙湖天街');
    await _enterInitialPassword(tester, '1234567890');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, isNull);
    await _enterInitialPassword(tester, 'fixture-pass7');
    final salonId = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '店铺ID',
    );
    await tester.ensureVisible(salonId);
    await tester.enterText(salonId, ' ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, isNull);
    await tester.enterText(salonId, '1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, '龙湖天街');
  });

  testWidgets('loads new server options on every dialog opening', (
    tester,
  ) async {
    final repository = _Repository()..districts = ['庞各庄'];
    await _mount(tester, repository);
    await tester.tap(find.text('新增商家账号'));
    await tester.pumpAndSettle();
    await _selectDistrict(tester, '庞各庄');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, '庞各庄');
    expect(repository.savedInitialPassword, '123456');
    repository.districts = ['后端新增商圈'];
    await tester.tap(find.byTooltip('编辑账号'));
    await tester.pumpAndSettle();
    expect(find.text('庞各庄'), findsOneWidget);
    await _selectDistrict(tester, '后端新增商圈');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.savedDistrict, '后端新增商圈');
  });

  testWidgets('option loading failure can be retried without saving', (
    tester,
  ) async {
    final repository = _Repository()..districtsError = Exception('商圈加载失败，请重试');
    await _mount(tester, repository);
    await tester.tap(find.text('新增商家账号'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('商圈加载失败，请重试'), findsOneWidget);
    expect(repository.savedDistrict, isNull);
    repository.districtsError = null;
    await tester.tap(find.text('新增商家账号'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
