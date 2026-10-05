import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);
const _surfaceKey = ValueKey('sheet_surface');

final class const _RootRoute() extends SheetRoute;

final class const _ListRoute() extends SheetRoute;

final class const _DetailsRoute() extends SheetRoute;

Widget _surface(BuildContext context, Widget card) =>
    ColoredBox(key: _surfaceKey, color: const Color(0xFFFFFFFF), child: card);

Finder _pageOf(SheetRoute route) =>
    find.byKey(ValueKey('page_${route.pageKey}'), skipOffstage: false);

class _LayerHoldingTransition() extends InstantSheetTransition {
  @override
  Duration layerSwitchDuration(SheetTransitionContext context) => const Duration(seconds: 3);
}

class _LateLayerTransition() extends InstantSheetTransition {
  @override
  Duration layerSwitchDuration(SheetTransitionContext context) => const Duration(milliseconds: 400);
}

class _Feature({
  required final bool Function(SheetRoute route) matcher,
  final double initialSize = 0.5,
  final List<double> snapSizes = const [0.2, 0.5, 0.9],
  final double? layerBottomValue,
}) with SheetFeature<SheetRoute> {
  @override
  bool handles(SheetRoute route) => matcher(route);

  @override
  SheetPage page(
    BuildContext context,
    SheetRoute route,
    double availableHeight,
    SheetController controller,
  ) => SheetPage(
    pageKey: route.pageKey,
    initialSize: initialSize,
    snapSizes: snapSizes,
    builder: (context, scrollController) => TextButton(
      key: ValueKey('page_${route.pageKey}'),
      onPressed: () {},
      child: Text('${route.runtimeType}'),
    ),
  );

  @override
  Widget? layer(BuildContext context, Object layerId, SheetRoute route) =>
      Text('layer $layerId ${route.runtimeType}');

  @override
  double? layerBottom(BuildContext context, Object layerId, SheetRoute route) => layerBottomValue;
}

List<_Feature> _features({double? rootLayerBottom}) => [
  _Feature(matcher: (route) => route is _RootRoute, layerBottomValue: rootLayerBottom),
  _Feature(matcher: (route) => route is _ListRoute || route is _DetailsRoute),
];

class const _ControllerHost({
  required final SheetNavigatorController<SheetRoute> controller,
  required final List<SheetOverlayLayer<SheetRoute, _Feature>> layers,
  final List<_Feature>? features,
  final SheetTransitionFactory transitions = SheetTransitionFactory.standard,
  final Duration exitFallbackTimeout = const Duration(milliseconds: 600),
  final Key? sheetLayerKey,
  final ValueChanged<bool>? onSheetInteractingChanged,
  final ValueChanged<double?>? onVisualTopExtentChanged,
  super.key,
}) extends StatefulWidget {
  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState() extends State<_ControllerHost> {
  late SheetNavigatorController<SheetRoute> controller = widget.controller;

  @override
  Widget build(BuildContext context) => SheetNavigator<SheetRoute, _Feature>.controlled(
    controller: controller,
    features: widget.features ?? _features(),
    style: _style,
    layers: widget.layers,
    transitions: widget.transitions,
    exitFallbackTimeout: widget.exitFallbackTimeout,
    sheetLayerKey: widget.sheetLayerKey,
    onSheetInteractingChanged: widget.onSheetInteractingChanged,
    onVisualTopExtentChanged: widget.onVisualTopExtentChanged,
  );

  void swap(SheetNavigatorController<SheetRoute> next) => setState(() => controller = next);
}

SheetNavigatorController<SheetRoute> _controller() {
  final controller = SheetNavigatorController<SheetRoute>(root: const _RootRoute());
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('controller replacement', () {
    testWidgets('switching controllers rebuilds the stack from the new controller', (tester) async {
      final first = _controller()..push(const _ListRoute());
      final second = _controller();
      final hostKey = GlobalKey<_ControllerHostState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(key: hostKey, controller: first, layers: const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(_pageOf(const _ListRoute()), findsOneWidget);

      hostKey.currentState?.swap(second);
      await tester.pumpAndSettle();

      expect(_pageOf(const _ListRoute()), findsNothing);
      expect(_pageOf(const _RootRoute()), findsOneWidget);

      second.push(const _DetailsRoute());
      await tester.pumpAndSettle();
      expect(_pageOf(const _DetailsRoute()), findsOneWidget);

      first.push(const _ListRoute());
      await tester.pumpAndSettle();
      expect(_pageOf(const _ListRoute()), findsNothing);
    });
  });

  group('overlay layers', () {
    testWidgets('a persistent builder stays mounted under the switching layer content', (
      tester,
    ) async {
      final controller = _controller();
      final seenTopRoutes = <Type>[];
      final layers = [
        SheetOverlayLayer<SheetRoute, _Feature>(
          id: 'chrome',
          persistentBuilder: (context, layer) {
            seenTopRoutes.add(layer.topRoute.runtimeType);
            return Text('persistent ${layer.topRoute.runtimeType}');
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(controller: controller, layers: layers),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('persistent _RootRoute'), findsOneWidget);
      expect(find.text('layer chrome _RootRoute'), findsOneWidget);
      final persistentElement = tester.element(find.text('persistent _RootRoute'));

      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(find.text('persistent _ListRoute'), findsOneWidget);
      expect(find.text('layer chrome _ListRoute'), findsOneWidget);
      expect(find.text('layer chrome _RootRoute'), findsNothing);
      expect(seenTopRoutes, containsAll(const [_RootRoute, _ListRoute]));
      expect(persistentElement.mounted, isTrue);
    });

    testWidgets('a layer is covered once the sheet top reaches the feature layer bottom', (
      tester,
    ) async {
      final controller = _controller();
      final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            features: _features(rootLayerBottom: viewportHeight * 0.3),
            layers: const [SheetOverlayLayer(id: 'chrome', key: ValueKey('chrome_layer'))],
            sheetLayerKey: const ValueKey('sheet_layer'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      IgnorePointer layerPointer() => tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('layer chrome _RootRoute'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );

      expect(layerPointer().ignoring, isFalse);

      await tester.dragFrom(Offset(400, viewportHeight - 10), Offset(0, -0.4 * viewportHeight));
      await tester.pumpAndSettle();

      expect(layerPointer().ignoring, isTrue);
    });
  });

  group('sheet interaction', () {
    testWidgets('a stack change during a drag ends the interaction immediately', (tester) async {
      final controller = _controller();
      final signals = <bool>[];
      final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            layers: const [],
            onSheetInteractingChanged: signals.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(Offset(400, viewportHeight - 10));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(signals, [true]);

      controller.push(const _ListRoute());
      await tester.pump();

      expect(signals, [true, false]);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(signals.last, isFalse);
    });
  });

  group('published extent', () {
    testWidgets('an instant push onto a taller page reports the new extent from the build phase', (
      tester,
    ) async {
      final controller = _controller();
      final extents = <double?>[];
      final features = [
        _Feature(matcher: (route) => route is _RootRoute),
        _Feature(
          matcher: (route) => route is _ListRoute,
          initialSize: 0.8,
          snapSizes: const [0.3, 0.8],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            features: features,
            layers: const [],
            transitions: SheetTransitionFactory.standard.prepend(const [
              SheetTransitionRule(strategy: InstantSheetTransition()),
            ]),
            onVisualTopExtentChanged: extents.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(extents.last, closeTo(0.5, 0.001));

      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(extents.last, closeTo(0.8, 0.001));
      final viewportHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetTop = tester.getTopLeft(find.byKey(_surfaceKey).last).dy;
      expect((viewportHeight - sheetTop) / viewportHeight, closeTo(0.8, 0.001));
    });
  });

  group('exit completion', () {
    testWidgets('the fallback timeout completes an exit whose layer subtree is still held', (
      tester,
    ) async {
      final controller = _ExitRecorder();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            layers: const [SheetOverlayLayer(id: 'chrome')],
            transitions: SheetTransitionFactory.standard.prepend([
              SheetTransitionRule(strategy: _LayerHoldingTransition()),
            ]),
            exitFallbackTimeout: const Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      controller.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.exited, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.exited, [const _ListRoute()]);
      await tester.pumpAndSettle();
      expect(controller.exited, [const _ListRoute()]);
      expect(find.text('layer chrome _RootRoute'), findsOneWidget);
    });

    testWidgets('an exit that finishes with the layer subtree is reported once, after the frame', (
      tester,
    ) async {
      final controller = _ExitRecorder();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            layers: const [SheetOverlayLayer(id: 'chrome')],
            transitions: SheetTransitionFactory.standard.prepend([
              SheetTransitionRule(strategy: _LateLayerTransition()),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      controller.pop();
      await tester.pump();
      for (var step = 0; step < 15; step++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(controller.exited, isEmpty);

      for (var step = 0; step < 15; step++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(controller.exited, [const _ListRoute()]);
      expect(_pageOf(const _ListRoute()), findsNothing);
    });

    testWidgets('re-pushing a route while its feature siblings are still exiting keeps only the '
        'siblings pending', (tester) async {
      final controller = _ExitRecorder();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerHost(
            controller: controller,
            layers: const [SheetOverlayLayer(id: 'chrome')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller
        ..push(const _ListRoute())
        ..push(const _DetailsRoute());
      await tester.pumpAndSettle();

      controller.popToRoot();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_pageOf(const _ListRoute()), findsOneWidget);
      expect(_pageOf(const _DetailsRoute()), findsNothing);
      expect(controller.exited, [const _DetailsRoute()]);
    });
  });
}

class _ExitRecorder extends SheetNavigatorController<SheetRoute> {
  final exited = <SheetRoute>[];

  new() : super(root: const _RootRoute());

  @override
  void notifyRouteExited(SheetRoute route) {
    exited.add(route);
    super.notifyRouteExited(route);
  }
}
