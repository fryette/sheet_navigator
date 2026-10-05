import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

final class const _RootRoute() extends SheetRoute;

final class const _ListRoute() extends SheetRoute;

final class const _DetailsRoute() extends SheetRoute;

void main() {
  late SheetNavigatorController<SheetRoute> controller;

  setUp(() => controller = SheetNavigatorController<SheetRoute>(root: const _RootRoute()));

  tearDown(() => controller.dispose());

  group('stack', () {
    test('starts with only the root route', () {
      expect(controller.stack, const [_RootRoute()]);
      expect(controller.current, const _RootRoute());
      expect(controller.depth, 1);
    });

    test('push adds a route to the top of the stack', () {
      controller.push(const _ListRoute());

      expect(controller.depth, 2);
      expect(controller.current, const _ListRoute());
      expect(controller.stack, const [_RootRoute(), _ListRoute()]);
    });

    test('push emits the new stack once on stackChanges', () async {
      final expectation = expectLater(
        controller.stackChanges,
        emits(const [_RootRoute(), _ListRoute()]),
      );

      controller.push(const _ListRoute());

      await expectation;
    });

    test('pushing the route already on top is a no-op', () async {
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.push(const _RootRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      expect(controller.depth, 1);
      await subscription.cancel();
    });

    test('pushing a route already deeper in the stack is a no-op', () async {
      controller
        ..push(const _ListRoute())
        ..push(const _DetailsRoute());
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller
        ..push(const _RootRoute())
        ..push(const _ListRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      expect(controller.stack, const [_RootRoute(), _ListRoute(), _DetailsRoute()]);
      await subscription.cancel();
    });

    test('pop at the root returns false and emits nothing', () async {
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      final popped = controller.pop();
      await pumpEventQueue();

      expect(popped, isFalse);
      expect(emissions, isEmpty);
      expect(controller.depth, 1);
      await subscription.cancel();
    });

    test('pop after two pushes restores the previous route', () {
      controller
        ..push(const _ListRoute())
        ..push(const _DetailsRoute());

      final popped = controller.pop();

      expect(popped, isTrue);
      expect(controller.current, const _ListRoute());
      expect(controller.depth, 2);
    });

    test('popToRoot from depth 3 restores only the root and emits once', () async {
      controller
        ..push(const _ListRoute())
        ..push(const _DetailsRoute());
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.popToRoot();
      await pumpEventQueue();

      expect(controller.stack, const [_RootRoute()]);
      expect(controller.depth, 1);
      expect(emissions, hasLength(1));
      await subscription.cancel();
    });

    test('popToRoot at the root is a no-op', () async {
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.popToRoot();
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });

    test('stackChanges is a broadcast stream reaching multiple listeners', () async {
      final firstListenerExpectation = expectLater(
        controller.stackChanges,
        emits(const [_RootRoute(), _ListRoute()]),
      );
      final secondListenerExpectation = expectLater(
        controller.stackChanges,
        emits(const [_RootRoute(), _ListRoute()]),
      );

      controller.push(const _ListRoute());

      await Future.wait([firstListenerExpectation, secondListenerExpectation]);
    });

    test('dispose closes the stackChanges stream', () async {
      final expectation = expectLater(controller.stackChanges, emitsDone);

      controller.dispose();

      await expectation;
    });
  });

  group('returnedToRoot', () {
    test('pop to root does not emit until the removed route reports exited', () async {
      controller.push(const _ListRoute());
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller.pop();
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });

    test('pop to root emits exactly once after the removed route reports exited', () async {
      controller.push(const _ListRoute());
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller.pop();
      controller.notifyRouteExited(const _ListRoute());
      await pumpEventQueue();

      expect(emissions, hasLength(1));
      await subscription.cancel();
    });

    test('pop that does not reach root never emits, even after the removed route exits', () async {
      controller
        ..push(const _ListRoute())
        ..push(const _DetailsRoute());
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller.pop();
      controller.notifyRouteExited(const _DetailsRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });

    test(
      'popToRoot from depth 3 emits only once, after both removed routes report exited',
      () async {
        controller
          ..push(const _ListRoute())
          ..push(const _DetailsRoute());
        final emissions = <void>[];
        final subscription = controller.returnedToRoot.listen(emissions.add);

        controller.popToRoot();
        controller.notifyRouteExited(const _DetailsRoute());
        await pumpEventQueue();
        expect(emissions, isEmpty);

        controller.notifyRouteExited(const _ListRoute());
        await pumpEventQueue();

        expect(emissions, hasLength(1));
        await subscription.cancel();
      },
    );

    test('notifying a route that was not removed is a no-op', () async {
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller.notifyRouteExited(const _ListRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });

    test('a stale exit signal for a route removed by a superseded pop is ignored once a later '
        'pop has re-armed the pending set for a different route', () async {
      controller.push(const _ListRoute());
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller.pop();
      controller
        ..push(const _DetailsRoute())
        ..pop();

      controller.notifyRouteExited(const _ListRoute());
      await pumpEventQueue();
      expect(emissions, isEmpty);

      controller.notifyRouteExited(const _DetailsRoute());
      await pumpEventQueue();
      expect(emissions, hasLength(1));

      await subscription.cancel();
    });

    test('dispose closes the returnedToRoot stream', () async {
      final expectation = expectLater(controller.returnedToRoot, emitsDone);

      controller.dispose();

      await expectation;
    });
  });

  group('canPop', () {
    test('is false at the root and true once a route is pushed', () {
      expect(controller.canPop, isFalse);

      controller.push(const _ListRoute());

      expect(controller.canPop, isTrue);
    });
  });

  group('replaceTop', () {
    test('swaps the top route in place and emits the new stack once', () async {
      controller.push(const _ListRoute());
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.replaceTop(const _DetailsRoute());
      await pumpEventQueue();

      expect(controller.stack, const [_RootRoute(), _DetailsRoute()]);
      expect(emissions, [
        const [_RootRoute(), _DetailsRoute()],
      ]);
      await subscription.cancel();
    });

    test('replacing the only route swaps the root and emits the new stack once', () async {
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.replaceTop(const _DetailsRoute());
      await pumpEventQueue();

      expect(controller.stack, const [_DetailsRoute()]);
      expect(controller.depth, 1);
      expect(emissions, [
        const [_DetailsRoute()],
      ]);
      await subscription.cancel();
    });

    test('replacing the top with the route already on top is a no-op', () async {
      final emissions = <List<SheetRoute>>[];
      final subscription = controller.stackChanges.listen(emissions.add);

      controller.replaceTop(const _RootRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });

    test('never arms returnedToRoot, even when the replaced route reports exited', () async {
      controller.push(const _ListRoute());
      final emissions = <void>[];
      final subscription = controller.returnedToRoot.listen(emissions.add);

      controller
        ..replaceTop(const _DetailsRoute())
        ..notifyRouteExited(const _ListRoute());
      await pumpEventQueue();

      expect(emissions, isEmpty);
      await subscription.cancel();
    });
  });
}
