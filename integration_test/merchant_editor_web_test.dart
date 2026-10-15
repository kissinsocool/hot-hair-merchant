// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hot_pepper_merchant/features/merchant/data/merchant_salon_repository.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_salon_screen.dart';

class _SalonRepository extends MerchantSalonRepository {
  Map<String, dynamic>? savedPayload;

  @override
  Future<Map<String, dynamic>> fetchSalon() async => {
    'name': '测试店铺',
    'address': '旧地址',
    'openingHours': '09:00-18:00',
    'phone': '13800138000',
    'description': '首页介绍',
    'fullDescription': '关于我们',
    'image': 'favicon.png',
    'promoImages': ['favicon.png'],
    'services': [
      {
        'name': '剪发套餐',
        'tagIds': ['wash_cut_blow'],
        'priceFen': 10000,
        'durationMinutes': 60,
        'note': '旧套餐简介',
        'imageUrl': 'favicon.png',
      },
    ],
    'staff': [
      {
        'name': '测试理发师',
        'roleId': 'senior_barber',
        'experience': '5年',
        'extraServiceFeeFen': 0,
        'imageUrl': 'favicon.png',
        'bio': '擅长短发',
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

html.TextAreaElement _textArea(String label) {
  html.TextAreaElement? findIn(html.Node node) {
    if (node is html.TextAreaElement &&
        node.dataset['nativeSelectionField'] == label) {
      return node;
    }
    if (node is html.Element && node.shadowRoot != null) {
      final found = findIn(node.shadowRoot!);
      if (found != null) return found;
    }
    for (final child in node.nodes) {
      final found = findIn(child);
      if (found != null) return found;
    }
    return null;
  }

  return findIn(html.document.body!) ?? (throw TestFailure('$label 未渲染原生输入框'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Web 店铺表单加载、重建、编辑和保存', (tester) async {
    final repository = _SalonRepository();
    Widget app() => MaterialApp(
      home: MerchantSalonScreen(repository: repository, enableRealtime: false),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('店铺信息'), findsWidgets);
    final initialAddress = _textArea('店铺地址');
    expect(initialAddress.value, '旧地址');

    // 资料加载后再次构建会走到原生输入框的 didUpdateWidget。
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final address = _textArea('店铺地址');
    expect(identical(address, initialAddress), isTrue);
    expect(address.maxLength, -1);
    address.value = '新地址';
    address.dispatchEvent(html.Event('input'));
    await tester.pump();

    await tester.tap(find.text('服务套餐').first);
    await tester.pumpAndSettle();
    final note = _textArea('简介');
    note.value = '新套餐简介';
    note.dispatchEvent(html.Event('input'));
    await tester.pump();

    await tester.tap(find.text('保存并提交审核'));
    await tester.pumpAndSettle();
    expect(repository.savedPayload?['address'], '新地址');
    expect(
      (repository.savedPayload?['services'] as List).first['note'],
      '新套餐简介',
    );
  });
}
