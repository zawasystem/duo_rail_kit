import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/edge/bar_regions.dart' show parseVerticalBarRegion;
import 'package:duo_rail_kit/src/toolbar/vertical_bar_column.dart'
    show VerticalBarArrangement, VerticalBarColumnArrangement, VerticalBarGroupSlot;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cells.dart';
import 'support/duo_windows.dart';

/// [rightWindow] without `topBarTop`; the items still start at the region top, y 124.
final DuoWindow _rightWindowNoTopBarTop = rightWindow.copyWith(
  region: _withRect(rightWindow.region!, rightWindow.region!.rect),
);

VerticalBarColumn? _resolve(
  DuoWindow window, {
  VerticalBarRegion? region,
  HorizontalEdge? edge,
  bool noEdge = false,
  EdgeInsets? padding,
  Size? size,
}) => VerticalBarColumn.resolve(
  region: region ?? window.region,
  edge: noEdge ? null : edge ?? window.edge,
  osViewPadding: padding ?? window.padding,
  windowSize: size ?? window.size,
);

VerticalBarColumn _columnOf(DuoWindow window) => _resolve(window)!;

VerticalBarRegion _withRect(VerticalBarRegion region, Rect rect, {double? topBarTop}) =>
    VerticalBarRegion(rect: rect, edge: region.edge, viewSize: region.viewSize, topBarTop: topBarTop);

VerticalBarGroupSlot _slot(double left, double top, double bottom, List<int> shown, {bool overflow = false}) =>
    VerticalBarGroupSlot(rect: Rect.fromLTRB(left, top, left + 48, bottom), shown: shown, endsWithOverflow: overflow);

/// Inner landscape groups at x 879-927.
VerticalBarGroupSlot _inner(double top, double bottom, List<int> shown, {bool overflow = false}) =>
    _slot(879, top, bottom, shown, overflow: overflow);

/// Reads [VerticalBarColumn.of] and counts builds.
class _ColumnProbe extends StatefulWidget {
  const _ColumnProbe();

  @override
  State<_ColumnProbe> createState() => _ColumnProbeState();
}

class _ColumnProbeState extends State<_ColumnProbe> {
  static int builds = 0;
  static VerticalBarColumn? column;

  @override
  Widget build(BuildContext context) {
    builds++;
    column = VerticalBarColumn.of(context);
    return const SizedBox.shrink();
  }
}

/// The production chain: `VerticalBarEdge > SideStatusBarInsets > page`, with injected scopes.
Widget _chain({
  HorizontalEdge? edge = HorizontalEdge.right,
  VerticalBarRegion? region,
  TextDirection textDirection = TextDirection.ltr,
}) => Directionality(
  textDirection: textDirection,
  child: VerticalBarEdgeScope(
    edge: edge,
    child: BarRegionScope(
      verticalBar: region,
      child: const SideStatusBarInsets(child: _ColumnProbe()),
    ),
  ),
);

void main() {
  setUp(() {
    _ColumnProbeState.builds = 0;
    _ColumnProbeState.column = null;
  });

  group('constants', () {
    test('match UIKit on the iOS 27.2 Simulator', () {
      expect(VerticalBarColumn.cellExtent, 48);
      expect(VerticalBarColumn.cellPitch, 52);
      expect(VerticalBarColumn.groupGap, 12);
      expect(VerticalBarColumn.buttonExtent, 38);
      expect(VerticalBarColumn.innerMargin, 12);
    });
  });

  group('resolve', () {
    test('inner landscape: column x 867-951, items x 879-927 from y 124, centred at x 903', () {
      final column = _columnOf(innerLandscape);
      expect(
        column,
        const VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(951, 669),
          column: Rect.fromLTRB(867, 0, 951, 669),
          items: Rect.fromLTRB(879, 124, 927, 635),
        ),
      );
      expect(column.width, 84);
      expect(column.items.center.dx, 903);
    });

    test('right Split View window: column x 385-469, items y 124-635', () {
      expect(
        _columnOf(_rightWindowNoTopBarTop),
        const VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(469, 669),
          column: Rect.fromLTRB(385, 0, 469, 669),
          items: Rect.fromLTRB(397, 124, 445, 635),
        ),
      );
      expect(_resolve(rightWindow)?.items.top, 124, reason: 'max(124, 24)');
    });

    test('left Split View window: column x 0-84, items from the top bar row top 24', () {
      final column = _columnOf(leftWindow);
      expect(
        column,
        const VerticalBarColumn(
          edge: HorizontalEdge.left,
          viewSize: Size(469, 669),
          column: Rect.fromLTRB(0, 0, 84, 669),
          items: Rect.fromLTRB(24, 24, 72, 635),
        ),
      );
      expect(column.width, 84, reason: 'max(0, 72 + 12)');
    });

    test('left Split View window without topBarTop: items start at the region top 16', () {
      final region = _withRect(leftWindow.region!, leftWindow.region!.rect);
      expect(_resolve(leftWindow, region: region)?.items, const Rect.fromLTRB(24, 16, 72, 635));
    });

    test('a payload without topBarTop, as from older native code, starts items at the region top', () {
      final region = parseVerticalBarRegion({
        'edge': 'right',
        'verticalBar': {'left': 879, 'top': 124, 'right': 927, 'bottom': 635, 'viewWidth': 951, 'viewHeight': 669},
      }, HorizontalEdge.right);
      expect(region?.topBarTop, isNull);
      expect(_resolve(innerLandscape, region: region)?.items, const Rect.fromLTRB(879, 124, 927, 635));
    });

    test('a 0.1.1 payload without a verticalBar entry gives no column', () {
      final payload = {'edge': 'right', 'statusBarHidden': false, 'sequence': 1};
      final edge = VerticalBarEdge.parse(payload);
      final region = parseVerticalBarRegion(payload, edge);
      expect(region, isNull);
      expect(
        VerticalBarColumn.resolve(
          region: region,
          edge: edge,
          osViewPadding: innerLandscape.padding,
          windowSize: innerLandscape.size,
        ),
        isNull,
      );
    });

    test('outer portrait: column x 382-466, items y 174-644', () {
      expect(
        _columnOf(outerPortraitBottom20),
        const VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(466, 678),
          column: Rect.fromLTRB(382, 0, 466, 678),
          items: Rect.fromLTRB(394, 174, 442, 644),
        ),
      );
    });

    test('outer landscape with a left column: column x 0-84, items from y 82', () {
      expect(
        _columnOf(outerLandscapeLeft),
        const VerticalBarColumn(
          edge: HorizontalEdge.left,
          viewSize: Size(678, 466),
          column: Rect.fromLTRB(0, 0, 84, 466),
          items: Rect.fromLTRB(24, 82, 72, 432),
        ),
      );
    });

    test('outer landscape with a right column: column x 594-678, items from the top bar row', () {
      expect(
        _columnOf(outerLandscapeRight),
        const VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(678, 466),
          column: Rect.fromLTRB(594, 0, 678, 466),
          items: Rect.fromLTRB(606, 24, 654, 384),
        ),
      );
    });

    test('the column is as wide as the own-side OS inset when that is wider', () {
      final column = _resolve(innerLandscape, padding: const EdgeInsets.only(right: 100, bottom: 34));
      expect(column?.column, const Rect.fromLTRB(851, 0, 951, 669));
      expect(column?.width, 100);
      expect(column?.items, const Rect.fromLTRB(879, 124, 927, 635), reason: 'items follow the region');
    });

    test('a left column is as wide as the left OS inset when that is wider', () {
      final column = _resolve(outerLandscapeLeft, padding: const EdgeInsets.only(left: 100, bottom: 34));
      expect(column?.column, const Rect.fromLTRB(0, 0, 100, 466));
      expect(column?.width, 100);
      expect(column?.items, const Rect.fromLTRB(24, 82, 72, 432), reason: 'items follow the region');
    });

    test('a region that is not 48 wide keeps 48-point cells centred on the items centre', () {
      final wide = _resolve(
        innerLandscape,
        region: _withRect(innerLandscape.region!, const Rect.fromLTRB(875, 124, 931, 635)),
      )!;
      expect(wide.items, const Rect.fromLTRB(875, 124, 931, 635));
      expect(wide.column, const Rect.fromLTRB(863, 0, 951, 669), reason: 'max(84, 951 - 875 + 12)');
      expect(wide.arrange([1, 2])!.groups.map((group) => group!.rect.left), [879, 879]);
      expect(wide.arrange([1])!.groups.single!.cells.single, const Rect.fromLTRB(879, 124, 927, 172));

      final narrow = _resolve(
        innerLandscape,
        region: _withRect(innerLandscape.region!, const Rect.fromLTRB(883, 124, 923, 635)),
      )!;
      expect(narrow.items.width, 40);
      expect(narrow.column, const Rect.fromLTRB(867, 0, 951, 669));
      expect(narrow.arrange([1])!.groups.single!.cells.single, const Rect.fromLTRB(879, 124, 927, 172));
    });

    group('returns null', () {
      test('1: without a region', () {
        expect(
          VerticalBarColumn.resolve(
            region: null,
            edge: HorizontalEdge.right,
            osViewPadding: innerLandscape.padding,
            windowSize: innerLandscape.size,
          ),
          isNull,
        );
      });

      test('2: without an edge, or with an edge other than the region edge', () {
        expect(_resolve(innerLandscape, noEdge: true), isNull);
        expect(_resolve(innerLandscape, edge: HorizontalEdge.left), isNull);
        expect(_resolve(leftWindow, edge: HorizontalEdge.right), isNull);
      });

      test('3: when the sampled window size differs from the window by more than 0.5', () {
        expect(_resolve(innerLandscape, size: const Size(951.5, 668.5)), isNotNull);
        expect(_resolve(innerLandscape, size: const Size(951.6, 669)), isNull);
        expect(_resolve(innerLandscape, size: const Size(951, 669.6)), isNull);
        expect(_resolve(innerLandscape, size: const Size(669, 951)), isNull, reason: 'stale after rotation');
      });

      test('4: when the OS top inset exceeds 0.5', () {
        expect(_resolve(innerLandscape, padding: const EdgeInsets.only(top: 0.5, right: 84)), isNotNull);
        expect(_resolve(innerLandscape, padding: const EdgeInsets.only(top: 0.6, right: 84)), isNull);
      });

      test('4: the mixed sample seen during rotation (669 x 951, OS top 82, x 597-645, y 82-917)', () {
        expect(_resolve(mixedRotation), isNull);
        expect(
          _resolve(mixedRotation, padding: const EdgeInsets.only(bottom: 34)),
          isNotNull,
          reason: 'only rule 4 applies',
        );
      });

      test('5: when the opposite OS side inset exceeds 0.5', () {
        expect(_resolve(innerLandscape, padding: const EdgeInsets.only(left: 0.5, right: 84)), isNotNull);
        expect(_resolve(innerLandscape, padding: const EdgeInsets.only(left: 0.6, right: 84)), isNull);
        expect(_resolve(innerLandscape, padding: const EdgeInsets.only(left: 62, right: 62)), isNull);
        expect(_resolve(outerLandscapeLeft, padding: const EdgeInsets.only(right: 84)), isNull);
        expect(_resolve(leftWindow, padding: const EdgeInsets.only(right: 1, bottom: 34)), isNull);
      });

      test('5: a stale sample after the outer landscape columns swap sides', () {
        // The right-column sample arrives while the OS insets already describe the left column.
        expect(_resolve(outerLandscapeRight, padding: outerLandscapeLeft.padding), isNull);
        expect(_resolve(outerLandscapeLeft, padding: outerLandscapeRight.padding), isNull);
      });

      test('6: when the region is not in its own half of the window', () {
        final leftRegionOnRight = _withRect(innerLandscape.region!, const Rect.fromLTRB(24, 124, 72, 635));
        expect(_resolve(innerLandscape, region: leftRegionOnRight), isNull);
        final atHalf = _withRect(innerLandscape.region!, const Rect.fromLTRB(475.5, 124, 523.5, 635));
        expect(_resolve(innerLandscape, region: atHalf), isNotNull, reason: 'left edge at width / 2');
        final pastHalf = _withRect(innerLandscape.region!, const Rect.fromLTRB(475, 124, 523, 635));
        expect(_resolve(innerLandscape, region: pastHalf), isNull);

        final rightRegionOnLeft = _withRect(leftWindow.region!, const Rect.fromLTRB(397, 124, 445, 635));
        expect(_resolve(leftWindow, region: rightRegionOnLeft), isNull);
        final leftAtHalf = _withRect(leftWindow.region!, const Rect.fromLTRB(186.5, 124, 234.5, 635));
        expect(_resolve(leftWindow, region: leftAtHalf), isNotNull, reason: 'right edge at width / 2');
        final leftPastHalf = _withRect(leftWindow.region!, const Rect.fromLTRB(187, 124, 235, 635));
        expect(_resolve(leftWindow, region: leftPastHalf), isNull);
      });

      test('7: when the items are more than 0.5 shorter than one cell, like capacity', () {
        Rect rect(double bottom) => Rect.fromLTRB(879, 124, 927, bottom);
        VerticalBarColumn? resolveTo(double bottom) =>
            _resolve(innerLandscape, region: _withRect(innerLandscape.region!, rect(bottom)));
        expect(resolveTo(172), isNotNull);
        expect(resolveTo(171.9), isNotNull);
        expect(resolveTo(171.5), isNotNull);
        expect(VerticalBarColumn.capacity(resolveTo(171.5)!.items.height), 1);
        expect(
          resolveTo(171.5)!.arrange([1]),
          VerticalBarArrangement(
            groups: [
              _inner(124, 172, [0]),
            ],
            overflow: const [],
          ),
          reason: 'arrange places the one cell within its 0.5 tolerance',
        );
        expect(resolveTo(171.4), isNull);
        expect(resolveTo(150), isNull);
      });

      test('7: topBarTop below the region top can leave too little height', () {
        const rect = Rect.fromLTRB(24, 16, 72, 70);
        expect(_resolve(leftWindow, region: _withRect(leftWindow.region!, rect))?.items.height, 54);
        expect(_resolve(leftWindow, region: _withRect(leftWindow.region!, rect, topBarTop: 24)), isNull);
      });
    });
  });

  group('capacity and groupExtent', () {
    test('capacity allows 0.5 like arrange and is 0 for negative extents', () {
      expect(VerticalBarColumn.capacity(-1), 0);
      expect(VerticalBarColumn.capacity(0), 0);
      expect(VerticalBarColumn.capacity(47.4), 0);
      expect(VerticalBarColumn.capacity(47.5), 1);
      expect(VerticalBarColumn.capacity(48), 1);
      expect(VerticalBarColumn.capacity(99.4), 1);
      expect(VerticalBarColumn.capacity(99.5), 2);
      expect(VerticalBarColumn.capacity(double.nan), 0);
      expect(VerticalBarColumn.capacity(double.negativeInfinity), 0);
      expect(() => VerticalBarColumn.capacity(double.infinity), throwsArgumentError);
    });

    test('inner landscape items hold 9 cells, y 124-588', () {
      final column = _columnOf(innerLandscape);
      expect(column.items.height, 511);
      expect(VerticalBarColumn.capacity(511), 9);
      expect(VerticalBarColumn.capacity(column.items.height), 9);
      expect(
        column.arrange([9]),
        VerticalBarArrangement(groups: [_inner(124, 588, List.generate(9, (i) => i))], overflow: const []),
      );
    });

    test('groupExtent is 48 + 52 per further cell, or 0 for none', () {
      expect(VerticalBarColumn.groupExtent(0), 0);
      expect(VerticalBarColumn.groupExtent(-1), 0);
      expect(VerticalBarColumn.groupExtent(1), 48);
      expect(VerticalBarColumn.groupExtent(2), 100);
      expect(VerticalBarColumn.groupExtent(3), 152);
    });
  });

  group('arrange matches UIKit', () {
    test('inner landscape [1, 2] keep: back y 124-172 (button x 884-922, y 129-167), actions y 184-284', () {
      final arrangement = _columnOf(innerLandscape).arrange([1, 2], keepFirstGroup: true)!;
      expect(
        arrangement,
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 284, [1, 2]),
          ],
          overflow: const [],
        ),
      );
      expect(button(arrangement.groups[0]!.cells.single), const Rect.fromLTRB(884, 129, 922, 167));
      expect(arrangement.groups[1]!.cells, const [
        Rect.fromLTRB(879, 184, 927, 232),
        Rect.fromLTRB(879, 236, 927, 284),
      ]);
      expect(arrangement.groups[1]!.cells.map(button), const [
        Rect.fromLTRB(884, 189, 922, 227),
        Rect.fromLTRB(884, 241, 922, 279),
      ]);
      expect(arrangement.overflowCell, isNull);
    });

    test('inner landscape [2] without back: y 124-224', () {
      expect(
        _columnOf(innerLandscape).arrange([2]),
        VerticalBarArrangement(
          groups: [
            _inner(124, 224, [0, 1]),
          ],
          overflow: const [],
        ),
      );
    });

    test('inner landscape [3, 2, 1]: y 124-276, 288-388, 400-448', () {
      expect(
        _columnOf(innerLandscape).arrange([3, 2, 1]),
        VerticalBarArrangement(
          groups: [
            _inner(124, 276, [0, 1, 2]),
            _inner(288, 388, [3, 4]),
            _inner(400, 448, [5]),
          ],
          overflow: const [],
        ),
      );
    });

    test('inner landscape [1, 5]: actions y 184-440', () {
      expect(
        _columnOf(innerLandscape).arrange([1, 5]),
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 440, [1, 2, 3, 4, 5]),
          ],
          overflow: const [],
        ),
      );
    });

    test('inner landscape [1, 8]: everything fits, actions y 184-596', () {
      expect(
        _columnOf(innerLandscape).arrange([1, 8]),
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 596, [1, 2, 3, 4, 5, 6, 7, 8]),
          ],
          overflow: const [],
        ),
      );
    });

    test('inner landscape [1, 9]: 7 actions and the overflow cell at y 548-596; the last 2 move', () {
      final arrangement = _columnOf(innerLandscape).arrange([1, 9])!;
      expect(
        arrangement,
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 596, [1, 2, 3, 4, 5, 6, 7], overflow: true),
          ],
          overflow: const [8, 9],
        ),
      );
      expect(arrangement.overflowCell, const Rect.fromLTRB(879, 548, 927, 596));
      expect(arrangement.groups[1]!.cells, hasLength(8));
      expect(_columnOf(innerLandscape).arrange([1, 9], keepFirstGroup: true), arrangement);
    });

    test('inner landscape [1, 10]: 7 actions and the overflow cell; the last 3 move', () {
      final arrangement = _columnOf(innerLandscape).arrange([1, 10])!;
      expect(
        arrangement,
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 596, [1, 2, 3, 4, 5, 6, 7], overflow: true),
          ],
          overflow: const [8, 9, 10],
        ),
      );
      expect(arrangement.overflowCell, const Rect.fromLTRB(879, 548, 927, 596));
    });

    test('inner landscape [1, 2] bottom 271 (7 tabs from y 283): the actions group is only the overflow cell', () {
      final arrangement = _columnOf(innerLandscape).arrange([1, 2], bottom: 271)!;
      expect(
        arrangement,
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 232, [], overflow: true),
          ],
          overflow: const [1, 2],
        ),
      );
      expect(arrangement.groups[1]!.shown, isEmpty);
      expect(arrangement.overflowCell, const Rect.fromLTRB(879, 184, 927, 232));
    });

    test('inner landscape [1, 2] bottom 321 (6 tabs from y 333): everything fits', () {
      expect(
        _columnOf(innerLandscape).arrange([1, 2], bottom: 321),
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 284, [1, 2]),
          ],
          overflow: const [],
        ),
      );
    });

    test('inner landscape [1, 4] keep bottom 336 with the last item pinned: items 2 and 3 move', () {
      expect(
        _columnOf(innerLandscape).arrange([1, 4], keepFirstGroup: true, bottom: 336, pinned: {4}),
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 336, [1, 4], overflow: true),
          ],
          overflow: const [2, 3],
        ),
      );
    });

    test('right Split View window [1, 2] keep: x 397-445, y 124-172 and 184-284', () {
      expect(
        _columnOf(_rightWindowNoTopBarTop).arrange([1, 2], keepFirstGroup: true),
        VerticalBarArrangement(
          groups: [
            _slot(397, 124, 172, [0]),
            _slot(397, 184, 284, [1, 2]),
          ],
          overflow: const [],
        ),
      );
    });

    test('left Split View window [1, 2] keep: x 24-72, y 24-72 and 84-184', () {
      expect(
        _columnOf(leftWindow).arrange([1, 2], keepFirstGroup: true),
        VerticalBarArrangement(
          groups: [
            _slot(24, 24, 72, [0]),
            _slot(24, 84, 184, [1, 2]),
          ],
          overflow: const [],
        ),
      );
    });

    test('left Split View window [1, 10] keep: everything fits, actions y 84-600', () {
      expect(
        _columnOf(leftWindow).arrange([1, 10], keepFirstGroup: true),
        VerticalBarArrangement(
          groups: [
            _slot(24, 24, 72, [0]),
            _slot(24, 84, 600, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
          ],
          overflow: const [],
        ),
      );
    });

    test('left Split View window without topBarTop: cells start at y 16, 8 above UIKit', () {
      final region = _withRect(leftWindow.region!, leftWindow.region!.rect);
      expect(
        _resolve(leftWindow, region: region)!.arrange([1, 2], keepFirstGroup: true),
        VerticalBarArrangement(
          groups: [
            _slot(24, 16, 64, [0]),
            _slot(24, 76, 176, [1, 2]),
          ],
          overflow: const [],
        ),
      );
    });
  });

  group('arrange', () {
    final column = _columnOf(innerLandscape);

    test('empty input gives an empty result, not null, even without room', () {
      final arrangement = column.arrange(const []);
      expect(arrangement, VerticalBarArrangement(groups: const [], overflow: const []));
      expect(arrangement!.overflowCell, isNull);
      expect(column.arrange(const [], bottom: 0), arrangement);
    });

    test('group sizes of 0 or less assert', () {
      expect(() => column.arrange([1, 0]), throwsAssertionError);
      expect(() => column.arrange([-1]), throwsAssertionError);
    });

    test('cells end at most 0.5 below bottom', () {
      final full = VerticalBarArrangement(
        groups: [
          _inner(124, 172, [0]),
          _inner(184, 596, [1, 2, 3, 4, 5, 6, 7, 8]),
        ],
        overflow: const [],
      );
      expect(column.arrange([1, 8], bottom: 596), full);
      expect(column.arrange([1, 8], bottom: 595.5), full);
      expect(column.arrange([1, 8], bottom: 595.4)!.overflow, isNotEmpty);
    });

    test('items bound the placement below a larger bottom', () {
      expect(column.arrange([1, 9], bottom: 1000)!.overflow, const [8, 9]);
      expect(column.arrange([1, 9], bottom: double.infinity), column.arrange([1, 9]));
      expect(column.arrange([1, 20], bottom: double.infinity)!.overflow, hasLength(13));
    });

    test('a NaN bottom asserts', () {
      // Release builds skip the assert and fall back to the items bound, like a null bottom.
      expect(() => column.arrange([1, 20], bottom: double.nan), throwsAssertionError);
      expect(() => column.arrange(const [], bottom: double.nan), throwsAssertionError);
    });

    test('keepFirstGroup returns null when the first group and the overflow cell do not fit', () {
      expect(column.arrange([1, 2], keepFirstGroup: true, bottom: 200), isNull);
      expect(column.arrange([1], keepFirstGroup: true, bottom: 150), isNull);
    });

    test('without keepFirstGroup the first group can move too', () {
      expect(
        column.arrange([1, 2], bottom: 200),
        VerticalBarArrangement(groups: [_inner(124, 172, [], overflow: true), null], overflow: const [0, 1, 2]),
      );
    });

    test('returns null when not even the overflow cell fits', () {
      expect(column.arrange([3], bottom: 150), isNull);
      expect(column.arrange([1, 2], bottom: 100), isNull, reason: 'bottom above the items');
    });

    test('a later group whose items all moved is null; the overflow cell joins the first moved item group', () {
      // [3, 2, 1] in y 124-388: moving 5 and 4 leaves group 1 with item 3 and the overflow cell.
      expect(
        column.arrange([3, 2, 1], bottom: 388),
        VerticalBarArrangement(
          groups: [
            _inner(124, 276, [0, 1, 2]),
            _inner(288, 388, [3], overflow: true),
            null,
          ],
          overflow: const [4, 5],
        ),
      );
    });

    test('pinned items move only after every other movable item', () {
      // Two of [1, 2, 3, 4] must move; pinning 3 and 4 moves 2 and 1 instead.
      expect(
        column.arrange([1, 4], keepFirstGroup: true, bottom: 336, pinned: {3, 4})!.overflow,
        const [1, 2],
      );
      // Only pinned items are left to move: they move from the end.
      expect(
        column.arrange([1, 4], keepFirstGroup: true, bottom: 336, pinned: {1, 2, 3, 4})!.overflow,
        const [3, 4],
      );
      // keepFirstGroup ignores a pinned first group, and pins outside the input are ignored.
      expect(
        column.arrange([1, 4], keepFirstGroup: true, bottom: 336, pinned: {0, 9})!.overflow,
        const [3, 4],
      );
    });

    test('a pinned item can stay below the overflow cell group', () {
      // Items 3 and 2 move instead of the pinned item 4, so the last group stays shown.
      expect(
        column.arrange([1, 3, 1], keepFirstGroup: true, bottom: 360, pinned: {4}),
        VerticalBarArrangement(
          groups: [
            _inner(124, 172, [0]),
            _inner(184, 284, [1], overflow: true),
            _inner(296, 344, [4]),
          ],
          overflow: const [2, 3],
        ),
      );
    });

    test('overflowCell is the last cell of the group ending with the overflow cell', () {
      final arrangement = column.arrange([2, 9])!;
      expect(arrangement.overflow, const [8, 9, 10]);
      expect(arrangement.overflowCell, arrangement.groups[1]!.cells.last);
      expect(arrangement.overflowCell, const Rect.fromLTRB(879, 548, 927, 596));
      expect(column.arrange([1, 2])!.overflowCell, isNull);
      expect(
        VerticalBarArrangement(groups: [_inner(124, 172, [], overflow: true)], overflow: const []).overflowCell,
        isNull,
        reason: 'no overflow items, even though a group claims the overflow cell',
      );
    });
  });

  group('value types', () {
    test('VerticalBarColumn compares edge, viewSize, column, and items', () {
      final column = _columnOf(innerLandscape);
      const same = VerticalBarColumn(
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
        column: Rect.fromLTRB(867, 0, 951, 669),
        items: Rect.fromLTRB(879, 124, 927, 635),
      );
      expect(column, same);
      expect(column.hashCode, same.hashCode);
      for (final other in const [
        VerticalBarColumn(
          edge: HorizontalEdge.left,
          viewSize: Size(951, 669),
          column: Rect.fromLTRB(867, 0, 951, 669),
          items: Rect.fromLTRB(879, 124, 927, 635),
        ),
        VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(951, 670),
          column: Rect.fromLTRB(867, 0, 951, 669),
          items: Rect.fromLTRB(879, 124, 927, 635),
        ),
        VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(951, 669),
          column: Rect.fromLTRB(851, 0, 951, 669),
          items: Rect.fromLTRB(879, 124, 927, 635),
        ),
        VerticalBarColumn(
          edge: HorizontalEdge.right,
          viewSize: Size(951, 669),
          column: Rect.fromLTRB(867, 0, 951, 669),
          items: Rect.fromLTRB(879, 24, 927, 635),
        ),
      ]) {
        expect(column, isNot(other));
      }
      expect(column.toString(), allOf(contains('VerticalBarColumn('), contains('items: Rect.fromLTRB(879.0, 124.0')));
    });

    test('VerticalBarGroupSlot compares rect, shown, and endsWithOverflow', () {
      final slot = _inner(184, 284, [1, 2]);
      expect(slot, _inner(184, 284, [1, 2]));
      expect(slot.hashCode, _inner(184, 284, [1, 2]).hashCode);
      expect(slot, isNot(_inner(184, 284, [1, 3])));
      expect(slot, isNot(_inner(184, 284, [1, 2], overflow: true)));
      expect(slot, isNot(_inner(188, 288, [1, 2])));
      expect(
        slot.toString(),
        allOf(contains('VerticalBarGroupSlot('), contains('shown: [1, 2]'), contains('endsWithOverflow: false')),
      );
    });

    test('VerticalBarArrangement compares groups and overflow', () {
      final arrangement = VerticalBarArrangement(
        groups: [_inner(124, 172, [], overflow: true), null],
        overflow: const [0, 1, 2],
      );
      final same = VerticalBarArrangement(
        groups: [_inner(124, 172, [], overflow: true), null],
        overflow: const [0, 1, 2],
      );
      expect(arrangement, same);
      expect(arrangement.hashCode, same.hashCode);
      expect(
        arrangement,
        isNot(VerticalBarArrangement(groups: [_inner(124, 172, [], overflow: true)], overflow: const [0, 1, 2])),
      );
      expect(
        arrangement,
        isNot(VerticalBarArrangement(groups: [_inner(124, 172, [], overflow: true), null], overflow: const [1, 2])),
      );
      expect(arrangement.toString(), allOf(contains('VerticalBarArrangement('), contains('overflow: [0, 1, 2]')));
    });

    test('result lists cannot be modified, and later input changes do not leak in', () {
      final shown = [1, 2];
      final slot = VerticalBarGroupSlot(
        rect: const Rect.fromLTRB(879, 184, 927, 284),
        shown: shown,
        endsWithOverflow: false,
      );
      final groups = <VerticalBarGroupSlot?>[slot];
      final overflow = <int>[3];
      final arrangement = VerticalBarArrangement(groups: groups, overflow: overflow);
      shown.add(9);
      groups.add(null);
      overflow.add(9);
      expect(slot.shown, const [1, 2]);
      expect(arrangement.groups, [slot]);
      expect(arrangement.overflow, const [3]);
      expect(() => slot.shown.add(3), throwsUnsupportedError);
      expect(() => slot.cells.add(Rect.zero), throwsUnsupportedError);
      expect(() => arrangement.groups.add(null), throwsUnsupportedError);
      expect(() => arrangement.overflow.add(4), throwsUnsupportedError);

      final arranged = _columnOf(innerLandscape).arrange([1, 9])!;
      expect(arranged.groups.removeLast, throwsUnsupportedError);
      expect(arranged.overflow.clear, throwsUnsupportedError);
      expect(() => arranged.groups.first!.shown.clear(), throwsUnsupportedError);
    });
  });

  group('of', () {
    testWidgets('resolves the window column below VerticalBarEdge and SideStatusBarInsets', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(_chain(region: innerLandscape.region));
      // SideStatusBarInsets raised the top to 16; of reads the OS value without it.
      expect(_ColumnProbeState.column, _columnOf(innerLandscape));
    });

    testWidgets('returns null without scopes, without an edge, or for a stale window size', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: _ColumnProbe()));
      expect(_ColumnProbeState.column, isNull);

      await tester.pumpWidget(_chain(edge: null, region: innerLandscape.region));
      expect(_ColumnProbeState.column, isNull);

      await tester.pumpWidget(_chain(region: _rightWindowNoTopBarTop.region));
      expect(_ColumnProbeState.column, isNull, reason: 'the 469-point sample does not match the window');
    });

    testWidgets('keyboard, text scale, and text direction changes do not rebuild the caller', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(_chain(region: innerLandscape.region));
      final column = _ColumnProbeState.column;
      expect(column, isNotNull);
      final builds = _ColumnProbeState.builds;

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(_ColumnProbeState.builds, builds, reason: 'viewInsets');

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(_ColumnProbeState.builds, builds, reason: 'textScaler');

      await tester.pumpWidget(_chain(region: innerLandscape.region, textDirection: TextDirection.rtl));
      expect(_ColumnProbeState.builds, builds, reason: 'Directionality');
      expect(_ColumnProbeState.column, column);
    });

    testWidgets('region, edge, and safe-area changes rebuild the caller with the new value', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(_chain(region: innerLandscape.region));
      var builds = _ColumnProbeState.builds;

      final lower = _withRect(innerLandscape.region!, const Rect.fromLTRB(879, 200, 927, 635), topBarTop: 24);
      await tester.pumpWidget(_chain(region: lower));
      expect(_ColumnProbeState.builds, builds + 1);
      expect(_ColumnProbeState.column?.items.top, 200);
      builds = _ColumnProbeState.builds;

      await tester.pumpWidget(_chain(edge: HorizontalEdge.left, region: lower));
      expect(_ColumnProbeState.builds, greaterThan(builds));
      expect(_ColumnProbeState.column, isNull);
      builds = _ColumnProbeState.builds;

      await tester.pumpWidget(_chain(region: lower));
      expect(_ColumnProbeState.column, isNotNull);
      builds = _ColumnProbeState.builds;

      tester.view.viewPadding = const FakeViewPadding(left: 62, right: 84, bottom: 34);
      tester.view.padding = const FakeViewPadding(left: 62, right: 84, bottom: 34);
      await tester.pump();
      expect(_ColumnProbeState.builds, greaterThan(builds));
      expect(_ColumnProbeState.column, isNull, reason: 'insets on both sides');
    });

    testWidgets('an own-side safe-area change alone rebuilds the caller with the new width', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(_chain(region: innerLandscape.region));
      expect(_ColumnProbeState.column?.width, 84);
      final builds = _ColumnProbeState.builds;

      // SideStatusBarInsets still adds top 16, so only the viewPadding dependency can rebuild the caller.
      tester.view.viewPadding = const FakeViewPadding(right: 100, bottom: 34);
      tester.view.padding = const FakeViewPadding(right: 100, bottom: 34);
      await tester.pump();
      expect(_ColumnProbeState.builds, greaterThan(builds));
      expect(_ColumnProbeState.column?.column, const Rect.fromLTRB(851, 0, 951, 669));
    });
  });
}
