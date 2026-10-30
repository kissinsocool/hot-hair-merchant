import 'package:flutter/material.dart';

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
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(NativeMultilineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: widget.minLines + 2,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
        ),
      ),
    );
  }
}
