import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/main.dart';

void main() {
  testWidgets('登录输入框在安卓微信大字体下保持紧凑', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MerchantApp());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    expect(tester.getSize(fields.at(0)).height, lessThanOrEqualTo(52));
    expect(tester.getSize(fields.at(1)).height, lessThanOrEqualTo(52));
    expect(tester.takeException(), isNull);
  });
}
