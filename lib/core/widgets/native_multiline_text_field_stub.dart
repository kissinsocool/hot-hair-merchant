import 'package:flutter/material.dart';

class NativeMultilineTextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        minLines: minLines,
        maxLines: minLines + 2,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
