import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/navigator/sheet_feature.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';
import 'package:sheet_navigator/src/route/sheet_route.dart';

typedef SheetLayerBuilder<R extends SheetRoute, F extends SheetFeature<R>> = Widget Function(
  BuildContext context,
  SheetLayerContext<R, F> layer,
);

class const SheetOverlayLayer<R extends SheetRoute, F extends SheetFeature<R>>({
  required final Object id,
  final Key? key,
  final SheetLayerBuilder<R, F>? persistentBuilder,
});

class const SheetLayerContext<R extends SheetRoute, F extends SheetFeature<R>>({
  required final R topRoute,
  required final F topFeature,
  required final SheetPage topPage,
  required final ValueListenable<double?> visualTopExtent,
  required final double availableWidth,
  required final double availableHeight,
});
