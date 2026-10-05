import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/navigator/sheet_feature.dart';
import 'package:sheet_navigator/src/navigator/sheet_navigator_scope.dart';
import 'package:sheet_navigator/src/navigator/sheet_navigator_style.dart';
import 'package:sheet_navigator/src/navigator/sheet_overlay_layer.dart';
import 'package:sheet_navigator/src/navigator/sheet_viewport_state.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';
import 'package:sheet_navigator/src/route/sheet_navigator_controller.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';
import 'package:sheet_navigator/src/stack/sheet_controller_extent.dart';
import 'package:sheet_navigator/src/stack/sheet_stack.dart';
import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_factory.dart';
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
         exitFallbackTimeout: exitFallbackTimeout,
         key: key,
       );

  @override
  State<SheetNavigator<R, F>> createState() => _SheetNavigatorState<R, F>();
}

const _fullyExpandedExtentTolerance = 0.0005;
const _settledSnapTolerance = 0.005;
const _settledSnapMaxFrameDelta = 0.001;

const _sequencedLayerCrossoverPoint = 0.45;
const _sequencedLayerIncomingOpacityCurve = Interval(_sequencedLayerCrossoverPoint, 1);
const _sequencedLayerOutgoingOpacityCurve = Interval(1 - _sequencedLayerCrossoverPoint, 1);

Widget _sequencedLayerTransitionBuilder(Widget child, Animation<double> animation) =>
    _SequencedLayerFade(animation: animation, child: child);

class _SheetNavigatorState<R extends SheetRoute, F extends SheetFeature<R>>()
    extends State<SheetNavigator<R, F>> {
  final _controllers = <Object, SheetController>{};
  final _routesByPageKey = <Object, R>{};
  final _pagesByPageKey = <Object, SheetPage>{};
  final _visualTopExtent = ValueNotifier<double?>(null);
  final _isTransitionActive = ValueNotifier<bool>(false);
  final _overlayContentKey = GlobalKey();
  final _pendingFeatureExits = <Type, _PendingFeatureExit<R, F>>{};
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
  ValueSetter<double>? _currentSettledFit;
  var _isSettleCheckScheduled = false;
  bool? _lastPublishedTopFullyExpanded;
  var _isDragUnsettled = false;
  var _isContentScrolling = false;
  ({Object pageKey, double extent})? _pendingSettledFit;

  bool get _isSheetInteracting => _isDragUnsettled || _isContentScrolling;

  bool get _isTopPageRestingOnSnap {
    final extent = _controllers[_topPageKey]?.extent;
    if (extent == null) return false;

    return _topPageSnapSizes.any((snap) => (extent - snap).abs() <= _settledSnapTolerance);
  }

  double? get _settledTopPageExtent =>
      _isTransitionActive.value ? null : _controllers[_topPageKey]?.extent ?? _topPageInitialSize;

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
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availableHeight = constraints.maxHeight;
      final availableWidth = constraints.maxWidth;
      final entries = <SheetStackEntry>[];
      for (final route in _stack) {
        _routesByPageKey[route.pageKey] = route;
        final isNewPage = !_controllers.containsKey(route.pageKey);
        final controller = _controllerFor(route.pageKey);
        final page = _featureFor(route).page(context, route, availableHeight, controller);
        if (isNewPage) _lastSettledExtentByPage[route.pageKey] = page.initialSize;
        _pagesByPageKey[route.pageKey] = page;
        entries.add(SheetStackEntry(route: route, page: page, controller: controller));
      }
      final [..., topRoute] = _stack;
      final topFeature = _featureFor(topRoute);
      final [..., SheetStackEntry(page: topPage)] = entries;
      _resolveLayerSwitchDuration(topRoute, topPage, availableHeight);
      final settledFallbackExtent = topPage.initialSize;
      final topPageExpandedExtent = topPage.snapSizes.isEmpty
          ? 1.0
          : topPage.snapSizes.reduce(math.max);
      _topPageExpandedExtent = topPageExpandedExtent;
      _topPageKey = topRoute.pageKey;
      _topPageInitialSize = topPage.initialSize;
      _topPageSnapSizes = topPage.snapSizes;
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

      return _wrapInScopes(
        context,
        _OrderedOverlayLayers(
          key: _overlayContentKey,
          extent: _visualTopExtent,
          isTransitionActive: _isTransitionActive,
          viewportHeight: availableHeight,
          sheetLayer: sheetLayer,
          layers: [
            for (final layer in widget.layers)
              (
                key: layer.key,
                content: _layerContent(context, layer, layerContext),
                bottom: topFeature.layerBottom(context, layer.id, topRoute),
              ),
          ],
          settledFallbackExtent: settledFallbackExtent,
          fullyExpandedExtent: topPageExpandedExtent,
        ),
      );
    },
  );

  @override
  void didUpdateWidget(covariant SheetNavigator<R, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _settledSnap.dispose();
    _isTransitionActive.dispose();
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
    _resetSheetInteracting();
    _stackBeforeLayerSwitch ??= oldStack;
    _dropLiveRoutesFromPendingExits(stack);

    final removedRoutes = [
      for (final route in oldStack)
        if (!stack.any((current) => current.pageKey == route.pageKey)) route,
    ];
    if (removedRoutes.isEmpty) return;

    final [..., oldTopRoute] = oldStack;
    final isOldTopRemoved = !stack.any((route) => route.pageKey == oldTopRoute.pageKey);

    final removedRoutesByFeature = <F, List<R>>{};
    for (final route in removedRoutes) {
      (removedRoutesByFeature[_featureFor(route)] ??= []).add(route);
    }

    for (final MapEntry(key: feature, value: featureRemovedRoutes)
        in removedRoutesByFeature.entries) {
      final isStillLiveElsewhere = stack.any((route) => _featureFor(route) == feature);
      final pending = _pendingFeatureExits.putIfAbsent(
        feature.runtimeType,
        () => _PendingFeatureExit<R, F>(feature),
      );
      pending.pendingPageKeys.addAll(featureRemovedRoutes.map((route) => route.pageKey));
      pending.removedRoutes.addAll(featureRemovedRoutes);
      if (!isStillLiveElsewhere && isOldTopRemoved && _featureFor(oldTopRoute) == feature) {
        pending.pendingLayerIds.addAll(widget.layers.map((layer) => layer.id));
      }
      _scheduleExitFallback(feature, pending);
    }
  }

  void _dropLiveRoutesFromPendingExits(List<R> stack) {
    final livePageKeys = {for (final route in stack) route.pageKey};
    for (final MapEntry<Type, _PendingFeatureExit<R, F>>(key: featureType, value: pending) in [
      ..._pendingFeatureExits.entries,
    ]) {
      pending.pendingPageKeys.removeWhere(livePageKeys.contains);
      pending.removedRoutes.removeWhere((route) => livePageKeys.contains(route.pageKey));
      if (pending.removedRoutes.isNotEmpty || pending.pendingPageKeys.isNotEmpty) continue;

      pending.fallbackTimer?.cancel();
      pending.pendingLayerIds.clear();
      _pendingFeatureExits.remove(featureType);
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

  Widget _layerContent(
    BuildContext context,
    SheetOverlayLayer<R, F> layer,
    SheetLayerContext<R, F> layerContext,
  ) {
    final topRoute = layerContext.topRoute;
    final topFeature = layerContext.topFeature;
    final switcher = AnimatedSwitcher(
      key: ValueKey(_layerSwitcherGenerations[layer.id] ?? 0),
      duration: _layerSwitchDuration,
      transitionBuilder: _sequencedLayerTransitionBuilder,
      child: KeyedSubtree(
        key: ValueKey(topRoute.pageKey),
        child: _RouteWidgetLifecycle(
          onDispose: () => _handleLayerSubtreeDisposed(topFeature, layer.id),
          child: topFeature.layer(context, layer.id, topRoute) ?? const SizedBox.shrink(),
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

  F _featureFor(R route) => widget.features.firstWhere((feature) => feature.handles(route));

  SheetController _controllerFor(Object pageKey) =>
      _controllers.putIfAbsent(pageKey, SheetController.new);

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

    final feature = _featureFor(route);
    _pendingFeatureExits[feature.runtimeType]?.pendingPageKeys.remove(pageKey);
    if (isLive) {
      if (_pendingFeatureExits[feature.runtimeType] case final pending?) {
        pending.removedRoutes.removeWhere((removed) => removed.pageKey == pageKey);
        _tryCompleteExit(feature, pending);
      }
      return;
    }

    _controllers.remove(pageKey)?.dispose();
    _pagesByPageKey.remove(pageKey);
    _lastSettledExtentByPage.remove(pageKey);
    if (_pendingFeatureExits[feature.runtimeType] case final pending?) {
      _tryCompleteExit(feature, pending);
    }
  }

  void _handleLayerSubtreeDisposed(F feature, Object layerId) {
    final pending = _pendingFeatureExits[feature.runtimeType];
    if (pending == null || !pending.pendingLayerIds.remove(layerId)) return;

    _tryCompleteExit(feature, pending);
  }

  void _tryCompleteExit(F feature, _PendingFeatureExit<R, F> pending) {
    if (!pending.isSettled) return;

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyExitCompleted(feature, pending));
    } else {
      _applyExitCompleted(feature, pending);
    }
  }

  void _applyExitCompleted(
    F feature,
    _PendingFeatureExit<R, F> pending, {
    Set<Object> resetLayerIds = const {},
  }) {
    if (!mounted || _pendingFeatureExits[feature.runtimeType] != pending) return;
    pending.fallbackTimer?.cancel();
    setState(() {
      _pendingFeatureExits.remove(feature.runtimeType);
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

  void _scheduleExitFallback(F feature, _PendingFeatureExit<R, F> pending) {
    pending.fallbackTimer?.cancel();
    final fallbackDelay = widget.exitFallbackTimeout * timeDilation;
    pending.fallbackTimer = Timer(fallbackDelay, () {
      if (!mounted || _pendingFeatureExits[feature.runtimeType] != pending) return;

      final resetLayerIds = {...pending.pendingLayerIds};
      pending.pendingPageKeys.clear();
      pending.pendingLayerIds.clear();
      _applyExitCompleted(feature, pending, resetLayerIds: resetLayerIds);
    });
  }

  Widget _wrapInScopes(BuildContext context, Widget child) {
    final orderedFeatures = <F>[];
    for (final route in _stack) {
      final feature = _featureFor(route);
      if (!orderedFeatures.contains(feature)) orderedFeatures.add(feature);
    }
    for (final MapEntry(key: featureType, value: pending) in _pendingFeatureExits.entries) {
      if (orderedFeatures.every((feature) => feature.runtimeType != featureType)) {
        orderedFeatures.add(pending.feature);
      }
    }

    final scoped = orderedFeatures.reversed.fold(
      child,
      (scoped, feature) => feature.scope(context, scoped),
    );
    return SheetNavigatorScope(
      visualTopExtent: _visualTopExtent,
      isTransitionActive: _isTransitionActive,
      requestPop: _requestPop,
      child: scoped,
    );
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
        _settledSnap.value = (pageKey: pageKey, extent: snap);
        _recordSettledSnap(pageKey, snap);
        _handleDragSettled();
        return;
      }
    }
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
      _publishSettledSnap();
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

  void _handleSheetDraggingChanged(bool isDragging) {
    if (isDragging) {
      _updateSheetInteracting(isDragUnsettled: true);
    } else if (_isTopPageRestingOnSnap) {
      _updateSheetInteracting(isDragUnsettled: false);
    }
  }

  void _handleDragSettled() => _updateSheetInteracting(isDragUnsettled: false);

  void _handleSheetContentScrollingChanged(bool isScrolling) =>
      _updateSheetInteracting(isContentScrolling: isScrolling);

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

bool _isTopSheetFullyExpanded(double? extent, double expandedExtent) =>
    extent != null && extent >= expandedExtent - _fullyExpandedExtentTolerance;

class _PendingFeatureExit<R extends SheetRoute, F extends SheetFeature<R>>(final F feature) {
  final Set<Object> pendingPageKeys = {};
  final Set<R> removedRoutes = {};
  final Set<Object> pendingLayerIds = {};
  Timer? fallbackTimer;

  bool get isSettled => pendingPageKeys.isEmpty && pendingLayerIds.isEmpty;
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
    builder: (context, isTransitionActive, _) =>
        AbsorbPointer(absorbing: isTransitionActive, child: _layers(context, isTransitionActive)),
  );

  Widget _layers(BuildContext context, bool isTransitionActive) => ValueListenableBuilder(
    valueListenable: extent,
    builder: (context, extent, _) {
      final placedLayers = [
        for (final layer in layers)
          _placeLayer(
            layer,
            isCovered: _isLayerCovered(
              bottom: layer.bottom,
              extent: extent,
              viewportHeight: viewportHeight,
              settledFallbackExtent: settledFallbackExtent,
              fullyExpandedExtent: fullyExpandedExtent,
            ),
            isTransitionActive: isTransitionActive,
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

  ({bool isCovered, Widget widget}) _placeLayer(
    _OverlayLayerSlot layer, {
    required bool isCovered,
    required bool isTransitionActive,
  }) => (
    isCovered: isCovered,
    widget: Positioned.fill(
      key: layer.key,
      child: Visibility(
        visible: !(isTransitionActive && isCovered),
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: ExcludeSemantics(
          excluding: isCovered,
          child: IgnorePointer(ignoring: isCovered, child: layer.content),
        ),
      ),
    ),
  );
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
