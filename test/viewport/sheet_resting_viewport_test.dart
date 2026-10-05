import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

SheetPage _page({
  Object pageKey = 'page',
  double initialSize = 0.5,
  List<double> snapSizes = const [0.2, 0.5, 0.9],
  double backgroundTopInset = 0,
}) => SheetPage(
  pageKey: pageKey,
  initialSize: initialSize,
  snapSizes: snapSizes,
  backgroundTopInset: backgroundTopInset,
  builder: (context, controller) => const SizedBox(),
);

void main() {
  group('restingSnapFor', () {
    test('is the highest snap below the largest', () {
      expect(SheetRestingViewport.restingSnapFor(_page()), 0.5);
    });

    test('ignores the order of the snaps', () {
      expect(SheetRestingViewport.restingSnapFor(_page(snapSizes: [0.9, 0.2, 0.5])), 0.5);
    });

    test('is the lowest snap when there is only one', () {
      expect(SheetRestingViewport.restingSnapFor(_page(snapSizes: [0.4])), 0.4);
    });

    test('is null without snaps', () {
      expect(SheetRestingViewport.restingSnapFor(_page(snapSizes: [])), isNull);
    });
  });

  group('restingExtentFor', () {
    test('uses the initial size without a settled snap', () {
      expect(SheetRestingViewport.restingExtentFor(_page(initialSize: 0.3), null), 0.3);
    });

    test('prefers the settled snap of the same page', () {
      final extent = SheetRestingViewport.restingExtentFor(_page(), (pageKey: 'page', extent: 0.2));

      expect(extent, 0.2);
    });

    test('ignores the settled snap of another page', () {
      final extent = SheetRestingViewport.restingExtentFor(_page(), (
        pageKey: 'other',
        extent: 0.2,
      ));

      expect(extent, 0.5);
    });

    test('clamps to the resting snap', () {
      expect(SheetRestingViewport.restingExtentFor(_page(initialSize: 0.7), null), 0.5);
      final settled = SheetRestingViewport.restingExtentFor(_page(), (
        pageKey: 'page',
        extent: 0.9,
      ));
      expect(settled, 0.5);
    });

    test('clamps to the lowest snap', () {
      expect(SheetRestingViewport.restingExtentFor(_page(initialSize: 0.1), null), 0.2);
    });

    test('is null without snaps', () {
      expect(SheetRestingViewport.restingExtentFor(_page(snapSizes: []), null), isNull);
    });
  });

  group('resolve', () {
    test('derives the insets from the resting extent and the top inset', () {
      final viewport = SheetRestingViewport.resolve(
        topPage: _page(backgroundTopInset: 40),
        settledSnap: null,
        size: const Size(400, 800),
        pageKeys: const ['a', 'page'],
      );

      expect(
        viewport,
        const SheetRestingViewport(
          restingExtent: 0.5,
          insets: EdgeInsets.only(top: 52, bottom: 412),
          size: Size(400, 800),
          topPageKey: 'page',
          pageKeys: ['a', 'page'],
        ),
      );
    });

    test('is null without snaps', () {
      final viewport = SheetRestingViewport.resolve(
        topPage: _page(snapSizes: []),
        settledSnap: null,
        size: const Size(400, 800),
        pageKeys: const ['page'],
      );

      expect(viewport, isNull);
    });
  });

  group('equality', () {
    SheetRestingViewport build({double extent = 0.5, List<Object> pageKeys = const ['a']}) =>
        SheetRestingViewport(
          restingExtent: extent,
          insets: EdgeInsets.only(bottom: extent),
          size: const Size(1, 2),
          topPageKey: 'a',
          pageKeys: pageKeys,
        );

    test('equal values share a hash code', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differing fields are unequal', () {
      expect(build(), isNot(build(extent: 0.4)));
      expect(build(), isNot(build(pageKeys: const ['a', 'b'])));
      expect(build(), isNot('other'));
    });
  });
}
