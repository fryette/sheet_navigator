import 'package:sheet_navigator/src/page/sheet_snap_state.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';

typedef SheetTransitionPredicate = bool Function(SheetTransitionContext context);

class const SheetTransitionRule({
  required final SheetTransitionStrategy strategy,
  final String? name,
  final Set<SheetTransitionOperation>? operations,
  final Set<SheetSnapState>? from,
  final Set<SheetSnapState>? to,
  final SheetTransitionPredicate? when,
}) {
  bool matches(SheetTransitionContext context) =>
      (operations?.contains(context.operation) ?? true) &&
      (from?.contains(context.from.snap) ?? true) &&
      (to?.contains(context.to.snap) ?? true) &&
      (when?.call(context) ?? true);
}
