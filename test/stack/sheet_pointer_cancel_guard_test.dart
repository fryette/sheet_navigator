import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);
const _contentKey = ValueKey('content');
const _dragStepInterval = Duration(milliseconds: 16);

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
            initialSize: 0.3,
            snapSizes: const [0.3, 0.9],
            builder: (context, scrollController) => const SizedBox.expand(key: _contentKey),
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

typedef _Drag = ({TestGesture gesture, Duration elapsed});

Future<_Drag> _startUpwardDrag(WidgetTester tester) async {
  var elapsed = Duration.zero;
  final topLeft = tester.getTopLeft(find.byKey(_contentKey));
  final width = tester.getSize(find.byKey(_contentKey)).width;
  final gesture = await tester.startGesture(topLeft + Offset(width / 2, 20));
  for (var i = 0; i < 8; i++) {
    elapsed += _dragStepInterval;
    await gesture.moveBy(const Offset(0, -60), timeStamp: elapsed);
    await tester.pump(_dragStepInterval);
  }
  return (gesture: gesture, elapsed: elapsed);
}

void main() {
  group('SheetPointerCancelGuard', () {
    testWidgets('returns the sheet to its drag-start snap when the drag is cancelled', (
      tester,
    ) async {
      final controller = SheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_singleSheet(controller: controller));
      await tester.pumpAndSettle();

      final startOffset = controller.metrics?.offset;
      if (startOffset == null) {
        fail('expected the sheet controller to have metrics after settling');
      }

      final drag = await _startUpwardDrag(tester);
      await drag.gesture.cancel(timeStamp: drag.elapsed + _dragStepInterval);
      await tester.pumpAndSettle();

      expect(controller.metrics?.offset, closeTo(startOffset, 0.5));
    });

    testWidgets('a normally released fast drag still flings the sheet to the expanded snap', (
      tester,
    ) async {
      final controller = SheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_singleSheet(controller: controller));
      await tester.pumpAndSettle();

      final drag = await _startUpwardDrag(tester);
      await drag.gesture.up(timeStamp: drag.elapsed + _dragStepInterval);
      await tester.pumpAndSettle();

      switch (controller.metrics) {
        case final metrics?:
          expect(metrics.offset, closeTo(metrics.maxOffset, 0.5));
        case null:
          fail('expected the sheet controller to have metrics after settling');
      }
    });
  });
}
