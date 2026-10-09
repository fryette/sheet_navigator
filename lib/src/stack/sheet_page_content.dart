import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:sheet_navigator/src/page/sheet_floor.dart';
import 'package:sheet_navigator/src/stack/sheet_bottom_bleed.dart';
import 'package:sheet_navigator/src/stack/sheet_controller_extent.dart';
import 'package:sheet_navigator/src/stack/sheet_floor_region.dart';
import 'package:sheet_navigator/src/stack/sheet_scrolled_content_drag_gate.dart';
import 'package:sheet_navigator/src/stack/sheet_visible_content.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetPageContent({
  required final SheetController controller,
  required final ScrollableWidgetBuilder builder,
  required final double viewportHeight,
  required final double contentBoxHeight,
  final WidgetBuilder? header,
  final WidgetBuilder? handle,
  final SheetFloor? floor,
  final List<double> snapSizes = const [],
  super.key,
}) extends StatelessWidget {
  static const handleTopPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final isBounded = viewportHeight.isFinite && viewportHeight > 0;

    final scrollSlot = SheetScrolledContentDragGate(
      controller: controller,
      child: Builder(builder: (context) => builder(context, PrimaryScrollController.of(context))),
    );

    final content = Column(
      children: [
        if (handle case final handle?)
          Padding(
            padding: const .only(top: handleTopPadding),
            child: Center(child: handle(context)),
          ),
        if (header case final header?)
          if (floor != null)
            SheetFloorRegion(child: Builder(builder: header))
          else
            Builder(builder: header),
        if (floor case final floor? when floor.trailingInset > 0)
          _FloorInsetSpacer(
            controller: controller,
            snapSizes: snapSizes,
            inset: floor.trailingInset,
          ),
        Expanded(
          child: isBounded
              ? LayoutBuilder(
                  builder: (context, constraints) => SheetVisibleContentScope(
                    controller: controller,
                    chromeHeight: contentBoxHeight - constraints.maxHeight,
                    child: scrollSlot,
                  ),
                )
              : scrollSlot,
        ),
      ],
    );

    return isBounded
        ? SheetBottomBleed(
            viewportHeight: viewportHeight,
            contentBoxHeight: contentBoxHeight,
            child: content,
          )
        : content;
  }
}

class const _FloorInsetSpacer({
  required final SheetController controller,
  required final List<double> snapSizes,
  required final double inset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SizedBox(height: _isNearestSnapFloor() ? inset : 0),
  );

  bool _isNearestSnapFloor() {
    final extent = controller.extent;
    final floorSnap = snapSizes.minOrNull;
    if (extent == null || floorSnap == null) return true;

    return minBy(snapSizes, (snap) => (snap - extent).abs()) == floorSnap;
  }
}
