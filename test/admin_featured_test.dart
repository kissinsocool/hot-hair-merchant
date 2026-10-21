import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/data/admin_repository.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/pages/admin_merchants_page.dart';

class _Repository extends AdminRepository {
  bool? featured;
  bool fail = false;
  int writes = 0;
  Completer<void>? pending;

  Map<String, dynamic> get merchant => {
    'id': 'merchant-1',
    'username': 'merchant',
    'displayName': '测试商家',
    'salonId': 'salon-1',
    'publishStatus': 'online',
    'licenseStatus': 'approved',
    'contentReviewStatus': 'approved',
    'salon': {if (featured != null) 'isFeatured': featured},
  };

  @override
  Future<List<Map<String, dynamic>>> fetchMerchants() async => [merchant];

  @override
  Future<Map<String, dynamic>> updateMerchantFeatured({
    required String id,
    required bool isFeatured,
  }) async {
    expect(id, 'merchant-1');
    writes++;
    if (pending != null) await pending!.future;
    if (fail) throw Exception('精选保存失败');
    featured = isFeatured;
    return merchant;
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

void main() {
  testWidgets(
    'legacy missing field defaults off; saves on and off and restores',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      expect(find.text('精选'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repository.featured, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, repository);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repository.featured, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(repository.writes, 2);
    },
  );

  testWidgets(
    'pending save disables toggle; failure keeps old state and allows retry',
    (tester) async {
      final repository = _Repository()
        ..pending = Completer<void>()
        ..fail = true;
      await _mount(tester, repository);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.textContaining('精选保存失败'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(repository.writes, 2);
    },
  );
}
