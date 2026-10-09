import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sheet_navigator/src/page/sheet_page.dart';

@immutable
class const SheetFloor({
  required final double defaultRegionHeight,
  final double leadingHeight = 0,
  final double trailingInset = 0,
}) {
  static const measurementTolerance = 0.5;

  double extentFor({required double? measuredRegionHeight, required double availableHeight}) =>
      (leadingHeight + (measuredRegionHeight ?? defaultRegionHeight) + trailingInset) /
      availableHeight;

  @override
  bool operator ==(Object other) =>
      other is SheetFloor &&
      other.defaultRegionHeight == defaultRegionHeight &&
      other.leadingHeight == leadingHeight &&
      other.trailingInset == trailingInset;

  @override
  int get hashCode => Object.hash(defaultRegionHeight, leadingHeight, trailingInset);
}

typedef SheetFloorResolution = ({List<double> snapSizes, double initialSize, double floorExtent});

class SheetFloorResolver() {
  @visibleForTesting
  static int resolveCount = 0;

  List<double>? _snapSizes;
  double? _initialSize;
  SheetFloor? _floor;
  double? _regionHeight;
  double? _availableHeight;
  SheetFloorResolution? _resolution;

  @visibleForTesting
  SheetFloorResolution? get lastResolution => _resolution;

  SheetFloorResolution resolve({
    required SheetPage page,
    required SheetFloor floor,
    required double? measuredRegionHeight,
    required double availableHeight,
  }) {
    final regionHeight = measuredRegionHeight ?? floor.defaultRegionHeight;
    final cached = _resolution;
    if (cached != null &&
        _floor == floor &&
        _regionHeight == regionHeight &&
        _availableHeight == availableHeight &&
        _initialSize == page.initialSize &&
        listEquals(_snapSizes, page.snapSizes)) {
      return cached;
    }

    assert(() {
      resolveCount++;
      return true;
    }());
    _snapSizes = page.snapSizes;
    _initialSize = page.initialSize;
    _floor = floor;
    _regionHeight = regionHeight;
    _availableHeight = availableHeight;
    return _resolution = _compute(page, floor, measuredRegionHeight, availableHeight);
  }

  static SheetFloorResolution _compute(
    SheetPage page,
    SheetFloor floor,
    double? measuredRegionHeight,
    double availableHeight,
  ) {
    if (availableHeight <= 0) {
      return (snapSizes: page.snapSizes, initialSize: page.initialSize, floorExtent: 0);
    }

    final expanded = page.snapSizes.isEmpty ? 1.0 : page.snapSizes.reduce(math.max);
    final floorExtent = math.min(
      floor.extentFor(measuredRegionHeight: measuredRegionHeight, availableHeight: availableHeight),
      expanded,
    );
    final snapSizes = <double>{
      floorExtent,
      for (final snap in page.snapSizes) math.max(snap, floorExtent),
    }.toList()..sort();
    return (
      snapSizes: snapSizes,
      initialSize: math.max(page.initialSize, floorExtent),
      floorExtent: floorExtent,
    );
  }
}
