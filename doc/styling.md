# Styling

`SheetNavigatorStyle` is applied to every sheet in the stack.

```dart
const style = SheetNavigatorStyle(surfaceBuilder: _surface);

Widget _surface(BuildContext context, Widget card) => Material(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  clipBehavior: Clip.antiAlias,
  child: card,
);
```

| Parameter | Default | Effect |
| --- | --- | --- |
| `surfaceBuilder` | required | `Widget Function(BuildContext, Widget card)`. Wraps the sheet content with its background, shape and elevation. `card` is the page content (handle, header, body). |
| `handleBuilder` | none | Builds a drag handle, placed centred above the header with 8 logical pixels of top padding (`SheetPageContent.handleTopPadding`). |
| `physics` | `SnapBounceSheetPhysics` | A `SheetPhysics` replacing the default snap-and-bounce spring. |
| `keyboardDismissBehavior` | none | A `SheetKeyboardDismissBehavior` from `smooth_sheets`. When set, each sheet is wrapped in `SheetKeyboardDismissible`. |
| `isKeyboardPaddingEnabled` | `false` | Adds the keyboard's `viewInsets.bottom` as bottom padding inside each sheet. |
| `scrollConfiguration` | `SheetContentBounce` | A `SheetScrollConfiguration` replacing the default scroll hand-over between content and sheet. |

Notes:

- The surface is built inside the transition's opacity and scale, so it fades and scales with its content. The sheet is clipped to the navigator area.
- Sheets that are not active keep the `MediaQuery` insets they last had, so the keyboard only affects the top sheet.
- Style is per navigator. For per-page differences, vary what the page builds inside `SheetPage.builder` and `SheetPage.header`.

```dart
const style = SheetNavigatorStyle(
  surfaceBuilder: _surface,
  handleBuilder: _handle,
  isKeyboardPaddingEnabled: true,
  keyboardDismissBehavior: SheetKeyboardDismissBehavior.onDragDown(),
);

Widget _handle(BuildContext context) => Container(
  width: 36,
  height: 4,
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.outline,
    borderRadius: BorderRadius.circular(2),
  ),
);
```
