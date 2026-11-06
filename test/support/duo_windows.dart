import 'dart:math' as math;

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One window: its size, the OS safe area, the native values, and the platform to theme.
typedef DuoWindow = ({
  String name,
  Size size,
  EdgeInsets padding,
  HorizontalEdge? edge,
  VerticalBarRegion? region,
  TargetPlatform platform,
  bool statusBarHidden,
});

/// The iPhone Duo inner landscape display. Recorded on the iOS 27.2 Simulator.
const DuoWindow innerLandscape = (
  name: 'iPhone Duo inner landscape',
  size: Size(951, 669),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(879, 124, 927, 635),
    edge: HorizontalEdge.right,
    viewSize: Size(951, 669),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

/// The right Split View window on iPhone Duo. Recorded on the iOS 27.2 Simulator.
const DuoWindow rightWindow = (
  name: 'iPhone Duo right Split View window',
  size: Size(469, 669),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(397, 124, 445, 635),
    edge: HorizontalEdge.right,
    viewSize: Size(469, 669),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

/// The left Split View window on iPhone Duo, without a side inset. Recorded on the iOS 27.2 Simulator.
const DuoWindow leftWindow = (
  name: 'iPhone Duo left Split View window',
  size: Size(469, 669),
  padding: EdgeInsets.only(bottom: 34),
  edge: HorizontalEdge.left,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(24, 16, 72, 635),
    edge: HorizontalEdge.left,
    viewSize: Size(469, 669),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

/// The inner landscape display before the native values arrive.
const DuoWindow firstFrame = (
  name: 'iPhone Duo inner landscape, first frame',
  size: Size(951, 669),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow innerPortrait = (
  name: 'iPhone Duo inner portrait',
  size: Size(669, 951),
  padding: EdgeInsets.only(top: 82, bottom: 34),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

/// The sample mixed from a rotation that the README describes.
const DuoWindow mixedRotation = (
  name: 'iPhone Duo inner portrait with a sample mixed from a rotation',
  size: Size(669, 951),
  padding: EdgeInsets.only(top: 82, bottom: 34),
  edge: HorizontalEdge.right,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(597, 82, 645, 917),
    edge: HorizontalEdge.right,
    viewSize: Size(669, 951),
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow iPhone17 = (
  name: 'iPhone 17 portrait',
  size: Size(402, 874),
  padding: EdgeInsets.only(top: 62, bottom: 34),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow iPhone17Landscape = (
  name: 'iPhone 17 landscape',
  size: Size(874, 402),
  padding: EdgeInsets.only(left: 62, right: 62, bottom: 20),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow iPadPortrait = (
  name: 'iPad Pro 13" portrait',
  size: Size(1032, 1376),
  padding: EdgeInsets.only(top: 32, bottom: 25),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow iPad = (
  name: 'iPad Pro 13" landscape',
  size: Size(1376, 1032),
  padding: EdgeInsets.only(top: 32, bottom: 25),
  edge: null,
  region: null,
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

const DuoWindow android = (
  name: 'Android phone',
  size: Size(412, 915),
  padding: EdgeInsets.only(top: 24, bottom: 24),
  edge: null,
  region: null,
  platform: TargetPlatform.android,
  statusBarHidden: false,
);

/// The iPhone Duo outer landscape display with the column on the right; the status bar is hidden there. The
/// region was recorded on the iOS 27.2 Simulator; the safe area is a fixture value.
const DuoWindow outerLandscapeRight = (
  name: 'iPhone Duo outer landscape (right column)',
  size: Size(678, 466),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(606, 2.3, 654, 384),
    edge: HorizontalEdge.right,
    viewSize: Size(678, 466),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: true,
);

/// The outer landscape display with the column on the left: the recorded region, with the fixture's
/// safe area. The status bar is hidden there.
const DuoWindow outerLandscapeLeft = (
  name: 'iPhone Duo outer landscape (left column)',
  size: Size(678, 466),
  padding: EdgeInsets.only(left: 84, bottom: 34),
  edge: HorizontalEdge.left,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(24, 82, 72, 432),
    edge: HorizontalEdge.left,
    viewSize: Size(678, 466),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: true,
);

/// The iPhone Duo outer portrait display, with the bottom inset of 34. The region was recorded on the
/// iOS 27.2 Simulator.
const DuoWindow outerPortrait = (
  name: 'iPhone Duo outer portrait',
  size: Size(466, 678),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  region: VerticalBarRegion(
    rect: Rect.fromLTRB(394, 174, 442, 644),
    edge: HorizontalEdge.right,
    viewSize: Size(466, 678),
    topBarTop: 24,
  ),
  platform: TargetPlatform.iOS,
  statusBarHidden: false,
);

/// [outerPortrait] with a bottom inset of 20 instead of 34, so that the column and the insets are also
/// checked with that geometry.
final DuoWindow outerPortraitBottom20 = outerPortrait.copyWith(padding: outerPortrait.padding.copyWith(bottom: 20));

/// Deliberate variants of a window, for a test that needs one value changed.
extension DuoWindowCopy on DuoWindow {
  /// This window with the given fields replaced; a null argument keeps the field.
  DuoWindow copyWith({
    String? name,
    Size? size,
    EdgeInsets? padding,
    HorizontalEdge? edge,
    VerticalBarRegion? region,
    TargetPlatform? platform,
    bool? statusBarHidden,
  }) => (
    name: name ?? this.name,
    size: size ?? this.size,
    padding: padding ?? this.padding,
    edge: edge ?? this.edge,
    region: region ?? this.region,
    platform: platform ?? this.platform,
    statusBarHidden: statusBarHidden ?? this.statusBarHidden,
  );
}

/// Sets the logical window [size] and the OS safe area [padding] at 1x, with a [keyboard] that tall, and
/// restores them at teardown. As on iOS, the keyboard is a bottom view inset that the bottom padding leaves
/// out, while the bottom view padding stays.
void useGeometry(WidgetTester tester, Size size, EdgeInsets padding, {double keyboard = 0}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..viewPadding = FakeViewPadding(left: padding.left, top: padding.top, right: padding.right, bottom: padding.bottom)
    ..padding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: math.max(0, padding.bottom - keyboard),
    )
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

/// [useGeometry] with the size and the OS safe area of [window].
void useWindow(WidgetTester tester, DuoWindow window, {double keyboard = 0}) =>
    useGeometry(tester, window.size, window.padding, keyboard: keyboard);

/// The scopes that `VerticalBarEdge` provides, then `SideStatusBarInsets`, around [child]:
/// `VerticalBarEdgeScope > BarRegionScope > SideStatusBarInsets`, with the native values of [window]
/// injected. [statusBarHidden] overrides the window's.
Widget duoScopes(DuoWindow window, Widget child, {bool? statusBarHidden}) => VerticalBarEdgeScope(
  edge: window.edge,
  statusBarHidden: statusBarHidden ?? window.statusBarHidden,
  child: BarRegionScope(
    verticalBar: window.region,
    child: SideStatusBarInsets(child: child),
  ),
);

/// The production chain `VerticalBarEdge > SideStatusBarInsets > app`, with the native values of
/// [window] injected. [statusBarHidden] overrides the window's; [around] wraps the root Navigator inside
/// the chain, as an application's player bar beside or below it does; [maxTextScale] clamps the text scale
/// around the chain.
Widget duoApp(
  DuoWindow window, {
  required Widget home,
  GlobalKey<NavigatorState>? navigatorKey,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  AnimationStyle? themeAnimationStyle,
  TextDirection? textDirection,
  bool? statusBarHidden,
  TransitionBuilder? around,
  double? maxTextScale,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: theme ?? ThemeData(platform: window.platform),
  darkTheme: darkTheme,
  themeMode: themeMode ?? ThemeMode.system,
  themeAnimationStyle: themeAnimationStyle,
  home: home,
  builder: (context, child) {
    final navigator = around == null ? child! : around(context, child);
    var result = duoScopes(window, navigator, statusBarHidden: statusBarHidden);
    if (maxTextScale != null) {
      result = MediaQuery.withClampedTextScaling(maxScaleFactor: maxTextScale, child: result);
    }
    return textDirection == null ? result : Directionality(textDirection: textDirection, child: result);
  },
);
