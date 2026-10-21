import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';

import 'merchant_order_paging_test.dart'
    show order, SalonRepository, StatusOrdersRepository;

class AppealRepository extends StatusOrdersRepository {
  AppealRepository({Map<String, dynamic>? appeal}) {
    booking = order(
      'BK1',
      'completed',
      feedback: {'reviewed': true, 'merchantAppeal': ?appeal},
    );
  }

  final appeals = <({String id, String reason, String description})>[];
  Completer<void>? submitting;
  bool fail = false;

  @override
  Future<BookingOrder> submitMerchantAppeal(
    String bookingId, {
    required String reason,
    required String description,
  }) async {
    appeals.add((id: bookingId, reason: reason, description: description));
    if (submitting != null) await submitting!.future;
    if (fail) throw Exception('提交失败，请重试');
    return booking = order(
      bookingId,
      'completed',
      feedback: {
        'reviewed': true,
        'merchantAppeal': {
          'reason': reason,
          'description': description,
          'status': 'pending',
        },
      },
    );
  }
}

Future<void> mount(WidgetTester tester, AppealRepository repository) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MerchantOrdersScreen(
        repository: repository,
        salonRepository: SalonRepository(),
        enableRealtime: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('已接单（1）'));
  await tester.pumpAndSettle();
}

void main() {
  for (final reason in ['no_show', 'other']) {
    testWidgets(
      'feedback order submits $reason appeal and shows its saved detail',
      (tester) async {
        final repository = AppealRepository()..submitting = Completer<void>();
        await mount(tester, repository);
        expect(find.byKey(const ValueKey('order-status-BK1')), findsNothing);
        await tester.tap(find.text('申诉'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('提交申诉'));
        await tester.pumpAndSettle();
        expect(find.text('请填写情况说明'), findsOneWidget);
        expect(repository.appeals, isEmpty);
        if (reason == 'other') {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('其他情况').last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byKey(const ValueKey('merchant-appeal-description')),
          '  请核实实际到店情况  ',
        );
        await tester.tap(find.text('提交申诉'));
        await tester.pumpAndSettle();
        expect(repository.appeals.single, (
          id: 'BK1',
          reason: reason,
          description: '请核实实际到店情况',
        ));
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '提交中…'))
              .onPressed,
          isNull,
        );
        repository.submitting!.complete();
        await tester.pumpAndSettle();
        expect(repository.booking.status, 'completed');
        expect(repository.booking.reviewed, isTrue);
        expect(repository.updates, isEmpty);
        await tester.tap(find.text('查看申诉'));
        await tester.pumpAndSettle();
        expect(find.text('请核实实际到店情况'), findsOneWidget);
        expect(find.text('等待平台处理'), findsOneWidget);
        expect(find.text('提交申诉'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancel sends nothing and failed appeal retains text for retry', (
    tester,
  ) async {
    final repository = AppealRepository()..fail = true;
    await mount(tester, repository);
    await tester.tap(find.text('申诉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.appeals, isEmpty);
    await tester.tap(find.text('申诉'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('merchant-appeal-description'));
    await tester.enterText(input, '商家补充说明');
    await tester.tap(find.text('提交申诉'));
    await tester.pumpAndSettle();
    expect(find.text('提交失败，请重试'), findsOneWidget);
    expect(tester.widget<TextFormField>(input).controller!.text, '商家补充说明');
    repository.fail = false;
    await tester.tap(find.text('提交申诉'));
    await tester.pumpAndSettle();
    expect(repository.appeals, hasLength(2));
    expect(find.text('查看申诉'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (decision, label) in <(String?, String)>[
    (null, '已处理'),
    ('approved', '审核通过'),
    ('rejected', '未通过'),
  ]) {
    testWidgets(
      'handled $decision appeal displays the platform response without a resubmit form',
      (tester) async {
        final repository = AppealRepository(
          appeal: {
            'reason': 'other',
            'description': '实际情况说明',
            'status': 'handled',
            'decision': ?decision,
            'response': '平台已核实并记录处理结果',
          },
        );
        await mount(tester, repository);
        await tester.tap(find.text('查看申诉'));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(find.text('平台已核实并记录处理结果'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(repository.appeals, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
