import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _height = 800.0;

class const _InsetsHost({
  required final double availableHeight,
  required final double pinnedExtent,
  required final double topInset,
  required final ValueChanged<SheetViewportInsetsValue> onInsetsChanged,
  final double? focusExtent,
  final double? floorExtent,
  final ValueChanged<EdgeInsets>? onRenderPaddingChanged,
  final bool isTickerEnabled = true,
  final bool isVisible = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: isTickerEnabled,
    child: Visibility(
      visible: isVisible,
      maintainState: true,
      child: SheetViewportInsets(
        availableHeight: availableHeight,
        pinnedExtent: pinnedExtent,
        topInset: topInset,
        focusExtent: focusExtent,
        floorExtent: floorExtent,
        onInsetsChanged: onInsetsChanged,
        onRenderPaddingChanged: onRenderPaddingChanged,
        child: const SizedBox(key: ValueKey('insets_child')),
      ),
    ),
  );
}

void main() {
  group('static insets', () {
    test('insetsFor pads the top by the inset plus the gap and the bottom by the pinned sheet', () {
      final insets = SheetViewportInsets.insetsFor(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 40,
      );

      expect(insets, const EdgeInsets.only(top: 40 + SheetViewportInsets.gap, bottom: 212));
    });

    test('renderPaddingFor pads the bottom by the floor sheet', () {
      final insets = SheetViewportInsets.renderPaddingFor(
        availableHeight: _height,
        floorExtent: 0.1,
        topInset: 24,
      );

      expect(insets, const EdgeInsets.only(top: 24 + SheetViewportInsets.gap, bottom: 92));
    });

    test('focusInsetsFor falls back to the pinned extent without a focus extent', () {
      final insets = SheetViewportInsets.focusInsetsFor(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
      );

      expect(insets.bottom, 0.25 * _height + SheetViewportInsets.gap);
    });

    test('focusInsetsFor uses a focus extent larger than the pinned extent', () {
      final insets = SheetViewportInsets.focusInsetsFor(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
        focusExtent: 0.5,
      );

      expect(insets.bottom, 0.5 * _height + SheetViewportInsets.gap);
    });

    test('focusInsetsFor never drops below the pinned extent', () {
      final insets = SheetViewportInsets.focusInsetsFor(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
        focusExtent: 0.1,
      );

      expect(insets.bottom, 0.25 * _height + SheetViewportInsets.gap);
    });
  });

  group('publishing', () {
    testWidgets('publishes padding and focus insets after the first frame', (tester) async {
      final values = <SheetViewportInsetsValue>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 40,
          focusExtent: 0.5,
          onInsetsChanged: values.add,
        ),
      );
      await tester.pump();

      expect(values, hasLength(1));
      expect(values.single.padding, const EdgeInsets.only(top: 52, bottom: 212));
      expect(values.single.focus, const EdgeInsets.only(top: 52, bottom: 412));
    });

    testWidgets('publishes the render padding from the floor extent when given', (tester) async {
      final paddings = <EdgeInsets>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 0,
          floorExtent: 0.1,
          onInsetsChanged: (_) {},
          onRenderPaddingChanged: paddings.add,
        ),
      );
      await tester.pump();

      expect(paddings, [const EdgeInsets.only(top: 12, bottom: 92)]);
    });

    testWidgets('publishes the render padding from the pinned extent without a floor', (
      tester,
    ) async {
      final paddings = <EdgeInsets>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 0,
          onInsetsChanged: (_) {},
          onRenderPaddingChanged: paddings.add,
        ),
      );
      await tester.pump();

      expect(paddings, [const EdgeInsets.only(top: 12, bottom: 212)]);
    });

    testWidgets('works without a render padding listener', (tester) async {
      final values = <SheetViewportInsetsValue>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 0,
          onInsetsChanged: values.add,
        ),
      );
      await tester.pump();

      expect(values, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('republishes when any input changes', (tester) async {
      final values = <SheetViewportInsetsValue>[];
      final paddings = <EdgeInsets>[];

      Widget host({
        double availableHeight = _height,
        double pinnedExtent = 0.25,
        double topInset = 0,
        double? focusExtent,
        double? floorExtent,
      }) => _InsetsHost(
        availableHeight: availableHeight,
        pinnedExtent: pinnedExtent,
        topInset: topInset,
        focusExtent: focusExtent,
        floorExtent: floorExtent,
        onInsetsChanged: values.add,
        onRenderPaddingChanged: paddings.add,
      );

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(availableHeight: 1000));
      await tester.pump();
      await tester.pumpWidget(host(availableHeight: 1000, pinnedExtent: 0.3));
      await tester.pump();
      await tester.pumpWidget(host(availableHeight: 1000, pinnedExtent: 0.3, topInset: 20));
      await tester.pump();
      await tester.pumpWidget(
        host(availableHeight: 1000, pinnedExtent: 0.3, topInset: 20, focusExtent: 0.6),
      );
      await tester.pump();
      await tester.pumpWidget(
        host(
          availableHeight: 1000,
          pinnedExtent: 0.3,
          topInset: 20,
          focusExtent: 0.6,
          floorExtent: 0.05,
        ),
      );
      await tester.pump();

      expect(values.last.padding, const EdgeInsets.only(top: 32, bottom: 312));
      expect(values.last.focus, const EdgeInsets.only(top: 32, bottom: 612));
      expect(paddings.last, const EdgeInsets.only(top: 32, bottom: 62));
      expect(values, hasLength(5));
      expect(paddings, hasLength(5));
    });

    testWidgets('does not republish unchanged insets when the parent rebuilds', (tester) async {
      final values = <SheetViewportInsetsValue>[];
      final paddings = <EdgeInsets>[];

      Widget host() => _InsetsHost(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
        onInsetsChanged: values.add,
        onRenderPaddingChanged: paddings.add,
      );

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host());
      await tester.pump();

      expect(values, hasLength(1));
      expect(paddings, hasLength(1));
    });
  });

  group('activity', () {
    testWidgets('does not publish while tickers are disabled', (tester) async {
      final values = <SheetViewportInsetsValue>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 0,
          isTickerEnabled: false,
          onInsetsChanged: values.add,
        ),
      );
      await tester.pump();

      expect(values, isEmpty);
    });

    testWidgets('does not publish while invisible', (tester) async {
      final values = <SheetViewportInsetsValue>[];

      await tester.pumpWidget(
        _InsetsHost(
          availableHeight: _height,
          pinnedExtent: 0.25,
          topInset: 0,
          isVisible: false,
          onInsetsChanged: values.add,
        ),
      );
      await tester.pump();

      expect(values, isEmpty);
    });

    testWidgets('republishes identical insets when it becomes active again', (tester) async {
      final values = <SheetViewportInsetsValue>[];
      final paddings = <EdgeInsets>[];

      Widget host({required bool isTickerEnabled}) => _InsetsHost(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
        isTickerEnabled: isTickerEnabled,
        onInsetsChanged: values.add,
        onRenderPaddingChanged: paddings.add,
      );

      await tester.pumpWidget(host(isTickerEnabled: true));
      await tester.pump();
      await tester.pumpWidget(host(isTickerEnabled: false));
      await tester.pump();
      expect(values, hasLength(1));

      await tester.pumpWidget(host(isTickerEnabled: true));
      await tester.pump();

      expect(values, hasLength(2));
      expect(paddings, hasLength(2));
      expect(values.last, values.first);
    });

    testWidgets('stays quiet while it remains active across dependency changes', (tester) async {
      final values = <SheetViewportInsetsValue>[];

      Widget host({required bool isVisible}) => _InsetsHost(
        availableHeight: _height,
        pinnedExtent: 0.25,
        topInset: 0,
        isVisible: isVisible,
        onInsetsChanged: values.add,
      );

      await tester.pumpWidget(host(isVisible: true));
      await tester.pump();
      await tester.pumpWidget(host(isVisible: false));
      await tester.pump();
      await tester.pumpWidget(host(isVisible: false));
      await tester.pump();

      expect(values, hasLength(1));
    });
  });
}
