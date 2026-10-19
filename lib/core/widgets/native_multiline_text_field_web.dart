// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

html.TextAreaElement createNativeMultilineTextArea({
  required String label,
  required String value,
  int? maxLength,
  String? hintText,
}) {
  final textarea = html.TextAreaElement()
    ..value = value
    ..setAttribute('aria-label', label)
    ..setAttribute('data-native-selection-field', label)
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.boxSizing = 'border-box'
    ..style.margin = '0'
    ..style.padding = '0'
    ..style.border = '0'
    ..style.outline = 'none'
    ..style.resize = 'none'
    ..style.overflowY = 'hidden'
    ..style.backgroundColor = 'transparent'
    ..style.color = '#5b5452'
    ..style.fontSize = '16px'
    ..style.lineHeight = '1.5'
    ..style.fontFamily =
        '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    ..style.setProperty('-webkit-user-select', 'text')
    ..style.setProperty('-webkit-touch-callout', 'default')
    ..style.touchAction = 'none';
  setNativeTextAreaMaxLength(textarea, maxLength);
  if (hintText != null) textarea.placeholder = hintText;
  return textarea;
}

void setNativeTextAreaMaxLength(html.TextAreaElement textarea, int? maxLength) {
  if (maxLength == null) {
    textarea.attributes.remove('maxlength');
  } else {
    textarea.maxLength = maxLength;
  }
}

// Keep native selection, but let Flutter's page own all vertical scrolling.
double measureNativeTextAreaHeight(
  html.TextAreaElement textarea,
  int minLines,
) {
  final previousHeight = textarea.style.height;
  textarea.style.height = '0';
  final contentHeight = textarea.scrollHeight.toDouble();
  textarea.style.height = previousHeight;
  final minHeight = minLines * 24.0;
  return contentHeight > minHeight ? contentHeight : minHeight;
}

class NativeMultilineTextField extends StatefulWidget {
  const NativeMultilineTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.minLines,
    this.maxLength,
    this.hintText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int? maxLength;
  final String? hintText;

  @override
  State<NativeMultilineTextField> createState() =>
      _NativeMultilineTextFieldState();
}

class _NativeMultilineTextFieldState extends State<NativeMultilineTextField> {
  static int _nextViewId = 0;

  late final String _viewType = 'native-multiline-text-field-${_nextViewId++}';
  late final html.TextAreaElement _textarea;
  final List<StreamSubscription<html.Event>> _subscriptions = [];
  bool _isFocused = false;
  late final html.ResizeObserver _resizeObserver;
  late double _height = widget.minLines * 24.0;
  int? _heightFrame;

  @override
  void initState() {
    super.initState();
    _textarea = createNativeMultilineTextArea(
      label: widget.label,
      value: widget.value,
      maxLength: widget.maxLength,
      hintText: widget.hintText,
    );

    _subscriptions
      ..add(
        _textarea.onInput.listen((_) {
          widget.onChanged(_textarea.value ?? '');
          _scheduleHeightUpdate();
          if (mounted) setState(() {});
        }),
      )
      ..add(
        _textarea.onFocus.listen((_) {
          if (mounted) setState(() => _isFocused = true);
        }),
      )
      ..add(
        _textarea.onBlur.listen((_) {
          if (mounted) setState(() => _isFocused = false);
        }),
      );
    _resizeObserver = html.ResizeObserver((_, _) => _scheduleHeightUpdate())
      ..observe(_textarea);
    html.document.addEventListener('pointerdown', _blurOnOutsidePointer);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _textarea,
    );
  }

  @override
  void didUpdateWidget(NativeMultilineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    setNativeTextAreaMaxLength(_textarea, widget.maxLength);
    _textarea.placeholder = widget.hintText ?? '';
    if (widget.value != oldWidget.value && _textarea.value != widget.value) {
      _textarea.value = widget.value;
    }
    _scheduleHeightUpdate();
  }

  void _scheduleHeightUpdate() {
    if (_heightFrame != null) return;
    _heightFrame = html.window.requestAnimationFrame((_) {
      _heightFrame = null;
      if (!mounted || _textarea.getBoundingClientRect().width == 0) return;
      final height = measureNativeTextAreaHeight(_textarea, widget.minLines);
      if (height != _height) setState(() => _height = height);
    });
  }

  void _blurOnOutsidePointer(html.Event event) {
    if (html.document.activeElement == _textarea && event.target != _textarea) {
      _textarea.blur();
    }
  }

  @override
  void dispose() {
    _resizeObserver.disconnect();
    if (_heightFrame != null) html.window.cancelAnimationFrame(_heightFrame!);
    html.document.removeEventListener('pointerdown', _blurOnOutsidePointer);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        isFocused: _isFocused,
        isEmpty: (_textarea.value ?? '').isEmpty,
        decoration: InputDecoration(
          labelText: widget.label,
          counterText: widget.maxLength == null
              ? null
              : '${(_textarea.value ?? '').length}/${widget.maxLength}',
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentBeige),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryPink),
          ),
        ),
        child: SizedBox(
          height: _height,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
