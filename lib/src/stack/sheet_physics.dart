import 'package:flutter/physics.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

final defaultSheetPhysics = ClampingSheetPhysics(
  spring: SpringDescription.withDampingRatio(mass: 0.5, stiffness: 121, ratio: 1.1),
);
