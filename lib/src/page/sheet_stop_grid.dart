import 'dart:math' as math;

abstract final class SheetStopGrid {
  static const expandedExtent = 1.0;
  static const _minTopEdgeGap = 100.0;

  static ({double floor, double resting, double expanded}) resolve({
    required double availableHeight,
    required double targetScreenFraction,
    double? floorExtent,
    double bottomBarInset = 0,
    double topInset = 0,
  }) {
    final expanded = availableHeight > 0
        ? (expandedExtent - topInset / availableHeight).clamp(0.0, expandedExtent)
        : expandedExtent;
    final contentAwareRestingExtent = availableHeight > 0
        ? _screenFractionRestingExtent(
            availableHeight: availableHeight,
            bottomBarInset: bottomBarInset,
            targetScreenFraction: targetScreenFraction,
          )
        : targetScreenFraction;
    final floor = math.min(floorExtent ?? contentAwareRestingExtent, expanded);
    final resting = math.max(contentAwareRestingExtent, floor).clamp(floor, expanded);
    return (floor: floor, resting: resting, expanded: expanded);
  }

  static double _screenFractionRestingExtent({
    required double availableHeight,
    required double bottomBarInset,
    required double targetScreenFraction,
  }) {
    final screenHeight = availableHeight + bottomBarInset;
    final contentParityResting = (targetScreenFraction * screenHeight / availableHeight).clamp(
      0.0,
      expandedExtent,
    );
    final minTopEdgeExtent = (1 - _minTopEdgeGap / availableHeight).clamp(0.0, expandedExtent);
    return math.min(contentParityResting, minTopEdgeExtent);
  }
}
