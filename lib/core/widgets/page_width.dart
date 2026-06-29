import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class PageWidth extends StatelessWidget {
  const PageWidth({
    super.key,
    required this.child,
    this.widthFactor = 0.9,
    this.maxWidth = 1200,
  });

  final Widget child;
  final double widthFactor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: math.min(constraints.maxWidth * widthFactor, maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
