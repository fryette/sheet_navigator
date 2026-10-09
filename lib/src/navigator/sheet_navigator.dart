import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/navigator/sheet_feature.dart';
import 'package:sheet_navigator/src/navigator/sheet_mover.dart';
import 'package:sheet_navigator/src/navigator/sheet_navigator_scope.dart';
import 'package:sheet_navigator/src/navigator/sheet_navigator_style.dart';
import 'package:sheet_navigator/src/navigator/sheet_overlay_layer.dart';
import 'package:sheet_navigator/src/navigator/sheet_viewport_state.dart';
import 'package:sheet_navigator/src/page/sheet_floor.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';
import 'package:sheet_navigator/src/route/sheet_navigator_controller.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';
import 'package:sheet_navigator/src/stack/sheet_controller_extent.dart';
import 'package:sheet_navigator/src/stack/sheet_stack.dart';
import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_factory.dart';
import 'package:sheet_navigator/src/viewport/sheet_resting_viewport.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetNavigator<R extends SheetRoute, F extends SheetFeature<R>>({
  required final List<F> features,
  required final List<R> stack,
  required final SheetNavigatorStyle style,
  final SheetNavigatorController<R>? controller,
  final List<SheetOverlayLayer<R, F>> layers = const [],
  final SheetTransitionFactory transitions = SheetTransitionFactory.standard,
  final SheetLayerWrapper? sheetLayerWrapper,
  final Key? sheetLayerKey,
  final VoidCallback? onPopRequested,
  final ValueChanged<R>? onRouteExited,
  final ValueChanged<bool>? onTopFullyExpandedChanged,
  final ValueChanged<bool>? onSheetInteractingChanged,
  final ValueChanged<double?>? onVisualTopExtentChanged,
  final ValueChanged<SheetRestingViewport>? onRestingViewportChanged,
  final double? restingAvailableHeight,
  final Duration exitFallbackTimeout = const Duration(milliseconds: 600),
  super.key,
}) extends StatefulWidget {
  this
    : assert(
        controller == null || (onPopRequested == null && onRouteExited == null),
        'A SheetNavigator with a controller takes no onPopRequested or onRouteExited.',
      );

  const new controlled({
    required SheetNavigatorController<R> controller,
    required List<F> features,
    required SheetNavigatorStyle style,
    List<SheetOverlayLayer<R, F>> layers = const [],
    SheetTransitionFactory transitions = SheetTransitionFactory.standard,
    SheetLayerWrapper? sheetLayerWrapper,
    Key? sheetLayerKey,
    ValueChanged<bool>? onTopFullyExpandedChanged,
    ValueChanged<bool>? onSheetInteractingChanged,
    ValueChanged<double?>? onVisualTopExtentChanged,
    ValueChanged<SheetRestingViewport>? onRestingViewportChanged,
    double? restingAvailableHeight,
    Duration exitFallbackTimeout = const Duration(milliseconds: 600),
    Key? key,
  }) : this(
         features: features,
         stack: const <Never>[],
         style: style,
         controller: controller,
         layers: layers,
         transitions: transitions,
         sheetLayerWrapper: sheetLayerWrapper,
         sheetLayerKey: sheetLayerKey,
         onTopFullyExpandedChanged: onTopFullyExpandedChanged,
         onSheetInteractingChanged: onSheetInteractingChanged,
         onVisualTopExtentChanged: onVisualTopExtentChanged,
         onRestingViewportChanged: onRestingViewportChanged,
         restingAvailableHeight: restingAvailableHeight,
         exitFallbackTimeout: exitFallbackTimeout,
         key: key,
       );

  @override
  State<SheetNavigator<R, F>> createState() => _SheetNavigatorState<R, F>();
}

const _fullyExpandedExtentTolerance = 0.0005;
const _settledSnapTolerance = 0.005;
const _floorResnapRestingTolerance = 0.0001;
const _settledSnapMaxFrameDelta = 0.001;
const _restingHeightTolerance = 0.01;
const _floorResnapDuration = Duration(milliseconds: 200);
const _floorInstantResnapDuration = Duration(milliseconds: 1);

typedef _FloorBasis = ({double extent, double regionHeight, double availableHeight});
typedef _FloorResnap = ({double fromExtent, bool isViewportOnly});

const _sequencedLayerCrossoverPoint = 0.45;
const _sequencedLayerIncomingOpacityCurve = Interval(_sequencedLayerCrossoverPoint, 1);
const _sequencedLayerOutgoingOpacityCurve = Interval(1 - _sequencedLayerCrossoverPoint, 1);

class _SheetNavigatorState<R extends SheetRoute, F extends SheetFeature<R>>()
    extends State<SheetNavigator<R, F>> {
  final _controllers = <Object, SheetController>{};
  final _routesByPageKey = <Object, R>{};
  final _pagesByPageKey = <Object, SheetPage>{};
  final _visualTopExtent = ValueNotifier<double?>(null);
  final _isTransitionActive = ValueNotifier<bool>(false);
  final _overlayContentKey = GlobalKey();
  final _pendingFeatureExits = <int, _PendingFeatureExit<R>>{};
  final _layerSwitcherGenerations = <Object, int>{};
  final _settledSnap = ValueNotifier<SheetSettledSnap?>(null);
  List<R> _stack = const [];
  List<R>? _stackBeforeLayerSwitch;
  StreamSubscription<List<R>>? _controllerSubscription;
  var _layerSwitchDuration = sheetPushDuration;
  var _topPageExpandedExtent = 1.0;
  Object? _topPageKey;
  double? _topPageInitialSize;
  List<double> _topPageSnapSizes = const [];
  final _lastSettledExtentByPage = <Object, double>{};
  final _confirmedSnapByPage = <Object, double>{};
  ValueSetter<double>? _currentSettledFit;
  var _isSettleCheckScheduled = false;
  bool? _lastPublishedTopFullyExpanded;
  var _isDragUnsettled = false;
  var _isContentScrolling = false;
  ({Object pageKey, double extent})? _pendingSettledFit;
  SheetPage? _restingTopPage;
  var _restingSize = Size.zero;
  var _restingPageKeys = const <Object>[];
  SheetRestingViewport? _lastReportedRestingViewport;
  var _isRestingReportScheduled = false;
  final _movers = <Object, SheetMover>{};
  final _measuredFloorHeights = <Object, double>{};
  final _floorBasisByPage = <Object, _FloorBasis>{};
  final _pendingFloorResnaps = <Object, _FloorResnap>{};
  var _isFloorResnapScheduled = false;
  final _floorResolvers = <Object, SheetFloorResolver>{};
  final _floorReporters = <Object, ValueChanged<double>>{};
  final _restingFloorResolver = SheetFloorResolver();
  _PlannedSnap? _plannedSnap;
  var _isActive = true;

  bool get _isSheetInteracting => _isDragUnsettled || _isContentScrolling;

  bool get _isTopPageRestingOnSnap {
    final extent = _controllers[_topPageKey]?.extent;
    if (extent == null) return false;

    return _topPageSnapSizes.any((snap) => (extent - snap).abs() <= _settledSnapTolerance);
  }

  double? get _settledTopPageExtent =>
      _isTransitionActive.value ? null : _controllers[_topPageKey]?.extent ?? _topPageInitialSize;

  SheetSettledSnap? get _restingSnap => switch (_plannedSnap) {
    final plan? => (pageKey: plan.pageKey, extent: plan.extent),
    null => _settledSnap.value,
  };

  @override
  void initState() {
    super.initState();
    assert(
      widget.controller == null || widget.stack.isEmpty,
      'A SheetNavigator with a controller takes no stack.',
    );
    _stack = widget.controller?.stack ?? widget.stack;
    assert(_stack.isNotEmpty, _emptyStackMessage);
    assert(_hasUniquePageKeys(_stack), _duplicatePageKeysMessage);
    _subscribeToController();
    _settledSnap.addListener(_scheduleRestingViewportReport);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (isActive && !_isActive) {
      _lastReportedRestingViewport = null;
      _scheduleRestingViewportReport();
    }
    _isActive = isActive;
  }

  @override
  Widget build(BuildContext context) => _FeatureScopes<R, F>(
    features: _orderedFeatures,
    visualTopExtent: _visualTopExtent,
    isTransitionActive: _isTransitionActive,
    requestPop: _requestPop,
    resolvedPage: _resolvedPageFor,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        final entries = <SheetStackEntry>[];
        for (final route in _stack) {
          _routesByPageKey[route.pageKey] = route;
          final isNewPage = !_controllers.containsKey(route.pageKey);
          final controller = _controllerFor(route.pageKey);
          final page = _resolveFloor(
            _featureFor(route).page(context, route, availableHeight, controller),
            availableHeight,
            _floorResolvers.putIfAbsent(route.pageKey, SheetFloorResolver.new),
          );
          if (isNewPage) _lastSettledExtentByPage[route.pageKey] = page.initialSize;
          _pagesByPageKey[route.pageKey] = page;
          _followFloor(route.pageKey, page, availableHeight);
          entries.add(
            SheetStackEntry(
              route: route,
              page: _withMoverScope(page, _moverFor(route.pageKey)),
              controller: controller,
              onFloorMeasured: page.floor == null ? null : _floorReporterFor(route.pageKey),
            ),
          );
        }
        final [..., topRoute] = _stack;
        final topFeatureIndex = _featureIndexFor(topRoute);
        final topFeature = widget.features[topFeatureIndex];
        final [..., SheetStackEntry(page: topPage)] = entries;
        _resolveLayerSwitchDuration(topRoute, topPage, availableHeight);
        final settledFallbackExtent = topPage.initialSize;
        final topPageExpandedExtent = topPage.snapSizes.isEmpty
            ? 1.0
            : topPage.snapSizes.reduce(math.max);
        _topPageExpandedExtent = topPageExpandedExtent;
        if (_plannedSnap?.pageKey != topRoute.pageKey) _plannedSnap = null;
        _topPageKey = topRoute.pageKey;
        _restoreRememberedSnap(topRoute.pageKey);
        _topPageInitialSize = topPage.initialSize;
        _topPageSnapSizes = topPage.snapSizes;
        final restingAvailableHeight = _heldRestingHeight(
          widget.restingAvailableHeight ?? availableHeight,
        );
        _restingTopPage = restingAvailableHeight == availableHeight
            ? topPage
            : _resolveFloor(
                topFeature.page(
                  context,
                  topRoute,
                  restingAvailableHeight,
                  _controllerFor(topRoute.pageKey),
                ),
                restingAvailableHeight,
                _restingFloorResolver,
              );
        _restingSize = Size(availableWidth, restingAvailableHeight);
        _restingPageKeys = [for (final route in _stack) route.pageKey];
        _scheduleRestingViewportReport();
        _publishTopSheetFullyExpanded(
          _isTopSheetFullyExpanded(_settledTopPageExtent, topPageExpandedExtent),
        );

        final sheetLayerChild = _SheetLayer<R, F>(
          topRouteKey: topRoute.pageKey,
          topFeature: topFeature,
          topRoute: topRoute,
          availableHeight: availableHeight,
          entries: entries,
          style: widget.style,
          transitions: widget.transitions,
          onExitCompleted: _handleSheetExitCompleted,
          onVisualTopExtentChanged: _publishVisualTopExtent,
          onTransitionActiveChanged: _publishTransitionActive,
          onSettledFitReady: (fit) => _currentSettledFit = fit,
          onSheetDraggingChanged: _handleSheetDraggingChanged,
          onSheetContentScrollingChanged: _handleSheetContentScrollingChanged,
        );
        final sheetLayer = ValueListenableBuilder(
          key: widget.sheetLayerKey,
          valueListenable: _settledSnap,
          builder: (context, settledSnap, _) => switch (widget.sheetLayerWrapper) {
            final wrapper? => wrapper(
              context,
              SheetViewportState(
                topPage: topPage,
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                settledSnap: settledSnap,
              ),
              sheetLayerChild,
            ),
            null => sheetLayerChild,
          },
        );
        final layerContext = SheetLayerContext<R, F>(
          topRoute: topRoute,
          topFeature: topFeature,
          topPage: topPage,
          visualTopExtent: _visualTopExtent,
          availableWidth: availableWidth,
          availableHeight: availableHeight,
        );

        return _OrderedOverlayLayers(
          key: _overlayContentKey,
          extent: _visualTopExtent,
          isTransitionActive: _isTransitionActive,
          viewportHeight: availableHeight,
          sheetLayer: sheetLayer,
          layers: [
            for (final layer in widget.layers)
              (
                key: layer.key,
                content: _OverlayLayerContent<R, F>(
                  layer: layer,
                  layerContext: layerContext,
                  switcherGeneration: _layerSwitcherGenerations[layer.id] ?? 0,
                  switchDuration: _layerSwitchDuration,
                  onDispose: () => _handleLayerSubtreeDisposed(topFeatureIndex, layer.id),
                ),
                bottom: topFeature.layerBottom(context, layer.id, topRoute),
              ),
          ],
          settledFallbackExtent: settledFallbackExtent,
          fullyExpandedExtent: topPageExpandedExtent,
        );
      },
    ),
  );

  @override
  void didUpdateWidget(covariant SheetNavigator<R, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onRestingViewportChanged == null && widget.onRestingViewportChanged != null) {
      _lastReportedRestingViewport = null;
    }
    if (oldWidget.onTopFullyExpandedChanged == null && widget.onTopFullyExpandedChanged != null) {
      _lastPublishedTopFullyExpanded = null;
    }
    if (widget.controller != oldWidget.controller) {
      _controllerSubscription?.cancel();
      _subscribeToController();
      _applyStack(widget.controller?.stack ?? widget.stack);
    } else if (widget.controller == null && !identical(oldWidget.stack, widget.stack)) {
      _applyStack(widget.stack);
    }
  }

  @override
  void dispose() {
    _controllerSubscription?.cancel();
    for (final pending in _pendingFeatureExits.values) {
      pending.fallbackTimer?.cancel();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _visualTopExtent.dispose();
    _settledSnap.removeListener(_scheduleRestingViewportReport);
    _settledSnap.dispose();
    _isTransitionActive.dispose();
    _reportInteractionEndedAfterFrame();
    super.dispose();
  }

  void _subscribeToController() => _controllerSubscription = widget.controller?.stackChanges.listen(
    (stack) => setState(() => _applyStack(stack)),
  );

  void _applyStack(List<R> stack) {
    final oldStack = _stack;
    _stack = stack;
    if (identical(oldStack, stack)) return;

    assert(stack.isNotEmpty, _emptyStackMessage);
    assert(_hasUniquePageKeys(stack), _duplicatePageKeysMessage);
    if (!_hasSamePageKeys(oldStack, stack)) _resetSheetInteracting();
    _stackBeforeLayerSwitch ??= oldStack;
    _dropLiveRoutesFromPendingExits(stack);

    final removedRoutes = [
      for (final route in oldStack)
        if (!stack.any((current) => current.pageKey == route.pageKey)) route,
    ];
    for (final route in removedRoutes) {
      _confirmedSnapByPage.remove(route.pageKey);
      _pendingFloorResnaps.remove(route.pageKey);
      _floorBasisByPage.remove(route.pageKey);
    }
    if (removedRoutes.isEmpty) return;

    final [..., oldTopRoute] = oldStack;
    final isOldTopRemoved = !stack.any((route) => route.pageKey == oldTopRoute.pageKey);

    final removedRoutesByFeature = <int, List<R>>{};
    for (final route in removedRoutes) {
      (removedRoutesByFeature[_featureIndexFor(route)] ??= []).add(route);
    }

    for (final MapEntry(key: featureIndex, value: featureRemovedRoutes)
        in removedRoutesByFeature.entries) {
      final isStillLiveElsewhere = stack.any((route) => _featureIndexFor(route) == featureIndex);
      final pending = _pendingFeatureExits.putIfAbsent(featureIndex, _PendingFeatureExit<R>.new);
      pending.pendingPageKeys.addAll(featureRemovedRoutes.map((route) => route.pageKey));
      pending.removedRoutes.addAll(featureRemovedRoutes);
      if (!isStillLiveElsewhere &&
          isOldTopRemoved &&
          _featureIndexFor(oldTopRoute) == featureIndex) {
        pending.pendingLayerIds.addAll(widget.layers.map((layer) => layer.id));
      }
      _scheduleExitFallback(featureIndex, pending);
    }
  }

  void _dropLiveRoutesFromPendingExits(List<R> stack) {
    final livePageKeys = {for (final route in stack) route.pageKey};
    for (final MapEntry<int, _PendingFeatureExit<R>>(key: featureIndex, value: pending) in [
      ..._pendingFeatureExits.entries,
    ]) {
      pending.pendingPageKeys.removeWhere(livePageKeys.contains);
      pending.removedRoutes.removeWhere((route) => livePageKeys.contains(route.pageKey));
      if (pending.removedRoutes.isNotEmpty || pending.pendingPageKeys.isNotEmpty) continue;

      pending.fallbackTimer?.cancel();
      pending.pendingLayerIds.clear();
      _pendingFeatureExits.remove(featureIndex);
    }
  }

  void _resolveLayerSwitchDuration(R topRoute, SheetPage topPage, double availableHeight) {
    final oldStack = _stackBeforeLayerSwitch;
    _stackBeforeLayerSwitch = null;
    if (oldStack == null) return;

    final oldTopRoute = oldStack.lastOrNull;
    final oldTopPage = _pagesByPageKey[oldTopRoute?.pageKey];
    final isStructural =
        oldStack.length != _stack.length || oldTopRoute?.pageKey != topRoute.pageKey;
    if (oldTopRoute == null || oldTopPage == null || !isStructural) return;

    // ignore: omit_local_variable_types
    final SheetTransitionOperation operation = switch (_stack.length - oldStack.length) {
      < 0 => .pop,
      0 => .replace,
      _ => .push,
    };
    final topExtent = operation == .pop
        ? _controllers[topRoute.pageKey]?.extent ?? topPage.initialSize
        : topPage.initialSize;
    final transition = SheetTransitionContext(
      operation: operation,
      from: SheetTransitionSide(
        route: oldTopRoute,
        extent: _controllers[oldTopRoute.pageKey]?.extent ?? oldTopPage.initialSize,
        snapSizes: oldTopPage.snapSizes,
      ),
      to: SheetTransitionSide(route: topRoute, extent: topExtent, snapSizes: topPage.snapSizes),
      depthBefore: oldStack.length,
      depthAfter: _stack.length,
      removedCount: oldStack.where((route) => !_stack.contains(route)).length,
      viewportHeight: availableHeight,
    );
    _layerSwitchDuration = widget.transitions.resolve(transition).layerSwitchDuration(transition);
  }

  int _featureIndexFor(R route) => widget.features.indexWhere((feature) => feature.handles(route));

  F _featureFor(R route) => widget.features[_featureIndexFor(route)];

  SheetController _controllerFor(Object pageKey) =>
      _controllers.putIfAbsent(pageKey, SheetController.new);

  SheetMover _moverFor(Object pageKey) =>
      _movers.putIfAbsent(pageKey, () => _PageSheetMover(pageKey, _moveTo));

  Future<void> _moveTo(
    Object pageKey,
    double snapExtent,
    Duration duration,
    Curve curve, {
    double restingTolerance = _settledSnapTolerance,
  }) {
    final controller = _controllers[pageKey];
    final page = _pagesByPageKey[pageKey];
    if (!mounted || controller == null || page == null || !controller.hasClient) {
      return Future.value();
    }

    assert(
      page.snapSizes.any((snap) => (snap - snapExtent).abs() <= _settledSnapTolerance),
      'SheetMover.moveTo($snapExtent) needs one of the page snap sizes ${page.snapSizes}.',
    );
    final snap = minBy(page.snapSizes, (snap) => (snap - snapExtent).abs()) ?? snapExtent;
    final offset = SheetOffset.proportionalToViewport(snap);
    if (pageKey != _topPageKey) {
      return controller.animateTo(offset, duration: duration, curve: curve);
    }

    final extent = controller.extent;
    final isResting =
        _plannedSnap == null && extent != null && (extent - snap).abs() <= restingTolerance;
    if (isResting) return Future.value();

    final plan = _PlannedSnap(pageKey, snap);
    _plannedSnap = plan;
    _reportRestingViewportNow();
    return controller
        .animateTo(offset, duration: duration, curve: curve)
        .whenComplete(() => _endPlannedMove(plan));
  }

  SheetPage _resolveFloor(SheetPage page, double availableHeight, SheetFloorResolver resolver) {
    final floor = page.floor;
    if (floor == null) return page;

    final resolution = resolver.resolve(
      page: page,
      floor: floor,
      measuredRegionHeight: _measuredFloorHeights[page.pageKey],
      availableHeight: availableHeight,
    );
    return SheetPage(
      pageKey: page.pageKey,
      initialSize: resolution.initialSize,
      snapSizes: resolution.snapSizes,
      builder: page.builder,
      header: page.header,
      pinnedExtent: page.pinnedExtent,
      backgroundTopInset: page.backgroundTopInset,
      focusExtent: page.focusExtent,
      floor: floor,
    );
  }

  ValueChanged<double> _floorReporterFor(Object pageKey) => _floorReporters.putIfAbsent(
    pageKey,
    () =>
        (height) => _handleFloorMeasured(pageKey, height),
  );

  void _handleFloorMeasured(Object pageKey, double height) {
    if (!mounted || height <= 0 || !_pagesByPageKey.containsKey(pageKey)) return;

    final previous = _measuredFloorHeights[pageKey];
    if (previous != null && (previous - height).abs() <= SheetFloor.measurementTolerance) return;

    final defaultHeight = _pagesByPageKey[pageKey]?.floor?.defaultRegionHeight;
    if (previous == null &&
        defaultHeight != null &&
        (defaultHeight - height).abs() <= SheetFloor.measurementTolerance) {
      _measuredFloorHeights[pageKey] = defaultHeight;
      return;
    }

    setState(() => _measuredFloorHeights[pageKey] = height);
  }

  SheetPage? _resolvedPageFor(Object pageKey) => _pagesByPageKey[pageKey];

  void _followFloor(Object pageKey, SheetPage page, double availableHeight) {
    final floor = page.floor;
    if (floor == null || page.snapSizes.isEmpty) return;

    final basis = (
      extent: page.snapSizes.first,
      regionHeight: _measuredFloorHeights[pageKey] ?? floor.defaultRegionHeight,
      availableHeight: availableHeight,
    );
    final previous = _floorBasisByPage[pageKey];
    _floorBasisByPage[pageKey] = basis;
    if (previous != null && previous.extent != basis.extent) {
      final existing = _pendingFloorResnaps[pageKey];
      _pendingFloorResnaps[pageKey] = (
        fromExtent: existing?.fromExtent ?? previous.extent,
        isViewportOnly:
            (existing?.isViewportOnly ?? true) &&
            previous.regionHeight == basis.regionHeight &&
            previous.availableHeight != basis.availableHeight,
      );
    }
    _scheduleFloorResnaps();
  }

  bool _isRestingAtFloor(Object pageKey, double floor) {
    final extent = _controllers[pageKey]?.extent;
    final reference = pageKey == _topPageKey ? _confirmedSnapByPage[pageKey] ?? extent : extent;
    return reference != null && (reference - floor).abs() <= _settledSnapTolerance;
  }

  void _scheduleFloorResnaps() {
    if (_pendingFloorResnaps.isEmpty || _isFloorResnapScheduled) return;

    _isFloorResnapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFloorResnapScheduled = false;
      if (!mounted || _isTransitionActive.value) return;

      for (final pageKey in _pendingFloorResnaps.keys.toList()) {
        _resnapToFloor(pageKey, _pendingFloorResnaps[pageKey]!);
      }
    });
  }

  void _resnapToFloor(Object pageKey, _FloorResnap resnap) {
    final page = _pagesByPageKey[pageKey];
    final controller = _controllers[pageKey];
    if (page == null) return;

    final isTop = pageKey == _topPageKey;
    if (isTop && _isSheetInteracting) {
      _pendingFloorResnaps.remove(pageKey);
      return;
    }

    final extent = controller?.extent;
    if (controller == null || !controller.hasClient || extent == null) return;
    if (isTop && (_plannedSnap?.isRunning ?? false)) return;

    _pendingFloorResnaps.remove(pageKey);
    final target = _isRestingAtFloor(pageKey, resnap.fromExtent)
        ? page.snapSizes.first
        : page.snapSizes.any((snap) => (extent - snap).abs() <= _settledSnapTolerance)
        ? null
        : minBy(page.snapSizes, (snap) => (snap - extent).abs());
    if (target == null) return;

    final isAnimated = !resnap.isViewportOnly && _confirmedSnapByPage.containsKey(pageKey);
    _confirmedSnapByPage[pageKey] = target;
    unawaited(
      _moveTo(
        pageKey,
        target,
        isAnimated ? _floorResnapDuration : _floorInstantResnapDuration,
        Curves.easeInOut,
        restingTolerance: _floorResnapRestingTolerance,
      ),
    );
  }

  void _endPlannedMove(_PlannedSnap plan) {
    if (!mounted || !identical(_plannedSnap, plan)) return;

    plan.isRunning = false;
    _publishSettledSnap();
    _scheduleFloorResnaps();
  }

  void _requestPop() {
    if (widget.controller case final controller?) {
      controller.pop();
    } else {
      widget.onPopRequested?.call();
    }
  }

  void _handleSheetExitCompleted(Object pageKey) {
    final isLive = _stack.any((route) => route.pageKey == pageKey);
    final route = isLive ? _routesByPageKey[pageKey] : _routesByPageKey.remove(pageKey);
    if (route == null) return;

    final featureIndex = _featureIndexFor(route);
    _pendingFeatureExits[featureIndex]?.pendingPageKeys.remove(pageKey);
    if (isLive) {
      if (_pendingFeatureExits[featureIndex] case final pending?) {
        pending.removedRoutes.removeWhere((removed) => removed.pageKey == pageKey);
        _tryCompleteExit(featureIndex, pending);
      }
      return;
    }

    _controllers.remove(pageKey)?.dispose();
    _movers.remove(pageKey);
    _measuredFloorHeights.remove(pageKey);
    _floorBasisByPage.remove(pageKey);
    _pendingFloorResnaps.remove(pageKey);
    _floorResolvers.remove(pageKey);
    _floorReporters.remove(pageKey);
    _pagesByPageKey.remove(pageKey);
    _lastSettledExtentByPage.remove(pageKey);
    _confirmedSnapByPage.remove(pageKey);
    if (_pendingFeatureExits[featureIndex] case final pending?) {
      _tryCompleteExit(featureIndex, pending);
    }
  }

  void _handleLayerSubtreeDisposed(int featureIndex, Object layerId) {
    final pending = _pendingFeatureExits[featureIndex];
    if (pending == null || !pending.pendingLayerIds.remove(layerId)) return;

    _tryCompleteExit(featureIndex, pending);
  }

  void _tryCompleteExit(int featureIndex, _PendingFeatureExit<R> pending) {
    if (!pending.isSettled) return;

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyExitCompleted(featureIndex, pending),
      );
    } else {
      _applyExitCompleted(featureIndex, pending);
    }
  }

  void _applyExitCompleted(
    int featureIndex,
    _PendingFeatureExit<R> pending, {
    Set<Object> resetLayerIds = const {},
  }) {
    if (!mounted || _pendingFeatureExits[featureIndex] != pending) return;
    pending.fallbackTimer?.cancel();
    setState(() {
      _pendingFeatureExits.remove(featureIndex);
      for (final layerId in resetLayerIds) {
        _layerSwitcherGenerations[layerId] = (_layerSwitcherGenerations[layerId] ?? 0) + 1;
      }
    });
    for (final route in pending.removedRoutes) {
      _notifyRouteExited(route);
    }
  }

  void _notifyRouteExited(R route) {
    if (widget.controller case final controller?) {
      controller.notifyRouteExited(route);
    } else {
      widget.onRouteExited?.call(route);
    }
  }

  void _scheduleExitFallback(int featureIndex, _PendingFeatureExit<R> pending) {
    pending.fallbackTimer?.cancel();
    final fallbackDelay = widget.exitFallbackTimeout * timeDilation;
    pending.fallbackTimer = Timer(fallbackDelay, () {
      if (!mounted || _pendingFeatureExits[featureIndex] != pending) return;

      final resetLayerIds = {...pending.pendingLayerIds};
      pending.pendingPageKeys.clear();
      pending.pendingLayerIds.clear();
      _applyExitCompleted(featureIndex, pending, resetLayerIds: resetLayerIds);
    });
  }

  List<F> get _orderedFeatures {
    final orderedFeatureIndexes = <int>[];
    for (final route in _stack) {
      final featureIndex = _featureIndexFor(route);
      if (!orderedFeatureIndexes.contains(featureIndex)) orderedFeatureIndexes.add(featureIndex);
    }
    for (final featureIndex in _pendingFeatureExits.keys) {
      if (!orderedFeatureIndexes.contains(featureIndex)) orderedFeatureIndexes.add(featureIndex);
    }

    return [for (final featureIndex in orderedFeatureIndexes) widget.features[featureIndex]];
  }

  void _publishVisualTopExtent(double? value) {
    if (_visualTopExtent.value == value) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishVisualTopExtent(value);
      });
    } else {
      _visualTopExtent.value = value;
      widget.onVisualTopExtentChanged?.call(value);
      _publishSettledSnap();
      _publishTopSheetFullyExpanded(
        _isTopSheetFullyExpanded(_settledTopPageExtent, _topPageExpandedExtent),
      );
    }
  }

  double _heldRestingHeight(double height) {
    final held = _restingSize.height;
    return (held - height).abs() < _restingHeightTolerance ? held : height;
  }

  void _scheduleRestingViewportReport() {
    if (_isRestingReportScheduled || widget.onRestingViewportChanged == null) return;

    _isRestingReportScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _reportRestingViewport())
      ..ensureVisualUpdate();
  }

  void _reportRestingViewport() {
    _isRestingReportScheduled = false;
    _reportRestingViewportNow();
  }

  void _reportRestingViewportNow() {
    final topPage = _restingTopPage;
    final onChanged = widget.onRestingViewportChanged;
    if (!mounted || !_isActive || topPage == null || onChanged == null) return;

    final viewport = SheetRestingViewport.resolve(
      topPage: topPage,
      settledSnap: _restingSnap,
      size: _restingSize,
      pageKeys: _restingPageKeys,
    );
    if (viewport == null || viewport == _lastReportedRestingViewport) return;

    _lastReportedRestingViewport = viewport;
    onChanged(viewport);
  }

  void _publishSettledSnap() {
    final extent = _controllers[_topPageKey]?.extent;
    if (_isSettleCheckScheduled || extent == null) return;

    _isSettleCheckScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _confirmSettledSnap(extent))
      ..ensureVisualUpdate();
  }

  void _confirmSettledSnap(double extentLastFrame) {
    _isSettleCheckScheduled = false;
    final pageKey = _topPageKey;
    final extent = _controllers[pageKey]?.extent;
    if (!mounted || pageKey == null || extent == null || _isTransitionActive.value) return;
    if ((extent - extentLastFrame).abs() > _settledSnapMaxFrameDelta) {
      _publishSettledSnap();
      return;
    }

    for (final snap in _topPageSnapSizes) {
      if ((extent - snap).abs() <= _settledSnapTolerance) {
        if (_plannedSnap case final plan? when plan.isRunning && plan.extent != snap) return;

        _plannedSnap = null;
        _settledSnap.value = (pageKey: pageKey, extent: snap);
        _confirmedSnapByPage[pageKey] = snap;
        _recordSettledSnap(pageKey, snap);
        _handleDragSettled();
        _scheduleRestingViewportReport();
        return;
      }
    }
  }

  void _restoreRememberedSnap(Object pageKey) {
    final snap = _confirmedSnapByPage[pageKey];
    if (snap == null || _settledSnap.value?.pageKey == pageKey) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isLive = _stack.any((route) => route.pageKey == pageKey);
      if (!mounted || !isLive || _topPageKey != pageKey) return;

      final remembered = _confirmedSnapByPage[pageKey];
      if (remembered != null) _settledSnap.value = (pageKey: pageKey, extent: remembered);
    });
  }

  void _recordSettledSnap(Object pageKey, double snap) {
    final previousExtent = _lastSettledExtentByPage[pageKey];
    _lastSettledExtentByPage[pageKey] = snap;
    if (previousExtent == null || previousExtent == snap) return;

    if (_isSheetInteracting) {
      _pendingSettledFit = (pageKey: pageKey, extent: snap);
    } else {
      _fireSettledFit(snap);
    }
  }

  void _fireSettledFit(double extent) {
    final fit = _currentSettledFit;
    if (fit == null) return;

    SchedulerBinding.instance.addPostFrameCallback(
      (_) => SchedulerBinding.instance
        ..addPostFrameCallback((_) => fit(extent))
        ..ensureVisualUpdate(),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _publishTransitionActive(bool value) {
    if (_isTransitionActive.value == value) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishTransitionActive(value);
      });
    } else {
      _isTransitionActive.value = value;
      if (!value) _isSettleCheckScheduled = false;
      _publishSettledSnap();
      if (!value) _scheduleFloorResnaps();
      _publishTopSheetFullyExpanded(
        _isTopSheetFullyExpanded(_settledTopPageExtent, _topPageExpandedExtent),
      );
    }
  }

  void _publishTopSheetFullyExpanded(bool value) {
    final onChanged = widget.onTopFullyExpandedChanged;
    if (onChanged == null) return;

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishTopSheetFullyExpanded(value);
      });
    } else if (_lastPublishedTopFullyExpanded != value) {
      _lastPublishedTopFullyExpanded = value;
      onChanged(value);
    }
  }

  void _reportInteractionEndedAfterFrame() {
    final onChanged = widget.onSheetInteractingChanged;
    if (!_isSheetInteracting || onChanged == null) return;

    SchedulerBinding.instance.addPostFrameCallback((_) => onChanged(false));
  }

  void _handleSheetDraggingChanged(bool isDragging) {
    if (!mounted) return;

    if (isDragging) {
      _plannedSnap = null;
      _updateSheetInteracting(isDragUnsettled: true);
    } else if (_isTopPageRestingOnSnap) {
      _updateSheetInteracting(isDragUnsettled: false);
    }
  }

  void _handleDragSettled() => _updateSheetInteracting(isDragUnsettled: false);

  void _handleSheetContentScrollingChanged(bool isScrolling) {
    if (!mounted) return;

    _updateSheetInteracting(isContentScrolling: isScrolling);
  }

  void _updateSheetInteracting({bool? isDragUnsettled, bool? isContentScrolling}) {
    final wasInteracting = _isSheetInteracting;
    _isDragUnsettled = isDragUnsettled ?? _isDragUnsettled;
    _isContentScrolling = isContentScrolling ?? _isContentScrolling;
    if (_isSheetInteracting == wasInteracting) return;

    widget.onSheetInteractingChanged?.call(_isSheetInteracting);
    if (!_isSheetInteracting) _releasePendingSettledFit();
  }

  void _releasePendingSettledFit() {
    final pending = _pendingSettledFit;
    _pendingSettledFit = null;
    if (pending == null || pending.pageKey != _topPageKey) return;

    _fireSettledFit(pending.extent);
  }

  void _resetSheetInteracting() {
    _pendingSettledFit = null;
    if (!_isSheetInteracting) return;

    _isDragUnsettled = false;
    _isContentScrolling = false;
    widget.onSheetInteractingChanged?.call(false);
  }
}

const _emptyStackMessage = 'A SheetNavigator needs at least one route in its stack.';
const _duplicatePageKeysMessage = 'Every route in a SheetNavigator stack needs a unique pageKey.';

bool _hasUniquePageKeys(List<SheetRoute> stack) =>
    stack.map((route) => route.pageKey).toSet().length == stack.length;

bool _hasSamePageKeys(List<SheetRoute> first, List<SheetRoute> second) =>
    first.length == second.length &&
    first.indexed.every((entry) => entry.$2.pageKey == second[entry.$1].pageKey);

bool _isTopSheetFullyExpanded(double? extent, double expandedExtent) =>
    extent != null && extent >= expandedExtent - _fullyExpandedExtentTolerance;

SheetPage _withMoverScope(SheetPage page, SheetMover mover) => SheetPage(
  pageKey: page.pageKey,
  initialSize: page.initialSize,
  snapSizes: page.snapSizes,
  builder: (context, scrollController) =>
      SheetMoverScope(mover: mover, child: page.builder(context, scrollController)),
  header: switch (page.header) {
    final header? => (context) => SheetMoverScope(mover: mover, child: header(context)),
    null => null,
  },
  pinnedExtent: page.pinnedExtent,
  backgroundTopInset: page.backgroundTopInset,
  focusExtent: page.focusExtent,
  floor: page.floor,
);

typedef _SheetMove = Future<void> Function(
  Object pageKey,
  double snapExtent,
  Duration duration,
  Curve curve,
);

final class const _PageSheetMover(final Object _pageKey, final _SheetMove _move)
    implements SheetMover {
  @override
  Future<void> moveTo(
    double snapExtent, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _move(_pageKey, snapExtent, duration, curve);
}

class _PendingFeatureExit<R extends SheetRoute>() {
  final Set<Object> pendingPageKeys = {};
  final Set<R> removedRoutes = {};
  final Set<Object> pendingLayerIds = {};
  Timer? fallbackTimer;

  bool get isSettled => pendingPageKeys.isEmpty && pendingLayerIds.isEmpty;
}

class const _FeatureScopes<R extends SheetRoute, F extends SheetFeature<R>>({
  required final List<F> features,
  required final ValueListenable<double?> visualTopExtent,
  required final ValueListenable<bool> isTransitionActive,
  required final VoidCallback requestPop,
  required final SheetResolvedPageLookup resolvedPage,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SheetNavigatorScope(
    visualTopExtent: visualTopExtent,
    isTransitionActive: isTransitionActive,
    requestPop: requestPop,
    resolvedPage: resolvedPage,
    child: features.reversed.fold(child, (scoped, feature) => feature.scope(context, scoped)),
  );
}

typedef _OverlayLayerSlot = ({Key? key, Widget content, double? bottom});

class const _OrderedOverlayLayers({
  required final ValueListenable<double?> extent,
  required final ValueListenable<bool> isTransitionActive,
  required final double viewportHeight,
  required final Widget sheetLayer,
  required final List<_OverlayLayerSlot> layers,
  required final double settledFallbackExtent,
  required final double fullyExpandedExtent,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: isTransitionActive,
    builder: (context, isTransitionActive, _) => AbsorbPointer(
      absorbing: isTransitionActive,
      child: _OverlayLayerStack(
        extent: extent,
        isTransitionActive: isTransitionActive,
        viewportHeight: viewportHeight,
        sheetLayer: sheetLayer,
        layers: layers,
        settledFallbackExtent: settledFallbackExtent,
        fullyExpandedExtent: fullyExpandedExtent,
      ),
    ),
  );
}

class const _OverlayLayerStack({
  required final ValueListenable<double?> extent,
  required final bool isTransitionActive,
  required final double viewportHeight,
  required final Widget sheetLayer,
  required final List<_OverlayLayerSlot> layers,
  required final double settledFallbackExtent,
  required final double fullyExpandedExtent,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: extent,
    builder: (context, extent, _) {
      final coveredFlags = [
        for (final layer in layers)
          _isLayerCovered(
            bottom: layer.bottom,
            extent: extent,
            viewportHeight: viewportHeight,
            settledFallbackExtent: settledFallbackExtent,
            fullyExpandedExtent: fullyExpandedExtent,
          ),
      ];
      final placedLayers = [
        for (final (index, layer) in layers.indexed)
          (
            isCovered: coveredFlags[index],
            widget: _PlacedOverlayLayer(
              key: layer.key,
              content: layer.content,
              isCovered: coveredFlags[index],
              isTransitionActive: isTransitionActive,
            ),
          ),
      ];

      return Stack(
        children: [
          ...placedLayers.where((layer) => layer.isCovered).map((layer) => layer.widget),
          sheetLayer,
          ...placedLayers.whereNot((layer) => layer.isCovered).map((layer) => layer.widget),
        ],
      );
    },
  );
}

class const _PlacedOverlayLayer({
  required final Widget content,
  required final bool isCovered,
  required final bool isTransitionActive,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Visibility(
      visible: !(isTransitionActive && isCovered),
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: ExcludeSemantics(
        excluding: isCovered,
        child: IgnorePointer(ignoring: isCovered, child: content),
      ),
    ),
  );
}

class const _OverlayLayerContent<R extends SheetRoute, F extends SheetFeature<R>>({
  required final SheetOverlayLayer<R, F> layer,
  required final SheetLayerContext<R, F> layerContext,
  required final int switcherGeneration,
  required final Duration switchDuration,
  required final VoidCallback onDispose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topRoute = layerContext.topRoute;
    final switcher = AnimatedSwitcher(
      key: ValueKey(switcherGeneration),
      duration: switchDuration,
      transitionBuilder: (child, animation) =>
          _SequencedLayerFade(animation: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(topRoute.pageKey),
        child: _RouteWidgetLifecycle(
          onDispose: onDispose,
          child:
              layerContext.topFeature.layer(context, layer.id, topRoute) ?? const SizedBox.shrink(),
        ),
      ),
    );
    return switch (layer.persistentBuilder) {
      final persistentBuilder? => Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (innerContext) => persistentBuilder(innerContext, layerContext),
            ),
          ),
          Positioned.fill(child: switcher),
        ],
      ),
      null => switcher,
    };
  }
}

bool _isLayerCovered({
  required double? bottom,
  required double? extent,
  required double viewportHeight,
  required double settledFallbackExtent,
  required double fullyExpandedExtent,
}) {
  if (bottom == null || extent == null || viewportHeight <= 0) {
    return settledFallbackExtent >= fullyExpandedExtent;
  }

  final sheetTopY = viewportHeight * (1 - extent);
  return sheetTopY <= bottom;
}

class const _SequencedLayerFade({
  required final Animation<double> animation,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_SequencedLayerFade> createState() => _SequencedLayerFadeState();
}

class _SequencedLayerFadeState() extends State<_SequencedLayerFade> {
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: widget.animation,
    curve: _sequencedLayerIncomingOpacityCurve,
    reverseCurve: _sequencedLayerOutgoingOpacityCurve,
  );

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }
}

class const _RouteWidgetLifecycle({
  required final VoidCallback onDispose,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_RouteWidgetLifecycle> createState() => _RouteWidgetLifecycleState();
}

class _RouteWidgetLifecycleState() extends State<_RouteWidgetLifecycle> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class const _SheetLayer<R extends SheetRoute, F extends SheetFeature<R>>({
  required final Object topRouteKey,
  required final F topFeature,
  required final R topRoute,
  required final double availableHeight,
  required final List<SheetStackEntry> entries,
  required final SheetNavigatorStyle style,
  required final SheetTransitionFactory transitions,
  required final ValueChanged<Object> onExitCompleted,
  required final ValueChanged<double?> onVisualTopExtentChanged,
  required final ValueChanged<ValueSetter<double>> onSettledFitReady,
  final ValueChanged<bool>? onTransitionActiveChanged,
  final ValueChanged<bool>? onSheetDraggingChanged,
  final ValueChanged<bool>? onSheetContentScrollingChanged,
}) extends StatefulWidget {
  @override
  State<_SheetLayer<R, F>> createState() => _SheetLayerState<R, F>();
}

class _SheetLayerState<R extends SheetRoute, F extends SheetFeature<R>>()
    extends State<_SheetLayer<R, F>> {
  @override
  Widget build(BuildContext context) {
    final topFeature = widget.topFeature;
    final topRoute = widget.topRoute;
    final topRouteKey = widget.topRouteKey;
    widget.onSettledFitReady((extent) {
      if (mounted && widget.topRouteKey == topRouteKey) {
        topFeature.onSettledAfterDrag(context, topRoute, extent);
      }
    });
    return SheetStack(
      entries: widget.entries,
      style: widget.style,
      transitions: widget.transitions,
      onExitCompleted: widget.onExitCompleted,
      onVisualTopExtentChanged: widget.onVisualTopExtentChanged,
      onTransitionActiveChanged: widget.onTransitionActiveChanged,
      onSheetDraggingChanged: widget.onSheetDraggingChanged,
      onSheetContentScrollingChanged: widget.onSheetContentScrollingChanged,
    );
  }

  @override
  void didUpdateWidget(covariant _SheetLayer<R, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topRouteKey != oldWidget.topRouteKey) {
      widget.topFeature.onBecameTop(context, widget.topRoute);
    } else if (widget.availableHeight != oldWidget.availableHeight) {
      widget.topFeature.onAvailableHeightChanged(context, widget.topRoute);
    }
  }
}

final class _PlannedSnap(final Object pageKey, final double extent) {
  bool isRunning = true;
}
