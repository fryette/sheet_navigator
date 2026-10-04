import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

typedef SheetSurfaceBuilder = Widget Function(BuildContext context, Widget card);

class const SheetNavigatorStyle({
  required final SheetSurfaceBuilder surfaceBuilder,
  final WidgetBuilder? handleBuilder,
  final SheetPhysics? physics,
  final SheetKeyboardDismissBehavior? keyboardDismissBehavior,
  final bool isKeyboardPaddingEnabled = false,
  final SheetScrollConfiguration scrollConfiguration = const SheetScrollConfiguration(),
});
