import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/stack/sheet_physics.dart';

class const SheetBottomBleed({
  required final double viewportHeight,
  required final double contentBoxHeight,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bleed = sheetBottomBleedFor(
      viewportHeight: viewportHeight,
      contentBoxHeight: contentBoxHeight,
    );

    return SizedBox(
      height: contentBoxHeight + bleed,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(height: contentBoxHeight, child: child),
      ),
    );
  }
}
