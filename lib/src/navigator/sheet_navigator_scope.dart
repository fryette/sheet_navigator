import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class const SheetNavigatorScope({
  required final ValueListenable<double?> visualTopExtent,
  required final ValueListenable<bool> isTransitionActive,
  required final VoidCallback requestPop,
  required super.child,
  super.key,
}) extends InheritedWidget {
  static SheetNavigatorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetNavigatorScope>();

  @override
  bool updateShouldNotify(SheetNavigatorScope oldWidget) =>
      visualTopExtent != oldWidget.visualTopExtent ||
      isTransitionActive != oldWidget.isTransitionActive ||
      requestPop != oldWidget.requestPop;
}
