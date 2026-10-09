import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

SheetPage _page({
  double initialSize = 0.5,
  List<double> snapSizes = const [0.5, 1],
  SheetFloor? floor,
}) => SheetPage(
  pageKey: 'page',
  initialSize: initialSize,
  snapSizes: snapSizes,
  builder: (context, scrollController) => const SizedBox(),
  floor: floor,
);

var _probeBuilds = 0;

class const _Probe() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    _probeBuilds++;
    SheetPageScope.snapSizesOf(context);
    return const SizedBox();
  }
}

const _floor = SheetFloor(defaultRegionHeight: 80, leadingHeight: 20, trailingInset: 10);

void main() {
  group('SheetFloor', () {
    test('equal floors share an equality and a hash', () {
      const same = SheetFloor(defaultRegionHeight: 80, leadingHeight: 20, trailingInset: 10);

      expect(_floor, same);
      expect(_floor.hashCode, same.hashCode);
    });

    test('floors differing in any field are unequal', () {
      expect(_floor, isNot(const SheetFloor(defaultRegionHeight: 81, leadingHeight: 20)));
      expect(
        _floor,
        isNot(const SheetFloor(defaultRegionHeight: 80, leadingHeight: 21, trailingInset: 10)),
      );
      expect(
        _floor,
        isNot(const SheetFloor(defaultRegionHeight: 80, leadingHeight: 20, trailingInset: 11)),
      );
      expect(_floor, isNot('floor'));
    });

    test('extentFor adds leading, region and trailing over the available height', () {
      expect(_floor.extentFor(measuredRegionHeight: null, availableHeight: 550), 0.2);
      expect(_floor.extentFor(measuredRegionHeight: 170, availableHeight: 400), 0.5);
    });
  });

  group('SheetFloorResolver', () {
    late SheetFloorResolver resolver;

    setUp(() {
      resolver = SheetFloorResolver();
      SheetFloorResolver.resolveCount = 0;
    });

    SheetFloorResolution resolve({
      SheetPage? page,
      SheetFloor floor = _floor,
      double? measured,
      double availableHeight = 550,
    }) => resolver.resolve(
      page: page ?? _page(),
      floor: floor,
      measuredRegionHeight: measured,
      availableHeight: availableHeight,
    );

    test('uses the default region height before any measurement', () {
      final resolution = resolve();

      expect(resolution.floorExtent, 0.2);
      expect(resolution.snapSizes, [0.2, 0.5, 1.0]);
      expect(resolution.initialSize, 0.5);
    });

    test('uses the measured region height once known', () {
      final resolution = resolve(measured: 190);

      expect(resolution.floorExtent, 0.4);
      expect(resolution.snapSizes, [0.4, 0.5, 1.0]);
    });

    test('raises stops and the initial size that sit below the floor', () {
      final resolution = resolve(
        page: _page(initialSize: 0.1, snapSizes: const [0.1, 0.3, 1]),
        measured: 300,
      );

      expect(resolution.floorExtent, 0.6);
      expect(resolution.snapSizes, [0.6, 1.0]);
      expect(resolution.initialSize, 0.6);
    });

    test('clamps the floor to the expanded stop', () {
      final resolution = resolve(page: _page(snapSizes: const [0.5, 0.8]), measured: 1000);

      expect(resolution.floorExtent, 0.8);
      expect(resolution.snapSizes, [0.8]);
    });

    test('an empty snap list resolves against a full-height expanded stop', () {
      final resolution = resolve(page: _page(snapSizes: const []));

      expect(resolution.snapSizes, [0.2]);
    });

    test('hands the page stops back untouched without a measurable height', () {
      final resolution = resolve(availableHeight: 0);

      expect(resolution.snapSizes, [0.5, 1.0]);
      expect(resolution.floorExtent, 0);
    });

    test('identical inputs resolve once', () {
      resolve(measured: 100);
      final countAfterFirst = SheetFloorResolver.resolveCount;
      final first = resolver.lastResolution;
      resolve(page: _page(), measured: 100);

      expect(SheetFloorResolver.resolveCount, countAfterFirst);
      expect(resolver.lastResolution, same(first));
    });

    test('every changed input resolves again', () {
      resolve(measured: 100);
      final base = SheetFloorResolver.resolveCount;

      resolve(measured: 120);
      resolve(measured: 120, availableHeight: 600);
      resolve(measured: 120, availableHeight: 600, floor: const SheetFloor(defaultRegionHeight: 1));
      resolve(
        measured: 120,
        availableHeight: 600,
        floor: const SheetFloor(defaultRegionHeight: 1),
        page: _page(snapSizes: const [0.6, 1]),
      );
      resolve(
        measured: 120,
        availableHeight: 600,
        floor: const SheetFloor(defaultRegionHeight: 1),
        page: _page(initialSize: 0.7, snapSizes: const [0.6, 1]),
      );

      expect(SheetFloorResolver.resolveCount, base + 5);
    });
  });

  group('SheetPageScope', () {
    testWidgets('snapSizesOf throws outside a scope', (tester) async {
      await tester.pumpWidget(const SizedBox());

      expect(
        () => SheetPageScope.snapSizesOf(tester.element(find.byType(SizedBox))),
        throwsFlutterError,
      );
    });

    testWidgets('snapSizesOf returns the nearest scope stops', (tester) async {
      await tester.pumpWidget(const SheetPageScope(snapSizes: [0.2, 1], child: SizedBox()));

      expect(SheetPageScope.snapSizesOf(tester.element(find.byType(SizedBox))), [0.2, 1]);
    });

    testWidgets('dependents rebuild only when stops, floor or callback change', (tester) async {
      void onMeasured(double _) {}
      Widget host({
        List<double> snaps = const [0.2, 1],
        SheetFloor? floor,
        ValueChanged<double>? callback,
      }) => SheetPageScope(
        snapSizes: snaps,
        floor: floor,
        onFloorMeasured: callback,
        child: const _Probe(),
      );
      _probeBuilds = 0;

      await tester.pumpWidget(host());
      await tester.pumpWidget(host(snaps: [0.2, 1]));
      expect(_probeBuilds, 1);

      await tester.pumpWidget(host(snaps: const [0.3, 1]));
      expect(_probeBuilds, 2);

      await tester.pumpWidget(host(snaps: const [0.3, 1], floor: _floor));
      expect(_probeBuilds, 3);

      await tester.pumpWidget(host(snaps: const [0.3, 1], floor: _floor, callback: onMeasured));
      expect(_probeBuilds, 4);
    });
  });
}
