import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) => card;

const _snapSizes = [0.4, 0.9];

Widget _sheet({
  required SheetController controller,
  required ScrollController scrollController,
  double initialSize = 0.9,
  int itemCount = 40,
}) => MaterialApp(
  home: Scaffold(
    body: SheetStack(
      entries: [
        SheetStackEntry(
          route: const _OnlyRoute(),
          page: SheetPage(
            pageKey: const _OnlyRoute().pageKey,
            initialSize: initialSize,
            snapSizes: _snapSizes,
            builder: (context, sheetScrollController) => CustomScrollView(
              key: const ValueKey('content'),
              controller: sheetScrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverList.builder(
                  itemCount: itemCount,
                  itemBuilder: (context, index) => SizedBox(height: 60, child: Text('Item $index')),
                ),
              ],
            ),
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

double _offset(SheetController controller) => controller.metrics!.offset;

Future<ScrollController> _pump(
  WidgetTester tester,
  SheetController controller, {
  double initialSize = 0.9,
  int itemCount = 40,
}) async {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);
  await tester.pumpWidget(
    _sheet(
      controller: controller,
      scrollController: scrollController,
      initialSize: initialSize,
      itemCount: itemCount,
    ),
  );
  await tester.pumpAndSettle();
  return scrollController;
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  late SheetController controller;

  setUp(() {
    controller = SheetController();
    addTearDown(controller.dispose);
  });

  testWidgets('a drag started mid-list that passes the top rubber-bands the content only', (
    tester,
  ) async {
    await _pump(tester, controller);
    final startOffset = _offset(controller);
    _position(tester).jumpTo(150);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_position(tester).pixels, lessThan(0));
    expect(_offset(controller), closeTo(startOffset, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_position(tester).pixels, closeTo(0, 0.5));
    expect(_offset(controller), closeTo(startOffset, 0.5));
  });

  for (final (:start, :distance) in [
    (start: 150.0, distance: 300.0),
    (start: 60.0, distance: 90.0),
  ]) {
    testWidgets('a downward fling from $start that reaches the top never moves the sheet', (
      tester,
    ) async {
      await _pump(tester, controller);
      final startOffset = _offset(controller);
      _position(tester).jumpTo(start);
      await tester.pump();

      await tester.fling(find.byKey(const ValueKey('content')), Offset(0, distance), 3000);
      var deviation = 0.0;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        deviation = math.max(deviation, (_offset(controller) - startOffset).abs());
      }

      expect(deviation, lessThan(0.5));
      expect(_position(tester).pixels, closeTo(0, 0.5));
    });
  }

  testWidgets('a drag started at the top of the list drags the sheet down', (tester) async {
    await _pump(tester, controller);
    final startOffset = _offset(controller);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_offset(controller), lessThan(startOffset - 10));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a drag up past the end of the list rubber-bands the content only', (tester) async {
    await _pump(tester, controller);
    final startOffset = _offset(controller);
    final position = _position(tester)..jumpTo(_position(tester).maxScrollExtent - 100);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(position.pixels, greaterThan(position.maxScrollExtent));
    expect(_offset(controller), closeTo(startOffset, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
    expect(_offset(controller), closeTo(startOffset, 0.5));
  });

  testWidgets('a touch that catches the top bounce drags the sheet instead of the content', (
    tester,
  ) async {
    await _pump(tester, controller);
    final position = _position(tester)..jumpTo(300);
    await tester.pump();
    final startOffset = _offset(controller);

    await tester.fling(find.byKey(const ValueKey('content')), const Offset(0, 600), 3000);
    for (var i = 0; i < 120 && position.pixels >= -5; i++) {
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(position.pixels, lessThan(-5));
    final caughtOffset = _offset(controller);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(position.pixels, closeTo(0, 0.5));
    expect(_offset(controller), lessThan(math.min(startOffset, caughtOffset)));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a drag started at the top that runs past the end bounces the content end', (
    tester,
  ) async {
    await _pump(tester, controller, itemCount: 11);
    final position = _position(tester);
    expect(position.maxScrollExtent, inInclusiveRange(20, 150));
    final startOffset = _offset(controller);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(position.pixels, greaterThan(position.maxScrollExtent + 1));
    expect(_offset(controller), closeTo(startOffset, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
    expect(_offset(controller), closeTo(startOffset, 0.5));
  });

  testWidgets('an upward fling started at the top overshoots the content end then settles', (
    tester,
  ) async {
    await _pump(tester, controller, itemCount: 11);
    final position = _position(tester);
    final startOffset = _offset(controller);

    await tester.fling(find.byKey(const ValueKey('content')), const Offset(0, -400), 4000);
    var peak = 0.0;
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      peak = math.max(peak, position.pixels);
    }
    await tester.pumpAndSettle();

    expect(peak, greaterThan(position.maxScrollExtent + 1));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
    expect(_offset(controller), closeTo(startOffset, 0.5));
  });

  testWidgets('a downward drag at the lowest snap never pushes the content above its top', (
    tester,
  ) async {
    await _pump(tester, controller, initialSize: 0.4, itemCount: 11);
    final position = _position(tester);
    expect(_offset(controller), closeTo(0.4 * 600, 1));
    var lowest = 0.0;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('content'))),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      lowest = math.min(lowest, position.pixels);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(lowest, greaterThanOrEqualTo(-0.5));
    expect(position.pixels, greaterThanOrEqualTo(-0.5));
  });
}
