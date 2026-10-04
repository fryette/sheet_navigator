import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _surfaceKey = ValueKey('surface');
const _frame = Duration(milliseconds: 8);
const _noise = 0.1;

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) =>
    ColoredBox(key: _surfaceKey, color: Colors.white, child: card);

Widget _sheet({
  required SheetController controller,
  List<double> snapSizes = const [0.3, 0.9],
  double initialSize = 0.3,
}) => MaterialApp(
  home: Scaffold(
    body: SheetStack(
      entries: [
        SheetStackEntry(
          route: const _OnlyRoute(),
          page: SheetPage(
            pageKey: const _OnlyRoute().pageKey,
            initialSize: initialSize,
            snapSizes: snapSizes,
            builder: (context, scrollController) =>
                ListView(controller: scrollController, children: const [SizedBox(height: 40)]),
          ),
          controller: controller,
        ),
      ],
      style: const SheetNavigatorStyle(surfaceBuilder: _surface),
      onExitCompleted: (_) {},
      onVisualTopExtentChanged: (_) {},
    ),
  ),
);

Offset _insideSheet(WidgetTester tester, {double heightFraction = 0.85}) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Offset(size.width / 2, size.height * heightFraction);
}

SheetMetrics _metricsOf(SheetController controller) {
  final metrics = controller.metrics;
  if (metrics == null) fail('expected the sheet controller to have metrics');
  return metrics;
}

Future<List<double>> _record(
  WidgetTester tester,
  SheetController controller, {
  int frames = 150,
}) async {
  final offsets = <double>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
    offsets.add(_metricsOf(controller).offset);
  }
  return offsets;
}

Future<void> _settleAtTop(WidgetTester tester, SheetController controller) async {
  await tester.flingFrom(_insideSheet(tester), const Offset(0, -500), 2000);
  await tester.pumpAndSettle();
  expect(_metricsOf(controller).offset, closeTo(_metricsOf(controller).maxOffset, 0.01));
}

void main() {
  const variant = TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});

  group('SheetStack snap bounce', () {
    testWidgets('a fling up to the top snap overshoots the maximum once and returns exactly', (
      tester,
    ) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_sheet(controller: controller));
      await tester.pumpAndSettle();
      final max = _metricsOf(controller).maxOffset;

      await tester.flingFrom(_insideSheet(tester), const Offset(0, -500), 2000);
      final offsets = await _record(tester, controller);

      final peak = offsets.reduce(math.max);
      expect(peak - max, greaterThan(1));
      expect(peak - max, lessThanOrEqualTo(sheetOvershootExtent));
      final peakIndex = offsets.indexOf(peak);
      final afterPeak = offsets.sublist(peakIndex);
      for (var i = 1; i < afterPeak.length; i++) {
        expect(afterPeak[i], lessThanOrEqualTo(afterPeak[i - 1] + _noise));
      }
      expect(offsets.last, max);
    }, variant: variant);

    testWidgets(
      'a fling down to the lowest snap undershoots the minimum once and returns exactly',
      (tester) async {
        final controller = SheetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_sheet(controller: controller));
        await tester.pumpAndSettle();
        await _settleAtTop(tester, controller);
        final min = _metricsOf(controller).minOffset;

        await tester.flingFrom(_insideSheet(tester), const Offset(0, 500), 2000);
        final offsets = await _record(tester, controller);

        final trough = offsets.reduce(math.min);
        expect(min - trough, greaterThan(1));
        expect(min - trough, lessThanOrEqualTo(sheetOvershootExtent));
        final troughIndex = offsets.indexOf(trough);
        final afterTrough = offsets.sublist(troughIndex);
        for (var i = 1; i < afterTrough.length; i++) {
          expect(afterTrough[i], greaterThanOrEqualTo(afterTrough[i - 1] - _noise));
        }
        expect(offsets.last, min);
      },
      variant: variant,
    );

    testWidgets('a fling that settles on a middle snap overshoots it once', (tester) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_sheet(controller: controller, snapSizes: const [0.3, 0.6, 0.9]));
      await tester.pumpAndSettle();
      final middle = 0.6 * tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.flingFrom(_insideSheet(tester), const Offset(0, -80), 1500);
      final offsets = await _record(tester, controller);

      final peak = offsets.reduce(math.max);
      expect(peak - middle, greaterThan(0.5));
      expect(peak - middle, lessThanOrEqualTo(sheetOvershootExtent));
      final afterPeak = offsets.sublist(offsets.indexOf(peak));
      for (var i = 1; i < afterPeak.length; i++) {
        expect(afterPeak[i], lessThanOrEqualTo(afterPeak[i - 1] + _noise));
        expect(afterPeak[i], greaterThanOrEqualTo(middle - _noise));
      }
      expect(offsets.last, closeTo(middle, 0.01));
    }, variant: variant);

    testWidgets('a slow drag pinned at the maximum never moves past it', (tester) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_sheet(controller: controller));
      await tester.pumpAndSettle();
      final max = _metricsOf(controller).maxOffset;

      final gesture = await tester.startGesture(_insideSheet(tester));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 50));
        expect(_metricsOf(controller).offset, lessThanOrEqualTo(max + 0.001));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_metricsOf(controller).offset, max);
    }, variant: variant);

    testWidgets('the surface bottom edge never leaves the viewport bottom while overshooting', (
      tester,
    ) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_sheet(controller: controller));
      await tester.pumpAndSettle();
      final max = _metricsOf(controller).maxOffset;
      final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.flingFrom(_insideSheet(tester), const Offset(0, -500), 2000);
      var overshot = false;
      for (var i = 0; i < 150; i++) {
        await tester.pump(_frame);
        overshot = overshot || _metricsOf(controller).offset > max + 1;
        expect(
          tester.getRect(find.byKey(_surfaceKey)).bottom,
          greaterThanOrEqualTo(viewportHeight),
        );
      }
      expect(overshot, isTrue);
    }, variant: variant);

    testWidgets('a full-height sheet has no room to overshoot and leaves no gap', (tester) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_sheet(controller: controller, snapSizes: const [0.3, 1.0]));
      await tester.pumpAndSettle();
      final max = _metricsOf(controller).maxOffset;
      final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.flingFrom(_insideSheet(tester), const Offset(0, -500), 2000);
      for (var i = 0; i < 150; i++) {
        await tester.pump(_frame);
        expect(_metricsOf(controller).offset, lessThanOrEqualTo(max + 0.001));
        expect(
          tester.getRect(find.byKey(_surfaceKey)).bottom,
          greaterThanOrEqualTo(viewportHeight),
        );
      }
      expect(_metricsOf(controller).offset, max);
    }, variant: variant);
  });
}
