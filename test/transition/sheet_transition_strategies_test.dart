import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _snaps = [0.2, 0.5, 0.9];

final class const _FromRoute() extends SheetRoute;

final class const _ToRoute() extends SheetRoute;

SheetTransitionContext _context(
  SheetTransitionOperation operation, {
  required double fromExtent,
  required double toExtent,
}) => SheetTransitionContext(
  operation: operation,
  from: SheetTransitionSide(route: const _FromRoute(), extent: fromExtent, snapSizes: _snaps),
  to: SheetTransitionSide(route: const _ToRoute(), extent: toExtent, snapSizes: _snaps),
  depthBefore: operation == .pop ? 2 : 1,
  depthAfter: operation == .pop ? 1 : 2,
  removedCount: operation == .push ? 0 : 1,
  viewportHeight: 800,
);

void main() {
  group('SheetTransitionContext', () {
    test('puts the old top above the returning sheet on a pop', () {
      final context = _context(.pop, fromExtent: 0.2, toExtent: 0.9);

      expect(context.upper, same(context.from));
      expect(context.lower, same(context.to));
      expect(context.backgroundDelta, closeTo(0.7, 1e-9));
      expect(context.isBackgroundTravelling, isTrue);
    });

    test('puts the new top above the covered sheet on a push', () {
      final context = _context(.push, fromExtent: 0.9, toExtent: 0.5);

      expect(context.upper, same(context.to));
      expect(context.lower, same(context.from));
      expect(context.backgroundDelta, closeTo(0.4, 1e-9));
    });

    test('never reports a negative background delta', () {
      final context = _context(.push, fromExtent: 0.2, toExtent: 0.9);

      expect(context.backgroundDelta, 0);
      expect(context.isBackgroundTravelling, isFalse);
    });
  });

  group('durations', () {
    test('an in-place push and replace take 320 ms and a pop 380 ms', () {
      const strategy = InPlaceSheetTransition();

      expect(strategy.duration(_context(.push, fromExtent: 0.5, toExtent: 0.5)), sheetPushDuration);
      expect(
        strategy.duration(_context(.replace, fromExtent: 0.5, toExtent: 0.5)),
        sheetPushDuration,
      );
      expect(strategy.duration(_context(.pop, fromExtent: 0.5, toExtent: 0.5)), sheetPopDuration);
      expect(sheetPushDuration, const Duration(milliseconds: 320));
      expect(sheetPopDuration, const Duration(milliseconds: 380));
    });

    test('a top-to-top pop takes the in-place pop duration', () {
      expect(
        const TopToTopPopTransition().duration(_context(.pop, fromExtent: 0.9, toExtent: 0.9)),
        sheetPopDuration,
      );
    });

    test('travel scales with the background delta between the 240 and 440 ms clamps', () {
      const strategy = TravelSheetTransition();

      expect(
        strategy.duration(_context(.push, fromExtent: 0.58, toExtent: 0.5)),
        const Duration(milliseconds: 240),
      );
      expect(
        strategy.duration(_context(.push, fromExtent: 0.97, toExtent: 0.5)),
        const Duration(milliseconds: 340),
      );
      expect(
        strategy.duration(_context(.pop, fromExtent: 0.2, toExtent: 0.95)),
        const Duration(milliseconds: 440),
      );
    });

    test('an instant transition takes no time', () {
      expect(
        const InstantSheetTransition().duration(_context(.push, fromExtent: 0.9, toExtent: 0.5)),
        Duration.zero,
      );
    });

    test('every built-in switches layers in 320 ms on push and replace and 380 ms on pop', () {
      const strategies = [
        InPlaceSheetTransition(),
        TravelSheetTransition(),
        TopToTopPopTransition(),
        InstantSheetTransition(),
      ];

      for (final strategy in strategies) {
        expect(
          strategy.layerSwitchDuration(_context(.push, fromExtent: 0.9, toExtent: 0.5)),
          sheetPushDuration,
        );
        expect(
          strategy.layerSwitchDuration(_context(.replace, fromExtent: 0.9, toExtent: 0.5)),
          sheetPushDuration,
        );
        expect(
          strategy.layerSwitchDuration(_context(.pop, fromExtent: 0.2, toExtent: 0.9)),
          sheetPopDuration,
        );
      }
    });
  });

  group('in-place motion', () {
    const strategy = InPlaceSheetTransition();

    test('a push slides the new top up from its own rest extent while the covered sheet fades '
        'and shrinks in place', () {
      final context = _context(.push, fromExtent: 0.2, toExtent: 0.5);
      final upper = strategy.upper(context);
      final lower = strategy.lower(context);

      expect(upper.dy(0), 0.5);
      expect(upper.dy(1), 0);
      expect(upper.alpha(0.5), 1);
      expect(lower.dy(0.5), 0);
      expect(lower.alpha(0), 1);
      expect(lower.alpha(0.65), 0);
      expect(lower.scale(0), 1);
      expect(lower.scale(0.2), closeTo(sheetInPlaceScale, 1e-12));
    });

    test('a pop slides the old top down by its captured extent while the returning sheet fades '
        'and grows in place', () {
      final context = _context(.pop, fromExtent: 0.5, toExtent: 0.2);
      final upper = strategy.upper(context);
      final lower = strategy.lower(context);

      expect(upper.dy(0), 0);
      expect(upper.dy(1), 0.5);
      expect(lower.dy(0.5), 0);
      expect(lower.alpha(0), 0);
      expect(lower.alpha(1), 1);
      expect(lower.scale(0.6), closeTo(sheetInPlaceScale, 1e-12));
      expect(lower.scale(1), 1);
    });

    test('a top-to-top pop fades the returning sheet in sooner than an in-place pop', () {
      final context = _context(.pop, fromExtent: 0.9, toExtent: 0.9);

      expect(const TopToTopPopTransition().lower(context).alpha(0.45), 1);
      expect(strategy.lower(context).alpha(0.45), lessThan(1));
    });
  });

  group('travel motion', () {
    const strategy = TravelSheetTransition();

    test('a push carries the covered sheet down by the delta, fading and shrinking it', () {
      final context = _context(.push, fromExtent: 0.9, toExtent: 0.5);
      final lower = strategy.lower(context);

      expect(lower.dy(0), 0);
      expect(lower.dy(1), closeTo(0.4, 1e-12));
      expect(lower.alpha(0.35), 1);
      expect(lower.alpha(0.8), 0);
      expect(lower.scale(0.25), 1);
      expect(lower.scale(1), closeTo(1 - sheetBackgroundScaleGain * 0.4, 1e-12));
    });

    test('a pop lifts the returning sheet back from the delta, fading and growing it', () {
      final context = _context(.pop, fromExtent: 0.2, toExtent: 0.9);
      final lower = strategy.lower(context);

      expect(lower.dy(0), closeTo(0.7, 1e-12));
      expect(lower.dy(1), 0);
      expect(lower.alpha(0), 0);
      expect(lower.alpha(0.3), 1);
      expect(lower.scale(0), closeTo(1 - sheetBackgroundScaleGain * 0.7, 1e-12));
      expect(lower.scale(1), 1);
    });

    test('moves the upper sheet exactly like the in-place transition of the same operation', () {
      final context = _context(.push, fromExtent: 0.9, toExtent: 0.5);

      for (final progress in [0.0, 0.3, 0.6, 1.0]) {
        expect(
          strategy.upper(context).dy(progress),
          const InPlaceSheetTransition().upper(context).dy(progress),
        );
      }
    });
  });

  group('instant motion', () {
    test('keeps both sheets still, opaque and unscaled', () {
      final context = _context(.push, fromExtent: 0.9, toExtent: 0.5);
      const strategy = InstantSheetTransition();

      for (final motion in [strategy.upper(context), strategy.lower(context)]) {
        expect(motion.dy(0), 0);
        expect(motion.alpha(0), 1);
        expect(motion.scale(0), 1);
      }
    });
  });
}
