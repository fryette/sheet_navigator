# Sheet floor

A sheet's lowest snap is normally a fixed fraction. A **floor** makes it track content instead: the lowest snap is the height of a header region (a handle, a title row, a search field) so the collapsed sheet always shows exactly that region, whatever the text scale or the header's content.

## SheetFloor

Attach a `SheetFloor` to a `SheetPage`:

```dart
SheetPage(
  pageKey: route.pageKey,
  initialSize: 0.5,
  snapSizes: const [0.5, 0.9],
  floor: const SheetFloor(defaultRegionHeight: 64, leadingHeight: 8, trailingInset: 16),
  header: (context) => const SizedBox(height: 56, child: Center(child: Text('Title'))),
  builder: (context, scrollController) => ListView(controller: scrollController),
);
```

| Parameter | Meaning |
| --- | --- |
| `defaultRegionHeight` | Required. Height of the region used until it has been measured, and the measurement the navigator assumes if the first one matches it. |
| `leadingHeight` | Fixed height above the region that the floor also covers (default 0). |
| `trailingInset` | Fixed height below the region that the floor also covers (default 0). |

`SheetFloor.extentFor(measuredRegionHeight:, availableHeight:)` returns `(leadingHeight + (measuredRegionHeight ?? defaultRegionHeight) + trailingInset) / availableHeight`. `SheetFloor.measurementTolerance` is 0.5 logical pixels. `SheetFloor` is a value type (`==` compares its three fields).

## The measured region

`SheetFloorRegion` is the widget that measures. It reports the height of its child after layout, via the nearest `SheetPageScope`:

- When a page has both a `floor` and a `header`, the navigator wraps the header in a `SheetFloorRegion` for you.
- To measure something else (for example a block at the top of the scrollable body), put a `SheetFloorRegion` around it and give the page a `floor` without a `header`.

Heights at or below 0, and changes within `measurementTolerance`, are ignored. A first measurement equal to `defaultRegionHeight` (within tolerance) is accepted without rebuilding. Any other measurement rebuilds the page with the new floor.

## How the floor changes the page

For every build the navigator resolves the page through a `SheetFloorResolver`:

1. `floorExtent = min(floor.extentFor(...), largest snap)`.
2. The snap sizes become `{floorExtent} + each snap raised to at least floorExtent`, de-duplicated and sorted. The floor is therefore always the lowest snap.
3. `initialSize` is raised to at least `floorExtent`.
4. When `availableHeight <= 0` the page is left as built.

The resolved page is what the stack uses, what `SheetPageScope.snapSizesOf(context)` and `SheetNavigatorScope.resolvedSnapSizesOf(pageKey)` return, and what feeds [`SheetSnapState`](architecture.md#snap-states-and-the-stop-grid) and the resting viewport. Results are cached until the floor, region height, available height or the page's snaps change.

## Re-snapping

When the resolved floor extent changes (text scale, region content, navigator height), a sheet resting on the old floor is moved to the new one so it keeps showing exactly the region:

- If the sheet rests at the previous floor, it goes to the new lowest snap.
- If it rests on any other snap, it is left alone.
- Otherwise (between snaps), it goes to the nearest snap.
- The move is animated for 200 ms when the region itself changed. When only the navigator height changed, or when the page has no confirmed snap yet, it is applied at once.
- It waits for any running transition to finish, is skipped while the user drags or scrolls the top sheet, and waits for a running `SheetMover` move.

## Limits

`SheetFloor` does not itself prevent snaps from overlapping: snaps below the floor collapse onto it, so a page with `snapSizes: [0.1, 0.5]` and a floor of 0.3 ends with `[0.3, 0.5]`.
