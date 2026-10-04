import 'package:flutter/foundation.dart';

@immutable
abstract class const SheetRoute() {
  Object get pageKey => runtimeType;

  @override
  bool operator ==(Object other) => other is SheetRoute && other.pageKey == pageKey;

  @override
  int get hashCode => pageKey.hashCode;
}
