import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

const sheetOvershootExtent = 8.0;

double sheetBottomBleedFor({required double viewportHeight, required double contentBoxHeight}) =>
    (viewportHeight - contentBoxHeight).clamp(0.0, sheetOvershootExtent);

class SnapBounceSheetPhysics() extends SheetPhysics with SheetPhysicsMixin {
  static const _peakOvershoot = 2.0;
  static const _minBounceVelocity = 100.0;

  bool _isSettling = false;

  @override
  late final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 121,
    ratio: 0.85,
  );

  @override
  double computeOverflow(double delta, SheetMetrics metrics) {
    if (!_isSettling) return super.computeOverflow(delta, metrics);

    final newOffset = metrics.offset + delta;
    final upperBound = metrics.maxOffset + _upperAllowance(metrics);
    final lowerBound = metrics.minOffset - sheetOvershootExtent;
    if (newOffset > upperBound) return math.min(newOffset - upperBound, delta);
    if (newOffset < lowerBound) return math.max(newOffset - lowerBound, delta);
    return 0;
  }

  @override
  double applyPhysicsToOffset(double delta, SheetMetrics metrics) {
    _isSettling = false;
    return super.applyPhysicsToOffset(delta, metrics);
  }

  @override
  Simulation? createBallisticSimulation(
    double velocity,
    SheetMetrics metrics,
    SheetSnapGrid snapGrid,
  ) {
    final snap = snapGrid.getSnapOffset(metrics, metrics.offset, velocity).resolve(metrics);
    final isSettlingToSnap = super.createBallisticSimulation(velocity, metrics, snapGrid) != null;
    final pushesIntoBound =
        velocity > _minBounceVelocity &&
            _isApprox(snap, metrics.maxOffset, metrics) &&
            _upperAllowance(metrics) > 0 ||
        velocity < -_minBounceVelocity && _isApprox(snap, metrics.minOffset, metrics);
    if (!isSettlingToSnap && !pushesIntoBound) {
      _isSettling = false;
      return null;
    }

    final direction = isSettlingToSnap ? (snap - metrics.offset).sign : velocity.sign;
    final launchVelocity = velocity.sign == direction ? velocity : 0.0;
    _isSettling = true;
    return ScrollSpringSimulation(
      spring,
      metrics.offset,
      snap,
      _limitVelocity(
        metrics.offset,
        snap,
        launchVelocity,
        direction,
        direction > 0 && _isApprox(snap, metrics.maxOffset, metrics)
            ? math.min(_peakOvershoot, _upperAllowance(metrics))
            : _peakOvershoot,
      ),
    );
  }

  double _upperAllowance(SheetMetrics metrics) => sheetBottomBleedFor(
    viewportHeight: metrics.viewportSize.height,
    contentBoxHeight: metrics.maxOffset,
  );

  bool _isApprox(double a, double b, SheetMetrics metrics) =>
      (a - b).abs() < 1 / metrics.devicePixelRatio;

  double _limitVelocity(double from, double snap, double velocity, double direction, double limit) {
    if (_overshootOf(from, snap, velocity, direction) <= limit) return velocity;

    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 14; i++) {
      final scale = (low + high) / 2;
      if (_overshootOf(from, snap, velocity * scale, direction) <= limit) {
        low = scale;
      } else {
        high = scale;
      }
    }
    return velocity * low;
  }

  double _overshootOf(double from, double snap, double velocity, double direction) {
    final simulation = ScrollSpringSimulation(spring, from, snap, velocity);
    var peak = 0.0;
    for (var i = 1; i <= 120; i++) {
      peak = math.max(peak, (simulation.x(i * (1 / 120)) - snap) * direction);
    }
    return peak;
  }
}
