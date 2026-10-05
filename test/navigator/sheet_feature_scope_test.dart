import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

final class const _RootRoute() extends SheetRoute;

class const _Level({required super.notifier, required super.child})
    extends InheritedNotifier<ValueNotifier<double>> {
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Level>()!.notifier!.value;
}

class _ScopedFeature(final ValueNotifier<double> notifier) with SheetFeature<SheetRoute> {
  final seenLevels = <double>[];

  @override
  bool handles(SheetRoute route) => true;

  @override
  Widget scope(BuildContext context, Widget child) => _Level(notifier: notifier, child: child);

  @override
  SheetPage page(
    BuildContext context,
    SheetRoute route,
    double availableHeight,
    SheetController controller,
  ) {
    final level = _Level.of(context);
    seenLevels.add(level);
    return SheetPage(
      pageKey: route.pageKey,
      initialSize: level,
      snapSizes: [level, 0.9],
      builder: (context, scrollController) => const SizedBox.expand(),
    );
  }
}

Future<void> _pump(WidgetTester tester, _ScopedFeature feature, {List<List<double>>? snapLog}) =>
    tester.pumpWidget(
      MaterialApp(
        home: SheetNavigator<SheetRoute, _ScopedFeature>(
          features: [feature],
          stack: const [_RootRoute()],
          style: SheetNavigatorStyle(surfaceBuilder: (context, card) => card),
          sheetLayerWrapper: (context, state, child) {
            snapLog?.add(state.topPage.snapSizes);
            return child;
          },
          onPopRequested: () {},
          onRouteExited: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('page reads an inherited widget installed by its feature scope', (tester) async {
    final feature = _ScopedFeature(ValueNotifier(0.4));
    addTearDown(feature.notifier.dispose);

    await _pump(tester, feature);

    expect(tester.takeException(), isNull);
    expect(feature.seenLevels, contains(0.4));
  });

  testWidgets('page is rebuilt with new snap sizes when the scoped value changes', (tester) async {
    final feature = _ScopedFeature(ValueNotifier(0.4));
    addTearDown(feature.notifier.dispose);
    final snapLog = <List<double>>[];
    await _pump(tester, feature, snapLog: snapLog);
    expect(snapLog.last, [0.4, 0.9]);

    feature.notifier.value = 0.6;
    await tester.pump();

    expect(feature.seenLevels, contains(0.6));
    expect(snapLog.last, [0.6, 0.9]);
  });
}
