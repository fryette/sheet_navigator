import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

void main() {
  testWidgets('of throws a FlutterError outside a mover scope', (tester) async {
    await tester.pumpWidget(const SizedBox());

    expect(() => SheetMover.of(tester.element(find.byType(SizedBox))), throwsFlutterError);
  });

  testWidgets('maybeOf returns the mover of the nearest scope', (tester) async {
    final controller = SheetController();
    addTearDown(controller.dispose);
    final mover = SheetMover.controller(controller);

    await tester.pumpWidget(SheetMoverScope(mover: mover, child: const SizedBox()));

    expect(SheetMover.maybeOf(tester.element(find.byType(SizedBox))), same(mover));
  });

  testWidgets('a scope rebuilt with another mover hands out the new one', (tester) async {
    final controller = SheetController();
    addTearDown(controller.dispose);
    final first = SheetMover.controller(controller);
    final second = SheetMover.controller(controller);

    await tester.pumpWidget(SheetMoverScope(mover: first, child: const SizedBox()));
    await tester.pumpWidget(SheetMoverScope(mover: second, child: const SizedBox()));

    expect(SheetMover.of(tester.element(find.byType(SizedBox))), same(second));
  });

  testWidgets('a controller mover animates its sheet to the extent', (tester) async {
    final controller = SheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SheetViewport(
          child: Sheet(
            controller: controller,
            initialOffset: const SheetOffset.proportionalToViewport(0.5),
            snapGrid: const SheetSnapGrid(
              snaps: [
                SheetOffset.proportionalToViewport(0.2),
                SheetOffset.proportionalToViewport(0.5),
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    unawaited(SheetMover.controller(controller).moveTo(0.2));
    await tester.pumpAndSettle();

    expect(controller.extent, closeTo(0.2, 0.005));
  });

  test('a controller mover without an attached sheet completes without moving', () async {
    final controller = SheetController();
    addTearDown(controller.dispose);

    await expectLater(SheetMover.controller(controller).moveTo(0.2), completes);
  });
}
