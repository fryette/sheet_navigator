import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';

typedef SheetMotionCurve = double Function(double progress);

class const SheetMotion({
  required final SheetMotionCurve dy,
  required final SheetMotionCurve alpha,
  required final SheetMotionCurve scale,
}) {
  static const still = SheetMotion(
    dy: sheetMotionZero,
    alpha: sheetMotionOne,
    scale: sheetMotionOne,
  );
}

abstract class const SheetTransitionStrategy() {
  Duration duration(SheetTransitionContext context);

  Duration layerSwitchDuration(SheetTransitionContext context) =>
      context.operation == .pop ? sheetPopDuration : sheetPushDuration;

  SheetMotion upper(SheetTransitionContext context);

  SheetMotion lower(SheetTransitionContext context);
}

double sheetMotionZero(double progress) => 0;

double sheetMotionOne(double progress) => 1;
