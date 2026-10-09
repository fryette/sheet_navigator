import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_floor.dart';

class const SheetPageScope({
  required final List<double> snapSizes,
  required super.child,
  final SheetFloor? floor,
  final ValueChanged<double>? onFloorMeasured,
  super.key,
}) extends InheritedWidget {
  static SheetPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetPageScope>();

  static List<double> snapSizesOf(BuildContext context) => switch (maybeOf(context)) {
    final scope? => scope.snapSizes,
    null => throw FlutterError(
      'SheetPageScope.snapSizesOf() was called with a context that has no SheetPageScope above it.',
    ),
  };

  @override
  bool updateShouldNotify(SheetPageScope oldWidget) =>
      !listEquals(snapSizes, oldWidget.snapSizes) ||
      floor != oldWidget.floor ||
      onFloorMeasured != oldWidget.onFloorMeasured;
}
