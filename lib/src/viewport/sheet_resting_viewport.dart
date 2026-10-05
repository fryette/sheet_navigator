import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/navigator/sheet_viewport_state.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';

@immutable
class const SheetRestingViewport({
  required final double restingExtent,
  required final EdgeInsets insets,
  required final Size size,
  required final Object topPageKey,
  required final List<Object> pageKeys,
}) {
  static const gap = 12.0;

  static SheetRestingViewport? resolve({
    required SheetPage topPage,
    required SheetSettledSnap? settledSnap,
    required Size size,
    required List<Object> pageKeys,
  }) {
    final restingExtent = restingExtentFor(topPage, settledSnap);
    if (restingExtent == null) return null;

    return SheetRestingViewport(
      restingExtent: restingExtent,
      insets: EdgeInsets.only(
        top: topPage.backgroundTopInset + gap,
        bottom: restingExtent * size.height + gap,
      ),
      size: size,
      topPageKey: topPage.pageKey,
      pageKeys: pageKeys,
    );
  }

  static double? restingSnapFor(SheetPage page) {
    if (page.snapSizes.isEmpty) return null;

    final lowest = page.snapSizes.reduce(math.min);
    final largest = page.snapSizes.reduce(math.max);
    return page.snapSizes.where((snap) => snap < largest).fold<double>(lowest, math.max);
  }

  static double? restingExtentFor(SheetPage page, SheetSettledSnap? settledSnap) {
    final restingSnap = restingSnapFor(page);
    if (restingSnap == null) return null;

    final lowest = page.snapSizes.reduce(math.min);
    final settled = settledSnap?.pageKey == page.pageKey ? settledSnap?.extent : null;
    return (settled ?? page.initialSize).clamp(lowest, restingSnap);
  }

  @override
  bool operator ==(Object other) =>
      other is SheetRestingViewport &&
      other.restingExtent == restingExtent &&
      other.insets == insets &&
      other.size == size &&
      other.topPageKey == topPageKey &&
      listEquals(other.pageKeys, pageKeys);

  @override
  int get hashCode =>
      Object.hash(restingExtent, insets, size, topPageKey, Object.hashAll(pageKeys));
}
