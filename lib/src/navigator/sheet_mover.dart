import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

abstract interface class SheetMover {
  factory controller(SheetController controller) = _ControllerSheetMover;

  static SheetMover? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetMoverScope>()?.mover;

  static SheetMover of(BuildContext context) => switch (maybeOf(context)) {
    final mover? => mover,
    null => throw FlutterError(
      'SheetMover.of() was called with a context that has no SheetMoverScope above it.',
    ),
  };

  Future<void> moveTo(
    double snapExtent, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  });
}

class const SheetMoverScope({required final SheetMover mover, required super.child, super.key})
    extends InheritedWidget {
  @override
  bool updateShouldNotify(SheetMoverScope oldWidget) => mover != oldWidget.mover;
}

final class const _ControllerSheetMover(final SheetController _controller) implements SheetMover {
  @override
  Future<void> moveTo(
    double snapExtent, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) => _controller.hasClient
      ? _controller.animateTo(
          SheetOffset.proportionalToViewport(snapExtent),
          duration: duration,
          curve: curve,
        )
      : Future.value();
}
