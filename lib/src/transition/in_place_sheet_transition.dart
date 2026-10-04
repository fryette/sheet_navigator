import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';

class const InPlaceSheetTransition() extends SheetTransitionStrategy {
  @override
  Duration duration(SheetTransitionContext context) =>
      context.operation == .pop ? sheetPopDuration : sheetPushDuration;

  @override
  SheetMotion upper(SheetTransitionContext context) => switch (context.operation) {
    .pop => SheetMotion(
      dy: (progress) => sheetExitTranslate.transform(progress) * context.from.extent,
      alpha: sheetMotionOne,
      scale: sheetMotionOne,
    ),
    .push || .replace => SheetMotion(
      dy: (progress) => (1 - sheetEnterTranslate.transform(progress)) * context.to.extent,
      alpha: sheetMotionOne,
      scale: sheetMotionOne,
    ),
  };

  @override
  SheetMotion lower(SheetTransitionContext context) => switch (context.operation) {
    .pop => SheetMotion(dy: sheetMotionZero, alpha: returningAlpha, scale: _returningScale),
    .push || .replace => const SheetMotion(
      dy: sheetMotionZero,
      alpha: _recedingAlpha,
      scale: _recedingScale,
    ),
  };

  double returningAlpha(double progress) => sheetInPlaceFadeIn.transform(progress);
}

double _recedingAlpha(double progress) => 1 - sheetInPlaceFadeOut.transform(progress);

double _recedingScale(double progress) =>
    _lerp(1, sheetInPlaceScale, sheetInPlacePushScaleWindow.transform(progress));

double _returningScale(double progress) =>
    _lerp(sheetInPlaceScale, 1, sheetInPlacePopScaleWindow.transform(progress));

double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
