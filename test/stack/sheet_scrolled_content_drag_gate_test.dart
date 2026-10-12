import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _viewportHeight = 800.0;
const _snapSizes = [0.2, 0.5, 0.9];
const _keptScroll = 300.0;
const _firstKey = ValueKey('first');
const _secondKey = ValueKey('second');

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) => card;

Widget _list(Key key, ScrollController controller, {required bool isVisible}) => Visibility(
  visible: isVisible,
  maintainState: true,
  child: ListView.builder(
    key: key,
    controller: controller,
    itemCount: 60,
    itemBuilder: (context, index) => SizedBox(height: 48, child: Text('Row $index')),
  ),
);

Widget _sheet(SheetController controller, ValueNotifier<bool> isFirstVisible) => MaterialApp(
  home: SheetStack(
    entries: [
      SheetStackEntry(
        route: const _OnlyRoute(),
        page: SheetPage(
          pageKey: const _OnlyRoute().pageKey,
          initialSize: 0.5,
          snapSizes: _snapSizes,
          header: (context) => const SizedBox(height: 48),
          builder: (context, scrollController) => ValueListenableBuilder<bool>(
            valueListenable: isFirstVisible,
            builder: (context, isFirst, child) => Stack(
              children: [
                Positioned.fill(child: _list(_firstKey, scrollController, isVisible: isFirst)),
                Positioned.fill(child: _list(_secondKey, scrollController, isVisible: !isFirst)),
              ],
            ),
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

Future<void> _animateTo(WidgetTester tester, SheetController controller, double extent) async {
  unawaited(
    controller.animateTo(
      SheetOffset.proportionalToViewport(extent),
      duration: const Duration(milliseconds: 1),
    ),
  );
  await tester.pumpAndSettle();
}

double _extent(SheetController controller) => (controller.metrics?.offset ?? 0) / _viewportHeight;

void main() {
  testWidgets('moves the sheet when the revisited content is scrolled', (tester) async {
    tester.view.physicalSize = const Size(400, _viewportHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = SheetController();
    addTearDown(controller.dispose);
    final isFirstVisible = ValueNotifier(true);
    addTearDown(isFirstVisible.dispose);

    await tester.pumpWidget(_sheet(controller, isFirstVisible));
    await tester.pumpAndSettle();
    await _animateTo(tester, controller, _snapSizes.last);
    tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(_firstKey), matching: find.byType(Scrollable)),
        )
        .position
        .jumpTo(_keptScroll);
    await tester.pumpAndSettle();
    await _animateTo(tester, controller, 0.5);

    isFirstVisible.value = false;
    await tester.pumpAndSettle();
    await _animateTo(tester, controller, 0.2);
    await _animateTo(tester, controller, 0.5);
    isFirstVisible.value = true;
    await tester.pumpAndSettle();

    await tester.flingFrom(
      const Offset(200, _viewportHeight * 0.5 + 150),
      const Offset(0, -100),
      1200,
    );
    await tester.pumpAndSettle();

    expect(_extent(controller), closeTo(0.9, 0.005));
  });
}
