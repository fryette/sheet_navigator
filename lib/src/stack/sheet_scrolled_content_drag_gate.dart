import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetScrolledContentDragGate({
  required final SheetController controller,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  static const _tolerance = 1.0;

  @override
  Widget build(BuildContext context) {
    final scrollController = PrimaryScrollController.maybeOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?scrollController]),
      builder: (context, child) => ScrollConfiguration(
        behavior: _isSheetDragOnly(scrollController)
            ? ScrollConfiguration.of(context).copyWith(dragDevices: const {})
            : ScrollConfiguration.of(context),
        child: child!,
      ),
      child: child,
    );
  }

  bool _isSheetDragOnly(ScrollController? scrollController) {
    final metrics = controller.metrics;
    if (metrics == null || scrollController == null) return false;
    if (metrics.offset >= metrics.maxOffset - _tolerance) return false;

    return scrollController.positions.any(
      (position) =>
          position.hasContentDimensions && position.pixels > position.minScrollExtent + _tolerance,
    );
  }
}
