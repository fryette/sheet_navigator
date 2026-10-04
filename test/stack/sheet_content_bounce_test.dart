import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

Future<ScrollController> _pumpTracked(
  WidgetTester tester,
  SheetContentBounce bounce, {
  required double itemHeight,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        height: 300,
        child: Builder(
          builder: (context) => bounce.track(
            (context, controller) => ListView(
              controller: controller,
              children: [SizedBox(height: itemHeight)],
            ),
          )(context, controller),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  test('does not delegate before any content is tracked', () {
    expect(SheetContentBounce().delegateUnhandledOverscrollToChild, isFalse);
  });

  testWidgets('delegates only while scrollable content is past its top', (tester) async {
    final bounce = SheetContentBounce();
    final controller = await _pumpTracked(tester, bounce, itemHeight: 1000);

    expect(bounce.delegateUnhandledOverscrollToChild, isFalse);

    controller.jumpTo(100);
    expect(bounce.delegateUnhandledOverscrollToChild, isTrue);

    controller.jumpTo(0);
    expect(bounce.delegateUnhandledOverscrollToChild, isFalse);
  });

  testWidgets('does not delegate for content that cannot scroll', (tester) async {
    final bounce = SheetContentBounce();
    await _pumpTracked(tester, bounce, itemHeight: 100);

    expect(bounce.delegateUnhandledOverscrollToChild, isFalse);
  });
}
