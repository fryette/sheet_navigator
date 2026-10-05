import 'package:flutter/material.dart';
import 'package:sheet_navigator/src/stack/sheet_bottom_bleed.dart';
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
        if (header case final header?) Builder(builder: header),
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
