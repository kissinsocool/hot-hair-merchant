@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/widgets/native_multiline_text_field_web.dart';

void main() {
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
    expect(textarea.value, '专业造型设计');
    expect(textarea.maxLength, 30);

    textarea.setSelectionRange(2, 6);
    expect(textarea.selectionStart, 2);
    expect(textarea.selectionEnd, 6);

    textarea.value = '剪发与染发';
    textarea.dispatchEvent(html.Event('input'));
    expect(changedValue, '剪发与染发');
  });
}
