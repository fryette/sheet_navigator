import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_navigator/sheet_navigator.dart';

const _snapSizes = [0.2, 0.5, 0.9];

void main() {
  group('SheetSnapState.classify', () {
    test('is expanded at the largest snap', () {
      expect(SheetSnapState.classify(0.9, _snapSizes), SheetSnapState.expanded);
    });

    test('is mid at the largest snap below the expanded one', () {
      expect(SheetSnapState.classify(0.5, _snapSizes), SheetSnapState.mid);
    });

    test('is collapsed at the smallest snap', () {
      expect(SheetSnapState.classify(0.2, _snapSizes), SheetSnapState.collapsed);
    });

    test('is between away from every snap', () {
      expect(SheetSnapState.classify(0.7, _snapSizes), SheetSnapState.between);
    });

    test('accepts an extent within the tolerance of a snap', () {
      expect(
        SheetSnapState.classify(0.9 - SheetSnapState.tolerance / 2, _snapSizes),
        SheetSnapState.expanded,
      );
      expect(
        SheetSnapState.classify(0.5 + SheetSnapState.tolerance / 2, _snapSizes),
        SheetSnapState.mid,
      );
    });

    test('rejects an extent just outside the tolerance of a snap', () {
      expect(
        SheetSnapState.classify(0.9 - 2 * SheetSnapState.tolerance, _snapSizes),
        SheetSnapState.between,
      );
    });

    test('treats a two-stop page as collapsed-is-mid, preferring mid', () {
      expect(SheetSnapState.classify(0.3, const [0.3, 0.8]), SheetSnapState.mid);
    });

    test('treats a single-stop page as expanded', () {
      expect(SheetSnapState.classify(0.6, const [0.6]), SheetSnapState.expanded);
    });

    test('is between when the page declares no snaps', () {
      expect(SheetSnapState.classify(0.5, const []), SheetSnapState.between);
    });

    test('ignores the order of the declared snaps', () {
      expect(SheetSnapState.classify(0.5, const [0.9, 0.2, 0.5]), SheetSnapState.mid);
    });
  });
}
