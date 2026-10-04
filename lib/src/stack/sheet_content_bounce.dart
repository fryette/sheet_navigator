import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class SheetContentBounce() implements SheetScrollConfiguration {
  ScrollController? _content;

  @override
  SheetScrollHandlingBehavior get scrollSyncMode => SheetScrollHandlingBehavior.onlyFromTop;

  @override
  bool get delegateUnhandledOverscrollToChild {
    final position = _content?.positions.firstOrNull;
    return position != null &&
        position.hasContentDimensions &&
        position.maxScrollExtent > position.minScrollExtent &&
        position.pixels > position.minScrollExtent;
  }

  ScrollableWidgetBuilder track(ScrollableWidgetBuilder builder) => (context, controller) {
    _content = controller;
    return builder(context, controller);
  };
}
