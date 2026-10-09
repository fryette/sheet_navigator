import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);
const _bodyKey = ValueKey('floor_body');
const _headerKey = ValueKey('floor_header');
const _baseRegionHeight = 40.0;
const _leading = 20.0;

final class const _FloorRoute() extends SheetRoute;

final class const _OtherRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) =>
    ColoredBox(color: const Color(0xFFFFFFFF), child: card);

class _FloorFeature({
  required final SheetFloor floor,
  required final List<double> snapSizes,
  required final double initialSize,
  final bool isOther = false,
}) with SheetFeature<SheetRoute> {
  final controllers = <Object, SheetController>{};
  final observedSnaps = <List<double>>[];
  final showHeader = ValueNotifier<bool>(true);

  @override
  bool handles(SheetRoute route) => (route is _OtherRoute) == isOther;

  @override
  SheetPage page(
    BuildContext context,
    SheetRoute route,
    double availableHeight,
    SheetController controller,
  ) {
    controllers[route.pageKey] = controller;
    return SheetPage(
      pageKey: route.pageKey,
      initialSize: initialSize,
      snapSizes: snapSizes,
      floor: floor,
      header: !showHeader.value
          ? null
          : (context) => SizedBox(
              key: _headerKey,
              height: MediaQuery.textScalerOf(context).scale(_baseRegionHeight),
              width: double.infinity,
            ),
      builder: (context, scrollController) {
        observedSnaps.add(SheetPageScope.snapSizesOf(context));
        return ListView(
          controller: scrollController,
          children: [
            for (var index = 0; index < 40; index++)
              SizedBox(key: index == 0 ? _bodyKey : null, height: 60, child: Text('$index')),
          ],
        );
      },
    );
  }
}

class const _Host({
  required final List<_FloorFeature> features,
  required final ValueNotifier<double> textScale,
  required final ValueNotifier<List<SheetRoute>> stack,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => ValueListenableBuilder(
      valueListenable: textScale,
      builder: (context, scale, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: ValueListenableBuilder(
      valueListenable: stack,
      builder: (context, routes, _) => SheetNavigator<SheetRoute, _FloorFeature>(
        features: features,
        stack: routes,
        style: _style,
        onPopRequested: () {},
        onRouteExited: (_) {},
      ),
    ),
  );
}

void main() {
  late ValueNotifier<double> textScale;
  late ValueNotifier<List<SheetRoute>> stack;

  setUp(() {
    textScale = ValueNotifier(1);
    stack = ValueNotifier(const [_FloorRoute()]);
    SheetFloorResolver.resolveCount = 0;
  });

  tearDown(() {
    textScale.dispose();
    stack.dispose();
  });

  _FloorFeature feature({
    double initialSize = 0.5,
    List<double> snapSizes = const [0.5, 1],
    double defaultRegionHeight = 100,
    double trailingInset = 0,
    bool isOther = false,
  }) => _FloorFeature(
    floor: SheetFloor(
      defaultRegionHeight: defaultRegionHeight,
      leadingHeight: _leading,
      trailingInset: trailingInset,
    ),
    snapSizes: snapSizes,
    initialSize: initialSize,
    isOther: isOther,
  );

  Future<void> pumpHost(WidgetTester tester, List<_FloorFeature> features) async {
    await tester.pumpWidget(_Host(features: features, textScale: textScale, stack: stack));
    await tester.pumpAndSettle();
  }

  double extentOf(_FloorFeature feature, [SheetRoute route = const _FloorRoute()]) =>
      feature.controllers[route.pageKey]!.metrics!.offset / 600;

  double viewportHeight(WidgetTester tester) => tester.getSize(find.byType(SheetViewport)).height;

  group('measured floor', () {
    testWidgets('resolves the floor from the default height before the first measurement', (
      tester,
    ) async {
      final floorFeature = feature(initialSize: 0.1);
      await tester.pumpWidget(_Host(features: [floorFeature], textScale: textScale, stack: stack));

      expect(floorFeature.observedSnaps.first.first, closeTo((_leading + 100) / 600, 1e-9));
    });

    testWidgets('resolves the floor from the measured region once it is laid out', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);

      expect(viewportHeight(tester), 600);
      expect(floorFeature.observedSnaps.last.first, closeTo((_leading + 40) / 600, 1e-9));
      expect(floorFeature.observedSnaps.last, hasLength(3));
    });

    testWidgets('a sheet resting on the floor follows it to the measured height', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);

      expect(extentOf(floorFeature), closeTo((_leading + 40) / 600, 0.005));
    });

    testWidgets('a text scale change resolves and reports exactly once', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);
      final before = SheetFloorResolver.resolveCount;

      textScale.value = 2;
      await tester.pumpAndSettle();

      expect(SheetFloorResolver.resolveCount, before + 1);
      expect(extentOf(floorFeature), closeTo((_leading + 80) / 600, 0.005));
    });

    testWidgets('a sheet resting above the floor stays put when the floor changes', (tester) async {
      final floorFeature = feature();
      await pumpHost(tester, [floorFeature]);

      textScale.value = 2;
      await tester.pumpAndSettle();

      expect(extentOf(floorFeature), closeTo(0.5, 0.005));
      expect(floorFeature.observedSnaps.last.first, closeTo((_leading + 80) / 600, 1e-9));
    });

    testWidgets('a floor change during a drag does not move the sheet', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);
      final gesture = await tester.startGesture(Offset(400, 600 - 20));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      final dragged = extentOf(floorFeature);

      textScale.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(extentOf(floorFeature), closeTo(dragged, 0.005));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('rebuilds, drags and scrolls never recalculate the floor', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);
      final before = SheetFloorResolver.resolveCount;

      for (var index = 0; index < 3; index++) {
        stack.value = [...stack.value];
        await tester.pump();
      }
      await tester.dragFrom(const Offset(400, 590), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(_bodyKey), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(_bodyKey), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(SheetFloorResolver.resolveCount, before);
    });

    testWidgets('a header that comes back at the same height changes nothing', (tester) async {
      final floorFeature = feature(initialSize: 0.1);
      await pumpHost(tester, [floorFeature]);
      final before = SheetFloorResolver.resolveCount;

      floorFeature.showHeader.value = false;
      stack.value = [...stack.value];
      await tester.pumpAndSettle();
      floorFeature.showHeader.value = true;
      stack.value = [...stack.value];
      await tester.pumpAndSettle();

      expect(find.byKey(_headerKey), findsOneWidget);
      expect(SheetFloorResolver.resolveCount, before);
      expect(extentOf(floorFeature), closeTo((_leading + 40) / 600, 0.005));
    });

    testWidgets('a lower page resting on its floor follows the floor too', (tester) async {
      final rootFeature = feature(initialSize: 0.1);
      final otherFeature = feature(initialSize: 0.5, isOther: true);
      await pumpHost(tester, [rootFeature, otherFeature]);
      stack.value = const [_FloorRoute(), _OtherRoute()];
      await tester.pumpAndSettle();

      textScale.value = 2;
      await tester.pumpAndSettle();

      expect(extentOf(rootFeature), closeTo((_leading + 80) / 600, 0.005));
      expect(extentOf(otherFeature, const _OtherRoute()), closeTo(0.5, 0.005));
    });

    testWidgets('a report for a page that is gone is ignored', (tester) async {
      final rootFeature = feature(initialSize: 0.1);
      final otherFeature = feature(initialSize: 0.5, isOther: true);
      await pumpHost(tester, [rootFeature, otherFeature]);
      stack.value = const [_FloorRoute(), _OtherRoute()];
      await tester.pumpAndSettle();
      stack.value = const [_FloorRoute()];
      await tester.pumpAndSettle();
      final before = SheetFloorResolver.resolveCount;

      textScale.value = 2;
      await tester.pumpAndSettle();

      expect(SheetFloorResolver.resolveCount, before + 1);
    });
  });

  group('floor inset spacer', () {
    testWidgets('sits below the region only while the sheet rests on the floor', (tester) async {
      final floorFeature = feature(initialSize: 0.1, trailingInset: 30);
      await pumpHost(tester, [floorFeature]);
      double gapBelowHeader() =>
          tester.getTopLeft(find.byKey(_bodyKey)).dy -
          tester.getBottomLeft(find.byKey(_headerKey)).dy;

      expect(gapBelowHeader(), closeTo(30, 0.01));

      await tester.dragFrom(const Offset(400, 600 - 20), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(gapBelowHeader(), closeTo(0, 0.01));
    });

    testWidgets('is excluded from the measured region', (tester) async {
      final floorFeature = feature(initialSize: 0.1, trailingInset: 30);
      await pumpHost(tester, [floorFeature]);

      expect(floorFeature.observedSnaps.last.first, closeTo((_leading + 40 + 30) / 600, 1e-9));
      expect(extentOf(floorFeature), closeTo((_leading + 40 + 30) / 600, 0.005));
    });
  });
}
