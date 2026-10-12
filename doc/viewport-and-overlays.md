# Viewport and overlays

Content behind or beside the sheets (a map, a floating button, a banner) usually needs to know where the top sheet is, or where it is about to be. This guide covers the APIs for that:

- `SheetMover`: move a page's sheet to a snap in a way the navigator can observe;
- `SheetRestingViewport` and `onRestingViewportChanged`: where the top sheet will rest;
- `SheetViewportState` and `sheetLayerWrapper`: the same data as a wrapper around the sheets;
- `SheetOverlayLayer` and `SheetFollowingOverlay`: widgets that sit above or below the sheets and follow them.

## SheetMover

`SheetMover` is an interface with one method:

```dart
Future<void> moveTo(
  double snapExtent, {
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
});
```

Inside a page's `builder` or `header`, get the page's mover with `SheetMover.of(context)` (throws a `FlutterError` when there is none) or `SheetMover.maybeOf(context)`. Both resolve through a `SheetMoverScope` the navigator places around the page. Overlay layers are outside it.

```dart
TextButton(
  onPressed: () => SheetMover.of(context).moveTo(0.9),
  child: const Text('Expand'),
)
```

Behavior of the navigator's mover:

- `snapExtent` must be one of the page's `snapSizes` (within 0.005). Anything else fails an assertion in debug builds; in release builds it moves to the nearest snap.
- Prefer it over `SheetController.animateTo` for the top page. When a move starts on the top page, the navigator immediately reports the viewport the sheet will rest in through `onRestingViewportChanged`, before the animation runs, so dependent content can animate in parallel with the sheet. A `SheetController` move is only noticed once the sheet settles.
- The call completes immediately if the top sheet already rests on that snap, if the page is no longer mounted, or if the sheet has no client yet.
- Moving a covered page animates it without reporting anything.
- Starting a new move replaces the running plan. A drag cancels it.

`SheetMover.controller(controller)` returns a plain mover over a `SheetController` for a sheet that is not managed by a navigator. It animates with `SheetOffset.proportionalToViewport(snapExtent)` and does nothing when the controller has no client. `SheetMoverScope(mover:, child:)` provides a mover to a subtree if you want `SheetMover.of` to work there too.

## SheetRestingViewport

`SheetNavigator(onRestingViewportChanged: ...)` receives a `SheetRestingViewport` describing the area the top sheet leaves free once it rests:

| Field | Meaning |
| --- | --- |
| `restingExtent` | Fraction of the height the top sheet will occupy at rest. |
| `insets` | `EdgeInsets.only(top: topPage.backgroundTopInset + gap, bottom: restingExtent * size.height + gap)`. |
| `size` | `Size(width, resting height)` of the navigator. |
| `topPageKey` | Page key of the top page. |
| `pageKeys` | Page keys of the whole stack. |

`SheetRestingViewport.gap` is 12.0. The class is a value type: equal viewports compare equal, and the navigator only reports a viewport that differs from the last one reported.

### What "resting" means

The resting extent never goes above the page's resting snap, so expanding a sheet does not report a new viewport:

- `SheetRestingViewport.restingSnapFor(page)` is the largest snap below the page's largest snap, or the lowest snap when there is only one (`null` for an empty `snapSizes`).
- `SheetRestingViewport.restingExtentFor(page, settledSnap)` takes the snap the page last settled on (from `SheetViewportState.settledSnap`) or `initialSize` when none, and clamps it between the lowest snap and the resting snap.

Example with `snapSizes: [0.2, 0.5, 1.0]`: resting at 0.2 reports 0.2, at 0.5 reports 0.5, at 1.0 reports 0.5.

### When it is reported

- After the first layout, after a push or pop (the revealed page reports the snap it was left on), and after the top sheet settles on a different snap.
- Synchronously when `SheetMover.moveTo` starts a move on the top page.
- Reports are scheduled after the frame and deduplicated. Nothing is reported while the navigator is not active (`TickerMode` disabled or `Visibility` hidden); it reports again when reactivated. A callback added after the first layout receives the current value on the next frame.

### restingAvailableHeight

If the host is about to resize the navigator (for example a bar sliding in below it), pass the height it will settle at:

```dart
SheetNavigator<AppRoute, AppFeature>(
  features: features,
  stack: stack,
  style: style,
  onRestingViewportChanged: (viewport) => mapPadding.value = viewport.insets,
  restingAvailableHeight: barVisible ? fullHeight - barHeight : fullHeight,
)
```

The resting viewport is then resolved against that height, with the page rebuilt by its feature for that height, while the layout is still animating towards it. A reported `size.height` therefore equals `restingAvailableHeight`, and no intermediate viewports are emitted while the real height catches up. Differences under 0.01 pixels from the previously held resting height are ignored. When it is `null` the laid-out height is used.

## SheetViewportState and sheetLayerWrapper

`sheetLayerWrapper` wraps the sheet layer in your own widget:

```dart
typedef SheetLayerWrapper = Widget Function(
  BuildContext context,
  SheetViewportState viewport,
  Widget sheetLayer,
);
```

`SheetViewportState` holds `topPage`, `availableWidth`, `availableHeight` and `settledSnap` (a record `({Object pageKey, double extent})?`), and `restingExtent`, computed as above. The wrapper rebuilds whenever the settled snap changes, which makes it a place to apply padding or a transform that depends on the resting extent. The wrapper sits above the sheets only; overlay layers are siblings of it. Use `sheetLayerKey` to give the wrapped layer a key.

## Overlay layers

Layers are widgets drawn over or under the sheet layer, filling the navigator. They are declared on the navigator and filled by features.

```dart
SheetNavigator<AppRoute, AppFeature>(
  features: features,
  stack: stack,
  style: style,
  layers: const [SheetOverlayLayer(id: 'actions')],
)
```

`SheetOverlayLayer<R, F>` takes:

| Parameter | Meaning |
| --- | --- |
| `id` | Required `Object` passed back to the feature. |
| `key` | Optional `Key` for the layer slot. |
| `persistentBuilder` | Optional `SheetLayerBuilder<R, F>`: `(context, SheetLayerContext)`. Content that stays mounted across route changes, drawn below the per-route content. |

The per-route content comes from the top route's feature:

```dart
class AppFeature with SheetFeature<AppRoute> {
  // handles / page as before

  @override
  Widget? layer(BuildContext context, Object layerId, AppRoute route) => switch (layerId) {
    'actions' when route is ListRoute => LayoutBuilder(
      builder: (context, constraints) => SheetFollowingOverlay(
        extent: SheetNavigatorScope.maybeOf(context)!.visualTopExtent,
        availableHeight: constraints.maxHeight,
        standardExtent: 0.4,
        gap: 12,
        right: 16,
        child: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
      ),
    ),
    _ => null,
  };

  @override
  double? layerBottom(BuildContext context, Object layerId, AppRoute route) => null;
}
```

Details:

- The content for the old top route cross-fades into the new one (the fade out runs first, then the fade in), over the transition strategy's `layerSwitchDuration`. Each route's content is keyed by its `pageKey`.
- `SheetLayerContext` carries `topRoute`, `topFeature`, `topPage`, `visualTopExtent` (a `ValueListenable<double?>`), `availableWidth` and `availableHeight`.
- While any transition is active, the whole navigator absorbs pointer events.

### Covered versus following layers

Each layer is either drawn above the sheets (it floats over them and stays interactive) or covered by them (drawn below the sheet layer, non-interactive and excluded from semantics). The decision is made on every frame from the visual top extent:

- If `layerBottom` returns a value `bottom`, the layer is covered when the sheet's top edge is at or above that line: `viewportHeight * (1 - extent) <= bottom`. `bottom` is measured in logical pixels from the top of the navigator, so it is the y coordinate of the lowest point of the layer's content.
- If `layerBottom` returns `null` (or no extent is known), the layer is covered only when the top page's `initialSize` is already its largest snap.
- A covered layer is hidden during transitions but stays mounted.

### SheetFollowingOverlay

A bottom-anchored widget that rides on top of the sheet.

| Parameter | Meaning |
| --- | --- |
| `extent` | `ValueListenable<double?>`, usually `SheetNavigatorScope.visualTopExtent` or `SheetLayerContext.visualTopExtent`. |
| `availableHeight` | Navigator height. |
| `standardExtent` | The extent above which the overlay stops following: it rides on the sheet up to this extent, then stays put. |
| `gap` | Space between the sheet edge and the overlay. |
| `left`, `right` | Horizontal inset from that side. `left` wins when both are set; with neither, it is anchored bottom right with no inset. |
| `child` | The overlay content. |

Its bottom offset is `min(extent, standardExtent) * availableHeight + gap`. When the sheet rises past the overlay (`extent * availableHeight` is larger than the offset) the overlay is excluded from semantics. When `extent` is `null` it uses `standardExtent`. It builds an `Align`, so give it the full-size area a layer provides.

## Reading the top extent

Three equivalent ways to follow the live (visual) extent of the top sheet, including during transitions:

- `SheetNavigator(onVisualTopExtentChanged: ...)`;
- `SheetNavigatorScope.maybeOf(context)?.visualTopExtent` as a `ValueListenable<double?>` for widgets inside pages or layers;
- `SheetLayerContext.visualTopExtent` in layer builders.

The value is the highest visible sheet extent over all sheets, with receding and returning sheets weighted by their opacity. It is `null` until the navigator has a positive height.
