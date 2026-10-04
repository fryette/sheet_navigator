import 'package:flutter/material.dart';
import 'package:sheet_navigator/src/stack/sheet_controller_extent.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetExtentBuilder({
  required final SheetController controller,
  required final ValueWidgetBuilder<double?> builder,
  final Widget? child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => builder(context, controller.extent, child),
    child: child,
  );
}
