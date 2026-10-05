import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);

final class const _KeyedRoute(final String id) extends SheetRoute {
  @override
  Object get pageKey => id;
}

Widget _surface(BuildContext context, Widget card) => card;

SheetStackEntry _entry(String id, SheetController controller) {
  final route = _KeyedRoute(id);
  return SheetStackEntry(
    route: route,
    page: SheetPage(
      pageKey: route.pageKey,
      initialSize: 0.5,
      snapSizes: const [0.5, 0.9],
      builder: (context, scrollController) => SizedBox.expand(key: ValueKey('content_$id')),
    ),
    controller: controller,
  );
}

Widget _host({
  required List<SheetStackEntry> entries,
  required ValueChanged<double?> onVisualTopExtentChanged,
  double height = 800,
}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      height: height,
      child: SheetStack(
        entries: entries,
        style: _style,
        onExitCompleted: (_) {},
        onVisualTopExtentChanged: onVisualTopExtentChanged,
      ),
    ),
  ),
);

void main() {
  testWidgets('a stack that starts empty mounts the first pushed entry without motion', (
    tester,
  ) async {
    final controller = SheetController();
    addTearDown(controller.dispose);
    final extents = <double?>[];

    await tester.pumpWidget(_host(entries: const [], onVisualTopExtentChanged: extents.add));
    expect(find.byKey(const ValueKey('content_a'), skipOffstage: false), findsNothing);

    await tester.pumpWidget(
      _host(entries: [_entry('a', controller)], onVisualTopExtentChanged: extents.add),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('content_a')), findsOneWidget);
    expect(extents.last, closeTo(0.5, 0.001));
  });

  testWidgets('reports no visual top extent while the viewport has no height', (tester) async {
    final controller = SheetController();
    addTearDown(controller.dispose);
    final extents = <double?>[];

    await tester.pumpWidget(
      _host(entries: [_entry('a', controller)], onVisualTopExtentChanged: extents.add, height: 0),
    );
    await tester.pumpAndSettle();

    expect(extents, isNotEmpty);
    expect(extents.last, isNull);
  });
}
