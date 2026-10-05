import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _viewportHeight = 800.0;
const _snapSizes = [0.2, 0.5, 0.9];
const _keptScroll = 300.0;
const _listKey = ValueKey('list');

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) => card;

Widget _sheet(SheetController controller) => MaterialApp(
  home: SheetStack(
    entries: [
      SheetStackEntry(
        route: const _OnlyRoute(),
        page: SheetPage(
          pageKey: const _OnlyRoute().pageKey,
          initialSize: 0.5,
          snapSizes: _snapSizes,
          header: (context) => const SizedBox(key: ValueKey('header'), height: 48),
          builder: (context, scrollController) => ListView.builder(
            key: _listKey,
            controller: scrollController,
            itemCount: 60,
            itemBuilder: (context, index) => SizedBox(height: 48, child: Text('Row $index')),
          ),
        ),
        controller: controller,
      ),
    ],
    style: const SheetNavigatorStyle(surfaceBuilder: _surface),
    onExitCompleted: (_) {},
    onVisualTopExtentChanged: (_) {},
  ),
);

Future<SheetController> _pumpSheet(WidgetTester tester, {required bool isContentScrolled}) async {
  tester.view.physicalSize = const Size(400, _viewportHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = SheetController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(_sheet(controller));
  await tester.pumpAndSettle();
  if (isContentScrolled) {
    await _animateTo(tester, controller, _snapSizes.last);
    _scrollPosition(tester).jumpTo(_keptScroll);
    await tester.pumpAndSettle();
  }
  await _animateTo(tester, controller, 0.5);

  return controller;
}

Future<void> _animateTo(WidgetTester tester, SheetController controller, double extent) async {
  unawaited(
    controller.animateTo(
      SheetOffset.proportionalToViewport(extent),
      duration: const Duration(milliseconds: 1),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

double _extent(SheetController controller) => (controller.metrics?.offset ?? 0) / _viewportHeight;

Offset _contentPoint() => const Offset(200, _viewportHeight * 0.5 + 150);

Future<void> _slowDrag(WidgetTester tester, double dy) async {
  await tester.timedDragFrom(_contentPoint(), Offset(0, dy), const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _fling(WidgetTester tester, double dy) async {
  await tester.flingFrom(_contentPoint(), Offset(0, dy), 1200);
  await tester.pumpAndSettle();
}

void main() {
  group('a content swipe on a sheet below its top stop with scrolled content', () {
    for (final isContentScrolled in [false, true]) {
      final label = isContentScrolled ? 'scrolled' : 'unscrolled';

      testWidgets('snaps to the nearest stop after a slow upward drag ($label)', (tester) async {
        final controller = await _pumpSheet(tester, isContentScrolled: isContentScrolled);

        await _slowDrag(tester, -200);

        expect(_extent(controller), closeTo(0.9, 0.005));
      });

      testWidgets('collapses on a short downward fling ($label)', (tester) async {
        final controller = await _pumpSheet(tester, isContentScrolled: isContentScrolled);

        await _fling(tester, 100);

        expect(_extent(controller), closeTo(0.2, 0.005));
      });

      testWidgets('expands on a short upward fling ($label)', (tester) async {
        final controller = await _pumpSheet(tester, isContentScrolled: isContentScrolled);

        await _fling(tester, -100);

        expect(_extent(controller), closeTo(0.9, 0.005));
      });
    }

    testWidgets('keeps the content scroll offset while the sheet moves', (tester) async {
      final controller = await _pumpSheet(tester, isContentScrolled: true);

      await _fling(tester, 100);

      expect(_extent(controller), closeTo(0.2, 0.005));
      expect(_scrollPosition(tester).pixels, _keptScroll);
    });

    testWidgets('scrolls the content again once the sheet is back at its top stop', (tester) async {
      final controller = await _pumpSheet(tester, isContentScrolled: true);
      await _fling(tester, -100);

      await tester.dragFrom(const Offset(200, _viewportHeight * 0.5), const Offset(0, 100));
      await tester.pumpAndSettle();

      expect(_extent(controller), closeTo(0.9, 0.005));
      expect(_scrollPosition(tester).pixels, lessThan(_keptScroll));
    });
  });
}
