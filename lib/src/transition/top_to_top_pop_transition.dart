import 'package:sheet_navigator/src/transition/in_place_sheet_transition.dart';
import 'package:sheet_navigator/src/transition/sheet_motion_tokens.dart';

class const TopToTopPopTransition() extends InPlaceSheetTransition {
  @override
  double returningAlpha(double progress) => sheetTopToTopFadeIn.transform(progress);
}
