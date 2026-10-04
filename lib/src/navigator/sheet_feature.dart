import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

abstract mixin class SheetFeature<R extends SheetRoute>() {
  bool handles(R route);

  Widget scope(BuildContext context, Widget child) => child;

  SheetPage page(BuildContext context, R route, double availableHeight, SheetController controller);

  Widget? layer(BuildContext context, Object layerId, R route) => null;

  double? layerBottom(BuildContext context, Object layerId, R route) => null;

  void onBecameTop(BuildContext context, R route) {}

  void onAvailableHeightChanged(BuildContext context, R route) {}

  void onSettledAfterDrag(BuildContext context, R route, double extent) {}
}
