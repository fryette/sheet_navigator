import 'package:smooth_sheets/smooth_sheets.dart';

extension SheetControllerExtent on SheetController {
  double? get extent => switch (metrics) {
    final metrics? when metrics.viewportSize.height > 0 =>
      metrics.offset / metrics.viewportSize.height,
    _ => null,
  };
}
