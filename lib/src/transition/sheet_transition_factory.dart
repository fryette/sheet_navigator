import 'package:collection/collection.dart';
import 'package:sheet_navigator/src/transition/in_place_sheet_transition.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_rule.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';
import 'package:sheet_navigator/src/transition/top_to_top_pop_transition.dart';
import 'package:sheet_navigator/src/transition/travel_sheet_transition.dart';

class const SheetTransitionFactory({
  required final List<SheetTransitionRule> rules,
  required final SheetTransitionStrategy fallback,
}) {
  static const standard = SheetTransitionFactory(
    rules: [
      SheetTransitionRule(
        name: 'travel',
        operations: {.push, .pop},
        when: _isBackgroundTravelling,
        strategy: TravelSheetTransition(),
      ),
      SheetTransitionRule(
        name: 'topToTop',
        operations: {.pop},
        from: {.expanded},
        to: {.expanded},
        strategy: TopToTopPopTransition(),
      ),
    ],
    fallback: InPlaceSheetTransition(),
  );

  SheetTransitionStrategy resolve(SheetTransitionContext context) =>
      rules.firstWhereOrNull((rule) => rule.matches(context))?.strategy ?? fallback;

  SheetTransitionFactory prepend(List<SheetTransitionRule> hostRules) =>
      SheetTransitionFactory(rules: [...hostRules, ...rules], fallback: fallback);
}

bool _isBackgroundTravelling(SheetTransitionContext context) => context.isBackgroundTravelling;
