import 'dart:math' as math;

enum SheetSnapState() {
  collapsed,
  mid,
  expanded,
  between;

  static const tolerance = 0.01;

  static SheetSnapState classify(double extent, List<double> snapSizes) {
    if (snapSizes.isEmpty) return .between;

    final floor = snapSizes.reduce(math.min);
    final expanded = snapSizes.reduce(math.max);
    final resting = snapSizes.where((snap) => snap < expanded).fold(floor, math.max);
    if ((extent - expanded).abs() <= tolerance) {
      return .expanded;
    } else if ((extent - resting).abs() <= tolerance) {
      return .mid;
    } else if ((extent - floor).abs() <= tolerance) {
      return .collapsed;
    } else {
      return .between;
    }
  }
}
