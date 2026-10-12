# Transitions

Every push, pop and replace is animated by a `SheetTransitionStrategy` chosen by a `SheetTransitionFactory`. Pass your own factory with `SheetNavigator(transitions: ...)`; the default is `SheetTransitionFactory.standard`.

## Vocabulary

In a transition two sheets move: the **upper** sheet and the **lower** sheet.

| Operation | Upper | Lower |
| --- | --- | --- |
| `push` | the new top (`to`) | the previous top (`from`) |
| `replace` | the new top (`to`) | the replaced top (`from`) |
| `pop` | the sheet leaving (`from`) | the sheet revealed (`to`) |

`SheetTransitionOperation` has the values `push`, `pop` and `replace`. In a pop that removes several sheets, `from` is the topmost one.

### SheetTransitionContext

Strategies and rules receive a `SheetTransitionContext`:

| Field | Meaning |
| --- | --- |
| `operation` | `SheetTransitionOperation`. |
| `from`, `to` | `SheetTransitionSide`s: `route`, `extent` (fraction of the viewport), `snapSizes`, and `snap`, the `SheetSnapState` of the extent. |
| `depthBefore`, `depthAfter` | Stack depth around the change. |
| `removedCount` | Number of routes removed. |
| `viewportHeight` | Navigator height in logical pixels. |
| `upper`, `lower` | The sides according to the table above. |
| `backgroundDelta` | `max(0, lower.extent - upper.extent)`: how much taller the lower sheet is. |
| `isBackgroundTravelling` | `backgroundDelta > 0`. |

Extents: on a push or replace, `from.extent` is where the old top currently is and `to.extent` is the new page's `initialSize`. On a pop, `from.extent` is where the leaving sheet currently is and `to.extent` is where the revealed sheet was left.

## Rules and the factory

```dart
SheetTransitionFactory({required List<SheetTransitionRule> rules, required SheetTransitionStrategy fallback})
```

`resolve(context)` returns the strategy of the first rule that matches, or `fallback`. `prepend(hostRules)` returns a new factory with your rules in front of the existing ones, which is the usual way to customize.

A `SheetTransitionRule` matches when every given condition holds. Omitted conditions match everything.

| Parameter | Condition |
| --- | --- |
| `strategy` | Required. Used when the rule matches. |
| `name` | Optional label. Not used for matching. |
| `operations` | `context.operation` is in the set. |
| `from` | `context.from.snap` is in the set. |
| `to` | `context.to.snap` is in the set. |
| `when` | A `SheetTransitionPredicate` (`bool Function(SheetTransitionContext)`) returns true. |

### The standard factory

Excerpt of the package source (it uses Dart dot shorthands such as `.push`):

```dart
SheetTransitionFactory(
  rules: [
    SheetTransitionRule(
      name: 'travel',
      operations: {.push, .pop},
      when: _isBackgroundTravelling,
      strategy: TravelSheetTransition(),
    ),
    SheetTransitionRule(
      name: 'topToTop',
      operations: {.pop},
      from: {.expanded},
      to: {.expanded},
      strategy: TopToTopPopTransition(),
    ),
  ],
  fallback: InPlaceSheetTransition(),
);
```

## Strategies

A strategy provides four things:

| Member | Purpose |
| --- | --- |
| `duration(context)` | Length of the sheet animation. |
| `layerSwitchDuration(context)` | Length of the cross-fade of overlay layers. Defaults to `sheetPopDuration` for a pop and `sheetPushDuration` otherwise. |
| `upper(context)` | `SheetMotion` for the upper sheet. |
| `lower(context)` | `SheetMotion` for the lower sheet. |

A `SheetMotion` has three `SheetMotionCurve`s (`double Function(double progress)`, progress 0 to 1 over the duration):

- `dy`: vertical offset as a fraction of the viewport height (0 means in place);
- `alpha`: opacity;
- `scale`: scale about the top centre.

`SheetMotion.still` keeps a sheet unchanged. `sheetMotionZero` and `sheetMotionOne` are constant curves.

| Strategy | Behavior |
| --- | --- |
| `InPlaceSheetTransition` | The upper sheet slides in (push, replace) or out (pop) by its own extent. The lower sheet stays in place: on push it fades out and scales down to `sheetInPlaceScale`; on pop it fades in and scales back. Durations are `sheetPushDuration` and `sheetPopDuration`. |
| `TravelSheetTransition` | Extends in-place. The lower sheet additionally travels down by `backgroundDelta` on push (and back up on pop), with a fade and a scale proportional to the delta. Duration scales with the delta: `sheetTravelDurationFor(delta)`. |
| `TopToTopPopTransition` | In-place, but the returning sheet fades in over the earlier `sheetTopToTopFadeIn` window, used when an expanded sheet is revealed from under an expanded one. |
| `InstantSheetTransition` | No motion: zero duration, zero layer switch duration, both sheets still. |

With the standard factory, a push or pop where the lower sheet is taller than the upper one travels; a pop from expanded to expanded fades the returning sheet in early; everything else is in place.

## Motion tokens

Exported from `sheet_motion_tokens.dart` so custom strategies can match the built-in feel:

| Token | Value |
| --- | --- |
| `sheetPushDuration`, `sheetPopDuration` | 320 ms, 380 ms |
| `sheetTravelReferenceDelta`, `sheetTravelReferenceDuration` | 0.47, 340 ms |
| `sheetTravelMinDuration`, `sheetTravelMaxDuration` | 240 ms, 440 ms |
| `sheetEnterCurve`, `sheetExitCurve` | `Easing.emphasizedDecelerate`, `Cubic(0.3333, 0, 0.6667, 0)` |
| `sheetEnterTranslate`, `sheetExitTranslate` | `Interval`s over the curves above (0.15 to 1.0 and 0.0 to 0.66) |
| `sheetInPlaceScale` | 0.969 |
| `sheetInPlacePushScaleWindow`, `sheetInPlacePopScaleWindow` | `Interval(0, 0.2)`, `Interval(0.6, 1.0)` |
| `sheetInPlaceFadeOut`, `sheetInPlaceFadeIn`, `sheetTopToTopFadeIn` | opacity windows |
| `sheetBackgroundScaleGain` | 0.1 |
| `sheetTravelTranslate`, `sheetTravelScaleWindow`, `sheetTravelFadeOut`, `sheetTravelFadeIn` | travel windows |
| `sheetTravelDurationFor(delta)` | `340 ms * delta / 0.47`, rounded and clamped to 240..440 ms |

## Adding a custom rule

### Skip animation for one case

Make pushes between sheets of the same height instant:

```dart
bool _isSameHeight(SheetTransitionContext context) =>
    context.backgroundDelta == 0 && context.from.extent == context.to.extent;

final transitions = SheetTransitionFactory.standard.prepend(const [
  SheetTransitionRule(
    name: 'sameHeightPush',
    operations: {SheetTransitionOperation.push},
    when: _isSameHeight,
    strategy: InstantSheetTransition(),
  ),
]);

// SheetNavigator(..., transitions: transitions)
```

Rules in `prepend` run before the standard ones, so this rule wins whenever it matches. `const` rules need a top-level or static function for `when`; a non-const factory can use closures.

### Write a strategy

A strategy that slides the upper sheet in over its full height and leaves the lower sheet untouched:

```dart
class SlideOnlyTransition extends SheetTransitionStrategy {
  const SlideOnlyTransition();

  @override
  Duration duration(SheetTransitionContext context) => const Duration(milliseconds: 250);

  @override
  SheetMotion upper(SheetTransitionContext context) => switch (context.operation) {
    SheetTransitionOperation.pop => SheetMotion(
      dy: (progress) => Curves.easeIn.transform(progress) * context.from.extent,
      alpha: sheetMotionOne,
      scale: sheetMotionOne,
    ),
    SheetTransitionOperation.push || SheetTransitionOperation.replace => SheetMotion(
      dy: (progress) => (1 - Curves.easeOut.transform(progress)) * context.to.extent,
      alpha: sheetMotionOne,
      scale: sheetMotionOne,
    ),
  };

  @override
  SheetMotion lower(SheetTransitionContext context) => SheetMotion.still;
}

final transitions = SheetTransitionFactory(
  rules: const [],
  fallback: const SlideOnlyTransition(),
);
```

Notes for strategy authors:

- `dy` is a fraction of the viewport, so an offset equal to the sheet's extent moves it fully off screen.
- Subclassing `InPlaceSheetTransition` and overriding only `lower`, `upper` or `returningAlpha` is often shorter (this is how `TravelSheetTransition` and `TopToTopPopTransition` are built).
- `duration` and `layerSwitchDuration` are independent; override both to keep overlay layers in step with a non-standard duration.
- A zero `duration` is not reported as an active transition (`SheetNavigatorScope.isTransitionActive` is not set to true for it).
