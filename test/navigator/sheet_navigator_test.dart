import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _style = SheetNavigatorStyle(surfaceBuilder: _surface);

final class const _RootRoute() extends SheetRoute;

final class const _ListRoute() extends SheetRoute;

final class const _DetailsRoute() extends SheetRoute;

final class const _KeyedRoute(final String id) extends SheetRoute {
  @override
  Object get pageKey => id;
}

Widget _surface(BuildContext context, Widget card) =>
    ColoredBox(color: const Color(0xFFFFFFFF), child: card);

Finder _pageOf(SheetRoute route) =>
    find.byKey(ValueKey('page_${route.pageKey}'), skipOffstage: false);

const _headerKey = ValueKey('test_header');
const _headerHeight = 48.0;

class _TestFeature({
  required final bool Function(SheetRoute route) matcher,
  required final List<String> log,
  final double initialSize = 0.5,
  final List<double> snapSizes = const [0.2, 0.5, 0.9],
  final bool hasHeader = false,
  final bool hasScrollableBody = false,
  final ValueChanged<SheetController>? onController,
  final void Function(SheetRoute route, double extent)? onSettled,
}) with SheetFeature<SheetRoute> {
  @override
  bool handles(SheetRoute route) => matcher(route);

  @override
  SheetPage page(
    BuildContext context,
    SheetRoute route,
    double availableHeight,
    SheetController controller,
  ) {
    onController?.call(controller);
    return SheetPage(
      pageKey: route.pageKey,
      initialSize: initialSize,
      snapSizes: snapSizes,
      header: hasHeader
          ? (context) =>
                const SizedBox(key: _headerKey, height: _headerHeight, width: double.infinity)
          : null,
      builder: (context, scrollController) => hasScrollableBody
          ? ListView(
              key: ValueKey('page_${route.pageKey}'),
              controller: scrollController,
              children: [
                for (var index = 0; index < 50; index++)
                  SizedBox(height: 60, child: Text('$index')),
              ],
            )
          : Builder(
              builder: (innerContext) => TextButton(
                key: ValueKey('page_${route.pageKey}'),
                onPressed: () => SheetNavigatorScope.maybeOf(innerContext)?.requestPop(),
                child: Text('${route.runtimeType}'),
              ),
            ),
    );
  }

  @override
  Widget? layer(BuildContext context, Object layerId, SheetRoute route) =>
      Text('layer $layerId ${route.runtimeType}');

  @override
  void onBecameTop(BuildContext context, SheetRoute route) => log.add('top ${route.runtimeType}');

  @override
  void onAvailableHeightChanged(BuildContext context, SheetRoute route) =>
      log.add('heightChanged ${route.runtimeType}');

  @override
  void onSettledAfterDrag(BuildContext context, SheetRoute route, double extent) {
    log.add('settledAfterDrag ${route.runtimeType}');
    onSettled?.call(route, extent);
  }
}

class _ScopedTripFeature({required super.matcher, required super.log}) extends _TestFeature {
  @override
  Widget scope(BuildContext context, Widget child) =>
      KeyedSubtree(key: const ValueKey('trip_scope'), child: child);
}

class _ExitSpyController extends SheetNavigatorController<SheetRoute> {
  final exited = <SheetRoute>[];

  new({super.root = const _RootRoute()});

  @override
  void notifyRouteExited(SheetRoute route) {
    exited.add(route);
    super.notifyRouteExited(route);
  }
}

class const _ParentSetStateHost({
  required final List<_TestFeature> features,
  required final VoidCallback onBuild,
}) extends StatefulWidget {
  @override
  State<_ParentSetStateHost> createState() => _ParentSetStateHostState();
}

class _ParentSetStateHostState() extends State<_ParentSetStateHost> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return SheetNavigator<SheetRoute, _TestFeature>(
      features: widget.features,
      stack: const [_RootRoute()],
      style: _style,
      onTopFullyExpandedChanged: (_) => setState(() {}),
    );
  }
}

class const _LateCallbackHost({
  required final List<_TestFeature> features,
  required final ValueChanged<bool> onValue,
  required final VoidCallback onBuild,
  super.key,
}) extends StatefulWidget {
  @override
  State<_LateCallbackHost> createState() => _LateCallbackHostState();
}

class _LateCallbackHostState() extends State<_LateCallbackHost> {
  bool isAttached = false;

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return SheetNavigator<SheetRoute, _TestFeature>(
      features: widget.features,
      stack: const [_RootRoute()],
      style: _style,
      onTopFullyExpandedChanged: isAttached
          ? (value) {
              widget.onValue(value);
              setState(() {});
            }
          : null,
    );
  }

  void attach() => setState(() => isAttached = true);

  void detach() => setState(() => isAttached = false);
}

class const _RemovableNavigatorHost({required final List<_TestFeature> features, super.key})
    extends StatefulWidget {
  @override
  State<_RemovableNavigatorHost> createState() => _RemovableNavigatorHostState();
}

class _RemovableNavigatorHostState() extends State<_RemovableNavigatorHost> {
  bool isNavigatorVisible = true;
  bool isInteracting = false;

  @override
  Widget build(BuildContext context) => isNavigatorVisible
      ? SheetNavigator<SheetRoute, _TestFeature>(
          features: widget.features,
          stack: const [_RootRoute()],
          style: _style,
          onSheetInteractingChanged: (value) => setState(() => isInteracting = value),
        )
      : const SizedBox();

  void removeNavigator() => setState(() => isNavigatorVisible = false);
}

class const _DeclarativeHost({
  required final List<_TestFeature> features,
  required final List<SheetRoute> initialStack,
  required final ValueChanged<SheetRoute> onRouteExited,
  final SheetTransitionFactory transitions = SheetTransitionFactory.standard,
  final SheetLayerWrapper? sheetLayerWrapper,
  final ValueChanged<bool>? onTopFullyExpandedChanged,
  final ValueChanged<bool>? onSheetInteractingChanged,
  final ValueChanged<double?>? onVisualTopExtentChanged,
  final ValueChanged<SheetRestingViewport>? onRestingViewportChanged,
  super.key,
}) extends StatefulWidget {
  @override
  State<_DeclarativeHost> createState() => _DeclarativeHostState();
}

class _DeclarativeHostState() extends State<_DeclarativeHost> {
  late List<SheetRoute> _stack = widget.initialStack;

  @override
  Widget build(BuildContext context) => SheetNavigator<SheetRoute, _TestFeature>(
    features: widget.features,
    stack: _stack,
    style: _style,
    layers: const [SheetOverlayLayer(id: 'chrome')],
    transitions: widget.transitions,
    sheetLayerWrapper: widget.sheetLayerWrapper,
    onPopRequested: pop,
    onRouteExited: widget.onRouteExited,
    onTopFullyExpandedChanged: widget.onTopFullyExpandedChanged,
    onSheetInteractingChanged: widget.onSheetInteractingChanged,
    onVisualTopExtentChanged: widget.onVisualTopExtentChanged,
    onRestingViewportChanged: widget.onRestingViewportChanged,
  );

  void push(SheetRoute route) => setState(() => _stack = [..._stack, route]);

  void pop() => setState(() => _stack = _stack.sublist(0, _stack.length - 1));

  void replaceTop(SheetRoute route) =>
      setState(() => _stack = [..._stack.sublist(0, _stack.length - 1), route]);

  void setStack(List<SheetRoute> stack) => setState(() => _stack = stack);

  void popToRoot() => setState(() => _stack = [_stack.first]);
}

void main() {
  late List<String> log;
  late List<SheetRoute> exited;

  setUp(() {
    log = [];
    exited = [];
  });

  _TestFeature rootFeature({
    double initialSize = 0.5,
    List<double>? snapSizes,
    bool hasHeader = false,
    bool hasScrollableBody = false,
    ValueChanged<SheetController>? onController,
    void Function(SheetRoute route, double extent)? onSettled,
  }) => _TestFeature(
    matcher: (route) => route is _RootRoute,
    log: log,
    initialSize: initialSize,
    snapSizes: snapSizes ?? const [0.2, 0.5, 0.9],
    hasHeader: hasHeader,
    hasScrollableBody: hasScrollableBody,
    onController: onController,
    onSettled: onSettled,
  );

  _TestFeature tripFeature() =>
      _TestFeature(matcher: (route) => route is _ListRoute || route is _DetailsRoute, log: log);

  Future<GlobalKey<_DeclarativeHostState>> pumpHost(
    WidgetTester tester, {
    List<_TestFeature>? features,
    List<SheetRoute> initialStack = const [_RootRoute()],
    SheetTransitionFactory transitions = SheetTransitionFactory.standard,
    SheetLayerWrapper? sheetLayerWrapper,
    ValueChanged<bool>? onTopFullyExpandedChanged,
    ValueChanged<bool>? onSheetInteractingChanged,
    ValueChanged<double?>? onVisualTopExtentChanged,
    ValueChanged<SheetRestingViewport>? onRestingViewportChanged,
    Widget Function(Widget host)? wrap,
  }) async {
    final hostKey = GlobalKey<_DeclarativeHostState>();
    final host = _DeclarativeHost(
          key: hostKey,
          features: features ?? [rootFeature(), tripFeature()],
          initialStack: initialStack,
          transitions: transitions,
          sheetLayerWrapper: sheetLayerWrapper,
          onTopFullyExpandedChanged: onTopFullyExpandedChanged,
          onSheetInteractingChanged: onSheetInteractingChanged,
          onVisualTopExtentChanged: onVisualTopExtentChanged,
          onRestingViewportChanged: onRestingViewportChanged,
          onRouteExited: (route) {
            expect(_pageOf(route), findsNothing);
            exited.add(route);
          },
        );
    await tester.pumpWidget(MaterialApp(home: wrap?.call(host) ?? host));
    await tester.pumpAndSettle();
    return hostKey;
  }

  group('declarative stack', () {
    testWidgets('a route popped while its feature still owns a lower route is reported exited', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      hostKey.currentState?.push(const _DetailsRoute());
      await tester.pumpAndSettle();

      hostKey.currentState?.pop();
      await tester.pumpAndSettle();

      expect(_pageOf(const _DetailsRoute()), findsNothing);
      expect(exited, [const _DetailsRoute()]);
    });

    testWidgets('a push mounts the new page on top and keeps the covered page mounted', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(_pageOf(const _ListRoute()), findsOneWidget);
      expect(_pageOf(const _RootRoute()), findsOneWidget);
      expect(find.text('layer chrome _ListRoute'), findsOneWidget);
      expect(find.text('layer chrome _RootRoute'), findsNothing);
    });

    testWidgets('the new top is told it became top exactly once on push and again on pop', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      hostKey.currentState?.pop();
      await tester.pumpAndSettle();

      expect(log, ['top _ListRoute', 'top _RootRoute']);
    });

    testWidgets('a popped route is reported exited once, only after its sheet has left the tree', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      hostKey.currentState?.pop();
      await tester.pump();

      expect(exited, isEmpty);
      expect(_pageOf(const _ListRoute()), findsOneWidget);

      await tester.pumpAndSettle();

      expect(exited, [const _ListRoute()]);
    });

    testWidgets('popping to root from depth 3 reports each removed route exited exactly once', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      hostKey.currentState?.push(const _DetailsRoute());
      await tester.pumpAndSettle();

      hostKey.currentState?.popToRoot();
      await tester.pumpAndSettle();

      expect(exited, unorderedEquals(const [_ListRoute(), _DetailsRoute()]));
      expect(exited, hasLength(2));
    });

    testWidgets('replacing the top swaps the page in place and reports the replaced route exited', (
      tester,
    ) async {
      final hostKey = await pumpHost(
        tester,
        features: [
          rootFeature(),
          _TestFeature(matcher: (route) => route is _ListRoute, log: log),
          _TestFeature(matcher: (route) => route is _DetailsRoute, log: log),
        ],
      );
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      hostKey.currentState?.replaceTop(const _DetailsRoute());
      await tester.pumpAndSettle();

      expect(_pageOf(const _DetailsRoute()), findsOneWidget);
      expect(_pageOf(const _ListRoute()), findsNothing);
      expect(exited, [const _ListRoute()]);
      expect(log.lastOrNull, 'top _DetailsRoute');
    });

    testWidgets('re-pushing a key while its pop is still exiting keeps the live controller', (
      tester,
    ) async {
      final controllers = <SheetController>[];
      final hostKey = await pumpHost(
        tester,
        features: [
          rootFeature(),
          _TestFeature(
            matcher: (route) => route is _ListRoute,
            log: log,
            onController: controllers.add,
          ),
        ],
      );
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      hostKey.currentState?.pop();
      await tester.pump(const Duration(milliseconds: 50));

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_pageOf(const _ListRoute()), findsOneWidget);
      expect(controllers.toSet(), hasLength(1));
      expect(controllers.first.hasClient, isTrue);
    });

    testWidgets('a page asks for a pop through the navigator scope', (tester) async {
      final hostKey = await pumpHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      await tester.tap(_pageOf(const _ListRoute()));
      await tester.pumpAndSettle();

      expect(_pageOf(const _ListRoute()), findsNothing);
      expect(exited, [const _ListRoute()]);
    });
  });

  group('transitions', () {
    bool isTransitionActive(WidgetTester tester) =>
        SheetNavigatorScope.maybeOf(tester.element(_pageOf(const _RootRoute())))
            ?.isTransitionActive
            .value ??
        false;

    testWidgets('the standard factory keeps a push animating after its first frame', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(isTransitionActive(tester), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a prepended host rule overrides the standard motion for the cells it matches', (
      tester,
    ) async {
      final hostKey = await pumpHost(
        tester,
        transitions: SheetTransitionFactory.standard.prepend(const [
          SheetTransitionRule(operations: {.push}, strategy: InstantSheetTransition()),
        ]),
      );

      hostKey.currentState?.push(const _ListRoute());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(isTransitionActive(tester), isFalse);
      expect(tester.takeException(), isNull);

      hostKey.currentState?.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(isTransitionActive(tester), isTrue);
      await tester.pumpAndSettle();
      expect(exited, [const _ListRoute()]);
    });
  });

  group('published geometry', () {
    testWidgets('the visual top extent follows the settled top sheet', (tester) async {
      await pumpHost(tester);

      final scope = SheetNavigatorScope.maybeOf(tester.element(_pageOf(const _RootRoute())));

      expect(scope?.visualTopExtent.value, closeTo(0.5, 0.001));
    });

    testWidgets('the sheet layer wrapper sees the settled snap of the top page', (tester) async {
      final settledSnaps = <SheetSettledSnap?>[];

      await pumpHost(
        tester,
        sheetLayerWrapper: (context, viewport, sheetLayer) {
          settledSnaps.add(viewport.settledSnap);
          return sheetLayer;
        },
      );

      expect(settledSnaps.lastOrNull, (pageKey: const _RootRoute().pageKey, extent: 0.5));
    });

    testWidgets('reports a top sheet resting at its own largest snap as fully expanded', (
      tester,
    ) async {
      final signals = <bool>[];

      await pumpHost(
        tester,
        features: [
          rootFeature(initialSize: 0.9, snapSizes: const [0.5, 0.9]),
          tripFeature(),
        ],
        onTopFullyExpandedChanged: signals.add,
      );

      expect(signals.lastOrNull, isTrue);
    });

    testWidgets('reports a top sheet resting below its largest snap as not fully expanded', (
      tester,
    ) async {
      final signals = <bool>[];

      await pumpHost(tester, onTopFullyExpandedChanged: signals.add);

      expect(signals.lastOrNull, isFalse);
    });
  });

  group('feature identity', () {
    testWidgets('a features list rebuilt on every build still reports exits at the normal time', (
      tester,
    ) async {
      var stack = const <SheetRoute>[_RootRoute()];
      late StateSetter setStack;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setStack = setState;
              return SheetNavigator<SheetRoute, _TestFeature>(
                features: [rootFeature(), tripFeature()],
                stack: stack,
                style: _style,
                layers: const [SheetOverlayLayer(id: 'chrome')],
                onRouteExited: exited.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      setStack(() => stack = const [_RootRoute(), _ListRoute()]);
      await tester.pumpAndSettle();

      setStack(() => stack = const [_RootRoute()]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(exited, [const _ListRoute()]);
    });
  });

  group('feature scope', () {
    testWidgets('a feature scope stays mounted until its routes have exited', (tester) async {
      final hostKey = await pumpHost(
        tester,
        features: [
          rootFeature(),
          _ScopedTripFeature(matcher: (route) => route is _ListRoute, log: log),
        ],
      );
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      hostKey.currentState?.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('trip_scope')), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('trip_scope')), findsNothing);
    });
  });

  group('controller exclusivity', () {
    SheetNavigator<SheetRoute, _TestFeature> build({
      List<SheetRoute> stack = const [],
      VoidCallback? onPopRequested,
      ValueChanged<SheetRoute>? onRouteExited,
    }) => SheetNavigator<SheetRoute, _TestFeature>(
      features: const [],
      stack: stack,
      style: _style,
      controller: SheetNavigatorController<SheetRoute>(root: const _RootRoute()),
      onPopRequested: onPopRequested,
      onRouteExited: onRouteExited,
    );

    testWidgets('a controller with a stack fails an assertion', (tester) async {
      await tester.pumpWidget(MaterialApp(home: build(stack: const [_RootRoute()])));

      expect(
        tester.takeException(),
        isA<AssertionError>().having((error) => '${error.message}', 'message', contains('stack')),
      );
    });

    test('a controller with onPopRequested fails an assertion', () {
      expect(() => build(onPopRequested: () {}), throwsA(isA<AssertionError>()));
    });

    test('a controller with onRouteExited fails an assertion', () {
      expect(() => build(onRouteExited: (_) {}), throwsA(isA<AssertionError>()));
    });

    test('a controller alone is accepted', () {
      expect(build, returnsNormally);
    });
  });

  group('stack validation', () {
    testWidgets('an empty uncontrolled stack fails an assertion naming the stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>(
            features: [_TestFeature(matcher: (_) => true, log: log)],
            stack: const [],
            style: _style,
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<AssertionError>().having((error) => '${error.message}', 'message', contains('stack')),
      );
    });

    testWidgets('a declarative stack with a repeated page key fails an assertion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>(
            features: [_TestFeature(matcher: (_) => true, log: log)],
            stack: const [_KeyedRoute('a'), _KeyedRoute('b'), _KeyedRoute('a')],
            style: _style,
          ),
        ),
      );

      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('parent rebuilds from callbacks', () {
    testWidgets('setState in onTopFullyExpandedChanged does not rebuild forever', (tester) async {
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: _ParentSetStateHost(
            features: [rootFeature(), tripFeature()],
            onBuild: () => builds++,
          ),
        ),
      );
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(builds, lessThan(5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('attaching onTopFullyExpandedChanged', () {
    testWidgets('a callback attached after an earlier one was removed receives the current value', (
      tester,
    ) async {
      final values = <bool>[];
      var builds = 0;
      final hostKey = GlobalKey<_LateCallbackHostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _LateCallbackHost(
            key: hostKey,
            features: [rootFeature(), tripFeature()],
            onValue: values.add,
            onBuild: () => builds++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      hostKey.currentState?.attach();
      await tester.pumpAndSettle();
      expect(values, [false]);
      hostKey.currentState?.detach();
      await tester.pumpAndSettle();
      builds = 0;

      hostKey.currentState?.attach();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(values, [false, false]);
      expect(builds, lessThan(6));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('onAvailableHeightChanged', () {
    testWidgets('the top page is told when the available height changes under it', (tester) async {
      addTearDown(tester.view.reset);
      final hostKey = await pumpHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      log.clear();

      final size = tester.view.physicalSize;
      tester.view.physicalSize = Size(size.width, size.height - 100 * tester.view.devicePixelRatio);
      await tester.pumpAndSettle();

      expect(log, ['heightChanged _ListRoute']);
    });

    testWidgets('a push at an unchanged height reports became-top only', (tester) async {
      final hostKey = await pumpHost(tester);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(log, ['top _ListRoute']);
    });
  });

  group('settled snap memory', () {
    final settledSnaps = <SheetSettledSnap?>[];

    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    Future<GlobalKey<_DeclarativeHostState>> pumpRecordingHost(
      WidgetTester tester,
    ) {
      settledSnaps.clear();
      return pumpHost(
        tester,
        sheetLayerWrapper: (context, viewport, sheetLayer) {
          settledSnaps.add(viewport.settledSnap);
          return sheetLayer;
        },
      );
    }

    Future<void> dragRootToLargestSnap(WidgetTester tester) async {
      await tester.dragFrom(
        Offset(400, viewportHeightOf(tester) - 10),
        Offset(0, -0.3 * viewportHeightOf(tester)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a revealed page publishes the snap it was left resting at', (
      tester,
    ) async {
      final hostKey = await pumpRecordingHost(tester);
      await dragRootToLargestSnap(tester);
      final rootSnap = settledSnaps.last;
      expect(rootSnap?.pageKey, const _RootRoute().pageKey);
      expect(rootSnap?.extent, isNot(0.5));

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      expect(settledSnaps.last?.pageKey, const _ListRoute().pageKey);

      hostKey.currentState?.pop();
      await tester.pumpAndSettle();

      expect(settledSnaps.last, rootSnap);
    });

    testWidgets(
      'the remembered snap is published as soon as the page is top again',
      (tester) async {
        final hostKey = await pumpRecordingHost(tester);
        await dragRootToLargestSnap(tester);
        final rootSnap = settledSnaps.last;
        hostKey.currentState?.push(const _ListRoute());
        await tester.pumpAndSettle();

        hostKey.currentState?.pop();
        await tester.pump();
        await tester.pump();

        expect(settledSnaps.last, rootSnap);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a page resting at a snap is confirmed when the transition ends',
      (tester) async {
        final hostKey = await pumpRecordingHost(tester);

        hostKey.currentState?.push(const _ListRoute());
        await tester.pumpAndSettle();
        hostKey.currentState?.pop();
        await tester.pumpAndSettle();

        expect(settledSnaps.last, (
          pageKey: const _RootRoute().pageKey,
          extent: 0.5,
        ));
      },
    );

    testWidgets('a removed route is forgotten when it returns to the stack', (
      tester,
    ) async {
      final hostKey = await pumpRecordingHost(tester);
      await dragRootToLargestSnap(tester);

      hostKey.currentState?.setStack(const [_ListRoute()]);
      await tester.pumpAndSettle();
      hostKey.currentState?.setStack(const [_RootRoute(), _ListRoute()]);
      await tester.pumpAndSettle();
      hostKey.currentState?.pop();
      await tester.pumpAndSettle();

      expect(settledSnaps.last, (
        pageKey: const _RootRoute().pageKey,
        extent: 0.5,
      ));
    });
  });

  group('resting viewport', () {
    final reports = <SheetRestingViewport>[];

    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    Future<GlobalKey<_DeclarativeHostState>> pumpReportingHost(
      WidgetTester tester, {
      Widget Function(Widget host)? wrap,
    }) {
      reports.clear();
      return pumpHost(
        tester,
        wrap: wrap,
        onRestingViewportChanged: reports.add,
      );
    }

    testWidgets('reports once when first laid out', (tester) async {
      await pumpReportingHost(tester);

      final height = viewportHeightOf(tester);
      expect(reports, hasLength(1));
      expect(reports.single.restingExtent, 0.5);
      expect(reports.single.insets, EdgeInsets.only(top: 12, bottom: 0.5 * height + 12));
      expect(reports.single.size.height, height);
      expect(reports.single.topPageKey, const _RootRoute().pageKey);
      expect(reports.single.pageKeys, [const _RootRoute().pageKey]);
    });

    testWidgets('does not report again for an unchanged rebuild', (tester) async {
      final hostKey = await pumpReportingHost(tester);

      hostKey.currentState?.setStack(hostKey.currentState!._stack.toList());
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));
    });

    testWidgets('reports the new resting extent when the sheet settles on another snap', (
      tester,
    ) async {
      await pumpReportingHost(tester);

      await tester.dragFrom(
        Offset(400, viewportHeightOf(tester) - 10),
        Offset(0, 0.25 * viewportHeightOf(tester)),
      );
      await tester.pumpAndSettle();

      expect(reports.map((report) => report.restingExtent), [0.5, 0.2]);
    });

    testWidgets('reports the stack when a page is pushed and popped', (tester) async {
      final hostKey = await pumpReportingHost(tester);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      expect(reports.last.topPageKey, const _ListRoute().pageKey);
      expect(reports.last.pageKeys, [const _RootRoute().pageKey, const _ListRoute().pageKey]);

      hostKey.currentState?.pop();
      await tester.pumpAndSettle();
      expect(reports.last.topPageKey, const _RootRoute().pageKey);
      expect(reports.last.pageKeys, [const _RootRoute().pageKey]);
    });

    testWidgets('reports the remembered snap of the page revealed by a pop', (tester) async {
      final hostKey = await pumpReportingHost(tester);
      await tester.dragFrom(
        Offset(400, viewportHeightOf(tester) - 10),
        Offset(0, 0.25 * viewportHeightOf(tester)),
      );
      await tester.pumpAndSettle();
      expect(reports.last.restingExtent, 0.2);

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      expect(reports.last.restingExtent, 0.5);

      hostKey.currentState?.pop();
      await tester.pumpAndSettle();

      expect(reports.last.topPageKey, const _RootRoute().pageKey);
      expect(reports.last.restingExtent, 0.2);
    });

    testWidgets('is silent while ticker mode is disabled and reports again on re-enable', (
      tester,
    ) async {
      var isEnabled = false;
      late StateSetter setHostState;
      await pumpReportingHost(
        tester,
        wrap: (host) => StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return TickerMode(enabled: isEnabled, child: host);
          },
        ),
      );
      expect(reports, isEmpty);

      setHostState(() => isEnabled = true);
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));

      setHostState(() => isEnabled = false);
      await tester.pumpAndSettle();
      setHostState(() => isEnabled = true);
      await tester.pumpAndSettle();

      expect(reports, hasLength(2));
      expect(reports.first, reports.last);
    });

    testWidgets('reports once a listener is attached later', (tester) async {
      final reportsLater = <SheetRestingViewport>[];
      Widget host({ValueChanged<SheetRestingViewport>? onChanged}) => MaterialApp(
        home: SheetNavigator<SheetRoute, _TestFeature>(
          features: [rootFeature()],
          stack: const [_RootRoute()],
          style: _style,
          onRestingViewportChanged: onChanged,
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(onChanged: reportsLater.add));
      await tester.pumpAndSettle();

      expect(reportsLater, hasLength(1));
    });

    testWidgets('the viewport state exposes the resting extent', (tester) async {
      final extents = <double?>[];
      await pumpHost(
        tester,
        sheetLayerWrapper: (context, viewport, sheetLayer) {
          extents.add(viewport.restingExtent);
          return sheetLayer;
        },
      );

      expect(extents.last, 0.5);
    });
  });

  group('planned move', () {
    final reports = <SheetRestingViewport>[];

    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    List<double> restingExtents() => reports.map((report) => report.restingExtent).toList();

    SheetMover moverOf(WidgetTester tester, SheetRoute route) =>
        SheetMover.of(tester.element(_pageOf(route)));

    Future<GlobalKey<_DeclarativeHostState>> pumpPlanningHost(
      WidgetTester tester, {
      ValueChanged<SheetController>? onController,
      bool hasHeader = false,
    }) {
      reports.clear();
      return pumpHost(
        tester,
        features: [
          rootFeature(onController: onController, hasHeader: hasHeader),
          tripFeature(),
        ],
        onRestingViewportChanged: reports.add,
      );
    }

    testWidgets('a page header and body find the same page mover', (tester) async {
      await pumpPlanningHost(tester, hasHeader: true);

      expect(
        SheetMover.of(tester.element(find.byKey(_headerKey))),
        same(moverOf(tester, const _RootRoute())),
      );
    });

    testWidgets('a page mover animates its own sheet to the extent', (tester) async {
      late SheetController controller;
      await pumpPlanningHost(tester, onController: (value) => controller = value);

      unawaited(moverOf(tester, const _RootRoute()).moveTo(0.2));
      await tester.pumpAndSettle();

      expect(controller.extent, closeTo(0.2, 0.005));
    });

    testWidgets(
      'reports the planned resting viewport synchronously, once, and nothing more when the sheet '
      'settles there',
      (tester) async {
        await pumpPlanningHost(tester);

        unawaited(moverOf(tester, const _RootRoute()).moveTo(0.2));

        expect(restingExtents(), [0.5, 0.2]);
        expect(
          reports.last.insets.bottom,
          0.2 * viewportHeightOf(tester) + SheetRestingViewport.gap,
        );

        await tester.pumpAndSettle();

        expect(restingExtents(), [0.5, 0.2]);
      },
    );

    testWidgets(
      'a move to the snap the sheet rests at reports nothing and leaves the sheet still',
      (tester) async {
        late SheetController controller;
        await pumpPlanningHost(tester, onController: (value) => controller = value);

        await moverOf(tester, const _RootRoute()).moveTo(0.5);

        expect(restingExtents(), [0.5]);
        expect(tester.hasRunningAnimations, isFalse);
        expect(controller.extent, closeTo(0.5, 0.005));
      },
    );

    testWidgets(
      'a move to the largest snap reports nothing, because the resting area stops at the resting '
      'snap',
      (tester) async {
        late SheetController controller;
        await pumpPlanningHost(tester, onController: (value) => controller = value);

        unawaited(moverOf(tester, const _RootRoute()).moveTo(0.9));
        await tester.pumpAndSettle();

        expect(restingExtents(), [0.5]);
        expect(controller.extent, closeTo(0.9, 0.005));
      },
    );

    testWidgets('an extent within tolerance of a snap plans that exact snap', (tester) async {
      await pumpPlanningHost(tester);

      unawaited(moverOf(tester, const _RootRoute()).moveTo(0.203));

      expect(restingExtents(), [0.5, 0.2]);
      await tester.pumpAndSettle();
    });

    testWidgets('a non-snap extent fails an assertion naming the page snap sizes', (tester) async {
      await pumpPlanningHost(tester);

      expect(
        () => moverOf(tester, const _RootRoute()).moveTo(0.33),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message,
            'message',
            contains('[0.2, 0.5, 0.9]'),
          ),
        ),
      );
    });

    testWidgets('moving a covered page reports nothing', (tester) async {
      final hostKey = await pumpPlanningHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      final reportCount = reports.length;

      unawaited(moverOf(tester, const _RootRoute()).moveTo(0.2));
      await tester.pumpAndSettle();

      expect(reports, hasLength(reportCount));
    });

    testWidgets('a mover kept after its page exited does nothing', (tester) async {
      final hostKey = await pumpPlanningHost(tester);
      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      final mover = moverOf(tester, const _ListRoute());
      hostKey.currentState?.pop();
      await tester.pumpAndSettle();
      final reportCount = reports.length;

      await mover.moveTo(0.2);

      expect(reports, hasLength(reportCount));
    });
  });

  group('onSettledAfterDrag', () {
    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    Offset sheetDragStartOf(WidgetTester tester) => Offset(400, viewportHeightOf(tester) - 10);

    testWidgets(
      'a drag that settles back on the same snap does not fire the drag-settled callback',
      (tester) async {
        await pumpHost(tester);
        final viewportHeight = viewportHeightOf(tester);

        await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.05 * viewportHeight));
        await tester.pumpAndSettle();

        expect(log, isNot(contains('settledAfterDrag _RootRoute')));
      },
    );

    testWidgets('a drag that settles on a different snap fires the drag-settled callback', (
      tester,
    ) async {
      await pumpHost(tester);
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));
      await tester.pumpAndSettle();

      expect(log, contains('settledAfterDrag _RootRoute'));
    });

    testWidgets(
      'a later drag that settles back on that same snap does not re-fire, as when the map was '
      'panned in between without changing the sheet stop point',
      (tester) async {
        await pumpHost(tester);
        final viewportHeight = viewportHeightOf(tester);

        await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));
        await tester.pumpAndSettle();
        expect(log.where((entry) => entry == 'settledAfterDrag _RootRoute'), hasLength(1));

        await tester.dragFrom(sheetDragStartOf(tester), Offset(0, 0.1 * viewportHeight));
        await tester.pumpAndSettle();

        expect(log.where((entry) => entry == 'settledAfterDrag _RootRoute'), hasLength(1));
      },
    );

    testWidgets('pushing a new page still frames it regardless of the last settled snap', (
      tester,
    ) async {
      final hostKey = await pumpHost(tester);
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.05 * viewportHeight));
      await tester.pumpAndSettle();

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(log, contains('top _ListRoute'));
      expect(log, isNot(contains('settledAfterDrag')));
    });

    testWidgets(
      'a push landing inside the deferred settle-fit window is not applied to the new top route',
      (tester) async {
        const step = Duration(milliseconds: 16);

        Future<int> settleFrameCountOf(WidgetTester tester) async {
          final probeLog = <String>[];
          await pumpHost(
            tester,
            features: [
              _TestFeature(matcher: (route) => route is _RootRoute, log: probeLog),
              _TestFeature(matcher: (route) => route is _ListRoute, log: probeLog),
            ],
          );
          final viewportHeight = viewportHeightOf(tester);
          await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));

          var frame = 0;
          while (probeLog.isEmpty) {
            await tester.pump(step);
            frame++;
          }
          await tester.pumpAndSettle();
          return frame;
        }

        final fireFrame = await settleFrameCountOf(tester);

        final hostKey = await pumpHost(tester);
        final viewportHeight = viewportHeightOf(tester);
        await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));

        for (var frame = 0; frame < fireFrame - 1; frame++) {
          await tester.pump(step);
        }
        expect(log, isEmpty, reason: 'the fit must not have fired yet at this point');

        hostKey.currentState?.push(const _ListRoute());
        await tester.pumpAndSettle();

        expect(log, isNot(contains('settledAfterDrag _RootRoute')));
        expect(log, isNot(contains('settledAfterDrag _ListRoute')));
      },
    );

    testWidgets(
      'with no push in the deferred settle-fit window, the fit still fires for the original route',
      (tester) async {
        late SheetController controller;
        await pumpHost(
          tester,
          features: [
            rootFeature(onController: (value) => controller = value),
            tripFeature(),
          ],
        );

        unawaited(
          controller.animateTo(
            const SheetOffset.proportionalToViewport(0.9),
            duration: const Duration(milliseconds: 100),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(log, contains('settledAfterDrag _RootRoute'));
      },
    );

    testWidgets(
      "a newly pushed page's very first settle to a different snap fires the drag-settled "
      'callback, seeded from its initial size rather than waiting for a prior settle',
      (tester) async {
        late SheetController pushedController;
        final hostKey = await pumpHost(
          tester,
          features: [
            rootFeature(),
            _TestFeature(
              matcher: (route) => route is _ListRoute,
              log: log,
              onController: (value) => pushedController = value,
            ),
          ],
        );

        hostKey.currentState?.push(const _ListRoute());
        await tester.pump();
        log.clear();

        unawaited(
          pushedController.animateTo(
            const SheetOffset.proportionalToViewport(0.9),
            duration: const Duration(milliseconds: 100),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(log, contains('settledAfterDrag _ListRoute'));
      },
    );
  });

  group('onSheetInteractingChanged', () {
    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    Offset sheetDragStartOf(WidgetTester tester) => Offset(400, viewportHeightOf(tester) - 10);

    testWidgets('a drag that settles on a different snap turns interaction on immediately '
        'and off once the sheet has settled', (tester) async {
      final signals = <bool>[];
      await pumpHost(tester, onSheetInteractingChanged: signals.add);
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));

      expect(signals, [true]);

      await tester.pumpAndSettle();

      expect(signals.last, isFalse);
    });

    testWidgets(
      'the extent delivered to onSettledAfterDrag is the exact snap sheet_navigator settled on',
      (tester) async {
        final settledExtents = <double>[];
        await pumpHost(
          tester,
          features: [
            rootFeature(onSettled: (route, extent) => settledExtents.add(extent)),
            tripFeature(),
          ],
        );
        final viewportHeight = viewportHeightOf(tester);

        await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.3 * viewportHeight));
        await tester.pumpAndSettle();

        expect(settledExtents, [closeTo(0.9, 0.001)]);
      },
    );

    testWidgets('a drag that settles back on the same snap still turns interaction off', (
      tester,
    ) async {
      final signals = <bool>[];
      await pumpHost(tester, onSheetInteractingChanged: signals.add);
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(sheetDragStartOf(tester), Offset(0, -0.05 * viewportHeight));
      await tester.pumpAndSettle();

      expect(signals, [true, false]);
    });

    testWidgets('removing the navigator mid-drag does not call back into a locked tree', (
      tester,
    ) async {
      final hostKey = GlobalKey<_RemovableNavigatorHostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _RemovableNavigatorHost(key: hostKey, features: [rootFeature(), tripFeature()]),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(sheetDragStartOf(tester));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(hostKey.currentState?.isInteracting, isTrue);

      hostKey.currentState?.removeNavigator();
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hostKey.currentState?.isInteracting, isFalse);
      await gesture.up();
    });

    testWidgets('removing a scrolling navigator reports the interaction as ended afterwards', (
      tester,
    ) async {
      final hostKey = GlobalKey<_RemovableNavigatorHostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _RemovableNavigatorHost(
            key: hostKey,
            features: [
              rootFeature(initialSize: 0.9, snapSizes: const [0.9], hasScrollableBody: true),
              tripFeature(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(_pageOf(const _RootRoute())));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(hostKey.currentState?.isInteracting, isTrue);

      hostKey.currentState?.removeNavigator();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hostKey.currentState?.isInteracting, isFalse);
      await gesture.up();
    });

    testWidgets('scrolling the sheet content turns interaction on and off with the gesture', (
      tester,
    ) async {
      final signals = <bool>[];
      await pumpHost(
        tester,
        features: [
          rootFeature(initialSize: 0.9, snapSizes: const [0.9], hasScrollableBody: true),
          tripFeature(),
        ],
        onSheetInteractingChanged: signals.add,
      );

      await tester.drag(_pageOf(const _RootRoute()), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(signals, [true, false]);
    });
  });

  group('header-originated snap changes', () {
    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    Offset headerDragStartOf(WidgetTester tester) => tester.getCenter(find.byKey(_headerKey));

    testWidgets('a header drag that settles on a different snap fires the drag-settled callback', (
      tester,
    ) async {
      await pumpHost(
        tester,
        features: [rootFeature(hasHeader: true, initialSize: 0.9), tripFeature()],
      );
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(headerDragStartOf(tester), Offset(0, 0.3 * viewportHeight));
      await tester.pumpAndSettle();

      expect(log.where((entry) => entry == 'settledAfterDrag _RootRoute'), hasLength(1));
    });

    testWidgets('a header drag that settles back on the same snap does not fire the callback', (
      tester,
    ) async {
      await pumpHost(
        tester,
        features: [rootFeature(hasHeader: true, initialSize: 0.9), tripFeature()],
      );
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(headerDragStartOf(tester), Offset(0, 0.05 * viewportHeight));
      await tester.pumpAndSettle();

      expect(log, isNot(contains('settledAfterDrag _RootRoute')));
    });

    testWidgets(
      'a header tap or accessibility expand/collapse action that settles on a different snap '
      'fires the drag-settled callback',
      (tester) async {
        late SheetController controller;
        await pumpHost(
          tester,
          features: [
            rootFeature(hasHeader: true, onController: (value) => controller = value),
            tripFeature(),
          ],
        );

        unawaited(
          controller.animateTo(
            const SheetOffset.proportionalToViewport(0.9),
            duration: const Duration(milliseconds: 10),
          ),
        );
        await tester.pumpAndSettle();

        expect(log.where((entry) => entry == 'settledAfterDrag _RootRoute'), hasLength(1));
      },
    );
  });

  group('navigation extent freezing', () {
    Future<List<double?>> collectSamples(
      WidgetTester tester,
      SheetRoute observedRoute,
      VoidCallback triggerTransition,
    ) async {
      final scope = SheetNavigatorScope.maybeOf(tester.element(_pageOf(observedRoute)));
      final samples = <double?>[];
      scope?.visualTopExtent.addListener(() => samples.add(scope.visualTopExtent.value));

      triggerTransition();
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      return samples;
    }

    testWidgets(
      'a push landing on the same extent as the current sheet publishes no intermediate values',
      (tester) async {
        final hostKey = await pumpHost(tester, features: [rootFeature(), tripFeature()]);

        final samples = await collectSamples(
          tester,
          const _RootRoute(),
          () => hostKey.currentState?.push(const _ListRoute()),
        );

        expect(samples, isEmpty);
      },
    );

    testWidgets('a push landing on a different extent still animates through intermediate values', (
      tester,
    ) async {
      final hostKey = await pumpHost(
        tester,
        features: [
          rootFeature(snapSizes: const [0.2, 0.5, 0.7, 0.9]),
          _TestFeature(
            matcher: (route) => route is _ListRoute,
            log: log,
            initialSize: 0.7,
            snapSizes: const [0.2, 0.5, 0.7, 0.9],
          ),
        ],
      );

      final samples = await collectSamples(
        tester,
        const _RootRoute(),
        () => hostKey.currentState?.push(const _ListRoute()),
      );

      expect(samples.toSet().length, greaterThan(1));
    });

    testWidgets(
      'a pop landing back on the same extent as the departing sheet publishes no intermediate '
      'values',
      (tester) async {
        final hostKey = await pumpHost(tester, features: [rootFeature(), tripFeature()]);
        hostKey.currentState?.push(const _ListRoute());
        await tester.pumpAndSettle();

        final samples = await collectSamples(
          tester,
          const _ListRoute(),
          () => hostKey.currentState?.pop(),
        );

        expect(samples, isEmpty);
      },
    );
  });

  group('onVisualTopExtentChanged', () {
    double viewportHeightOf(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    testWidgets('reports the resting extent of the top sheet on first build', (tester) async {
      final extents = <double?>[];

      await pumpHost(tester, onVisualTopExtentChanged: extents.add);

      expect(extents.lastOrNull, closeTo(0.5, 0.001));
    });

    testWidgets('reports a drag as it moves the top sheet', (tester) async {
      final extents = <double?>[];
      await pumpHost(tester, onVisualTopExtentChanged: extents.add);
      extents.clear();
      final viewportHeight = viewportHeightOf(tester);

      await tester.dragFrom(Offset(400, viewportHeight - 10), Offset(0, -0.3 * viewportHeight));
      await tester.pumpAndSettle();

      expect(extents, isNotEmpty);
      expect(extents.lastOrNull, closeTo(0.9, 0.001));
    });

    testWidgets('reports the extent of the new top on push and the revealed page on pop', (
      tester,
    ) async {
      final extents = <double?>[];
      final hostKey = await pumpHost(
        tester,
        features: [
          rootFeature(initialSize: 0.3, snapSizes: const [0.3]),
          tripFeature(),
        ],
        onVisualTopExtentChanged: extents.add,
      );
      expect(extents.lastOrNull, closeTo(0.3, 0.001));

      hostKey.currentState?.push(const _ListRoute());
      await tester.pumpAndSettle();
      expect(extents.lastOrNull, closeTo(0.5, 0.001));

      hostKey.currentState?.pop();
      await tester.pumpAndSettle();
      expect(extents.lastOrNull, closeTo(0.3, 0.001));
    });

    testWidgets('is forwarded by the controlled constructor', (tester) async {
      final controller = SheetNavigatorController<SheetRoute>(root: const _RootRoute());
      addTearDown(controller.dispose);
      final extents = <double?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>.controlled(
            controller: controller,
            features: [rootFeature(), tripFeature()],
            style: _style,
            onVisualTopExtentChanged: extents.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(extents.lastOrNull, closeTo(0.5, 0.001));
    });
  });

  group('rebase', () {
    const a = _KeyedRoute('a');
    const b = _KeyedRoute('b');
    const c = _KeyedRoute('c');
    const d = _KeyedRoute('d');
    const x = _KeyedRoute('x');
    const y = _KeyedRoute('y');
    const z = _KeyedRoute('z');

    Future<GlobalKey<_DeclarativeHostState>> pumpKeyed(
      WidgetTester tester,
      List<SheetRoute> stack,
    ) => pumpHost(
      tester,
      features: [
        for (final id in const ['a', 'b', 'c', 'd', 'x', 'y', 'z'])
          _TestFeature(matcher: (route) => route is _KeyedRoute && route.id == id, log: log),
      ],
      initialStack: stack,
    );

    testWidgets('replacing the tail of a deeper stack animates the swap then drops the rest', (
      tester,
    ) async {
      final hostKey = await pumpKeyed(tester, const [a, b, c, d]);

      hostKey.currentState?.setStack(const [a, x]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(_pageOf(d), findsOneWidget);
      expect(_pageOf(x), findsOneWidget);
      expect(exited, isEmpty);

      await tester.pumpAndSettle();

      expect(_pageOf(a), findsOneWidget);
      expect(_pageOf(x), findsOneWidget);
      expect(_pageOf(b), findsNothing);
      expect(_pageOf(c), findsNothing);
      expect(_pageOf(d), findsNothing);
      expect(exited, unorderedEquals(const [b, c, d]));
      expect(exited, hasLength(3));
    });

    testWidgets('a longer replacement lands on the new top with the intermediates mounted', (
      tester,
    ) async {
      final hostKey = await pumpKeyed(tester, const [a, b, c]);

      hostKey.currentState?.setStack(const [a, x, y, z]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final route in const [a, x, y, z]) {
        expect(_pageOf(route), findsOneWidget);
      }
      expect(_pageOf(b), findsNothing);
      expect(_pageOf(c), findsNothing);
      expect(exited, unorderedEquals(const [b, c]));
      expect(find.text('layer chrome _KeyedRoute'), findsOneWidget);
    });

    testWidgets('popping after a rebase returns through the mounted intermediates', (tester) async {
      final hostKey = await pumpKeyed(tester, const [a, b, c]);
      hostKey.currentState?.setStack(const [a, x, y, z]);
      await tester.pumpAndSettle();

      hostKey.currentState?.setStack(const [a, x, y]);
      await tester.pumpAndSettle();

      expect(_pageOf(y), findsOneWidget);
      expect(_pageOf(z), findsNothing);
      expect(exited, contains(z));
    });

    testWidgets('a stack that keeps its top settles without motion and without an error', (
      tester,
    ) async {
      final hostKey = await pumpKeyed(tester, const [a, b, c]);

      hostKey.currentState?.setStack(const [a, x, c]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_pageOf(x), findsOneWidget);
      expect(_pageOf(c), findsOneWidget);
      expect(_pageOf(b), findsNothing);
      expect(exited, [b]);
    });
  });

  group('controlled', () {
    testWidgets('follows the controller and hands pops and exits back to it', (tester) async {
      final controller = SheetNavigatorController<SheetRoute>(root: const _RootRoute());
      addTearDown(controller.dispose);
      final returnedToRoot = <void>[];
      final subscription = controller.returnedToRoot.listen(returnedToRoot.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>.controlled(
            controller: controller,
            features: [rootFeature(), tripFeature()],
            style: _style,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.push(const _ListRoute());
      await tester.pumpAndSettle();

      expect(_pageOf(const _ListRoute()), findsOneWidget);

      await tester.tap(_pageOf(const _ListRoute()));
      await tester.pumpAndSettle();

      expect(controller.depth, 1);
      expect(_pageOf(const _ListRoute()), findsNothing);
      expect(returnedToRoot, hasLength(1));
    });

    testWidgets('returns to the root when the popped route shares a feature with the root', (
      tester,
    ) async {
      final controller = SheetNavigatorController<SheetRoute>(root: const _KeyedRoute('a'));
      addTearDown(controller.dispose);
      final returnedToRoot = <void>[];
      final subscription = controller.returnedToRoot.listen(returnedToRoot.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>.controlled(
            controller: controller,
            features: [_TestFeature(matcher: (_) => true, log: log)],
            style: _style,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.push(const _KeyedRoute('b'));
      await tester.pumpAndSettle();

      controller.pop();
      await tester.pumpAndSettle();

      expect(returnedToRoot, hasLength(1));
    });

    testWidgets('returns to the root after popToRoot over routes sharing a feature', (
      tester,
    ) async {
      final controller = _ExitSpyController(root: const _KeyedRoute('a'));
      addTearDown(controller.dispose);
      final returnedToRoot = <void>[];
      final subscription = controller.returnedToRoot.listen(returnedToRoot.add);
      addTearDown(subscription.cancel);
      final shared = _TestFeature(matcher: (route) => route.pageKey != 'b', log: log);
      final other = _TestFeature(matcher: (route) => route.pageKey == 'b', log: log);

      await tester.pumpWidget(
        MaterialApp(
          home: SheetNavigator<SheetRoute, _TestFeature>.controlled(
            controller: controller,
            features: [shared, other],
            style: _style,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller
        ..push(const _KeyedRoute('b'))
        ..push(const _KeyedRoute('c'));
      await tester.pumpAndSettle();

      controller.popToRoot();
      await tester.pumpAndSettle();

      expect(controller.exited.map((route) => route.pageKey), unorderedEquals(['b', 'c']));
      expect(returnedToRoot, hasLength(1));
    });

    testWidgets(
      'a route popped and pushed back in the same frame is never reported exited and keeps '
      'its layer subtree',
      (tester) async {
        final controller = _ExitSpyController();
        addTearDown(controller.dispose);
        const route = _ListRoute();

        await tester.pumpWidget(
          MaterialApp(
            home: SheetNavigator<SheetRoute, _TestFeature>.controlled(
              controller: controller,
              features: [rootFeature(), tripFeature()],
              style: _style,
              exitFallbackTimeout: const Duration(milliseconds: 100),
              layers: const [SheetOverlayLayer(id: 'chrome')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.push(route);
        await tester.pumpAndSettle();
        final layerElement = tester.element(find.text('layer chrome _ListRoute'));

        controller.pop();
        controller.push(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(controller.exited, isEmpty);
        expect(tester.element(find.text('layer chrome _ListRoute')), same(layerElement));
        expect(_pageOf(route), findsOneWidget);
      },
    );
  });
}
