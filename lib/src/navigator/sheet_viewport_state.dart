import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';

typedef SheetSettledSnap = ({Object pageKey, double extent});

typedef SheetLayerWrapper = Widget Function(
  BuildContext context,
  SheetViewportState viewport,
  Widget sheetLayer,
);

class const SheetViewportState({
  required final SheetPage topPage,
  required final double availableWidth,
  required final double availableHeight,
  required final SheetSettledSnap? settledSnap,
});
