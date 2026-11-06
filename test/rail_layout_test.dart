import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/duo_windows.dart';

/// Example application rule: show a rail at a window width of 600 or more.
bool _showsRail(double windowWidth) => windowWidth >= 600;

/// The width of the example's width-based rail.
const double _railWidth = 80;

/// Every window of `support/duo_windows.dart`, plus the iPhone 17 windows with a native edge injected.
final List<DuoWindow> _windows = [
  innerLandscape,
  rightWindow,
  leftWindow,
  firstFrame,
  innerPortrait,
  mixedRotation,
  iPhone17,
  iPhone17.copyWith(name: 'iPhone 17 portrait with a left edge', edge: HorizontalEdge.left),
  iPhone17.copyWith(name: 'iPhone 17 portrait with a right edge', edge: HorizontalEdge.right),
  iPhone17Landscape,
  iPhone17Landscape.copyWith(name: 'iPhone 17 landscape with a left edge', edge: HorizontalEdge.left),
  iPhone17Landscape.copyWith(name: 'iPhone 17 landscape with a right edge', edge: HorizontalEdge.right),
  iPadPortrait,
  iPad,
  android,
  outerLandscapeRight,
  outerLandscapeLeft,
  outerPortrait,
  outerPortraitBottom20.copyWith(name: 'iPhone Duo outer portrait with a bottom inset of 20'),
];

/// The values a rail reads: the fields of a [RailLayout], its getters, and its two method results.
typedef _HandWritten = ({
  RailPlacement? placement,
  double width,
  EdgeInsets safeArea,
  HorizontalEdge? edge,
  bool followsSystemBar,
  double occupiedWidth,
  EdgeInsets centredSafeArea,
  Rect contentRect,
  MediaQueryData body,
});

/// The hand-written sequence: [RailPlacement.of], [RailPlacement.railSafeAreaOf], then the values derived from them.
_HandWritten _handWritten(
  BuildContext context, {
  required double systemRailWidth,
  required bool receivesAddedTop,
  bool Function(double windowWidth) showsRailByWidth = _showsRail,
}) {
  final placement = RailPlacement.of(context, showsRailByWidth: showsRailByWidth);
  final safeArea = RailPlacement.railSafeAreaOf(context, receivesAddedTop: receivesAddedTop);
  final width = placement?.followsSystemBar == true ? systemRailWidth : _railWidth;
  final occupiedWidth = placement?.occupiedWidth(safeArea, width) ?? 0.0;
  final size = MediaQuery.sizeOf(context);
  return (
    placement: placement,
    width: width,
    safeArea: safeArea,
    edge: placement?.edge,
    followsSystemBar: placement?.followsSystemBar ?? false,
    occupiedWidth: occupiedWidth,
    centredSafeArea: placement?.centredRailSafeArea(safeArea) ?? safeArea,
    contentRect: Rect.fromLTRB(
      placement?.edge == HorizontalEdge.left ? occupiedWidth : 0,
      0,
      size.width - (placement?.edge == HorizontalEdge.right ? occupiedWidth : 0),
      size.height,
    ),
    body: MediaQuery.of(context).removePadding(
      removeLeft: placement?.edge == HorizontalEdge.left,
      removeRight: placement?.edge == HorizontalEdge.right,
    ),
  );
}

/// [RailLayout.of] with [systemRailWidth], leaving the argument out for its default.
RailLayout _railLayout(BuildContext context, {required double systemRailWidth, required bool receivesAddedTop}) =>
    systemRailWidth == RailPlacement.systemRailWidth
    ? RailLayout.of(context, showsRailByWidth: _showsRail, railWidth: _railWidth, receivesAddedTop: receivesAddedTop)
    : RailLayout.of(
        context,
        showsRailByWidth: _showsRail,
        railWidth: _railWidth,
        systemRailWidth: systemRailWidth,
        receivesAddedTop: receivesAddedTop,
      );

/// [rail]'s fields, getters and method results, in the shape of [_handWritten].
_HandWritten _readFrom(RailLayout rail, BuildContext context) => (
  placement: rail.placement,
  width: rail.width,
  safeArea: rail.safeArea,
  edge: rail.edge,
  followsSystemBar: rail.followsSystemBar,
  occupiedWidth: rail.occupiedWidth,
  centredSafeArea: rail.centredSafeArea,
  contentRect: rail.contentRect(MediaQuery.sizeOf(context)),
  body: rail.removeRailEdge(MediaQuery.of(context)),
);

void main() {
  group('RailLayout.of', () {
    for (final window in _windows) {
      testWidgets('equals the RailPlacement sequence read in the same context: ${window.name}', (tester) async {
        useWindow(tester, window);
        final cases =
            <({String label, RailLayout rail, RailLayout again, _HandWritten actual, _HandWritten expected})>[];
        // A value without a width-based rail. In a window that shows one, it has the width and safe area of the cases
        // with receivesAddedTop false and a different placement.
        late final ({String label, RailLayout rail, _HandWritten expected}) withoutWidthRail;
        await tester.pumpWidget(
          duoApp(
            window,
            home: Builder(
              builder: (context) {
                for (final systemRailWidth in [RailPlacement.systemRailWidth, RailPlacement.statusColumnWidth]) {
                  for (final receivesAddedTop in [false, true]) {
                    final rail = _railLayout(
                      context,
                      systemRailWidth: systemRailWidth,
                      receivesAddedTop: receivesAddedTop,
                    );
                    cases.add((
                      label: 'systemRailWidth $systemRailWidth, receivesAddedTop $receivesAddedTop',
                      rail: rail,
                      again: _railLayout(context, systemRailWidth: systemRailWidth, receivesAddedTop: receivesAddedTop),
                      actual: _readFrom(rail, context),
                      expected: _handWritten(
                        context,
                        systemRailWidth: systemRailWidth,
                        receivesAddedTop: receivesAddedTop,
                      ),
                    ));
                  }
                }
                withoutWidthRail = (
                  label: 'showsRailByWidth false',
                  rail: RailLayout.of(context, showsRailByWidth: (_) => false, railWidth: _railWidth),
                  expected: _handWritten(
                    context,
                    systemRailWidth: RailPlacement.systemRailWidth,
                    receivesAddedTop: false,
                    showsRailByWidth: (_) => false,
                  ),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(cases, hasLength(4));
        for (final (:label, :rail, :again, :actual, :expected) in cases) {
          expect(actual.placement, expected.placement, reason: label);
          expect(actual.width, expected.width, reason: label);
          expect(actual.width, greaterThan(0), reason: label);
          expect(actual.safeArea, expected.safeArea, reason: label);
          expect(actual.edge, expected.edge, reason: label);
          expect(actual.followsSystemBar, expected.followsSystemBar, reason: label);
          expect(actual.occupiedWidth, expected.occupiedWidth, reason: label);
          expect(actual.centredSafeArea, expected.centredSafeArea, reason: label);
          expect(actual.contentRect, expected.contentRect, reason: label);
          expect(actual.body, expected.body, reason: label);
          expect(again, rail, reason: label);
          expect(again.hashCode, rail.hashCode, reason: label);
          expect(
            rail.toString(),
            'RailLayout(placement: ${expected.placement}, width: ${expected.width}, safeArea: ${expected.safeArea})',
            reason: label,
          );
        }
        // Two values are equal exactly when their fields are.
        final values = [
          for (final (:label, :rail, :expected, again: _, actual: _) in cases)
            (label: label, rail: rail, expected: expected),
          withoutWidthRail,
        ];
        for (final a in values) {
          for (final b in values) {
            final sameFields =
                a.expected.placement == b.expected.placement &&
                a.expected.width == b.expected.width &&
                a.expected.safeArea == b.expected.safeArea;
            expect(a.rail == b.rail, sameFields, reason: '${a.label} == ${b.label}');
          }
        }
      });
    }
  });
}
