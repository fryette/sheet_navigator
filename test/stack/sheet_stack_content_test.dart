import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);

final class const _OnlyRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) => card;

Widget _singleSheet({
  required SheetController controller,
  required double initialSize,
  required List<double> snapSizes,
  required ScrollableWidgetBuilder builder,
  Widget? sibling,
}) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        ?sibling,
        SheetStack(
          entries: [
            SheetStackEntry(
              route: const _OnlyRoute(),
              page: SheetPage(
                pageKey: const _OnlyRoute().pageKey,
                initialSize: initialSize,
                snapSizes: snapSizes,
                builder: builder,
              ),
              controller: controller,
            ),
          ],
          style: _style,
          onExitCompleted: (_) {},
          onVisualTopExtentChanged: (_) {},
        ),
      ],
    ),
  ),
);

void main() {
  group('SheetExtentBuilder', () {
    testWidgets('rebuilds with the extent the sheet was animated to', (tester) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      final observedExtents = <double?>[];

      await tester.pumpWidget(
        _singleSheet(
          controller: controller,
          initialSize: 0.5,
          snapSizes: const [0.2, 0.5, 0.8],
          builder: (context, scrollController) => const SizedBox.expand(),
          sibling: SheetExtentBuilder(
            controller: controller,
            builder: (context, extent, child) {
              observedExtents.add(extent);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      unawaited(
        controller.animateTo(
          const SheetOffset.proportionalToViewport(0.8),
          duration: const Duration(milliseconds: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(observedExtents.lastOrNull, closeTo(0.8, 0.001));
    });
  });

  group('SheetVisibleContent', () {
    testWidgets('centres content within the visible sheet area at a partial snap', (tester) async {
      final markerKey = UniqueKey();
      final controller = SheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _singleSheet(
          controller: controller,
          initialSize: 0.3,
          snapSizes: const [0.3, 0.9],
          builder: (context, scrollController) => SheetVisibleContent(
            child: Center(child: SizedBox(key: markerKey, width: 20, height: 20)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewportHeight = tester.getSize(find.byType(SheetStack)).height;
      final contentBoxHeight = 0.9 * viewportHeight;
      final slotRect = tester.getRect(find.byType(SheetVisibleContent));
      final chromeHeight = contentBoxHeight - slotRect.height;
      final fullSlotCenterY = slotRect.top + slotRect.height / 2;

      switch (controller.metrics) {
        case final metrics?:
          final expectedVisibleHeight = (metrics.offset - chromeHeight).clamp(0.0, slotRect.height);
          final markerCenter = tester.getCenter(find.byKey(markerKey));

          expect(markerCenter.dy, closeTo(slotRect.top + expectedVisibleHeight / 2, 1));
          expect((markerCenter.dy - fullSlotCenterY).abs(), greaterThan(20));
        case null:
          fail('expected the sheet controller to have metrics after settling');
      }
    });

    testWidgets('renders the child unchanged outside any sheet', (tester) async {
      final markerKey = UniqueKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SheetVisibleContent(
              child: Center(child: SizedBox(key: markerKey, width: 20, height: 20)),
            ),
          ),
        ),
      );

      expect(tester.getCenter(find.byKey(markerKey)), tester.getCenter(find.byType(Scaffold)));
      expect(tester.getSize(find.byKey(markerKey)), const Size(20, 20));
    });
  });

  group('SheetPageContent handle', () {
    testWidgets('draws the style handle above the page when the style supplies one', (
      tester,
    ) async {
      final controller = SheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SheetStack(
            entries: [
              SheetStackEntry(
                route: const _OnlyRoute(),
                page: SheetPage(
                  pageKey: const _OnlyRoute().pageKey,
                  initialSize: 0.5,
                  snapSizes: const [0.5],
                  builder: (context, scrollController) => const SizedBox.expand(),
                ),
                controller: controller,
              ),
            ],
            style: SheetNavigatorStyle(
              surfaceBuilder: _surface,
              handleBuilder: (context) => const SizedBox(key: ValueKey('handle'), height: 4),
            ),
            onExitCompleted: (_) {},
            onVisualTopExtentChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('handle')), findsOneWidget);
    });
  });

  group('SheetNavigatorStyle sheet hooks', () {
    Future<void> pumpStyled(
      WidgetTester tester, {
      required SheetNavigatorStyle style,
      double keyboardHeight = 0,
    }) async {
      final controller = SheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
            child: SheetStack(
              entries: [
                SheetStackEntry(
                  route: const _OnlyRoute(),
                  page: SheetPage(
                    pageKey: const _OnlyRoute().pageKey,
                    initialSize: 0.5,
                    snapSizes: const [0.5],
                    builder: (context, scrollController) => const SizedBox.expand(),
                  ),
                  controller: controller,
                ),
              ],
              style: style,
              onExitCompleted: (_) {},
              onVisualTopExtentChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('wraps the sheet in a keyboard dismissible only when a behavior is set', (
      tester,
    ) async {
      await pumpStyled(tester, style: _style);
      expect(find.byType(SheetKeyboardDismissible), findsNothing);

      await pumpStyled(
        tester,
        style: const SheetNavigatorStyle(
          surfaceBuilder: _surface,
          keyboardDismissBehavior: SheetKeyboardDismissBehavior.onDragDown(
            isContentScrollAware: true,
          ),
        ),
      );

      final dismissible = tester.widget<SheetKeyboardDismissible>(
        find.byType(SheetKeyboardDismissible),
      );
      expect(
        dismissible.dismissBehavior,
        const SheetKeyboardDismissBehavior.onDragDown(isContentScrollAware: true),
      );
    });

    testWidgets('pads the sheet by the keyboard height only when enabled', (tester) async {
      await pumpStyled(tester, style: _style, keyboardHeight: 300);
      expect(tester.widget<Sheet>(find.byType(Sheet)).padding, EdgeInsets.zero);

      await pumpStyled(
        tester,
        style: const SheetNavigatorStyle(surfaceBuilder: _surface, isKeyboardPaddingEnabled: true),
        keyboardHeight: 300,
      );
      expect(tester.widget<Sheet>(find.byType(Sheet)).padding, const EdgeInsets.only(bottom: 300));
    });

    testWidgets('hands the style scroll configuration to the sheet', (tester) async {
      const configuration = SheetScrollConfiguration(scrollSyncMode: .onlyFromTop);

      await pumpStyled(
        tester,
        style: const SheetNavigatorStyle(
          surfaceBuilder: _surface,
          scrollConfiguration: configuration,
        ),
      );

      expect(tester.widget<Sheet>(find.byType(Sheet)).scrollConfiguration, configuration);
    });
  });
}
