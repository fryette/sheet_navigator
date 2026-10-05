import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sheet_navigator/src/navigator/sheet_navigator_style.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';
import 'package:sheet_navigator/src/stack/sheet_content_bounce.dart';
import 'package:sheet_navigator/src/stack/sheet_controller_extent.dart';
import 'package:sheet_navigator/src/stack/sheet_page_content.dart';
import 'package:sheet_navigator/src/stack/sheet_physics.dart';
import 'package:sheet_navigator/src/stack/sheet_pointer_cancel_guard.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_context.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_factory.dart';
import 'package:sheet_navigator/src/transition/sheet_transition_strategy.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetStackEntry({
  required final SheetRoute route,
  required final SheetPage page,
  required final SheetController controller,
});

class const SheetStack({
  required final List<SheetStackEntry> entries,
  required final SheetNavigatorStyle style,
  required final ValueChanged<Object> onExitCompleted,
  required final ValueChanged<double?> onVisualTopExtentChanged,
  final SheetTransitionFactory transitions = SheetTransitionFactory.standard,
  final ValueChanged<bool>? onTransitionActiveChanged,
  final ValueChanged<bool>? onSheetDraggingChanged,
  final ValueChanged<bool>? onSheetContentScrollingChanged,
  super.key,
}) extends StatefulWidget {
  @override
  State<SheetStack> createState() => _SheetStackState();
}

enum _SheetRole() {
  advancing,
  retreating,
  receding,
  returning,
  idle,
}

const _navigationExtentFreezeTolerancePixels = 1.0;

bool _isNavigationExtentUnchanged(SheetTransitionContext transition) =>
    (transition.from.extent - transition.to.extent).abs() * transition.viewportHeight <=
    _navigationExtentFreezeTolerancePixels;

class _SheetStackState() extends State<SheetStack> with TickerProviderStateMixin {
  final List<_LiveSheet> _live = [];
  AnimationController? _running;
  double _viewportHeight = 0;
  bool _isNavigationExtentFrozen = false;
  bool _isDragging = false;
  bool _isContentScrolling = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant SheetStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntries();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewportHeight = constraints.maxHeight;
      return NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final live in _live)
              KeyedSubtree(
                key: live.subtreeKey,
                child: _SheetStackEntryView(
                  live: live,
                  style: widget.style,
                  viewportHeight: constraints.maxHeight,
                  onNotification: _handleSheetNotification,
                ),
              ),
          ],
        ),
      );
    },
  );

  @override
  void dispose() {
    for (final live in _live) {
      _detachExtentListener(live);
    }
    _running?.dispose();
    _reportEndedAfterFrame(_isDragging, widget.onSheetDraggingChanged);
    _reportEndedAfterFrame(_isContentScrolling, widget.onSheetContentScrollingChanged);
    super.dispose();
  }

  void _bootstrap() {
    for (final entry in widget.entries) {
      _live.add(_createLiveSheet(entry));
    }
    for (var index = 0; index < _live.length; index++) {
      _live[index].isTop = index == _live.length - 1;
    }
  }

  void _syncEntries() {
    for (final entry in widget.entries) {
      if (_liveByKey(entry.page.pageKey) case final live?) {
        if (live.entry.controller != entry.controller) {
          _detachExtentListener(live);
          live.entry = entry;
          _attachExtentListener(live);
        } else {
          live.entry = entry;
        }
      }
    }

    final targetKeys = [for (final entry in widget.entries) entry.page.pageKey];
    var liveKeys = [
      for (final live in _live)
        if (!live.isExiting) live.key,
    ];
    if (listEquals(liveKeys, targetKeys)) return;

    if (_running case final running?) _finishImmediately(running);
    liveKeys = [
      for (final live in _live)
        if (!live.isExiting) live.key,
    ];
    if (listEquals(liveKeys, targetKeys)) return;

    final isPush =
        targetKeys.length == liveKeys.length + 1 &&
        listEquals(liveKeys, targetKeys.sublist(0, liveKeys.length));
    if (isPush) {
      _applyPush();
      return;
    }

    final isPop =
        targetKeys.isNotEmpty &&
        targetKeys.length < liveKeys.length &&
        listEquals(targetKeys, liveKeys.sublist(0, targetKeys.length));
    if (isPop) {
      _applyPop(targetKeys.length);
      return;
    }

    final isReplace =
        targetKeys.isNotEmpty &&
        targetKeys.length == liveKeys.length &&
        listEquals(
          liveKeys.sublist(0, liveKeys.length - 1),
          targetKeys.sublist(0, targetKeys.length - 1),
        );
    if (isReplace) {
      _applyReplace();
      return;
    }

    _applyRebase();
  }

  void _applyPush() {
    final outgoing = _live.lastOrNull;
    if (outgoing == null) {
      _rebuildWithoutMotion();
      return;
    }

    final [..., lastEntry] = widget.entries;
    final incoming = _createLiveSheet(lastEntry);
    final depthBefore = _live.length;
    final transition = SheetTransitionContext(
      operation: .push,
      from: _sideOf(outgoing, outgoing.entry.controller.extent ?? outgoing.restExtent),
      to: _sideOf(incoming, incoming.restExtent),
      depthBefore: depthBefore,
      depthAfter: depthBefore + 1,
      removedCount: 0,
      viewportHeight: _viewportHeight,
    );
    final strategy = widget.transitions.resolve(transition);
    _startTransition(strategy.duration(transition), (motion) {
      outgoing
        ..role = .receding
        ..spec = strategy.lower(transition)
        ..isTop = false
        ..motion = motion;
      incoming
        ..role = .advancing
        ..spec = strategy.upper(transition)
        ..isTop = true
        ..motion = motion;
      _live.add(incoming);
    }, holdExtent: _isNavigationExtentUnchanged(transition));
  }

  void _applyPop(int keepCount) {
    final departing = _live.sublist(keepCount);
    final topmost = departing.last;
    final returning = _live[keepCount - 1];
    final transition = SheetTransitionContext(
      operation: .pop,
      from: _sideOf(topmost, topmost.entry.controller.extent ?? topmost.restExtent),
      to: _sideOf(returning, returning.entry.controller.extent ?? returning.restExtent),
      depthBefore: _live.length,
      depthAfter: keepCount,
      removedCount: departing.length,
      viewportHeight: _viewportHeight,
    );
    final strategy = widget.transitions.resolve(transition);
    _startTransition(strategy.duration(transition), (motion) {
      for (final live in departing) {
        live.isExiting = true;
      }
      topmost
        ..role = .retreating
        ..spec = strategy.upper(transition)
        ..motion = motion;
      returning
        ..role = .returning
        ..spec = strategy.lower(transition)
        ..isTop = true
        ..motion = motion;
    }, holdExtent: _isNavigationExtentUnchanged(transition));
  }

  void _applyReplace() {
    final outgoing = _live.last;
    final [..., lastEntry] = widget.entries;
    final incoming = _createLiveSheet(lastEntry);
    final transition = SheetTransitionContext(
      operation: .replace,
      from: _sideOf(outgoing, outgoing.entry.controller.extent ?? outgoing.restExtent),
      to: _sideOf(incoming, incoming.restExtent),
      depthBefore: _live.length,
      depthAfter: _live.length,
      removedCount: 1,
      viewportHeight: _viewportHeight,
    );
    final strategy = widget.transitions.resolve(transition);
    _startTransition(strategy.duration(transition), (motion) {
      outgoing
        ..role = .receding
        ..spec = strategy.lower(transition)
        ..isTop = false
        ..isExiting = true
        ..motion = motion;
      incoming
        ..role = .advancing
        ..spec = strategy.upper(transition)
        ..isTop = true
        ..motion = motion;
      _live.add(incoming);
    }, holdExtent: _isNavigationExtentUnchanged(transition));
  }

  void _applyRebase() {
    final targetKeys = [for (final entry in widget.entries) entry.page.pageKey];
    final outgoing = _live.lastOrNull;
    final incomingEntry = widget.entries.lastOrNull;
    if (outgoing == null ||
        incomingEntry == null ||
        targetKeys.contains(outgoing.key) ||
        _liveByKey(incomingEntry.page.pageKey) != null) {
      _rebuildWithoutMotion();
      return;
    }

    final incoming = _createLiveSheet(incomingEntry);
    final retained = [
      for (final entry in widget.entries.sublist(0, widget.entries.length - 1))
        _liveByKey(entry.page.pageKey) ?? _createLiveSheet(entry),
    ];
    final dropped = _live
        .where((live) => live != outgoing && !targetKeys.contains(live.key))
        .toList();
    final transition = SheetTransitionContext(
      operation: .replace,
      from: _sideOf(outgoing, outgoing.entry.controller.extent ?? outgoing.restExtent),
      to: _sideOf(incoming, incoming.restExtent),
      depthBefore: _live.length,
      depthAfter: targetKeys.length,
      removedCount: dropped.length + 1,
      viewportHeight: _viewportHeight,
    );
    final strategy = widget.transitions.resolve(transition);
    _startTransition(strategy.duration(transition), (motion) {
      for (final live in dropped) {
        live.isExiting = true;
      }
      outgoing
        ..role = .receding
        ..spec = strategy.lower(transition)
        ..isTop = false
        ..isExiting = true
        ..motion = motion;
      incoming
        ..role = .advancing
        ..spec = strategy.upper(transition)
        ..isTop = true
        ..motion = motion;
      _live
        ..clear()
        ..addAll([...retained, ...dropped, outgoing, incoming]);
    }, holdExtent: _isNavigationExtentUnchanged(transition));
  }

  SheetTransitionSide _sideOf(_LiveSheet live, double extent) => SheetTransitionSide(
    route: live.entry.route,
    extent: extent,
    snapSizes: live.entry.page.snapSizes,
  );

  void _rebuildWithoutMotion() {
    final targetKeys = [for (final entry in widget.entries) entry.page.pageKey];
    final removed = _live.where((live) => !targetKeys.contains(live.key)).toList();

    setState(() {
      _live.removeWhere((live) => !targetKeys.contains(live.key));
      for (final entry in widget.entries) {
        if (_liveByKey(entry.page.pageKey) == null) _live.add(_createLiveSheet(entry));
      }
      _live.sort((a, b) => targetKeys.indexOf(a.key).compareTo(targetKeys.indexOf(b.key)));
      for (var index = 0; index < _live.length; index++) {
        _live[index]
          ..isTop = index == _live.length - 1
          ..role = .idle
          ..spec = null
          ..motion = kAlwaysCompleteAnimation
          ..isExiting = false;
      }
    });
    for (final live in removed) {
      _detachExtentListener(live);
    }

    _publishVisualTopExtent();
    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final live in removed.reversed) {
        widget.onExitCompleted(live.key);
      }
    });
  }

  void _startTransition(
    Duration duration,
    void Function(AnimationController transition) configure, {
    required bool holdExtent,
  }) {
    final transition = AnimationController(vsync: this, duration: duration)
      ..addStatusListener(_onTransitionStatus)
      ..addListener(_publishVisualTopExtentFromTransitionFrame);

    _isNavigationExtentFrozen = holdExtent;
    setState(() {
      _running = transition;
      configure(transition);
    });

    if (duration > Duration.zero) widget.onTransitionActiveChanged?.call(true);
    transition.forward();
    _publishVisualTopExtent();
  }

  void _publishVisualTopExtentFromTransitionFrame() {
    if (_isNavigationExtentFrozen) return;
    _publishVisualTopExtent();
  }

  void _finishImmediately(AnimationController transition) {
    transition.value = 1;
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (status != .completed) return;

    final transition = _running;
    if (transition == null) return;

    _running = null;
    _finalizeTransition(transition);
  }

  void _finalizeTransition(AnimationController transition) {
    _isNavigationExtentFrozen = false;
    final removed = _live.where((live) => live.isExiting).toList();

    setState(() {
      for (final live in _live) {
        if (live.role == .idle) continue;
        live
          ..role = .idle
          ..spec = null
          ..motion = kAlwaysCompleteAnimation
          ..isExiting = false;
      }
      _live.removeWhere(removed.contains);
      for (var index = 0; index < _live.length; index++) {
        _live[index].isTop = index == _live.length - 1;
      }
    });
    for (final live in removed) {
      _detachExtentListener(live);
    }

    transition.dispose();
    widget.onTransitionActiveChanged?.call(false);
    _publishVisualTopExtent();

    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final live in removed.reversed) {
        widget.onExitCompleted(live.key);
      }
    });
  }

  bool _handleSheetNotification(SheetNotification notification) {
    switch (notification) {
      case SheetDragStartNotification():
        _setDragging(true);
      case SheetDragEndNotification() || SheetDragCancelNotification():
        _setDragging(false);
      case SheetUpdateNotification() ||
          SheetDragUpdateNotification() ||
          SheetOverflowNotification():
        break;
    }
    _publishVisualTopExtent();
    return false;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    switch (notification) {
      case ScrollStartNotification():
        _setContentScrolling(true);
      case ScrollEndNotification():
        _setContentScrolling(false);
    }
    return false;
  }

  void _reportEndedAfterFrame(bool isActive, ValueChanged<bool>? onChanged) {
    if (!isActive || onChanged == null) return;

    SchedulerBinding.instance.addPostFrameCallback((_) => onChanged(false));
  }

  void _setDragging(bool value) {
    if (_isDragging == value) return;

    _isDragging = value;
    widget.onSheetDraggingChanged?.call(value);
  }

  void _setContentScrolling(bool value) {
    if (_isContentScrolling == value) return;

    _isContentScrolling = value;
    widget.onSheetContentScrollingChanged?.call(value);
  }

  void _publishVisualTopExtent() {
    final viewportHeight = _viewportHeight;
    if (viewportHeight <= 0) {
      widget.onVisualTopExtentChanged(null);
      return;
    }

    var visualTopExtent = 0.0;
    for (final live in _live) {
      final liveExtent = live.entry.controller.extent ?? live.restExtent;
      final visualExtent = math.max(0.0, liveExtent - live.dyFor(viewportHeight) / viewportHeight);
      final contribution = switch (live.role) {
        .advancing || .retreating => visualExtent,
        .idle when live.isTop => visualExtent,
        .idle => 0.0,
        .receding || .returning => visualExtent * live.alpha,
      };
      visualTopExtent = math.max(visualTopExtent, contribution);
    }

    widget.onVisualTopExtentChanged(visualTopExtent);
  }

  _LiveSheet _createLiveSheet(SheetStackEntry entry) {
    final live = _LiveSheet(key: entry.page.pageKey, entry: entry);
    _attachExtentListener(live);
    return live;
  }

  _LiveSheet? _liveByKey(Object key) => _live.firstWhereOrNull((live) => live.key == key);

  void _attachExtentListener(_LiveSheet live) =>
      live.entry.controller.addListener(_publishVisualTopExtent);

  void _detachExtentListener(_LiveSheet live) =>
      live.entry.controller.removeListener(_publishVisualTopExtent);
}

class _LiveSheet {
  final Object key;
  final GlobalKey subtreeKey = GlobalKey();
  final SheetContentBounce contentBounce = SheetContentBounce();
  final SnapBounceSheetPhysics physics = SnapBounceSheetPhysics();
  SheetStackEntry entry;
  Animation<double> motion = kAlwaysCompleteAnimation;
  _SheetRole role = .idle;
  SheetMotion? spec;
  bool isTop = false;
  bool isExiting = false;

  new({required this.key, required this.entry});

  double get restExtent => entry.page.initialSize;

  bool get isPainted => role != .idle || isTop;

  bool get isInteractive => role == .idle && isTop;

  bool get isSemanticsReadable =>
      role == .advancing || role == .returning || (role == .idle && isTop);

  double get alpha => spec?.alpha(motion.value) ?? 1;

  double get scale => spec?.scale(motion.value) ?? 1;

  double dyFor(double viewportHeight) {
    final motionSpec = spec;
    return motionSpec == null ? 0 : motionSpec.dy(motion.value) * viewportHeight;
  }
}

class const _SheetStackEntryView({
  required final _LiveSheet live,
  required final SheetNavigatorStyle style,
  required final double viewportHeight,
  required final NotificationListenerCallback<SheetNotification> onNotification,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Visibility(
      visible: live.isPainted,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: IgnorePointer(
        ignoring: !live.isInteractive,
        child: ExcludeSemantics(
          excluding: !live.isSemanticsReadable,
          child: AnimatedBuilder(
            animation: live.motion,
            builder: (_, child) =>
                Transform.translate(offset: Offset(0, live.dyFor(viewportHeight)), child: child),
            child: _ViewInsetsGate(
              isActive: live.isPainted,
              child: Builder(builder: _sheet),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _sheet(BuildContext context) {
    final page = live.entry.page;
    final sortedSnapSizes = page.snapSizes.toSet().toList()..sort();
    final maxSize = sortedSnapSizes.isEmpty ? page.initialSize : sortedSnapSizes.reduce(math.max);

    final sheet = Sheet(
      controller: live.entry.controller,
      initialOffset: SheetOffset.proportionalToViewport(page.initialSize),
      snapGrid: SheetSnapGrid(
        snaps: [for (final size in sortedSnapSizes) SheetOffset.proportionalToViewport(size)],
      ),
      physics: style.physics ?? live.physics,
      scrollConfiguration: style.scrollConfiguration ?? live.contentBounce,
      padding: style.isKeyboardPaddingEnabled
          ? .only(bottom: MediaQuery.viewInsetsOf(context).bottom)
          : .zero,
      decoration: SheetDecorationBuilder(
        size: .fit,
        builder: (context, card) => AnimatedBuilder(
          animation: live.motion,
          builder: (_, surface) => Opacity(
            opacity: live.alpha,
            child: Transform.scale(scale: live.scale, alignment: .topCenter, child: surface),
          ),
          child: style.surfaceBuilder(context, card),
        ),
      ),
      child: SheetPageContent(
        controller: live.entry.controller,
        builder: live.contentBounce.track(page.builder),
        header: page.header,
        handle: style.handleBuilder,
        viewportHeight: viewportHeight,
        contentBoxHeight: maxSize * viewportHeight,
      ),
    );

    return SheetPointerCancelGuard(
      controller: live.entry.controller,
      child: SheetViewport(
        child: NotificationListener<SheetNotification>(
          onNotification: onNotification,
          child: switch (style.keyboardDismissBehavior) {
            final behavior? => SheetKeyboardDismissible(dismissBehavior: behavior, child: sheet),
            null => sheet,
          },
        ),
      ),
    );
  }
}

class const _ViewInsetsGate({required final bool isActive, required final Widget child})
    extends StatefulWidget {
  @override
  State<_ViewInsetsGate> createState() => _ViewInsetsGateState();
}

class _ViewInsetsGateState extends State<_ViewInsetsGate> {
  EdgeInsets? _viewInsets;
  EdgeInsets? _padding;
  EdgeInsets? _viewPadding;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    if (widget.isActive || _viewInsets == null) {
      _viewInsets = data.viewInsets;
      _padding = data.padding;
      _viewPadding = data.viewPadding;
    }
    return MediaQuery(
      data: data.copyWith(viewInsets: _viewInsets, padding: _padding, viewPadding: _viewPadding),
      child: widget.child,
    );
  }
}
