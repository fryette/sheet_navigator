import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

final class const _Route() extends SheetRoute;

class _MinimalFeature() extends SheetFeature<_Route> {
  @override
  bool handles(_Route route) => true;

  @override
  SheetPage page(
    BuildContext context,
    _Route route,
    double availableHeight,
    SheetController controller,
  ) => SheetPage(
    pageKey: route.pageKey,
    initialSize: 0.5,
    snapSizes: const [0.5],
    builder: (context, scrollController) => const SizedBox.shrink(),
  );
}

void main() {
  testWidgets('a feature that overrides nothing else adds no scope, layer or reactions', (
    tester,
  ) async {
    final feature = _MinimalFeature();
    const child = SizedBox(key: ValueKey('scoped_child'));
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(feature.scope(context, child), same(child));
    expect(feature.layer(context, 'chrome', const _Route()), isNull);
    expect(feature.layerBottom(context, 'chrome', const _Route()), isNull);
    expect(() => feature.onBecameTop(context, const _Route()), returnsNormally);
    expect(() => feature.onAvailableHeightChanged(context, const _Route()), returnsNormally);
    expect(() => feature.onSettledAfterDrag(context, const _Route(), 0.5), returnsNormally);
  });
}
