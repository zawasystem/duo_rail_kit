import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical window size and OS safe areas, independent of application fixtures.
/// Duo geometry is based on iOS 27.1 simulator measurements.
typedef _Screen = ({Size size, EdgeInsets padding});

/// Duo inner landscape.
const _Screen _duoInner = (size: Size(951, 669), padding: EdgeInsets.only(right: 84, bottom: 34));

/// Left Split View window: native edge on the left, without a status column.
const _Screen _duoSplitLeft = (size: Size(469, 669), padding: EdgeInsets.only(bottom: 34));

/// Duo outer landscape with the column on the left and the status bar hidden.
const _Screen _duoOuterLandscapeLeft = (size: Size(678, 466), padding: EdgeInsets.only(left: 84, bottom: 34));

/// Portrait iPad with a top status bar.
const _Screen _iPad13Portrait = (size: Size(1032, 1376), padding: EdgeInsets.only(top: 32, bottom: 25));

/// Landscape iPhone: two-sided safe areas exclude synthetic top padding.
const _Screen _iPhone17Landscape = (size: Size(874, 402), padding: EdgeInsets.only(left: 62, right: 62, bottom: 20));

/// Applies [screen] geometry and restores the test window at teardown.
void _useScreen(WidgetTester tester, _Screen screen) {
  final padding = FakeViewPadding(
    left: screen.padding.left,
    top: screen.padding.top,
    right: screen.padding.right,
    bottom: screen.padding.bottom,
  );
  tester.view
    ..physicalSize = screen.size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// Example application rule: show a rail at a window width of 720 or more.
bool _wideWindowShowsRail(double windowWidth) => windowWidth >= 720;

void main() {
  group('RailPlacement.of', () {
    /// [hasScope] optionally supplies native values; false tests a missing ancestor.
    Future<RailPlacement?> placementOf(
      WidgetTester tester, {
      required bool hasScope,
      HorizontalEdge? osEdge,
      Size window = const Size(800, 600),
      bool Function(double windowWidth) showsRailByWidth = _wideWindowShowsRail,
    }) async {
      RailPlacement? placement;
      Widget probe = Builder(
        builder: (context) {
          placement = RailPlacement.of(context, showsRailByWidth: showsRailByWidth);
          return const SizedBox.shrink();
        },
      );
      if (hasScope) {
        probe = VerticalBarEdgeScope(edge: osEdge, child: probe);
      }
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: window),
          child: probe,
        ),
      );
      return placement;
    }

    testWidgets('native right edge places the rail on the right and follows the system bar', (tester) async {
      expect(
        await placementOf(tester, hasScope: true, osEdge: HorizontalEdge.right),
        const RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true),
      );
    });

    testWidgets('hidden native status bar in outer landscape propagates statusBarHidden', (tester) async {
      RailPlacement? placement;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(678, 466)),
          child: VerticalBarEdgeScope(
            edge: HorizontalEdge.left,
            statusBarHidden: true,
            child: Builder(
              builder: (context) {
                placement = RailPlacement.of(context, showsRailByWidth: _wideWindowShowsRail);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(placement, const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true, statusBarHidden: true));
    });

    testWidgets('width-based rails reset statusBarHidden to false', (tester) async {
      RailPlacement? placement;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(951, 669)),
          child: VerticalBarEdgeScope(
            edge: null,
            statusBarHidden: true,
            child: Builder(
              builder: (context) {
                placement = RailPlacement.of(context, showsRailByWidth: _wideWindowShowsRail);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(placement, const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false));
    });

    testWidgets('native left edge in Split View also follows the system bar', (tester) async {
      expect(
        await placementOf(tester, hasScope: true, osEdge: HorizontalEdge.left),
        const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true),
      );
    });

    testWidgets('native edge takes precedence without calling the width rule, even in narrow windows', (tester) async {
      var asked = 0;
      final placement = await placementOf(
        tester,
        hasScope: true,
        osEdge: HorizontalEdge.right,
        window: const Size(466, 678),
        showsRailByWidth: (width) {
          asked++;
          return false;
        },
      );
      expect(placement, const RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true));
      expect(asked, 0);
    });

    testWidgets('null native edge and a true width rule select a left rail without system alignment', (tester) async {
      expect(
        await placementOf(tester, hasScope: true),
        const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false),
      );
    });

    testWidgets('missing VerticalBarEdge ancestor uses only the width rule', (tester) async {
      expect(
        await placementOf(tester, hasScope: false),
        const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false),
      );
    });

    testWidgets('width rule receives the window width from MediaQuery.sizeOf', (tester) async {
      double? received;
      await placementOf(
        tester,
        hasScope: false,
        window: const Size(951, 669),
        showsRailByWidth: (width) {
          received = width;
          return true;
        },
      );
      expect(received, 951);
    });

    testWidgets('no native edge and a false width rule return null for bottom navigation', (tester) async {
      expect(await placementOf(tester, hasScope: true, window: const Size(466, 678)), isNull);
      expect(await placementOf(tester, hasScope: false, window: const Size(466, 678)), isNull);
    });
  });

  group('RailPlacement value semantics', () {
    test('equality and hashCode use edge, followsSystemBar, and statusBarHidden', () {
      const a = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true);
      const same = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true);
      const otherEdge = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      const otherFollows = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: false);
      const otherHidden = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true, statusBarHidden: true);
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(otherEdge));
      expect(a, isNot(otherFollows));
      expect(a, isNot(otherHidden));
      expect(a.statusBarHidden, isFalse, reason: 'defaults to false');
      expect(otherHidden.toString(), contains('statusBarHidden: true'));
    });
  });

  group('RailPlacement.railSafeAreaOf', () {
    /// Wraps [device] in native edge then inset scopes, matching production order.
    /// Reads both top-inset policies from one context/build to avoid stale values.
    Future<({EdgeInsets withTop, EdgeInsets withoutTop})> railSafeArea(
      WidgetTester tester,
      _Screen device, {
      HorizontalEdge? edge,
    }) async {
      _useScreen(tester, device);
      EdgeInsets? withTop;
      EdgeInsets? withoutTop;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => VerticalBarEdgeScope(
            edge: edge,
            child: SideStatusBarInsets(child: child ?? const SizedBox.shrink()),
          ),
          home: Builder(
            builder: (context) {
              withTop = RailPlacement.railSafeAreaOf(context, receivesAddedTop: true);
              withoutTop = RailPlacement.railSafeAreaOf(context, receivesAddedTop: false);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return (withTop: withTop!, withoutTop: withoutTop!);
    }

    testWidgets('Duo columns can keep the added 16-point top while preserving other OS insets', (tester) async {
      expect(
        (await railSafeArea(tester, _duoInner, edge: HorizontalEdge.right)).withTop,
        const EdgeInsets.fromLTRB(0, 16, 84, 34),
      );
      expect(
        (await railSafeArea(tester, _duoOuterLandscapeLeft, edge: HorizontalEdge.left)).withTop,
        const EdgeInsets.fromLTRB(84, 16, 0, 34),
        reason: 'a left column does not add padding on the column-free right edge',
      );
    });

    testWidgets('opting out of the added top restores all four OS insets for Duo columns', (tester) async {
      expect(
        (await railSafeArea(tester, _duoInner, edge: HorizontalEdge.right)).withoutTop,
        const EdgeInsets.only(right: 84, bottom: 34),
      );
      expect(
        (await railSafeArea(tester, _duoOuterLandscapeLeft, edge: HorizontalEdge.left)).withoutTop,
        const EdgeInsets.only(left: 84, bottom: 34),
      );
    });

    // The column-free left window gains top spacing for content, but the rail must not move.
    testWidgets('left Split View uses all four OS insets regardless of the added-top policy', (tester) async {
      final result = await railSafeArea(tester, _duoSplitLeft, edge: HorizontalEdge.left);
      expect(
        result.withTop,
        _duoSplitLeft.padding,
        reason: 'the added top is excluded for a column-free window even when requested',
      );
      expect(result.withoutTop, _duoSplitLeft.padding);
    });

    testWidgets('both policies preserve all insets when SideStatusBarInsets adds nothing', (tester) async {
      // Unadjusted iPad and landscape iPhone safe areas must survive either policy.
      for (final device in [_iPad13Portrait, _iPhone17Landscape]) {
        final result = await railSafeArea(tester, device);
        expect(result.withTop, device.padding, reason: '${device.padding}: receivesAddedTop is true');
        expect(result.withoutTop, device.padding, reason: '${device.padding}: receivesAddedTop is false');
      }
    });

    testWidgets('missing SideStatusBarInsets ancestor leaves application insets unchanged', (tester) async {
      _useScreen(tester, _duoInner);
      late EdgeInsets result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = RailPlacement.railSafeAreaOf(context, receivesAddedTop: true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, _duoInner.padding);
    });
  });

  group('RailPlacement.occupiedWidth', () {
    const rightFollowing = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true);
    const leftByWidth = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false);

    test('system rail occupies the larger of column width and rail width', () {
      const column = EdgeInsets.only(right: 84, bottom: 34);
      expect(rightFollowing.occupiedWidth(column, 64), 84);
      expect(rightFollowing.occupiedWidth(column, 104), 104);
    });

    test('system rail uses its own width when its edge has no column', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      expect(placement.occupiedWidth(const EdgeInsets.only(right: 84), 64), 64);
      expect(placement.occupiedWidth(const EdgeInsets.only(left: 84), 64), 84);
    });

    test('width-based left rail adds its width after the safe-area inset', () {
      expect(leftByWidth.occupiedWidth(const EdgeInsets.only(left: 62, bottom: 20), 64), 126);
      expect(leftByWidth.occupiedWidth(EdgeInsets.zero, 64), 64);
      expect(leftByWidth.occupiedWidth(const EdgeInsets.only(left: 62), 104), 166);
    });

    test('occupied width ignores the opposite safe-area inset', () {
      expect(leftByWidth.occupiedWidth(const EdgeInsets.only(right: 84), 64), 64);
    });

    // Measured Duo status columns are 84 points across orientations and Split View.
    test('statusColumnWidth matches the measured 84-point Duo column', () {
      expect(RailPlacement.statusColumnWidth, 84);
    });

    test('a statusColumnWidth rail occupies the column once and stays within its width', () {
      const width = RailPlacement.statusColumnWidth;
      expect(rightFollowing.occupiedWidth(const EdgeInsets.only(right: 84, bottom: 34), width), 84);
      expect(rightFollowing.occupiedWidth(const EdgeInsets.only(right: 84, bottom: 20), width), 84);
      const leftColumn = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true, statusBarHidden: true);
      expect(leftColumn.occupiedWidth(const EdgeInsets.only(left: 84, bottom: 34), width), 84);
      // Without a column, occupied width is just the rail width.
      const splitLeft = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      expect(splitLeft.occupiedWidth(const EdgeInsets.only(bottom: 34), width), 84);
    });
  });

  group('RailPlacement.centredRailSafeArea', () {
    const top = RailPlacement.statusColumnBottom;

    test('statusColumnBottom is the measured outer-display boundary of approximately 151 plus one', () {
      expect(RailPlacement.statusColumnBottom, 152);
    });

    test('visible right status column clears the right inset and sets top to 152 without changing bottom', () {
      const placement = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.only(right: 84, bottom: 34)),
        const EdgeInsets.fromLTRB(0, top, 0, 34),
      );
    });

    // The opposite outer-landscape orientation has a right column and hidden status bar.
    test('hidden right status column clears the right inset without adding a top band', () {
      const placement = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true, statusBarHidden: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.only(right: 84, bottom: 34)),
        const EdgeInsets.only(bottom: 34),
      );
    });

    test('hidden left status column clears the left inset without adding a top band', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true, statusBarHidden: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.only(left: 84, bottom: 34)),
        const EdgeInsets.only(bottom: 34),
      );
    });

    test('hypothetical visible left status column clears the left inset and sets top to 152', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.only(left: 84, bottom: 34)),
        const EdgeInsets.fromLTRB(0, top, 0, 34),
      );
    });

    test('column-free left Split View retains its safe area', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      const safeArea = EdgeInsets.only(bottom: 34);
      expect(placement.centredRailSafeArea(safeArea), safeArea);
    });

    test('opposite-edge inset remains unchanged', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.only(right: 84, bottom: 34)),
        const EdgeInsets.only(right: 84, bottom: 34),
      );
    });

    test('width-based left rail retains both 62-point landscape notch insets', () {
      const placement = RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false);
      const notch = EdgeInsets.only(left: 62, right: 62, bottom: 20);
      expect(placement.centredRailSafeArea(notch), notch);
    });

    test('top inset already above 152 is preserved while the rail-edge inset is cleared', () {
      const placement = RailPlacement(edge: HorizontalEdge.right, followsSystemBar: true);
      expect(
        placement.centredRailSafeArea(const EdgeInsets.fromLTRB(0, 160, 84, 34)),
        const EdgeInsets.fromLTRB(0, 160, 0, 34),
      );
    });
  });
}
