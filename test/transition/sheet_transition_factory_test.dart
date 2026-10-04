import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _snaps = [0.2, 0.5, 0.9];
const _collapsed = 0.2;
const _mid = 0.5;
const _expanded = 0.9;

const _inPlace = InPlaceSheetTransition();
const _travel = TravelSheetTransition();
const _topToTop = TopToTopPopTransition();
const _instant = InstantSheetTransition();

final class const _FromRoute() extends SheetRoute;

final class const _ToRoute() extends SheetRoute;

class const _Cell({
  required final String name,
  required final SheetTransitionOperation operation,
  required final double fromExtent,
  required final double toExtent,
  required final SheetTransitionStrategy expected,
  final List<double> fromSnaps = _snaps,
  final List<double> toSnaps = _snaps,
});

const _cells = [
  _Cell(
    name: 'push collapsed to collapsed with an equal floor stays in place',
    operation: .push,
    fromExtent: _collapsed,
    toExtent: _collapsed,
    expected: _inPlace,
  ),
  _Cell(
    name: 'push collapsed to collapsed onto a lower floor travels',
    operation: .push,
    fromExtent: 0.3,
    toExtent: _collapsed,
    fromSnaps: [0.3, 0.5, 0.9],
    expected: _travel,
  ),
  _Cell(
    name: 'push collapsed to collapsed onto a higher floor stays in place',
    operation: .push,
    fromExtent: _collapsed,
    toExtent: 0.3,
    toSnaps: [0.3, 0.5, 0.9],
    expected: _inPlace,
  ),
  _Cell(
    name: 'push collapsed to mid stays in place',
    operation: .push,
    fromExtent: _collapsed,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'push collapsed to expanded stays in place',
    operation: .push,
    fromExtent: _collapsed,
    toExtent: _expanded,
    expected: _inPlace,
  ),
  _Cell(
    name: 'push mid to collapsed travels',
    operation: .push,
    fromExtent: _mid,
    toExtent: _collapsed,
    expected: _travel,
  ),
  _Cell(
    name: 'push mid to mid at the same level stays in place',
    operation: .push,
    fromExtent: _mid,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'push mid to a lower mid travels',
    operation: .push,
    fromExtent: 0.58,
    toExtent: _mid,
    fromSnaps: [0.2, 0.58, 0.95],
    toSnaps: [0.2, 0.5, 0.95],
    expected: _travel,
  ),
  _Cell(
    name: 'push mid to expanded stays in place',
    operation: .push,
    fromExtent: _mid,
    toExtent: _expanded,
    expected: _inPlace,
  ),
  _Cell(
    name: 'push expanded to collapsed travels',
    operation: .push,
    fromExtent: _expanded,
    toExtent: _collapsed,
    expected: _travel,
  ),
  _Cell(
    name: 'push expanded to mid travels',
    operation: .push,
    fromExtent: _expanded,
    toExtent: _mid,
    expected: _travel,
  ),
  _Cell(
    name: 'push expanded to expanded stays in place',
    operation: .push,
    fromExtent: _expanded,
    toExtent: _expanded,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop collapsed to collapsed with an equal floor stays in place',
    operation: .pop,
    fromExtent: _collapsed,
    toExtent: _collapsed,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop collapsed to collapsed onto a higher floor travels',
    operation: .pop,
    fromExtent: _collapsed,
    toExtent: 0.3,
    toSnaps: [0.3, 0.5, 0.9],
    expected: _travel,
  ),
  _Cell(
    name: 'pop collapsed to collapsed onto a lower floor stays in place',
    operation: .pop,
    fromExtent: 0.3,
    toExtent: _collapsed,
    fromSnaps: [0.3, 0.5, 0.9],
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop collapsed to mid travels',
    operation: .pop,
    fromExtent: _collapsed,
    toExtent: _mid,
    expected: _travel,
  ),
  _Cell(
    name: 'pop collapsed to expanded travels',
    operation: .pop,
    fromExtent: _collapsed,
    toExtent: _expanded,
    expected: _travel,
  ),
  _Cell(
    name: 'pop mid to collapsed stays in place',
    operation: .pop,
    fromExtent: _mid,
    toExtent: _collapsed,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop mid to mid at the same level stays in place',
    operation: .pop,
    fromExtent: _mid,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop mid to a higher mid travels',
    operation: .pop,
    fromExtent: _mid,
    toExtent: 0.58,
    fromSnaps: [0.2, 0.5, 0.95],
    toSnaps: [0.2, 0.58, 0.95],
    expected: _travel,
  ),
  _Cell(
    name: 'pop mid to expanded travels',
    operation: .pop,
    fromExtent: _mid,
    toExtent: _expanded,
    expected: _travel,
  ),
  _Cell(
    name: 'pop expanded to collapsed stays in place',
    operation: .pop,
    fromExtent: _expanded,
    toExtent: _collapsed,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop expanded to mid stays in place',
    operation: .pop,
    fromExtent: _expanded,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop expanded to expanded fades top to top',
    operation: .pop,
    fromExtent: _expanded,
    toExtent: _expanded,
    expected: _topToTop,
  ),
  _Cell(
    name: 'push from between onto a lower sheet travels',
    operation: .push,
    fromExtent: 0.7,
    toExtent: _mid,
    expected: _travel,
  ),
  _Cell(
    name: 'push from between onto a higher sheet stays in place',
    operation: .push,
    fromExtent: 0.35,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'pop from between onto a higher sheet travels',
    operation: .pop,
    fromExtent: 0.35,
    toExtent: _mid,
    expected: _travel,
  ),
  _Cell(
    name: 'pop from between onto a lower sheet stays in place',
    operation: .pop,
    fromExtent: 0.7,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'replace expanded to mid falls back to in place even with a background delta',
    operation: .replace,
    fromExtent: _expanded,
    toExtent: _mid,
    expected: _inPlace,
  ),
  _Cell(
    name: 'replace expanded to expanded falls back to in place',
    operation: .replace,
    fromExtent: _expanded,
    toExtent: _expanded,
    expected: _inPlace,
  ),
];

SheetTransitionContext _context(
  SheetTransitionOperation operation, {
  required double fromExtent,
  required double toExtent,
  List<double> fromSnaps = _snaps,
  List<double> toSnaps = _snaps,
}) => SheetTransitionContext(
  operation: operation,
  from: SheetTransitionSide(route: const _FromRoute(), extent: fromExtent, snapSizes: fromSnaps),
  to: SheetTransitionSide(route: const _ToRoute(), extent: toExtent, snapSizes: toSnaps),
  depthBefore: operation == .pop ? 2 : 1,
  depthAfter: operation == .pop ? 1 : 2,
  removedCount: operation == .push ? 0 : 1,
  viewportHeight: 800,
);

void main() {
  group('SheetTransitionFactory.standard', () {
    for (final cell in _cells) {
      test(cell.name, () {
        final context = _context(
          cell.operation,
          fromExtent: cell.fromExtent,
          toExtent: cell.toExtent,
          fromSnaps: cell.fromSnaps,
          toSnaps: cell.toSnaps,
        );

        expect(SheetTransitionFactory.standard.resolve(context), same(cell.expected));
      });
    }

    test('resolves the reference expanded-to-mid push to a 340 ms travel', () {
      final context = _context(
        .push,
        fromExtent: 0.97,
        toExtent: _mid,
        fromSnaps: const [0.5, 0.97],
      );

      final strategy = SheetTransitionFactory.standard.resolve(context);

      expect(strategy, same(_travel));
      expect(strategy.duration(context), const Duration(milliseconds: 340));
    });

    test('lists the travel rule before the top-to-top rule', () {
      expect(SheetTransitionFactory.standard.rules.map((rule) => rule.name), [
        'travel',
        'topToTop',
      ]);
    });
  });

  group('SheetTransitionRule.matches', () {
    test('treats every null field as a wildcard', () {
      const rule = SheetTransitionRule(strategy: _instant);

      expect(rule.matches(_context(.push, fromExtent: _mid, toExtent: _mid)), isTrue);
      expect(rule.matches(_context(.pop, fromExtent: 0.7, toExtent: _collapsed)), isTrue);
    });

    test('requires every non-null field to match', () {
      const rule = SheetTransitionRule(
        operations: {.push},
        from: {.expanded},
        to: {.mid},
        strategy: _instant,
      );

      expect(rule.matches(_context(.push, fromExtent: _expanded, toExtent: _mid)), isTrue);
      expect(rule.matches(_context(.pop, fromExtent: _expanded, toExtent: _mid)), isFalse);
      expect(rule.matches(_context(.push, fromExtent: _mid, toExtent: _mid)), isFalse);
      expect(rule.matches(_context(.push, fromExtent: _expanded, toExtent: _collapsed)), isFalse);
    });

    test('consults the when predicate after the snap filters', () {
      final rule = SheetTransitionRule(
        from: const {.expanded},
        when: (context) => context.depthAfter > 1,
        strategy: _instant,
      );

      expect(rule.matches(_context(.push, fromExtent: _expanded, toExtent: _mid)), isTrue);
      expect(rule.matches(_context(.pop, fromExtent: _expanded, toExtent: _mid)), isFalse);
    });
  });

  group('SheetTransitionFactory.resolve', () {
    test('returns the strategy of the first matching rule', () {
      const factory = SheetTransitionFactory(
        rules: [
          SheetTransitionRule(operations: {.push}, strategy: _instant),
          SheetTransitionRule(operations: {.push}, strategy: _travel),
        ],
        fallback: _inPlace,
      );

      expect(factory.resolve(_context(.push, fromExtent: _mid, toExtent: _mid)), same(_instant));
    });

    test('returns the fallback when no rule matches', () {
      const factory = SheetTransitionFactory(
        rules: [
          SheetTransitionRule(operations: {.pop}, strategy: _instant),
        ],
        fallback: _travel,
      );

      expect(factory.resolve(_context(.push, fromExtent: _mid, toExtent: _mid)), same(_travel));
    });
  });

  group('SheetTransitionFactory.prepend', () {
    const pushExpandedToMid = SheetTransitionRule(
      operations: {.push},
      from: {.expanded},
      to: {.mid},
      strategy: _instant,
    );
    const popCollapsedToExpanded = SheetTransitionRule(
      operations: {.pop},
      from: {.collapsed},
      to: {.expanded},
      strategy: _topToTop,
    );
    final factory = SheetTransitionFactory.standard.prepend([
      pushExpandedToMid,
      popCollapsedToExpanded,
    ]);

    test('lets a host rule win over the standard travel rule on a push', () {
      expect(
        factory.resolve(_context(.push, fromExtent: _expanded, toExtent: _mid)),
        same(_instant),
      );
    });

    test('lets a host rule win over the standard travel rule on a pop', () {
      expect(
        factory.resolve(_context(.pop, fromExtent: _collapsed, toExtent: _expanded)),
        same(_topToTop),
      );
    });

    test('keeps the standard rules for every cell the host rules do not cover', () {
      expect(
        factory.resolve(_context(.push, fromExtent: _expanded, toExtent: _collapsed)),
        same(_travel),
      );
      expect(
        factory.resolve(_context(.pop, fromExtent: _expanded, toExtent: _expanded)),
        same(_topToTop),
      );
      expect(
        factory.resolve(_context(.pop, fromExtent: _mid, toExtent: _collapsed)),
        same(_inPlace),
      );
    });

    test('keeps the fallback and leaves the source factory unchanged', () {
      expect(factory.fallback, same(SheetTransitionFactory.standard.fallback));
      expect(factory.rules, hasLength(SheetTransitionFactory.standard.rules.length + 2));
      expect(SheetTransitionFactory.standard.rules, hasLength(2));
    });
  });
}
