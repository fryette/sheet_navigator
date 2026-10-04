import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetPointerCancelGuard({
  required final SheetController controller,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<SheetPointerCancelGuard> createState() => _SheetPointerCancelGuardState();
}

class _SheetPointerCancelGuardState() extends State<SheetPointerCancelGuard> {
  int? _activePointer;
  double? _dragStartOffset;
  bool _isPointerCancelled = false;

  void _handlePointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _isPointerCancelled = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointer) _isPointerCancelled = true;
  }

  bool _handleSheetNotification(SheetNotification notification) {
    switch (notification) {
      case SheetDragStartNotification():
        _dragStartOffset = notification.metrics.offset;
        _isPointerCancelled = false;
      case SheetDragEndNotification() || SheetDragCancelNotification():
        _restoreIfPointerCancelled();
      case SheetUpdateNotification() ||
          SheetDragUpdateNotification() ||
          SheetOverflowNotification():
        break;
    }
    return false;
  }

  void _restoreIfPointerCancelled() {
    final startOffset = _dragStartOffset;
    final isPointerCancelled = _isPointerCancelled;
    _dragStartOffset = null;
    _isPointerCancelled = false;
    if (!isPointerCancelled || startOffset == null) return;

    final controller = widget.controller;
    scheduleMicrotask(() {
      if (!controller.hasClient) return;
      controller.animateTo(SheetOffset.absolute(startOffset), curve: Curves.easeInOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: .translucent,
    onPointerDown: _handlePointerDown,
    onPointerCancel: _handlePointerCancel,
    child: NotificationListener<SheetNotification>(
      onNotification: _handleSheetNotification,
      child: widget.child,
    ),
  );
}
