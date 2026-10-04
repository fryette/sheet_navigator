import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _availableHeight = 760.0;
const _restingExtent = 0.68;

void main() {
  group('SheetStopGrid.resolve', () {
    test('rests at the shared resting extent when no floor is given', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
      );

      expect(grid.resting, _restingExtent);
      expect(grid.floor, _restingExtent);
      expect(grid.expanded, 1.0);
    });

    test('rests at the shared resting extent when the floor is below it', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.1,
      );

      expect(grid.floor, 0.1);
      expect(grid.resting, _restingExtent);
      expect(grid.expanded, 1.0);
    });

    test('raises the resting extent to the floor when the floor exceeds it', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.9,
      );

      expect(grid.floor, 0.9);
      expect(grid.resting, 0.9);
      expect(grid.expanded, 1.0);
    });

    test('an explicit floor is never inflated by a bottom bar inset outside the viewport', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.1,
        bottomBarInset: 84,
      );

      expect(grid.floor, 0.1);
    });

    test('resolves an identical grid for every caller given the same floor', () {
      final nearby = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.12,
      );
      final tripResults = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.09,
      );
      final tripDetails = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        floorExtent: 0.23,
      );

      expect(nearby.resting, tripResults.resting);
      expect(tripResults.resting, tripDetails.resting);
      expect(nearby.expanded, tripResults.expanded);
      expect(tripResults.expanded, tripDetails.expanded);
    });

    test('falls back to the flat resting extent when availableHeight collapses to nothing', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: 0,
        targetScreenFraction: _restingExtent,
        bottomBarInset: 84,
      );

      expect(grid.resting, _restingExtent);
    });

    test('a small bottom bar inset still rests at the same usable content height, in pixels, as '
        'one without', () {
      const bottomBarInset = 16.0;

      final withoutBar = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
      );
      final withBar = SheetStopGrid.resolve(
        availableHeight: _availableHeight - bottomBarInset,
        targetScreenFraction: _restingExtent,
        bottomBarInset: bottomBarInset,
      );

      final withoutBarContentHeight = withoutBar.resting * _availableHeight;
      final withBarContentHeight = withBar.resting * (_availableHeight - bottomBarInset);

      expect(withBarContentHeight, closeTo(withoutBarContentHeight, 0.01));
    });

    test('a moderate bottom bar inset raises the resting fraction above the flat resting '
        'extent', () {
      final withBar = SheetStopGrid.resolve(
        availableHeight: _availableHeight - 30.0,
        targetScreenFraction: _restingExtent,
        bottomBarInset: 30.0,
      );

      expect(withBar.resting, greaterThan(_restingExtent));
    });

    test('caps the resting top edge at exactly the minimum top-edge gap when the content-aware '
        'target would otherwise sit closer to the top', () {
      const availableHeight = 200.0;

      final grid = SheetStopGrid.resolve(
        availableHeight: availableHeight,
        targetScreenFraction: 0.9,
      );

      final topEdge = (1 - grid.resting) * availableHeight;

      expect(topEdge, closeTo(100.0, 0.001));
    });

    test('an oversized bottom bar still keeps the top edge no closer than the minimum gap, '
        'however far the content-aware target would otherwise push past it', () {
      const availableHeight = 200.0;
      const bottomBarInset = 300.0;

      final grid = SheetStopGrid.resolve(
        availableHeight: availableHeight,
        targetScreenFraction: _restingExtent,
        bottomBarInset: bottomBarInset,
      );

      final topEdge = (1 - grid.resting) * availableHeight;

      expect(topEdge, closeTo(100.0, 0.001));
    });

    test('a top inset with no other callers pulls the expanded extent below the screen edge '
        'by its own fraction of the available height', () {
      const topInset = 47.5;

      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
        topInset: topInset,
      );

      expect(grid.expanded, closeTo(1 - topInset / _availableHeight, 0.0001));
    });

    test('omitting the top inset leaves the expanded extent at the full 1.0, matching every '
        'existing caller', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
      );

      expect(grid.expanded, 1.0);
    });

    test('a top inset never pulls the expanded extent, and by extension the resting and floor '
        'extents it bounds, negative', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: 100,
        targetScreenFraction: _restingExtent,
        topInset: 90,
        floorExtent: 0.5,
      );

      expect(grid.expanded, greaterThanOrEqualTo(0));
      expect(grid.resting, inInclusiveRange(grid.floor, grid.expanded));
      expect(grid.floor, lessThanOrEqualTo(grid.expanded));
    });

    test('omitting targetScreenFraction overrides leaves the content-aware resting extent '
        'unchanged', () {
      final withoutFraction = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: _restingExtent,
      );

      expect(withoutFraction.resting, _restingExtent);
      expect(withoutFraction.floor, _restingExtent);
      expect(withoutFraction.expanded, 1.0);
    });

    test('targetScreenFraction rests at that fraction of the expanded extent instead of '
        'the content-aware resting extent', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        targetScreenFraction: 0.40,
      );

      expect(grid.resting, closeTo(0.40 * grid.expanded, 0.0001));
    });

    test('targetScreenFraction rests at that fraction of the screen height, independent of '
        'the top inset, not at that fraction of the safe-area-adjusted expanded extent', () {
      const topInset = 47.5;

      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        topInset: topInset,
        targetScreenFraction: 0.40,
      );

      expect(grid.expanded, closeTo(1 - topInset / _availableHeight, 0.0001));
      expect(grid.resting, closeTo(0.40, 0.0001));
      expect(grid.resting, isNot(closeTo(0.40 * grid.expanded, 0.0001)));
    });

    test('targetScreenFraction still raises the resting extent to the floor when the '
        'floor exceeds it', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        floorExtent: 0.9,
        targetScreenFraction: 0.40,
      );

      expect(grid.floor, 0.9);
      expect(grid.resting, 0.9);
    });

    test('targetScreenFraction still clamps the floor below the expanded extent', () {
      final grid = SheetStopGrid.resolve(
        availableHeight: _availableHeight,
        floorExtent: 0.1,
        targetScreenFraction: 0.40,
      );

      expect(grid.floor, 0.1);
      expect(grid.resting, closeTo(0.40 * grid.expanded, 0.0001));
      expect(grid.expanded, 1.0);
    });

    test('the minimum top-edge gap holds as the same pixel amount, not as a fraction of the '
        'screen, regardless of the screen height', () {
      final small = SheetStopGrid.resolve(availableHeight: 150, targetScreenFraction: 0.95);
      final large = SheetStopGrid.resolve(availableHeight: 400, targetScreenFraction: 0.95);

      final smallTopEdge = (1 - small.resting) * 150;
      final largeTopEdge = (1 - large.resting) * 400;

      expect(smallTopEdge, closeTo(100.0, 0.001));
      expect(largeTopEdge, closeTo(100.0, 0.001));
    });
  });
}
