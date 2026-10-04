import 'package:sheet_navigator/src/transition/in_place_sheet_transition.dart';
import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';

class const TravelSheetTransition() extends InPlaceSheetTransition {
  @override
  Duration duration(SheetTransitionContext context) =>
      sheetTravelDurationFor(context.backgroundDelta);

  @override
  SheetMotion lower(SheetTransitionContext context) {
    final delta = context.backgroundDelta;
    return switch (context.operation) {
      .pop => SheetMotion(
        dy: (progress) => (1 - sheetTravelTranslate.transform(progress)) * delta,
        alpha: sheetTravelFadeIn.transform,
        scale: (progress) =>
            1 - sheetBackgroundScaleGain * delta * sheetTravelScaleWindow.transform(1 - progress),
      ),
      .push || .replace => SheetMotion(
        dy: (progress) => sheetTravelTranslate.transform(progress) * delta,
        alpha: (progress) => 1 - sheetTravelFadeOut.transform(progress),
        scale: (progress) =>
            1 - sheetBackgroundScaleGain * delta * sheetTravelScaleWindow.transform(progress),
      ),
    };
  }
}
