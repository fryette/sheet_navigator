import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetVisibleContentScope({
  required final SheetController controller,
  required final double chromeHeight,
  required super.child,
  super.key,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(SheetVisibleContentScope oldWidget) =>
      controller != oldWidget.controller || chromeHeight != oldWidget.chromeHeight;
}

class const SheetVisibleContent({required final Widget child, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SheetVisibleContentScope>();
    if (scope == null) return child;

    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: scope.controller,
        builder: (context, _) {
          final contentBoxHeight = scope.chromeHeight + constraints.maxHeight;
          final visibleHeight =
              ((scope.controller.metrics?.offset ?? contentBoxHeight) - scope.chromeHeight).clamp(
                0.0,
                constraints.maxHeight,
              );

          return Align(
            alignment: .topCenter,
            child: SizedBox(height: visibleHeight, width: double.infinity, child: child),
          );
        },
      ),
    );
  }
}
