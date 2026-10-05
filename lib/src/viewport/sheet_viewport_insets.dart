import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef SheetViewportInsetsValue = ({EdgeInsets padding, EdgeInsets focus});

class const SheetViewportInsets({
  required final double availableHeight,
  required final double pinnedExtent,
  required final double topInset,
  required final ValueChanged<SheetViewportInsetsValue> onInsetsChanged,
  required final Widget child,
  final double? focusExtent,
  final double? floorExtent,
  final ValueChanged<EdgeInsets>? onRenderPaddingChanged,
  super.key,
}) extends StatefulWidget {
  static const gap = 12.0;

  @override
  State<SheetViewportInsets> createState() => _SheetViewportInsetsState();

  static EdgeInsets insetsFor({
    required double availableHeight,
    required double pinnedExtent,
    required double topInset,
  }) => EdgeInsets.only(top: topInset + gap, bottom: pinnedExtent * availableHeight + gap);

  static EdgeInsets renderPaddingFor({
    required double availableHeight,
    required double floorExtent,
    required double topInset,
  }) => EdgeInsets.only(top: topInset + gap, bottom: floorExtent * availableHeight + gap);

  static EdgeInsets focusInsetsFor({
    required double availableHeight,
    required double pinnedExtent,
    required double topInset,
    double? focusExtent,
  }) => EdgeInsets.only(
    top: topInset + gap,
    bottom: math.max(focusExtent ?? pinnedExtent, pinnedExtent) * availableHeight + gap,
  );
}

class _SheetViewportInsetsState() extends State<SheetViewportInsets> {
  SheetViewportInsetsValue? _targetInsets;
  EdgeInsets? _targetRenderPadding;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _schedulePublish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (isActive && !_isActive) {
      _targetInsets = null;
      _targetRenderPadding = null;
      _schedulePublish();
    }
    _isActive = isActive;
  }

  @override
  void didUpdateWidget(covariant SheetViewportInsets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onRenderPaddingChanged == null && widget.onRenderPaddingChanged != null) {
      _targetRenderPadding = null;
      _schedulePublish();
    }
    if (oldWidget.availableHeight != widget.availableHeight ||
        oldWidget.pinnedExtent != widget.pinnedExtent ||
        oldWidget.topInset != widget.topInset ||
        oldWidget.focusExtent != widget.focusExtent ||
        oldWidget.floorExtent != widget.floorExtent) {
      _schedulePublish();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _schedulePublish() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _publishCurrentInsets());

  void _publishCurrentInsets() {
    if (!mounted || !_isActive) return;

    final targetInsets = (
      padding: SheetViewportInsets.insetsFor(
        availableHeight: widget.availableHeight,
        pinnedExtent: widget.pinnedExtent,
        topInset: widget.topInset,
      ),
      focus: SheetViewportInsets.focusInsetsFor(
        availableHeight: widget.availableHeight,
        pinnedExtent: widget.pinnedExtent,
        topInset: widget.topInset,
        focusExtent: widget.focusExtent,
      ),
    );
    if (targetInsets != _targetInsets) {
      _targetInsets = targetInsets;
      widget.onInsetsChanged(targetInsets);
    }

    final targetRenderPadding = SheetViewportInsets.renderPaddingFor(
      availableHeight: widget.availableHeight,
      floorExtent: widget.floorExtent ?? widget.pinnedExtent,
      topInset: widget.topInset,
    );
    if (targetRenderPadding != _targetRenderPadding) {
      _targetRenderPadding = targetRenderPadding;
      widget.onRenderPaddingChanged?.call(targetRenderPadding);
    }
  }
}
