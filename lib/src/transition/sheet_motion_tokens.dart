import 'package:flutter/material.dart';

const sheetPushDuration = Duration(milliseconds: 320);
const sheetPopDuration = Duration(milliseconds: 380);
const sheetTravelReferenceDelta = 0.47;
const sheetTravelReferenceDuration = Duration(milliseconds: 340);
const sheetTravelMinDuration = Duration(milliseconds: 240);
const sheetTravelMaxDuration = Duration(milliseconds: 440);

const sheetEnterCurve = Easing.emphasizedDecelerate;
const sheetExitCurve = Cubic(0.3333, 0, 0.6667, 0);

const sheetEnterTranslate = Interval(0.15, 1.0, curve: sheetEnterCurve);
const sheetExitTranslate = Interval(0.0, 0.66, curve: sheetExitCurve);

const sheetInPlaceScale = 0.969;
const sheetInPlacePushScaleWindow = Interval(0.0, 0.2);
const sheetInPlacePopScaleWindow = Interval(0.6, 1.0);
const sheetInPlaceFadeOut = Interval(0.0, 0.65);
const sheetInPlaceFadeIn = Interval(0.26, 0.92, curve: Curves.easeOut);
const sheetTopToTopFadeIn = Interval(0.0, 0.45, curve: Curves.easeOut);

const sheetBackgroundScaleGain = 0.1;
const sheetTravelTranslate = Interval(0.0, 1.0, curve: Curves.easeOutCubic);
const sheetTravelScaleWindow = Interval(0.25, 1.0);
const sheetTravelFadeOut = Interval(0.35, 0.8);
const sheetTravelFadeIn = Interval(0.0, 0.3);

Duration sheetTravelDurationFor(double backgroundDelta) => Duration(
  milliseconds:
      (sheetTravelReferenceDuration.inMilliseconds * backgroundDelta / sheetTravelReferenceDelta)
          .round()
          .clamp(sheetTravelMinDuration.inMilliseconds, sheetTravelMaxDuration.inMilliseconds),
);
