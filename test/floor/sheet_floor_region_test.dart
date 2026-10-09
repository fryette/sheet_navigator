import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

class const _RoutePage() extends SheetRoute;

class const _DoubleLayout({required super.child}) extends SingleChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDoubleLayout();
}

class _RenderDoubleLayout extends RenderProxyBox {
  @override
  void performLayout() {
    child!.layout(const BoxConstraints.tightFor(width: 100, height: 10), parentUsesSize: true);
    child!.layout(const BoxConstraints.tightFor(width: 100, height: 30), parentUsesSize: true);
    size = constraints.constrain(child!.size);
  }
}

Widget _region(List<double> reports, double height, {Key? key}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SheetPageScope(
    snapSizes: const [0.5, 1],
    onFloorMeasured: reports.add,
    child: Align(
      alignment: Alignment.topLeft,
      child: SheetFloorRegion(
        key: key,
        child: SizedBox(width: 100, height: height),
      ),
    ),
  ),
);

void main() {
  group('SheetFloorRegion', () {
    testWidgets('reports its height once after the first layout', (tester) async {
      final reports = <double>[];

      await tester.pumpWidget(_region(reports, 60));

      expect(reports, [60]);
    });

    testWidgets('layouts at the same height report nothing', (tester) async {
      final reports = <double>[];
      await tester.pumpWidget(_region(reports, 60));

      await tester.pumpWidget(_region(reports, 60));
      await tester.pump();
      tester.element(find.byType(SheetFloorRegion)).markNeedsBuild();
      await tester.pump();

      expect(reports, [60]);
    });

    testWidgets('a height change reports once', (tester) async {
      final reports = <double>[];
      await tester.pumpWidget(_region(reports, 60));

      await tester.pumpWidget(_region(reports, 90));
      await tester.pump();

      expect(reports, [60, 90]);
    });

    testWidgets('a change within half a pixel reports nothing', (tester) async {
      final reports = <double>[];
      await tester.pumpWidget(_region(reports, 60));

      await tester.pumpWidget(_region(reports, 60.4));

      expect(reports, [60]);
    });

    testWidgets('a zero height is never reported', (tester) async {
      final reports = <double>[];

      await tester.pumpWidget(_region(reports, 0));
      await tester.pumpWidget(_region(reports, 60));
      await tester.pumpWidget(_region(reports, 0));

      expect(reports, [60]);
    });

    testWidgets('several layouts in one frame schedule a single report', (tester) async {
      final reports = <double>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SheetPageScope(
            snapSizes: const [1],
            onFloorMeasured: reports.add,
            child: _DoubleLayout(child: SheetFloorRegion(child: const SizedBox())),
          ),
        ),
      );

      expect(reports, [30]);
    });

    testWidgets('follows a callback swapped on the scope', (tester) async {
      final first = <double>[];
      final second = <double>[];
      await tester.pumpWidget(_region(first, 60));

      await tester.pumpWidget(_region(second, 90));

      expect(first, [60]);
      expect(second, [90]);
    });

    testWidgets('lays out without a scope and reports nothing', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SheetFloorRegion(child: SizedBox(height: 20)),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SheetStack floor reports', () {
    late SheetController controller;
    late List<double> reports;
    late ValueNotifier<double> textScale;

    setUp(() {
      controller = SheetController();
      reports = [];
      textScale = ValueNotifier(1);
    });

    tearDown(() {
      controller.dispose();
      textScale.dispose();
    });

    Widget stack() => MaterialApp(
      builder: (context, child) => ValueListenableBuilder(
        valueListenable: textScale,
        builder: (context, scale, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: SheetStack(
          entries: [
            SheetStackEntry(
              route: const _RoutePage(),
              page: SheetPage(
                pageKey: const _RoutePage().pageKey,
                initialSize: 0.3,
                snapSizes: const [0.3, 1],
                floor: const SheetFloor(defaultRegionHeight: 50, trailingInset: 20),
                header: (context) =>
                    SizedBox(height: MediaQuery.textScalerOf(context).scale(40), width: 300),
                builder: (context, scrollController) => ListView(
                  controller: scrollController,
                  children: [for (var index = 0; index < 40; index++) const SizedBox(height: 50)],
                ),
              ),
              controller: controller,
              onFloorMeasured: reports.add,
            ),
          ],
          style: const SheetNavigatorStyle(surfaceBuilder: _surface),
          onExitCompleted: (_) {},
          onVisualTopExtentChanged: (_) {},
        ),
      ),
    );

    testWidgets('drags, scrolls and rebuilds never report again', (tester) async {
      await tester.pumpWidget(stack());
      await tester.pumpAndSettle();
      expect(reports, [40]);

      await tester.pumpWidget(stack());
      await tester.dragFrom(const Offset(400, 590), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(reports, [40]);
    });

    testWidgets('a text scale change reports exactly once', (tester) async {
      await tester.pumpWidget(stack());
      await tester.pumpAndSettle();

      textScale.value = 2;
      await tester.pumpAndSettle();

      expect(reports, [40, 80]);
    });
  });
}

Widget _surface(BuildContext context, Widget card) => card;
