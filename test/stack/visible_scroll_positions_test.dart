import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';
import 'package:sheet_navigator/src/stack/visible_scroll_positions.dart';

Future<ScrollController> _pumpTwoTabs(
  WidgetTester tester,
  SheetContentBounce bounce, {
  required bool isFirstVisible,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        height: 300,
        child: Builder(
          builder: (context) => bounce.track(
            (context, controller) => Stack(
              children: [
                TickerMode(
                  enabled: isFirstVisible,
                  child: ListView(
                    key: const ValueKey('first'),
                    controller: controller,
                    children: const [SizedBox(height: 1000)],
                  ),
                ),
                TickerMode(
                  enabled: !isFirstVisible,
                  child: ListView(
                    key: const ValueKey('second'),
                    controller: controller,
                    children: const [SizedBox(height: 1000)],
                  ),
                ),
              ],
            ),
          )(context, controller),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('a single attached position is always visible', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: ListView(controller: controller, children: const [SizedBox(height: 1000)]),
        ),
      ),
    );

    expect(controller.visiblePositions, hasLength(1));
  });

  testWidgets('only positions of ticker-enabled content are visible', (tester) async {
    final controller = await _pumpTwoTabs(tester, SheetContentBounce(), isFirstVisible: false);

    expect(controller.positions, hasLength(2));
    expect(controller.visiblePositions.single, controller.positions.last);
  });

  testWidgets('bounce follows the visible content, not the first attached one', (tester) async {
    final bounce = SheetContentBounce();
    final controller = await _pumpTwoTabs(tester, bounce, isFirstVisible: false);

    controller.positions.first.jumpTo(100);

    expect(bounce.delegateUnhandledOverscrollToChild, isFalse);

    controller.positions.last.jumpTo(100);

    expect(bounce.delegateUnhandledOverscrollToChild, isTrue);
  });

  testWidgets('bounce delegates for the first content only while it is visible', (tester) async {
    final bounce = SheetContentBounce();
    final controller = await _pumpTwoTabs(tester, bounce, isFirstVisible: true);

    controller.positions.first.jumpTo(100);

    expect(bounce.delegateUnhandledOverscrollToChild, isTrue);
  });
}
