import 'dart:math' as math;

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/toolbar/shell_geometry.dart' show arrangeBesideRail, shellFloorTop;
import 'package:duo_rail_kit/src/toolbar/vertical_bar_column.dart' show VerticalBarArrangement;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/duo_windows.dart';

/// The column [VerticalBarColumn.of] resolves for [window] from its recorded region.
VerticalBarColumn _columnOf(DuoWindow window) => VerticalBarColumn.resolve(
  region: window.region,
  edge: window.edge,
  osViewPadding: window.padding,
  windowSize: window.size,
)!;

/// Cells of one group that fit beside a rail whose first item is at [railTop], as the shell counts them.
int _cellsBeside(VerticalBarColumn column, double railTop, {required double floorTop}) =>
    VerticalBarColumn.capacity(math.max(railTop, floorTop) - VerticalBarColumn.groupGap - column.items.top);

void main() {
  group('UIKit reproduction (back and 2 actions, reservesBack: true)', () {
    for (final (window, left, right) in [(innerLandscape, 879.0, 927.0), (rightWindow, 397.0, 445.0)]) {
      for (final (tabs, railTop, folds) in [
        (3, 483.0, false),
        (5, 383.0, false),
        (6, 333.0, false),
        (7, 283.0, true),
        (8, 233.0, true),
      ]) {
        test('${window.name}: $tabs tabs with the rail top at $railTop', () {
          final column = _columnOf(window);
          final floorTop = shellFloorTop(column, reservesBack: true);
          expect(floorTop, 244);
          final arranged = arrangeBesideRail(
            column: column,
            floorTop: floorTop,
            railTop: railTop,
            railCentre: null,
            back: true,
            actions: 2,
          )!;
          final groups = arranged.arrangement.groups;
          expect(groups, hasLength(2));
          expect(groups[0]!.rect, Rect.fromLTRB(left, 124, right, 172));
          expect(groups[0]!.shown, [0]);
          if (folds) {
            expect(groups[1]!.rect, Rect.fromLTRB(left, 184, right, 232));
            expect(groups[1]!.endsWithOverflow, isTrue);
            expect(groups[1]!.shown, isEmpty);
            expect(arranged.arrangement.overflow, [1, 2]);
          } else {
            expect(groups[1]!.rect, Rect.fromLTRB(left, 184, right, 284));
            expect(groups[1]!.endsWithOverflow, isFalse);
            expect(groups[1]!.shown, [1, 2]);
            expect(arranged.arrangement.overflow, isEmpty);
          }
        });
      }
    }
  });

  group('per window', () {
    for (final (
          window,
          items,
          railBox,
          centre,
          floors,
          cellX,
        )
        in <(DuoWindow, Rect, (double, double), double, (double, double), (double, double))>[
          (innerLandscape, const Rect.fromLTRB(879, 124, 927, 635), (867, 951), 909, (184, 244), (885, 933)),
          (rightWindow, const Rect.fromLTRB(397, 124, 445, 635), (385, 469), 427, (184, 244), (403, 451)),
          (outerPortrait, const Rect.fromLTRB(394, 174, 442, 644), (382, 466), 424, (234, 294), (400, 448)),
          (outerLandscapeRight, const Rect.fromLTRB(606, 24, 654, 384), (594, 678), 636, (84, 144), (612, 660)),
          (outerLandscapeLeft, const Rect.fromLTRB(24, 82, 72, 432), (0, 84), 42, (142, 202), (18, 66)),
        ]) {
      test(window.name, () {
        final column = _columnOf(window);
        expect(column.items, items);
        expect((column.column.left, column.column.right), railBox);
        expect(shellFloorTop(column, reservesBack: false), floors.$1);
        expect(shellFloorTop(column, reservesBack: true), floors.$2);

        final arranged = arrangeBesideRail(
          column: column,
          floorTop: floors.$1,
          railTop: null,
          railCentre: centre,
          back: false,
          actions: 1,
        )!;
        final cell = arranged.arrangement.groups.single!.rect;
        expect((cell.left, cell.right), cellX);
        expect(cell.top, items.top);
        // The returned column is the window's, with only the item region moved to the rail's centre.
        expect(arranged.column.items, Rect.fromLTRB(cellX.$1, items.top, cellX.$2, items.bottom));
        expect(arranged.column.column, column.column);
        expect(arranged.column.edge, column.edge);
        expect(arranged.column.viewSize, column.viewSize);
      });
    }
  });

  group('reference rails (text 1.0, no keyboard, reservesBack: false)', () {
    /// One reference rail: [actions] actions beside a rail whose first destination is at [railTop].
    void row(
      String name,
      DuoWindow window, {
      required double centre,
      required double railTop,
      required int actions,
      required int cells,
      required bool folds,
    }) {
      test('${window.name}: $name, rail top $railTop', () {
        final column = _columnOf(window);
        final floorTop = shellFloorTop(column, reservesBack: false);
        expect(_cellsBeside(column, railTop, floorTop: floorTop), cells);
        final arranged = arrangeBesideRail(
          column: column,
          floorTop: floorTop,
          railTop: railTop,
          railCentre: centre,
          back: false,
          actions: actions,
        )!;
        final group = arranged.arrangement.groups.single!;
        expect(group.rect.left, centre - VerticalBarColumn.cellExtent / 2);
        expect(group.rect.top, column.items.top);
        if (folds) {
          expect(group.endsWithOverflow, isTrue);
          expect(group.shown, isEmpty);
          expect(arranged.arrangement.overflow, [for (var i = 0; i < actions; i++) i]);
        } else {
          expect(group.endsWithOverflow, isFalse);
          expect(group.shown, [for (var i = 0; i < actions; i++) i]);
          expect(arranged.arrangement.overflow, isEmpty);
        }

        // arrangeBesideRail itself places exactly [cells] cells: that many actions fit, one more folds.
        VerticalBarArrangement arrangeActions(int count) => arrangeBesideRail(
          column: column,
          floorTop: floorTop,
          railTop: railTop,
          railCentre: centre,
          back: false,
          actions: count,
        )!.arrangement;
        final full = arrangeActions(cells);
        expect(full.overflow, isEmpty);
        expect(
          full.groups.single!.rect,
          Rect.fromLTWH(
            centre - VerticalBarColumn.cellExtent / 2,
            column.items.top,
            VerticalBarColumn.cellExtent,
            VerticalBarColumn.groupExtent(cells),
          ),
        );
        expect(full.groups.single!.shown, [for (var i = 0; i < cells; i++) i]);
        final over = arrangeActions(cells + 1);
        expect(over.groups.single!.endsWithOverflow, isTrue);
        expect(over.groups.single!.shown, [for (var i = 0; i < cells - 1; i++) i]);
        expect(over.overflow, [cells - 1, cells]);
      });
    }

    for (final (window, centre) in [(innerLandscape, 909.0), (rightWindow, 427.0)]) {
      row('four actions', window, centre: centre, railTop: 411, actions: 4, cells: 5, folds: false);
      row('two actions', window, centre: centre, railTop: 315, actions: 2, cells: 3, folds: false);
      row('two actions', window, centre: centre, railTop: 283, actions: 2, cells: 2, folds: false);
      row('two actions', window, centre: centre, railTop: 251, actions: 2, cells: 2, folds: false);
      row('two actions', window, centre: centre, railTop: 219, actions: 2, cells: 1, folds: true);
      row('one action', window, centre: centre, railTop: 315, actions: 1, cells: 3, folds: false);
      row('one action', window, centre: centre, railTop: 267, actions: 1, cells: 2, folds: false);
      row('one action', window, centre: centre, railTop: 387, actions: 1, cells: 4, folds: false);
      row('one action', window, centre: centre, railTop: 373, actions: 1, cells: 4, folds: false);
    }

    const portraitCentre = 424.0;
    row('four actions', outerPortrait, centre: portraitCentre, railTop: 420, actions: 4, cells: 4, folds: false);
    row('two actions', outerPortrait, centre: portraitCentre, railTop: 324, actions: 2, cells: 2, folds: false);
    row('two actions', outerPortrait, centre: portraitCentre, railTop: 292, actions: 2, cells: 2, folds: false);
    row('two actions', outerPortrait, centre: portraitCentre, railTop: 260, actions: 2, cells: 1, folds: true);
    row('two actions', outerPortrait, centre: portraitCentre, railTop: 228, actions: 2, cells: 1, folds: true);
    row('one action', outerPortrait, centre: portraitCentre, railTop: 324, actions: 1, cells: 2, folds: false);
    row('one action', outerPortrait, centre: portraitCentre, railTop: 276, actions: 1, cells: 1, folds: false);
    row('one action', outerPortrait, centre: portraitCentre, railTop: 396, actions: 1, cells: 4, folds: false);
    row('one action', outerPortrait, centre: portraitCentre, railTop: 382, actions: 1, cells: 3, folds: false);

    test('${outerPortrait.name}: with two actions and rail top 228, the rail scrolls about 14 below the floor', () {
      // The rail's content starts 8 below the top padding that railPaddingOf raises to the floor.
      expect(shellFloorTop(_columnOf(outerPortrait), reservesBack: false) + 8 - 228, 14);
    });

    for (final window in [innerLandscape, rightWindow, outerPortrait]) {
      test('${window.name}: a Settings tab without actions has no cells and keeps the floor', () {
        final column = _columnOf(window);
        final floorTop = shellFloorTop(column, reservesBack: false);
        expect(floorTop, column.items.top + 60);
        expect(
          arrangeBesideRail(
            column: column,
            floorTop: floorTop,
            railTop: 411,
            railCentre: column.items.center.dx + 6,
            back: false,
            actions: 0,
          ),
          isNull,
        );
      });
    }
    test('${innerLandscape.name}: the Settings floor is 184', () {
      expect(shellFloorTop(_columnOf(innerLandscape), reservesBack: false), 184);
    });
  });

  group('other cases', () {
    test('without a marker, 4 actions fold into one overflow cell on the floor', () {
      final column = _columnOf(innerLandscape);
      final arranged = arrangeBesideRail(
        column: column,
        floorTop: shellFloorTop(column, reservesBack: false),
        railTop: null,
        railCentre: null,
        back: false,
        actions: 4,
      )!;
      final group = arranged.arrangement.groups.single!;
      expect(group.rect, const Rect.fromLTRB(879, 124, 927, 172));
      expect(group.endsWithOverflow, isTrue);
      expect(group.shown, isEmpty);
      expect(arranged.arrangement.overflow, [0, 1, 2, 3]);
      expect(arranged.arrangement.overflowCell, const Rect.fromLTRB(879, 124, 927, 172));
    });

    test('back only makes one group', () {
      final column = _columnOf(innerLandscape);
      final arranged = arrangeBesideRail(
        column: column,
        floorTop: shellFloorTop(column, reservesBack: true),
        railTop: 483,
        railCentre: null,
        back: true,
        actions: 0,
      )!;
      final group = arranged.arrangement.groups.single!;
      expect(group.rect, const Rect.fromLTRB(879, 124, 927, 172));
      expect(group.shown, [0]);
      expect(group.endsWithOverflow, isFalse);
      expect(arranged.arrangement.overflow, isEmpty);
    });

    test('a pinned action stays while the others fold', () {
      final column = _columnOf(innerLandscape);
      final arranged = arrangeBesideRail(
        column: column,
        floorTop: 184,
        railTop: 283,
        railCentre: null,
        back: false,
        actions: 3,
        pinned: {2},
      )!;
      final group = arranged.arrangement.groups.single!;
      expect(group.shown, [2]);
      expect(group.endsWithOverflow, isTrue);
      expect(arranged.arrangement.overflow, [0, 1]);
    });

    test('pinned indices are flattened with the back control first', () {
      final column = _columnOf(innerLandscape);
      final arranged = arrangeBesideRail(
        column: column,
        floorTop: 244,
        railTop: 333,
        railCentre: null,
        back: true,
        actions: 3,
        pinned: {3},
      )!;
      expect(arranged.arrangement.groups[0]!.shown, [0]);
      expect(arranged.arrangement.groups[1]!.rect, const Rect.fromLTRB(879, 184, 927, 284));
      expect(arranged.arrangement.groups[1]!.shown, [3]);
      expect(arranged.arrangement.groups[1]!.endsWithOverflow, isTrue);
      expect(arranged.arrangement.overflow, [1, 2]);
    });

    test('the back control never moves to the overflow cell', () {
      final column = _columnOf(innerLandscape);
      // A pinned last action makes the back control the next candidate to move.
      final arranged = arrangeBesideRail(
        column: column,
        floorTop: 244,
        railTop: 283,
        railCentre: null,
        back: true,
        actions: 2,
        pinned: {2},
      )!;
      final groups = arranged.arrangement.groups;
      expect(groups, hasLength(2));
      expect(groups[0]!.rect, const Rect.fromLTRB(879, 124, 927, 172));
      expect(groups[0]!.shown, [0]);
      expect(groups[0]!.endsWithOverflow, isFalse);
      expect(groups[1]!.rect, const Rect.fromLTRB(879, 184, 927, 232));
      expect(groups[1]!.endsWithOverflow, isTrue);
      expect(groups[1]!.shown, isEmpty);
      expect(arranged.arrangement.overflow, [1, 2]);

      // Only the back cell fits above the floor: nothing is arranged rather than folding the back control.
      expect(
        arrangeBesideRail(column: column, floorTop: 184, railTop: null, railCentre: null, back: true, actions: 2),
        isNull,
      );
    });

    test('the cells end the group gap above the rail top', () {
      final column = _columnOf(innerLandscape);
      VerticalBarArrangement arrangeAbove(double railTop) => arrangeBesideRail(
        column: column,
        floorTop: 184,
        railTop: railTop,
        railCentre: null,
        back: false,
        actions: 2,
      )!.arrangement;
      // Two cells end at 224, 12 above a rail top of 236.
      final fits = arrangeAbove(236);
      expect(fits.groups.single!.rect, const Rect.fromLTRB(879, 124, 927, 224));
      expect(fits.groups.single!.shown, [0, 1]);
      expect(fits.overflow, isEmpty);
      // Beyond the 0.5 tolerance, both fold into one overflow cell.
      final folds = arrangeAbove(235.4);
      expect(folds.groups.single!.rect, const Rect.fromLTRB(879, 124, 927, 172));
      expect(folds.groups.single!.endsWithOverflow, isTrue);
      expect(folds.groups.single!.shown, isEmpty);
      expect(folds.overflow, [0, 1]);
    });

    test('neither back nor actions gives no arrangement', () {
      final column = _columnOf(innerLandscape);
      expect(
        arrangeBesideRail(column: column, floorTop: 184, railTop: 483, railCentre: 909, back: false, actions: 0),
        isNull,
      );
    });

    test('a rail top above the floor arranges against the floor', () {
      final column = _columnOf(innerLandscape);
      final above = arrangeBesideRail(
        column: column,
        floorTop: 184,
        railTop: 100,
        railCentre: 909,
        back: false,
        actions: 2,
      )!;
      final atFloor = arrangeBesideRail(
        column: column,
        floorTop: 184,
        railTop: 184,
        railCentre: 909,
        back: false,
        actions: 2,
      )!;
      expect(above.arrangement, atFloor.arrangement);
      expect(above.arrangement.groups.single!.rect, const Rect.fromLTRB(885, 124, 933, 172));
    });
  });
}
