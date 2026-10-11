import 'package:flutter/widgets.dart';

extension VisibleScrollPositions on ScrollController {
  Iterable<ScrollPosition> get visiblePositions {
    final attached = positions;
    if (attached.length < 2) return attached;

    return attached.where(
      (position) => TickerMode.getValuesNotifier(position.context.storageContext).value.enabled,
    );
  }
}
