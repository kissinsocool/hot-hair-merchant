@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/widgets/native_multiline_text_field_web.dart';

class _TextareaRegistry extends ui_web.PlatformViewRegistry {
  late html.TextAreaElement textarea;

  @override
  bool registerViewFactory(
    String viewType,
    Function viewFactory, {
    bool isVisible = true,
  }) {
    textarea = viewFactory(0) as html.TextAreaElement;
    return super.registerViewFactory(
      viewType,
      viewFactory,
      isVisible: isVisible,
    );
  }
}

void main() {
  testWidgets('原生输入框获得焦点时营业时间下拉框失去焦点', (tester) async {
    final registry = _TextareaRegistry();
    ui_web.debugOverridePlatformViewRegistry(registry);
    addTearDown(() => ui_web.debugOverridePlatformViewRegistry(null));
    final dropdownFocus = FocusNode();
    addTearDown(dropdownFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DropdownButtonFormField<String>(
                focusNode: dropdownFocus,
                initialValue: '09:00',
                decoration: const InputDecoration(labelText: '营业开始时间'),
                items: const [
                  DropdownMenuItem(value: '09:00', child: Text('09:00')),
                  DropdownMenuItem(value: '10:00', child: Text('10:00')),
                ],
                onChanged: (_) {},
              ),
              NativeMultilineTextField(
                label: '店铺地址',
                value: '测试地址',
                onChanged: (_) {},
                minLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00').last);
    await tester.pumpAndSettle();
    expect(dropdownFocus.hasFocus, true);

    // Browser widget tests do not attach platform views to the DOM.
    final textarea = registry.textarea;
    html.document.body!.append(textarea);
    addTearDown(textarea.remove);
    await tester.runAsync(() async {
      textarea.focus();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(html.document.activeElement, textarea);
    expect(dropdownFocus.hasFocus, false);
    textarea.value = '新地址';
    textarea.dispatchEvent(html.Event('input'));
    textarea.setSelectionRange(0, 2);
    await tester.pump();
    expect(html.document.activeElement, textarea);
    expect(textarea.selectionEnd, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('uses a native textarea with browser-managed selection', () {
    var changedValue = '';
    final textarea = createNativeMultilineTextArea(
      label: '首页短介绍',
      value: '专业造型设计',
      maxLength: 30,
    );
    html.document.body!.append(textarea);
    addTearDown(textarea.remove);
    textarea.onInput.listen((_) => changedValue = textarea.value ?? '');

    expect(textarea.dataset['nativeSelectionField'], '首页短介绍');
    expect(textarea.style.touchAction, 'none');
    expect(textarea.value, '专业造型设计');
    expect(textarea.maxLength, 30);

    textarea.setSelectionRange(2, 6);
    expect(textarea.selectionStart, 2);
    expect(textarea.selectionEnd, 6);

    textarea.value = '剪发与染发';
    textarea.dispatchEvent(html.Event('input'));
    expect(changedValue, '剪发与染发');
  });

  test(
    'long descriptions grow without losing native selection or page gestures',
    () {
      final textarea = createNativeMultilineTextArea(
        label: '详情页关于我们',
        value: List.generate(20, (i) => '第$i行简介').join('\n'),
        maxLength: 200,
      )..style.width = '280px';
      html.document.body!.append(textarea);
      addTearDown(textarea.remove);
      textarea.focus();
      textarea.setSelectionRange(0, 4);

      final height = measureNativeTextAreaHeight(textarea, 5);
      textarea.style.height = '${height}px';
      expect(height, greaterThan(120));
      expect(textarea.scrollHeight, lessThanOrEqualTo(textarea.clientHeight));
      expect(textarea.style.touchAction, 'none');
      expect(textarea.style.overflowY, 'hidden');
      expect(html.document.activeElement, textarea);
      expect(textarea.selectionStart, 0);
      expect(textarea.selectionEnd, 4);

      textarea.value = '简短介绍';
      expect(measureNativeTextAreaHeight(textarea, 5), 120);
      textarea.value = List.filled(30, '造型设计').join();
      final wideHeight = measureNativeTextAreaHeight(textarea, 5);
      textarea.style.width = '100px';
      final narrowHeight = measureNativeTextAreaHeight(textarea, 5);
      expect(narrowHeight, greaterThan(wideHeight));
    },
  );

  test('address textarea has no length limit and supports selection', () {
    final textarea = createNativeMultilineTextArea(
      label: '店铺地址',
      value: '旧地址',
      hintText: '请重新定位生成店铺地址，也可以手动修改',
    );
    html.document.body!.append(textarea);
    addTearDown(textarea.remove);
    expect(textarea.maxLength, -1);
    expect(textarea.placeholder, '请重新定位生成店铺地址，也可以手动修改');

    expect(() => setNativeTextAreaMaxLength(textarea, null), returnsNormally);
    expect(textarea.maxLength, -1);

    textarea.focus();
    textarea.setSelectionRange(0, 2);
    expect(textarea.selectionStart, 0);
    expect(textarea.selectionEnd, 2);
    textarea.value = '定位得到的新地址';
    expect(textarea.value, '定位得到的新地址');
  });
}
