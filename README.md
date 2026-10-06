# sheet_navigator

Declarative bottom-sheet stack navigator for Flutter, built on [smooth_sheets](https://pub.dev/packages/smooth_sheets).

Every level of the stack is its own sheet. A push slides the new sheet up over the current one, which recedes (fades and scales) or travels down when it is taller. A pop slides the top sheet away and returns the previous one at the extent it was left at. Transitions are pluggable through `SheetTransitionFactory` rules.

## Install

```yaml
dependencies:
  sheet_navigator:
    git:
      url: https://github.com/fryette/sheet_navigator.git
      ref: v1.0.0

dependency_overrides:
  smooth_sheets:
    git:
      url: https://github.com/fryette/smooth_sheets.git
      ref: da90438a85c45ca2b51f39537b7e95b7a8d7c7e2
```

The `smooth_sheets` override is recommended: the fork fixes the sheet overrunning its top snap when content that does not overflow is dragged.

## Usage

Drive it declaratively from your own state with `SheetNavigator(stack: ..., onPopRequested: ...)`, or imperatively with `SheetNavigator.controlled` and a `SheetNavigatorController` (`push`, `pop`, `replaceTop`, `popToRoot`). Pages are described by `SheetFeature`s that turn a `SheetRoute` into a `SheetPage` with its snap sizes; the look is injected through `SheetNavigatorStyle`. Inside a page, move the sheet with `SheetMover.of(context).moveTo(snap)` rather than the `SheetController`: the navigator reports the resting viewport for that snap through `onRestingViewportChanged` as the move starts, so overlays can frame against where the sheet will rest. `SheetMover.controller(controller)` gives a plain mover for sheets outside a navigator.

## Development

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```
