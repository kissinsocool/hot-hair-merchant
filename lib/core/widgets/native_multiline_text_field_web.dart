// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

html.TextAreaElement createNativeMultilineTextArea({
  required String label,
  required String value,
  required int maxLength,
}) {
  return html.TextAreaElement()
    ..value = value
    ..maxLength = maxLength
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
    ..style.overflowY = 'auto'
    ..style.backgroundColor = 'transparent'
    ..style.color = '#5b5452'
    ..style.fontSize = '16px'
    ..style.lineHeight = '1.5'
    ..style.fontFamily =
        '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    ..style.setProperty('-webkit-user-select', 'text')
    ..style.setProperty('-webkit-touch-callout', 'default')
    ..style.touchAction = 'auto';
}

class NativeMultilineTextField extends StatefulWidget {
  const NativeMultilineTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.minLines,
    required this.maxLength,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLength;

  @override
  State<NativeMultilineTextField> createState() =>
      _NativeMultilineTextFieldState();
}

class _NativeMultilineTextFieldState extends State<NativeMultilineTextField> {
  static int _nextViewId = 0;
  static const _pointerEvents = [
    'pointerdown',
    'pointermove',
    'pointerup',
    'pointercancel',
  ];

  late final String _viewType = 'native-multiline-text-field-${_nextViewId++}';
  late final html.TextAreaElement _textarea;
  final List<StreamSubscription<html.Event>> _subscriptions = [];
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _textarea = createNativeMultilineTextArea(
      label: widget.label,
      value: widget.value,
      maxLength: widget.maxLength,
    );

    _subscriptions
      ..add(
        _textarea.onInput.listen((_) {
          widget.onChanged(_textarea.value ?? '');
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
    for (final eventName in _pointerEvents) {
      _textarea.addEventListener(eventName, _stopPointerPropagation);
    }
    html.document.addEventListener('pointerdown', _blurOnOutsidePointer);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _textarea,
    );
  }

  @override
  void didUpdateWidget(NativeMultilineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _textarea.maxLength = widget.maxLength;
    if (html.document.activeElement != _textarea &&
        _textarea.value != widget.value) {
      _textarea.value = widget.value;
    }
  }

  void _stopPointerPropagation(html.Event event) => event.stopPropagation();

  void _blurOnOutsidePointer(html.Event event) {
    if (html.document.activeElement == _textarea && event.target != _textarea) {
      _textarea.blur();
    }
  }

  @override
  void dispose() {
    for (final eventName in _pointerEvents) {
      _textarea.removeEventListener(eventName, _stopPointerPropagation);
    }
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
          counterText: '${(_textarea.value ?? '').length}/${widget.maxLength}',
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
          height: widget.minLines * 24,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
