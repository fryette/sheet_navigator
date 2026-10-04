import 'dart:math' as math;

import 'package:sheet_navigator/src/page/sheet_snap_state.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';

enum SheetTransitionOperation() {
  push,
  pop,
  replace,
}

class const SheetTransitionSide({
  required final SheetRoute route,
  required final double extent,
  required final List<double> snapSizes,
}) {
  SheetSnapState get snap => SheetSnapState.classify(extent, snapSizes);
}

class const SheetTransitionContext({
  required final SheetTransitionOperation operation,
  required final SheetTransitionSide from,
  required final SheetTransitionSide to,
  required final int depthBefore,
  required final int depthAfter,
  required final int removedCount,
  required final double viewportHeight,
}) {
  SheetTransitionSide get lower => operation == .pop ? to : from;

  SheetTransitionSide get upper => operation == .pop ? from : to;

  double get backgroundDelta => math.max(0.0, lower.extent - upper.extent);

  bool get isBackgroundTravelling => backgroundDelta > 0;
}
