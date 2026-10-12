# Testing

The package's own suite (`test/`) shows the patterns below. Most of the library is plain Dart value logic and can be tested without a widget tree; the navigator itself is tested with `testWidgets`.

## Pure logic

These types need no widgets:

| Type | What to test |
| --- | --- |
| `SheetNavigatorController` | Stack operations, duplicate-key rules, `stackChanges` and `returnedToRoot` events. |
| `SheetSnapState.classify` | Extent to state mapping for a given snap list. |
| `SheetFloor`, `SheetFloorResolver` | `extentFor`, and the resolved snap sizes for a page. |
| `SheetStopGrid.resolve` | Snap fractions for given insets. |
| `SheetRestingViewport.resolve` / `restingExtentFor` | The viewport for a page and settled snap. |
| `SheetTransitionFactory.resolve` | Which strategy a context selects. |

```dart
test('push then pop emits both stacks', () async {
  final controller = SheetNavigatorController<AppRoute>(root: const ListRoute());
  addTearDown(controller.dispose);

  final emitted = expectLater(
    controller.stackChanges,
    emitsInOrder([
      [const ListRoute(), const SettingsRoute()],
      [const ListRoute()],
    ]),
  );

  controller.push(const SettingsRoute());
  controller.pop();

  await emitted;
});

test('classify treats the lowest of two snaps as mid', () {
  expect(SheetSnapState.classify(0.4, const [0.4, 0.9]), SheetSnapState.mid);
  expect(SheetSnapState.classify(0.9, const [0.4, 0.9]), SheetSnapState.expanded);
});
```

`SheetNavigatorController.notifyRouteExited` is what the navigator calls when a route has left the tree. Subclass the controller and override it to record exits in a widget test (the package's suite does this).

### Table-driven transition rules

`SheetTransitionContext` and `SheetTransitionSide` are plain constructible values, so rule selection can be checked as a table without animating anything:

```dart
test('a pop from expanded to expanded uses the top-to-top strategy', () {
  const snaps = [0.2, 0.5, 0.9];
  final context = SheetTransitionContext(
    operation: SheetTransitionOperation.pop,
    from: SheetTransitionSide(route: const SettingsRoute(), extent: 0.9, snapSizes: snaps),
    to: SheetTransitionSide(route: const ListRoute(), extent: 0.9, snapSizes: snaps),
    depthBefore: 2,
    depthAfter: 1,
    removedCount: 1,
    viewportHeight: 800,
  );

  expect(SheetTransitionFactory.standard.resolve(context), isA<TopToTopPopTransition>());
});
```

## Widget tests

### A test host

Pump the navigator inside a `MaterialApp` (it needs a `Directionality`, `MediaQuery` and, for most pages, a `Material` from the style). The default test surface is 800x600 logical pixels, so the navigator is 600 px tall and a snap of 0.5 is 300 px. A minimal host:

```dart
Widget host(SheetNavigatorController<AppRoute> controller, {SheetTransitionFactory? transitions}) =>
    MaterialApp(
      home: SheetNavigator<AppRoute, AppFeature>.controlled(
        controller: controller,
        features: [AppFeature(open: controller.push)],
        style: style,
        transitions: transitions ?? SheetTransitionFactory.standard,
      ),
    );

testWidgets('a push mounts the details page and a pop removes it', (tester) async {
  final controller = SheetNavigatorController<AppRoute>(root: const ListRoute());
  addTearDown(controller.dispose);
  await tester.pumpWidget(host(controller));

  controller.push(const DetailsRoute(1));
  await tester.pumpAndSettle();
  expect(find.text('Back'), findsOneWidget);

  controller.pop();
  await tester.pumpAndSettle();
  expect(find.text('Back'), findsNothing);
  expect(controller.stack, const [ListRoute()]);
});
```

For the declarative mode use a small `StatefulWidget` host that holds the stack and exposes `push`, `pop` and `replaceTop` methods through a `GlobalKey<State>`, and record `onRouteExited` calls in a list; the package tests assert that a route is reported exited only after its page has left the tree.

### Skipping or inspecting animation

- `await tester.pumpAndSettle()` runs a transition to the end.
- `await tester.pump(); await tester.pump(const Duration(milliseconds: 16));` advances to the first frames, to inspect mid-transition state.
- To make navigation instant in a test, pass a factory that falls back to `InstantSheetTransition`, or prepend a rule: `SheetTransitionFactory.standard.prepend(const [SheetTransitionRule(strategy: InstantSheetTransition())])`.
- Whether a transition is running: `SheetNavigatorScope.maybeOf(context)?.isTransitionActive.value`, with a `context` taken from `tester.element(...)` of a widget inside a page.

### Reaching the sheet

A feature receives each page's `SheetController` in `page(...)`. Keep it in your test feature to read or drive the sheet:

```dart
class RecordingFeature extends AppFeature {
  RecordingFeature({required super.open});

  final controllers = <Object, SheetController>{};

  @override
  SheetPage page(
    BuildContext context,
    AppRoute route,
    double availableHeight,
    SheetController controller,
  ) {
    controllers[route.pageKey] = controller;
    return super.page(context, route, availableHeight, controller);
  }
}
```

Then `controllers[const ListRoute().pageKey]!.extent` (the `SheetControllerExtent` extension) gives the current extent as a fraction of the viewport. Move the top sheet with `SheetMover.of(tester.element(find.text('Back'))).moveTo(0.9)` from inside a page, wrapping the call in `unawaited` and finishing with `pumpAndSettle`. Dragging with `tester.drag` works as for any `smooth_sheets` sheet; the extent settles on the nearest snap within `SheetSnapState.tolerance`.

### Callbacks and geometry

Collect values from `onTopFullyExpandedChanged`, `onSheetInteractingChanged`, `onVisualTopExtentChanged` and `onRestingViewportChanged` in lists and assert on them after settling. Examples worth copying from the suite:

- the resting viewport is reported once on first layout, not again for an unchanged rebuild, and again after the sheet settles on another snap;
- with `restingAvailableHeight` set, the reported `size.height` is that height and no value is emitted while the laid-out height animates;
- a navigator whose `TickerMode` is disabled stays silent and reports again when re-enabled;
- `moveTo` with a value that is not one of the snaps fails an assertion naming the page snap sizes.

### Overlays

`SheetFollowingOverlay` is independent of the navigator. Drive it with a `ValueNotifier<double?>`:

```dart
testWidgets('the overlay follows the extent up to the standard extent', (tester) async {
  final extent = ValueNotifier<double?>(0.2);
  addTearDown(extent.dispose);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: SheetFollowingOverlay(
            extent: extent,
            availableHeight: 600,
            standardExtent: 0.5,
            gap: 12,
            child: const SizedBox(key: Key('overlay'), width: 40, height: 40),
          ),
        ),
      ),
    ),
  );

  expect(tester.getBottomLeft(find.byKey(const Key('overlay'))).dy, 600 - (0.2 * 600 + 12));

  extent.value = 0.9;
  await tester.pump();

  expect(tester.getBottomLeft(find.byKey(const Key('overlay'))).dy, 600 - (0.5 * 600 + 12));
});
```

### Assertions that guard misuse

Debug builds assert on an empty stack, duplicate page keys, a controller combined with `stack`, `onPopRequested` or `onRouteExited`, and a `moveTo` value that is not a snap. Test these with `expect(..., throwsAssertionError)` or by checking `tester.takeException()` after the pump.
