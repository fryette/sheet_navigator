import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';

class const InstantSheetTransition() extends SheetTransitionStrategy {
  @override
  Duration duration(SheetTransitionContext context) => Duration.zero;

  @override
  Duration layerSwitchDuration(SheetTransitionContext context) => Duration.zero;

  @override
  SheetMotion upper(SheetTransitionContext context) => SheetMotion.still;

  @override
  SheetMotion lower(SheetTransitionContext context) => SheetMotion.still;
}
