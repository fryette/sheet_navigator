# sheet_navigator

Declarative bottom-sheet stack navigator for Flutter, built on [smooth_sheets](https://pub.dev/packages/smooth_sheets).

Every level of the navigation stack is its own sheet. A push slides the new sheet up over the current one, which recedes (fades and scales) or travels down when it is taller. A pop slides the top sheet away and returns the previous one at the extent it was left at.

## When to use it

Use it when a screen is a persistent surface (a map, a canvas, a dashboard) and secondary content lives in sheets that stack on top of it: list, then details, then settings. It fits when you need:

- a back stack of sheets, each with its own snap points and remembered position;
- overlays (floating buttons, banners) that follow the top sheet as it moves;
- the host to know where the top sheet will rest, so it can frame other content against that area;
- motion that depends on how the two sheets relate (equal height, taller, expanded to expanded) and can be replaced by rules.

For a single modal sheet, or a sheet without a stack, `smooth_sheets` alone is enough.

## Install

```yaml
dependencies:
  sheet_navigator:
    git:
      url: https://github.com/fryette/sheet_navigator.git
      ref: v1.0.4

dependency_overrides:
  smooth_sheets:
    git:
      url: https://github.com/fryette/smooth_sheets.git
      ref: 940afd28bebba0ac40bff1ae82c0382f191fdc39
```

The package requires Dart `^3.13.0` and Flutter `>=3.47.4`, and depends on `smooth_sheets` 1.3.0.

The `smooth_sheets` override is recommended: it pins the fork commit this package's own `pubspec.yaml` overrides, which is what its test suite runs against. Without it the package resolves against the published `smooth_sheets` 1.3.0, and sheet behavior that depends on fork fixes may differ. Dependency overrides are not inherited from dependencies, so a consuming app has to repeat the override itself. Keep the `ref` in step with this package's `pubspec.yaml` when you upgrade.

```dart
import 'package:sheet_navigator/sheet_navigator.dart';
```

The library re-exports `SheetController`, `SheetMetrics`, `SheetOffset` and `SheetPhysics` from `smooth_sheets`. Import `package:smooth_sheets/smooth_sheets.dart` for anything else (for example `SheetKeyboardDismissBehavior`).

## Quick start

Both modes share the same routes, feature and style.

```dart
import 'package:flutter/material.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

sealed class AppRoute extends SheetRoute {
  const AppRoute();
}

final class ListRoute extends AppRoute {
  const ListRoute();
}

final class DetailsRoute extends AppRoute {
  const DetailsRoute(this.id);

  final int id;

  @override
  Object get pageKey => 'details_$id';
}

final class SettingsRoute extends AppRoute {
  const SettingsRoute();
}

class AppFeature with SheetFeature<AppRoute> {
  AppFeature({required this.open});

  final void Function(AppRoute route) open;

  @override
  bool handles(AppRoute route) => true;

  @override
  SheetPage page(
    BuildContext context,
    AppRoute route,
    double availableHeight,
    SheetController controller,
  ) {
    return switch (route) {
      ListRoute() => SheetPage(
        pageKey: route.pageKey,
        initialSize: 0.4,
        snapSizes: const [0.4, 0.9],
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            for (var id = 0; id < 20; id++)
              ListTile(title: Text('Item $id'), onTap: () => open(DetailsRoute(id))),
          ],
        ),
      ),
      DetailsRoute(:final id) => SheetPage(
        pageKey: route.pageKey,
        initialSize: 0.5,
        snapSizes: const [0.5, 0.9],
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            ListTile(title: Text('Item $id')),
            ListTile(title: const Text('Settings'), onTap: () => open(const SettingsRoute())),
            ListTile(
              title: const Text('Back'),
              onTap: () => SheetNavigatorScope.maybeOf(context)?.requestPop(),
            ),
          ],
        ),
      ),
      SettingsRoute() => SheetPage(
        pageKey: route.pageKey,
        initialSize: 0.3,
        snapSizes: const [0.3],
        builder: (context, scrollController) =>
            ListView(controller: scrollController, children: const [ListTile(title: Text('Settings'))]),
      ),
    };
  }
}

const style = SheetNavigatorStyle(surfaceBuilder: _surface);

Widget _surface(BuildContext context, Widget card) => Material(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  clipBehavior: Clip.antiAlias,
  child: card,
);
```

### Declarative: the host owns the stack

Pass the stack as a list and rebuild with a new list instance (not a mutated one) when it changes. The navigator diffs the page keys and animates the difference.

```dart
class DeclarativeDemo extends StatefulWidget {
  const DeclarativeDemo({super.key});

  @override
  State<DeclarativeDemo> createState() => _DeclarativeDemoState();
}

class _DeclarativeDemoState extends State<DeclarativeDemo> {
  var _stack = <AppRoute>[const ListRoute()];
  late final _features = [AppFeature(open: _push)];

  void _push(AppRoute route) => setState(() => _stack = [..._stack, route]);

  void _pop() {
    if (_stack.length > 1) setState(() => _stack = _stack.sublist(0, _stack.length - 1));
  }

  @override
  Widget build(BuildContext context) => SheetNavigator<AppRoute, AppFeature>(
    features: _features,
    stack: _stack,
    style: style,
    onPopRequested: _pop,
  );
}
```

### Controlled: a controller owns the stack

`SheetNavigator.controlled` takes a `SheetNavigatorController` and no `stack`, `onPopRequested` or `onRouteExited`.

```dart
class ControlledDemo extends StatefulWidget {
  const ControlledDemo({super.key});

  @override
  State<ControlledDemo> createState() => _ControlledDemoState();
}

class _ControlledDemoState extends State<ControlledDemo> {
  final _controller = SheetNavigatorController<AppRoute>(root: const ListRoute());
  late final _features = [AppFeature(open: _controller.push)];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetNavigator<AppRoute, AppFeature>.controlled(
    controller: _controller,
    features: _features,
    style: style,
  );
}
```

The navigator fills the space it is given and needs a bounded height, so put it in a `Stack` over your background content or in a `Scaffold` body. The controller is not disposed by the navigator.

## Concepts at a glance

| Concept | Role |
| --- | --- |
| `SheetRoute` | Immutable description of a stack entry. Identity is its `pageKey` (default `runtimeType`). |
| `SheetFeature` | Turns the routes it `handles` into `SheetPage`s; optionally contributes a scope, overlay layers and lifecycle hooks. |
| `SheetPage` | One sheet: key, initial size, snap sizes (fractions of the navigator height), content builder, optional header and floor. |
| `SheetNavigator` | The widget. Diffs the stack and drives the sheets, overlays and callbacks. |
| `SheetNavigatorController` | Imperative stack: `push`, `pop`, `replaceTop`, `popToRoot`, plus `stackChanges` and `returnedToRoot` streams. |
| `SheetNavigatorScope` | Inherited access for pages and layers: `requestPop`, `visualTopExtent`, `isTransitionActive`. |
| `SheetMover` | Moves the current page's sheet to a snap while keeping the resting viewport report in step. |
| `SheetTransitionFactory` | Picks a `SheetTransitionStrategy` per push, pop or replace from an ordered list of `SheetTransitionRule`s. |
| `SheetRestingViewport` | The area the top sheet leaves free once it rests, reported through `onRestingViewportChanged`. |
| `SheetFloor` | A lowest snap derived from the measured height of the page header. |
| `SheetNavigatorStyle` | Surface, handle, physics, keyboard behavior. |

## Guides

- [Architecture](doc/architecture.md): routes, features, pages, snap states, stack internals, push and pop flow.
- [Transitions](doc/transitions.md): rules, strategies, motion tokens, custom rules.
- [Viewport and overlays](doc/viewport-and-overlays.md): `SheetMover`, the resting viewport, following overlays, overlay layers.
- [Sheet floor](doc/floor.md): measured header floor.
- [Styling](doc/styling.md): `SheetNavigatorStyle`.
- [Testing](doc/testing.md): testing apps that use the package.

## Development

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```
