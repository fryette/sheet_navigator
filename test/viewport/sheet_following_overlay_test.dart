import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _height = 800.0;
const _standardExtent = 0.5;
const _gap = 12.0;
const _childKey = ValueKey('overlay_child');
const _viewport = Size(400, _height);

Widget _pump({
  required ValueNotifier<double?> extent,
  double? left,
  double? right,
  Widget child = const SizedBox(key: _childKey, width: 40, height: 40),
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox.fromSize(
      size: _viewport,
      child: SheetFollowingOverlay(
        extent: extent,
        availableHeight: _height,
        standardExtent: _standardExtent,
        gap: _gap,
        left: left,
        right: right,
        child: child,
      ),
    ),
  ),
);

Rect _viewportRect(WidgetTester tester) {
  final box = find.descendant(of: find.byType(SheetFollowingOverlay), matching: find.byType(Align));
  return tester.getRect(box);
}

void main() {
  late ValueNotifier<double?> extent;

  setUp(() => extent = ValueNotifier(null));

  tearDown(() => extent.dispose());

  testWidgets('sits bottom right above the standard extent when no extent is published', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(extent: extent));

    final viewport = _viewportRect(tester);
    final child = tester.getRect(find.byKey(_childKey));

    expect(child.right, viewport.right);
    expect(child.bottom, viewport.bottom - (_standardExtent * _height + _gap));
  });

  testWidgets('follows the published extent while it stays under the standard extent', (
    tester,
  ) async {
    extent.value = 0.2;
    await tester.pumpWidget(_pump(extent: extent));

    final viewport = _viewportRect(tester);
    expect(tester.getRect(find.byKey(_childKey)).bottom, viewport.bottom - (0.2 * _height + _gap));

    extent.value = 0.3;
    await tester.pump();

    expect(tester.getRect(find.byKey(_childKey)).bottom, viewport.bottom - (0.3 * _height + _gap));
  });

  testWidgets('stops rising at the standard extent when the sheet goes higher', (tester) async {
    extent.value = 0.9;
    await tester.pumpWidget(_pump(extent: extent));

    final viewport = _viewportRect(tester);

    expect(
      tester.getRect(find.byKey(_childKey)).bottom,
      viewport.bottom - (_standardExtent * _height + _gap),
    );
  });

  testWidgets('is excluded from semantics only while the sheet covers it', (tester) async {
    bool isExcluded() => tester
        .widget<ExcludeSemantics>(
          find.descendant(
            of: find.byType(SheetFollowingOverlay),
            matching: find.byType(ExcludeSemantics),
          ),
        )
        .excluding;

    extent.value = 0.3;
    await tester.pumpWidget(_pump(extent: extent));
    expect(isExcluded(), isFalse);

    extent.value = 0.9;
    await tester.pump();
    expect(isExcluded(), isTrue);

    extent.value = 0.5;
    await tester.pump();
    expect(isExcluded(), isFalse);
  });

  testWidgets('anchors to the left edge when a left offset is given', (tester) async {
    await tester.pumpWidget(_pump(extent: extent, left: 16));

    final viewport = _viewportRect(tester);
    final child = tester.getRect(find.byKey(_childKey));

    expect(child.left, viewport.left + 16);
    expect(child.bottom, viewport.bottom - (_standardExtent * _height + _gap));
  });

  testWidgets('anchors to the right edge by the given right offset', (tester) async {
    await tester.pumpWidget(_pump(extent: extent, right: 24));

    final viewport = _viewportRect(tester);

    expect(tester.getRect(find.byKey(_childKey)).right, viewport.right - 24);
  });

  testWidgets('prefers the left offset when both offsets are given', (tester) async {
    await tester.pumpWidget(_pump(extent: extent, left: 8, right: 30));

    final viewport = _viewportRect(tester);

    expect(tester.getRect(find.byKey(_childKey)).left, viewport.left + 8);
  });
}
