import 'dart:async';

import 'package:sheet_navigator/src/route/sheet_route.dart';

class SheetNavigatorController<R extends SheetRoute>({required final R root}) {
  R _root = root;
  final List<R> _tail = [];
  final _stackChangesController = StreamController<List<R>>.broadcast();
  final _returnedToRootController = StreamController<void>.broadcast();
  final _pendingRootReturnPageKeys = <Object>{};

  List<R> get stack => List.unmodifiable([_root, ..._tail]);

  R get current => _tail.lastOrNull ?? _root;

  int get depth => _tail.length + 1;

  bool get canPop => depth > 1;

  Stream<List<R>> get stackChanges => _stackChangesController.stream;

  Stream<void> get returnedToRoot => _returnedToRootController.stream;

  void push(R route) {
    if (route.pageKey == current.pageKey) {
      _updateTop(route);
      return;
    }
    if (stack.contains(route)) return;

    _tail.add(route);
    _emitStackChange();
  }

  bool pop() {
    if (depth == 1) return false;

    final removed = _tail.removeLast();
    if (depth == 1) _armPendingRootReturn({removed.pageKey});
    _emitStackChange();
    return true;
  }

  void popToRoot() {
    if (depth == 1) return;

    final removedPageKeys = _tail.map((route) => route.pageKey).toSet();
    _tail.clear();
    _armPendingRootReturn(removedPageKeys);
    _emitStackChange();
  }

  void replaceTop(R route) {
    if (route.pageKey == current.pageKey) {
      _updateTop(route);
      return;
    }
    if (stack.contains(route)) return;

    _setTop(route);
    _emitStackChange();
  }

  void notifyRouteExited(R route) {
    if (!_pendingRootReturnPageKeys.remove(route.pageKey)) return;
    if (_pendingRootReturnPageKeys.isEmpty && depth == 1) {
      _returnedToRootController.add(null);
    }
  }

  void dispose() {
    unawaited(_stackChangesController.close());
    unawaited(_returnedToRootController.close());
  }

  void _updateTop(R route) {
    if (identical(route, current)) return;

    _setTop(route);
    _emitStackChange();
  }

  void _setTop(R route) {
    if (_tail.isEmpty) {
      _root = route;
    } else {
      _tail[_tail.length - 1] = route;
    }
  }

  void _armPendingRootReturn(Set<Object> pageKeys) {
    _pendingRootReturnPageKeys
      ..clear()
      ..addAll(pageKeys);
  }

  void _emitStackChange() => _stackChangesController.add(stack);
}
