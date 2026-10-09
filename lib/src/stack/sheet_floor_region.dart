import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/page/sheet_floor.dart';
import 'package:sheet_navigator/src/page/sheet_page_scope.dart';

class const SheetFloorRegion({required final Widget child, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _FloorRegionRender(
    onHeightChanged: context.getInheritedWidgetOfExactType<SheetPageScope>()?.onFloorMeasured,
    child: child,
  );
}

class const _FloorRegionRender({
  required final ValueChanged<double>? onHeightChanged,
  required super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFloorRegion(onHeightChanged: onHeightChanged);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderFloorRegion renderObject) =>
      renderObject.onHeightChanged = onHeightChanged;
}

class _RenderFloorRegion extends RenderProxyBox {
  new({this.onHeightChanged});

  ValueChanged<double>? onHeightChanged;
  double? _lastReported;
  var _isReportScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_isReportScheduled || height <= 0) return;

    final last = _lastReported;
    if (last != null && (height - last).abs() <= SheetFloor.measurementTolerance) return;

    _isReportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    _isReportScheduled = false;
    final height = size.height;
    _lastReported = height;
    onHeightChanged?.call(height);
  }
}
