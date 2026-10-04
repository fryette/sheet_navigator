import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);
const _lowestSnap = 0.3;
const _highestSnap = 0.9;

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) => card;

Widget _singleSheet({required SheetController controller}) => MaterialApp(
  home: Scaffold(
    body: SheetStack(
      entries: [
        SheetStackEntry(
          route: const _OnlyRoute(),
          page: SheetPage(
            pageKey: const _OnlyRoute().pageKey,
            initialSize: _lowestSnap,
            snapSizes: const [_lowestSnap, _highestSnap],
            builder: (context, scrollController) =>
                ListView(controller: scrollController, children: const [SizedBox(height: 40)]),
          ),
          controller: controller,
        ),
      ],
      style: _style,
      onExitCompleted: (_) {},
      onVisualTopExtentChanged: (_) {},
    ),
  ),
);

SheetMetrics _metricsOf(SheetController controller) {
  final metrics = controller.metrics;
  if (metrics == null) fail('expected the sheet controller to have metrics');
  return metrics;
}

Offset _insideSheet(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Offset(size.width / 2, size.height * 0.85);
}

void main() {
  group('SheetStack overrun', () {
    for (final dragDistance in [500.0, 503.0]) {
      testWidgets('a fling of $dragDistance never lifts the sheet past its top stop', (
        tester,
      ) async {
        final controller = SheetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_singleSheet(controller: controller));
        await tester.pumpAndSettle();

        var highestOffset = 0.0;
        void recordOffset() {
          final offset = controller.metrics?.offset;
          if (offset != null) highestOffset = math.max(highestOffset, offset);
        }

        controller.addListener(recordOffset);
        addTearDown(() => controller.removeListener(recordOffset));

        await tester.flingFrom(_insideSheet(tester), Offset(0, -dragDistance), 8000);
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          recordOffset();
        }

        expect(highestOffset, lessThanOrEqualTo(_metricsOf(controller).maxOffset + 0.01));
      }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}));
    }
  });
}
