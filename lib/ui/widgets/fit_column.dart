import 'package:flutter/material.dart';

/// A centered column that scales down instead of overflowing, never up. For
/// the side-by-side layouts, where a short display (iPhone Duo's cover held
/// sideways is 466 tall) can't fit a stack of big buttons.
class FitColumn extends StatelessWidget {
  const FitColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
