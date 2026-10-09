import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_floor.dart';

class const SheetPage({
  required final Object pageKey,
  required final double initialSize,
  required final List<double> snapSizes,
  required final ScrollableWidgetBuilder builder,
  final WidgetBuilder? header,
  final double pinnedExtent = 0,
  final double backgroundTopInset = 0,
  final double? focusExtent,
  final SheetFloor? floor,
});
