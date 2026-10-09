import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';

typedef SheetResolvedPageLookup = SheetPage? Function(Object pageKey);

class const SheetNavigatorScope({
  required final ValueListenable<double?> visualTopExtent,
  required final ValueListenable<bool> isTransitionActive,
  required final VoidCallback requestPop,
  required super.child,
  final SheetResolvedPageLookup? resolvedPage,
  super.key,
}) extends InheritedWidget {
  static SheetNavigatorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetNavigatorScope>();

  SheetPage? resolvedPageOf(Object pageKey) => resolvedPage?.call(pageKey);

  List<double>? resolvedSnapSizesOf(Object pageKey) => resolvedPageOf(pageKey)?.snapSizes;

  @override
  bool updateShouldNotify(SheetNavigatorScope oldWidget) =>
      visualTopExtent != oldWidget.visualTopExtent ||
      isTransitionActive != oldWidget.isTransitionActive ||
      requestPop != oldWidget.requestPop;
}
