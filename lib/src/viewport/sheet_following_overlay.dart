import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class const SheetFollowingOverlay({
  required final ValueListenable<double?> extent,
  required final double availableHeight,
  required final double standardExtent,
  required final double gap,
  required final Widget child,
  final double? left,
  final double? right,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: extent,
    builder: (context, extent, child) => switch (child) {
      final child? => _OverlaySlot(
        availableHeight: availableHeight,
        extent: extent,
        standardExtent: standardExtent,
        gap: gap,
        left: left,
        right: right,
        child: child,
      ),
      null => const SizedBox.shrink(),
    },
    child: child,
  );
}

class const _OverlaySlot({
  required final double availableHeight,
  required final double? extent,
  required final double standardExtent,
  required final double gap,
  required final Widget child,
  final double? left,
  final double? right,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final resolvedExtent = extent ?? standardExtent;
    final offset = math.min(resolvedExtent, standardExtent) * availableHeight + gap;
    final isOccluded = resolvedExtent * availableHeight > offset;

    final (Alignment alignment, EdgeInsetsGeometry padding) = switch ((left, right)) {
      (final left?, _) => (.bottomLeft, .only(left: left, bottom: offset)),
      (_, final right?) => (.bottomRight, .only(right: right, bottom: offset)),
      (null, null) => (.bottomRight, .only(bottom: offset)),
    };

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ExcludeSemantics(excluding: isOccluded, child: child),
      ),
    );
  }
}
