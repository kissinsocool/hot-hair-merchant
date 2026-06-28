import 'package:flutter/widgets.dart';

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.widthFactor = 0.9});

  final Widget child;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(widthFactor: widthFactor, child: child),
    );
  }
}
