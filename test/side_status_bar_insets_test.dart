import 'dart:async';

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Independent fixtures for logical window size, OS safe areas, and native edge.
/// Based on simulator measurements; the outer Duo fixture retains an earlier
/// 20-point bottom inset to cover that geometry as well as the later 34-point inset.
typedef _Screen = ({String name, Size size, EdgeInsets padding, HorizontalEdge? edge});

const _Screen _iPhone17Portrait = (
  name: 'iPhone 17 portrait',
  size: Size(402, 874),
  padding: EdgeInsets.only(top: 62, bottom: 34),
  edge: null,
);
const _Screen _iPhone17Landscape = (
  name: 'iPhone 17 landscape',
  size: Size(874, 402),
  padding: EdgeInsets.only(left: 62, right: 62, bottom: 20),
  edge: null,
);
const _Screen _duoOuterPortrait = (
  name: 'iPhone Duo outer portrait',
  size: Size(466, 678),
  padding: EdgeInsets.only(right: 84, bottom: 20),
  edge: HorizontalEdge.right,
);
const _Screen _duoOuterLandscapeLeft = (
  name: 'iPhone Duo outer landscape (left column)',
  size: Size(678, 466),
  padding: EdgeInsets.only(left: 84, bottom: 34),
  edge: HorizontalEdge.left,
);
const _Screen _duoOuterLandscapeRight = (
  name: 'iPhone Duo outer landscape (right column)',
  size: Size(678, 466),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
);
const _Screen _duoInner = (
  name: 'iPhone Duo inner landscape',
  size: Size(951, 669),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
);
const _Screen _duoSplitRight = (
  name: 'iPhone Duo right Split View',
  size: Size(469, 669),
  padding: EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
);
const _Screen _duoSplitLeft = (
  name: 'iPhone Duo left Split View',
  size: Size(469, 669),
  padding: EdgeInsets.only(bottom: 34),
  edge: HorizontalEdge.left,
);
const _Screen _duoInnerPortrait = (
  name: 'iPhone Duo inner portrait',
  size: Size(669, 951),
  padding: EdgeInsets.only(top: 82, bottom: 34),
  edge: null,
);
const _Screen _iPad13Portrait = (
  name: 'iPad Pro 13" portrait',
  size: Size(1032, 1376),
  padding: EdgeInsets.only(top: 32, bottom: 25),
  edge: null,
);
const _Screen _iPad13Landscape = (
  name: 'iPad Pro 13" landscape',
  size: Size(1376, 1032),
  padding: EdgeInsets.only(top: 32, bottom: 25),
  edge: null,
);

/// Duo fixtures with 16 points added only at the top; other edges retain OS values.
final List<(_Screen, EdgeInsets)> _duoScreens = [
  (_duoOuterPortrait, const EdgeInsets.fromLTRB(0, 16, 84, 20)),
  (_duoOuterLandscapeLeft, const EdgeInsets.fromLTRB(84, 16, 0, 34)),
  (_duoOuterLandscapeRight, const EdgeInsets.fromLTRB(0, 16, 84, 34)),
  (_duoInner, const EdgeInsets.fromLTRB(0, 16, 84, 34)),
  (_duoSplitRight, const EdgeInsets.fromLTRB(0, 16, 84, 34)),
  (_duoSplitLeft, const EdgeInsets.fromLTRB(0, 16, 0, 34)),
];

/// Fixtures whose safe areas must remain unchanged.
const List<_Screen> _otherScreens = [
  _iPhone17Portrait,
  _iPhone17Landscape,
  _duoInnerPortrait,
  _iPad13Portrait,
  _iPad13Landscape,
];

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

/// Preserves production wrapper order: OS metrics, native-edge scope, then insets.
/// [VerticalBarEdgeScope] substitutes [screen]'s values for the native channel.
Widget _appBuilder(_Screen screen, Widget? child) => VerticalBarEdgeScope(
  edge: screen.edge,
  child: SideStatusBarInsets(child: child ?? const SizedBox.shrink()),
);

/// Adds top spacing for Duo column layouts and the column-free left Split View
/// window. Horizontal insets and unrelated layouts must remain unchanged.
void main() {
  group('Inset eligibility and adjustment (applies / adjust)', () {
    test('Duo columns add 16 only at the top, even without a native edge', () {
      for (final (screen, app) in _duoScreens.where((e) => e.$1 != _duoSplitLeft)) {
        for (final systemBarEdge in [false, true]) {
          final reason = '${screen.name} (native edge present: $systemBarEdge)';
          expect(SideStatusBarInsets.applies(screen.padding, systemBarEdge: systemBarEdge), isTrue, reason: reason);
          expect(SideStatusBarInsets.adjust(screen.padding, systemBarEdge: systemBarEdge), app, reason: reason);
        }
      }
    });

    test('horizontal and bottom insets remain unchanged, including a zero column-free edge', () {
      for (final (screen, _) in _duoScreens) {
        final adjusted = SideStatusBarInsets.adjust(screen.padding, systemBarEdge: true);
        expect(adjusted.left, screen.padding.left, reason: screen.name);
        expect(adjusted.right, screen.padding.right, reason: screen.name);
        expect(adjusted.bottom, screen.padding.bottom, reason: '${screen.name}: bottom inset is unchanged');
        expect(adjusted.top, SideStatusBarInsets.minTop, reason: screen.name);
      }
      // Pin the literal value so changing the constant cannot silently change this contract.
      expect(SideStatusBarInsets.minTop, 16);
    });

    test('left Split View adds 16 at the top only with a native edge; horizontal insets stay zero', () {
      expect(SideStatusBarInsets.applies(_duoSplitLeft.padding, systemBarEdge: true), isTrue);
      expect(
        SideStatusBarInsets.adjust(_duoSplitLeft.padding, systemBarEdge: true),
        const EdgeInsets.fromLTRB(0, 16, 0, 34),
      );
      // No native edge is available on the first frame or outside VerticalBarEdge.
      expect(SideStatusBarInsets.applies(_duoSplitLeft.padding), isFalse);
      expect(SideStatusBarInsets.adjust(_duoSplitLeft.padding), _duoSplitLeft.padding);
    });

    test('unrelated window geometries remain unchanged', () {
      for (final padding in [
        for (final screen in _otherScreens) screen.padding, // Landscape iPhone: insets on both sides.
        const EdgeInsets.only(top: 24, right: 48), // Landscape Android: navigation buttons on the right.
        const EdgeInsets.only(top: 24, left: 48), // Reverse landscape: navigation buttons on the left.
        const EdgeInsets.only(top: 24, bottom: 48), // Android tablet.
        EdgeInsets.zero, // Column-free window without a native edge.
      ]) {
        expect(SideStatusBarInsets.applies(padding), isFalse, reason: '$padding');
        expect(SideStatusBarInsets.adjust(padding), padding, reason: '$padding');
      }
    });

    test('two-sided safe areas remain unchanged even with a native edge', () {
      // Exclude two-sided safe areas even if a native edge is reported; ordinary
      // landscape iPhone geometry must not depend on an assumed native response.
      expect(
        SideStatusBarInsets.applies(const EdgeInsets.only(left: 62, right: 62, bottom: 20), systemBarEdge: true),
        isFalse,
      );
      for (final padding in [
        _iPhone17Landscape.padding,
        const EdgeInsets.only(left: 62, right: 62), // Keyboard removes the bottom padding.
      ]) {
        expect(SideStatusBarInsets.applies(padding, systemBarEdge: true), isFalse, reason: '$padding');
        expect(SideStatusBarInsets.adjust(padding, systemBarEdge: true), padding, reason: '$padding');
      }
      // Left Split View still qualifies when the keyboard removes bottom padding.
      expect(SideStatusBarInsets.applies(EdgeInsets.zero, systemBarEdge: true), isTrue);
    });

    test('windows with a top safe area remain unchanged even with a native edge', () {
      for (final padding in [
        _duoInnerPortrait.padding,
        _iPad13Portrait.padding,
        const EdgeInsets.only(top: 24, right: 84, bottom: 34),
      ]) {
        expect(SideStatusBarInsets.applies(padding, systemBarEdge: true), isFalse, reason: '$padding');
        expect(SideStatusBarInsets.adjust(padding, systemBarEdge: true), padding, reason: '$padding');
      }
    });
  });

  group('SideStatusBarInsets (widget)', () {
    /// Reads the adjusted MediaQuery for [screen].
    Future<MediaQueryData> pumpInsets(WidgetTester tester, _Screen screen, {double keyboard = 0}) async {
      _useScreen(tester, screen);
      if (keyboard > 0) {
        // Keyboard geometry clears bottom padding while preserving viewPadding.
        tester.view
          ..padding = FakeViewPadding(left: screen.padding.left, top: screen.padding.top, right: screen.padding.right)
          ..viewInsets = FakeViewPadding(bottom: keyboard);
      }
      late MediaQueryData seen;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => _appBuilder(screen, child),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('Duo padding and viewPadding gain 16 only at the top; other OS insets are preserved', (tester) async {
      for (final (screen, app) in _duoScreens) {
        final data = await pumpInsets(tester, screen);
        expect(data.padding, app, reason: screen.name);
        expect(data.viewPadding, app, reason: screen.name);
      }
    });

    testWidgets('keyboard clears bottom padding while preserving the 16-point top and horizontal insets', (
      tester,
    ) async {
      var data = await pumpInsets(tester, _duoOuterPortrait, keyboard: 300);
      expect(data.padding, const EdgeInsets.fromLTRB(0, 16, 84, 0));
      expect(data.viewPadding, const EdgeInsets.fromLTRB(0, 16, 84, 20));
      expect(data.viewInsets.bottom, 300);

      // Left Split View retains 16 points at the top even with zero keyboard-adjusted padding.
      data = await pumpInsets(tester, _duoSplitLeft, keyboard: 300);
      expect(data.padding, const EdgeInsets.fromLTRB(0, 16, 0, 0));
      expect(data.viewPadding, const EdgeInsets.fromLTRB(0, 16, 0, 34));
    });

    testWidgets('unrelated windows receive unchanged MediaQuery insets', (tester) async {
      for (final screen in _otherScreens) {
        final data = await pumpInsets(tester, screen);
        expect(data.padding, screen.padding, reason: screen.name);
        expect(data.viewPadding, screen.padding, reason: screen.name);
      }
    });

    testWidgets('landscape iPhone 17 keeps its MediaQuery insets even when a native edge arrives', (tester) async {
      for (final edge in HorizontalEdge.values) {
        final _Screen screen = (
          name: '${_iPhone17Landscape.name} (native edge: $edge)',
          size: _iPhone17Landscape.size,
          padding: _iPhone17Landscape.padding,
          edge: edge,
        );
        final data = await pumpInsets(tester, screen);
        expect(data.padding, const EdgeInsets.only(left: 62, right: 62, bottom: 20), reason: screen.name);
        expect(data.viewPadding, const EdgeInsets.only(left: 62, right: 62, bottom: 20), reason: screen.name);
      }
    });

    testWidgets('placing insets outside VerticalBarEdge prevents left Split View top spacing', (tester) async {
      _useScreen(tester, _duoSplitLeft);
      late EdgeInsets inner;
      await tester.pumpWidget(
        MaterialApp(
          // Reversing the wrappers hides the native edge from SideStatusBarInsets.
          builder: (context, child) => SideStatusBarInsets(
            child: VerticalBarEdgeScope(edge: HorizontalEdge.left, child: child ?? const SizedBox.shrink()),
          ),
          home: Builder(
            builder: (context) {
              inner = MediaQuery.paddingOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(inner, _duoSplitLeft.padding);
    });

    testWidgets('left Split View top changes from 0 to 16 after the native reply; column windows start at 16', (
      tester,
    ) async {
      Future<List<double>> topsOnFirstFrames(_Screen screen) async {
        _useScreen(tester, screen);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          VerticalBarEdge.channel,
          (call) async => {'edge': screen.edge == HorizontalEdge.left ? 'left' : 'right'},
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null),
        );
        final tops = <double>[];
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            // Production wrapper order, with VerticalBarEdge querying the mocked native channel.
            builder: (context, child) =>
                VerticalBarEdge(child: SideStatusBarInsets(child: child ?? const SizedBox.shrink())),
            home: Builder(
              builder: (context) {
                tops.add(MediaQuery.paddingOf(context).top);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final firstFrame = List<double>.of(tops);
        await tester.pump();
        return [firstFrame.last, tops.last];
      }

      expect(await topsOnFirstFrames(_duoSplitLeft), [0, 16]);
      expect(await topsOnFirstFrames(_duoInner), [16, 16]);
      // Only iOS queries the native edge.
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    group('Added insets (addedOf / removeAdded / isActiveOf)', () {
      /// Returns a descendant context below SideStatusBarInsets for [screen].
      Future<BuildContext> pumpProbe(WidgetTester tester, _Screen screen) async {
        _useScreen(tester, screen);
        late BuildContext inner;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _appBuilder(screen, child),
            home: Builder(
              builder: (context) {
                inner = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return inner;
      }

      testWidgets('Duo adds only 16 at the top; removeAdded restores all four OS insets', (tester) async {
        for (final (screen, _) in _duoScreens) {
          final context = await pumpProbe(tester, screen);
          expect(SideStatusBarInsets.addedOf(context), const EdgeInsets.only(top: 16), reason: screen.name);
          expect(SideStatusBarInsets.isActiveOf(context), isTrue, reason: '${screen.name} (including left Split View)');
          expect(
            SideStatusBarInsets.removeAdded(context, MediaQuery.paddingOf(context)),
            screen.padding,
            reason: screen.name,
          );
        }
      });

      testWidgets('unrelated windows add no insets and removeAdded leaves them unchanged', (tester) async {
        for (final screen in _otherScreens) {
          final context = await pumpProbe(tester, screen);
          expect(SideStatusBarInsets.addedOf(context), EdgeInsets.zero, reason: screen.name);
          expect(SideStatusBarInsets.isActiveOf(context), isFalse, reason: screen.name);
          expect(
            SideStatusBarInsets.removeAdded(context, MediaQuery.paddingOf(context)),
            screen.padding,
            reason: screen.name,
          );
        }
      });

      testWidgets('removeAdded clamps at zero when the added inset has already been removed', (tester) async {
        final context = await pumpProbe(tester, _duoInner);
        expect(
          SideStatusBarInsets.removeAdded(context, const EdgeInsets.fromLTRB(0, 0, 84, 34)),
          const EdgeInsets.fromLTRB(0, 0, 84, 34),
        );
      });

      testWidgets('no ancestor SideStatusBarInsets means no added insets', (tester) async {
        late BuildContext inner;
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              inner = context;
              return const SizedBox.shrink();
            },
          ),
        );
        expect(SideStatusBarInsets.addedOf(inner), EdgeInsets.zero);
        expect(SideStatusBarInsets.isActiveOf(inner), isFalse);
        expect(
          SideStatusBarInsets.removeAdded(inner, const EdgeInsets.only(top: 16)),
          const EdgeInsets.only(top: 16),
        );
      });
    });

    testWidgets('window and native-edge changes preserve child State through a stable wrapper tree', (tester) async {
      Widget wrap(HorizontalEdge? edge) => Directionality(
        textDirection: TextDirection.ltr,
        child: VerticalBarEdgeScope(
          edge: edge,
          child: const SideStatusBarInsets(child: _Counter()),
        ),
      );

      _useScreen(tester, _duoInner);
      await tester.pumpWidget(wrap(_duoInner.edge));
      final state = tester.state(find.byType(_Counter));

      for (final screen in [
        _iPhone17Portrait,
        _duoOuterPortrait,
        _duoSplitLeft,
        _duoSplitRight,
        _duoOuterLandscapeLeft,
        _iPhone17Landscape,
        _duoInnerPortrait,
        _duoInner,
      ]) {
        _useScreen(tester, screen);
        await tester.pumpWidget(wrap(screen.edge));
        expect(tester.state(find.byType(_Counter)), same(state), reason: screen.name);
      }

      // Keep the same window while the native edge appears or disappears.
      _useScreen(tester, _duoSplitLeft);
      for (final edge in [null, HorizontalEdge.left, null, HorizontalEdge.right]) {
        await tester.pumpWidget(wrap(edge));
        expect(tester.state(find.byType(_Counter)), same(state), reason: 'native edge: $edge');
      }
    });

    // Root wrappers sit above Navigator, so dialogs and sheets inherit the same insets.
    group('Dialogs and bottom sheets', () {
      late BuildContext pageContext;

      Future<void> pumpPage(WidgetTester tester, _Screen screen) async {
        _useScreen(tester, screen);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _appBuilder(screen, child),
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold();
              },
            ),
          ),
        );
      }

      Future<Rect> showSheet(WidgetTester tester) async {
        unawaited(
          showModalBottomSheet<void>(
            context: pageContext,
            useSafeArea: true,
            builder: (context) => const SizedBox(key: ValueKey('sheet'), width: double.infinity, height: 120),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byKey(const ValueKey('sheet')));
      }

      Future<Rect> showAlert(WidgetTester tester) async {
        unawaited(
          showDialog<void>(
            context: pageContext,
            builder: (context) => const AlertDialog(content: Text('dialog')),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byType(AlertDialog));
      }

      testWidgets('Duo outer portrait sheet spans from the left edge to the right status column', (tester) async {
        await pumpPage(tester, _duoOuterPortrait);
        final sheet = await showSheet(tester);
        // No synthetic horizontal padding may shift this edge.
        expect(sheet.left, 0);
        expect(sheet.right, 466 - 84);
      });

      testWidgets(
        'Duo outer portrait dialog centers before the right column, below top 16, and above the bottom inset',
        (tester) async {
          await pumpPage(tester, _duoOuterPortrait);
          final dialog = await showAlert(tester);
          expect(dialog.center.dx, closeTo((0 + 466 - 84) / 2, 0.01));
          expect(dialog.center.dy, closeTo((16 + 678 - 20) / 2, 0.01));
        },
      );

      testWidgets('left Split View dialog centers across the full width between top 16 and the bottom inset', (
        tester,
      ) async {
        await pumpPage(tester, _duoSplitLeft);
        final dialog = await showAlert(tester);
        expect(dialog.center.dx, closeTo(469 / 2, 0.01));
        expect(dialog.center.dy, closeTo((16 + 669 - 34) / 2, 0.01));
      });

      testWidgets('portrait iPhone 17 sheet retains its full width', (tester) async {
        await pumpPage(tester, _iPhone17Portrait);
        final sheet = await showSheet(tester);
        expect(sheet.left, 0);
        expect(sheet.right, 402);
      });
    });
  });
}

/// Child used to verify State identity.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
