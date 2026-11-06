import 'dart:async';
import 'dart:math' as math;

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/toolbar/vertical_bar_toolbar.dart' show VerticalBarShellDebugStats;
import 'package:flutter/cupertino.dart' show CupertinoSheetRoute;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/actions.dart';
import 'support/cells.dart';
import 'support/diagnostics.dart';
import 'support/duo_windows.dart';
import 'support/shell_harness.dart';
import 'support/traversal.dart';

/// Home with four actions and three tabs with two each.
const List<List<String>> _fourTabs = [
  ['a0', 'b0', 'c0', 'd0'],
  ['a1', 'b1'],
  ['a2', 'b2'],
  ['a3', 'b3'],
];

/// The rectangles of the rail's first [items] items.
List<Rect> _railRects(WidgetTester tester, int items) => [
  for (var item = 0; item < items; item++) tester.getRect(find.byKey(ValueKey('rail:$item'))),
];

/// The top of the scrolling rail's viewport: the rail's top padding.
double _scrollingRailTop(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('railViewport'))).top;

/// The labels [ids] show with beside a rail that leaves room for [capacity] cells.
List<String> _labelsFitting(List<String> ids, int capacity) =>
    ids.length <= capacity ? ids : [...ids.take(capacity - 1), 'Show menu'];

/// A standard action labelled and identified by [id].
VerticalBarAction _action(String id) =>
    VerticalBarAction(id: id, icon: const Icon(Icons.star), label: id, onPressed: (invocation) {});

/// The four 56-point items of a custom rail, keyed `rail:<index>`.
List<Widget> _railItems() => [
  for (var item = 0; item < 4; item++) SizedBox(key: ValueKey('rail:$item'), width: 84, height: 56),
];

/// A custom rail whose items, in the Flex that [group] builds, sit above the bottom inset.
Widget _customRail(Widget group) => SizedBox(
  width: 84,
  child: Material(
    child: Column(children: [const Spacer(), group, const SizedBox(height: 34)]),
  ),
);

/// A shell on the inner landscape display with [rail] beside a page with four actions.
Widget _railApp(ShellHarness harness, Widget rail) => duoApp(
  innerLandscape,
  home: VerticalBarShell(
    railEdge: HorizontalEdge.right,
    rail: rail,
    content: harnessPage(harness, title: 'Home', actions: const ['a0', 'b0', 'c0', 'd0']),
  ),
);

/// Records what [VerticalBarShell.railPaddingOf] returned to a rail, and how often the rail built.
class _ProbeRecord {
  int builds = 0;

  /// For [_probeInput].
  EdgeInsets? padding;

  /// For [_noTopInput].
  EdgeInsets? noTopPadding;
}

/// A rail that only asks the shell for its padding, given [_probeInput] and [_noTopInput].
class _Probe extends StatelessWidget {
  const _Probe(this.record);

  final _ProbeRecord record;

  @override
  Widget build(BuildContext context) {
    record
      ..builds += 1
      ..padding = VerticalBarShell.railPaddingOf(context, _probeInput)
      ..noTopPadding = VerticalBarShell.railPaddingOf(context, _noTopInput);
    return const SizedBox(width: 84);
  }
}

const EdgeInsets _probeInput = EdgeInsets.only(top: 152, bottom: 34);

/// Below every floor, so that the shell raises it wherever it uses the column; [_probeInput] is above
/// the floors that the outer landscape displays and the left Split View window would have.
const EdgeInsets _noTopInput = EdgeInsets.only(bottom: 34);

/// A focusable sibling beside the shell in the "unchanged" fixtures.
enum _Sibling {
  none(''),

  /// [miniPlayerAround]: read by screen readers, outside the route's focus scope.
  belowNavigator(', with a focusable sibling below the Navigator'),

  /// `shellApp(playerBelowShell: true)`: in the route's focus scope, below every rail and content item.
  belowShell(', with a focusable sibling below the shell in its route');

  const _Sibling(this.suffix);

  final String suffix;
}

/// Pumps a shell with a [_Probe] rail for [window] and returns the probe's record.
Future<_ProbeRecord> _pumpProbe(
  WidgetTester tester,
  DuoWindow window, {
  required HorizontalEdge? railEdge,
  bool enabled = true,
  bool reservesBack = false,
}) async {
  useWindow(tester, window);
  final record = _ProbeRecord();
  await tester.pumpWidget(
    duoApp(
      window,
      home: VerticalBarShell(
        railEdge: railEdge,
        rail: _Probe(record),
        content: const SizedBox.expand(),
        enabled: enabled,
        reservesBack: reservesBack,
      ),
    ),
  );
  return record;
}

void main() {
  group('unchanged where the column is not used', () {
    final cases = <(DuoWindow, String, HorizontalEdge?, HarnessRail, ShellShape, bool)>[
      (iPhone17, 'no rail', null, navigationRail(destinations: 3), ShellShape.inBody, true),
      (iPad, 'a left NavigationRail', HorizontalEdge.left, navigationRail(destinations: 3), ShellShape.inBody, true),
      (android, 'no rail', null, navigationRail(destinations: 3), ShellShape.inBody, true),
      (innerPortrait, 'no rail', null, scrollingRail, ShellShape.outside, true),
      (firstFrame, 'a left scrolling rail', HorizontalEdge.left, scrollingRail, ShellShape.outside, true),
      (leftWindow, 'a left scrolling rail', HorizontalEdge.left, scrollingRail, ShellShape.outside, true),
      (mixedRotation, 'a right scrolling rail', HorizontalEdge.right, scrollingRail, ShellShape.outside, true),
      (
        outerLandscapeRight,
        'a right NavigationRail',
        HorizontalEdge.right,
        navigationRail(destinations: 3),
        ShellShape.inBody,
        true,
      ),
      (outerLandscapeLeft, 'a left scrolling rail', HorizontalEdge.left, scrollingRail, ShellShape.outside, true),
      (
        innerLandscape,
        'a right scrolling rail, enabled: false',
        HorizontalEdge.right,
        scrollingRail,
        ShellShape.outside,
        false,
      ),
      (
        innerLandscape,
        'a right NavigationRail, enabled: false',
        HorizontalEdge.right,
        navigationRail(destinations: 5),
        ShellShape.inBody,
        false,
      ),
    ];
    for (final (window, label, railEdge, rail, shape, enabled) in cases) {
      for (final sibling in _Sibling.values) {
        testWidgets('${window.name}, $label${sibling.suffix}: rects, semantics, and Tab order as a RailSideRow', (
          tester,
        ) async {
          useWindow(tester, window);
          final semantics = tester.ensureSemantics();
          Widget app({required bool plain}) => shellApp(
            window,
            ShellHarness(),
            railEdge: railEdge,
            rail: rail,
            shape: shape,
            enabled: enabled,
            plain: plain,
            around: sibling == _Sibling.belowNavigator ? miniPlayerAround : null,
            playerBelowShell: sibling == _Sibling.belowShell,
          );
          final expected = await harnessSnapshot(tester, app(plain: true), presses: 16);
          final actual = await harnessSnapshot(tester, app(plain: false), presses: 16);
          expect(actual.rects, expected.rects);
          expect(actual.semantics, expected.semantics);
          expect(actual.tabOrder, expected.tabOrder);
          // The fixtures have something to compare.
          expect(expected.rects, isNotEmpty);
          expect(expected.tabOrder.where((rect) => rect != Rect.zero), isNotEmpty);
          if (sibling == _Sibling.belowShell) {
            // Tab reaches the player in both hosts.
            expect(
              tabCycleOf(expected.tabOrder).where((rect) => rect.top >= window.size.height - playerHeight),
              hasLength(1),
            );
          }
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }

    for (final (window, railEdge, enabled) in [
      (innerLandscape, HorizontalEdge.right, false),
      (leftWindow, HorizontalEdge.left, true),
      (iPad, HorizontalEdge.left, true),
    ]) {
      testWidgets('${window.name}: a rail and content that do not fill the height stay centred as in a RailSideRow', (
        tester,
      ) async {
        useWindow(tester, window);
        const rail = SizedBox(key: ValueKey('shortRail'), width: 84, height: 48);
        const content = SizedBox(key: ValueKey('shortContent'), height: 100);
        Future<List<Rect>> rects({required bool plain}) async {
          await tester.pumpWidget(
            duoApp(
              window,
              home: plain
                  ? RailSideRow(railEdge: railEdge, rail: rail, content: content)
                  : VerticalBarShell(railEdge: railEdge, rail: rail, content: content, enabled: enabled),
            ),
          );
          final rects = [
            for (final key in ['shortRail', 'shortContent']) tester.getRect(find.byKey(ValueKey(key))),
          ];
          await tester.pumpWidget(const SizedBox());
          return rects;
        }

        final expected = await rects(plain: true);
        expect(await rects(plain: false), expected);
        expect(expected.last.center.dy, window.size.height / 2);
      });
    }

    // The comparisons above put a marker in the shell's rail only.
    for (final rail in [navigationRail(destinations: 3), scrollingRail, movableRail]) {
      testWidgets('the ${rail.kind.name} fixture holds one marker in the shell rail and none in the plain one', (
        tester,
      ) async {
        useWindow(tester, iPad);
        for (final plain in [false, true]) {
          await tester.pumpWidget(
            shellApp(iPad, ShellHarness(), railEdge: HorizontalEdge.left, rail: rail, plain: plain),
          );
          expect(find.byType(VerticalBarRailEnd), plain ? findsNothing : findsOneWidget);
        }
      });
    }

    testWidgets('the app bars keep their actions and the shell takes the window', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, enabled: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
      expect(tester.getRect(find.byType(VerticalBarShell)), Offset.zero & innerLandscape.size);
    });
  });

  // The shell is one focus traversal group, so the policy around it orders the whole shell by its box
  // among focusable siblings in its route, where a plain RailSideRow's items are ordered by their own.
  group('focusable siblings in the shell route', () {
    for (final enabled in [false, true]) {
      testWidgets(
        'with the column ${enabled ? '' : 'not '}used, Tab visits the shell as one block between a floating button '
        'and a player bar',
        (tester) async {
          useWindow(tester, innerLandscape);
          Future<({List<Rect> cycle, int button, int player})> visit({required bool plain}) async {
            await tester.pumpWidget(
              shellApp(
                innerLandscape,
                ShellHarness(),
                railEdge: HorizontalEdge.right,
                rail: navigationRail(destinations: 5),
                shape: ShellShape.inBody,
                enabled: enabled,
                plain: plain,
                floatingButton: true,
                playerBelowShell: true,
                // While the column is used the app bars have no buttons, and Tab cannot leave a branch
                // without a focusable widget in it.
                textField: true,
              ),
            );
            await tester.pumpAndSettle();
            final buttonRect = tester.getRect(find.byKey(floatingButtonKey));
            final playerRect = tester.getRect(find.byKey(routePlayerKey));
            final cycle = tabCycleOf(await tabOrderOf(tester, 16));
            await tester.pumpWidget(const SizedBox());
            return (
              cycle: cycle,
              button: cycle.indexWhere((rect) => buttonRect.contains(rect.center)),
              player: cycle.indexWhere((rect) => playerRect.contains(rect.center)),
            );
          }

          // With two siblings, the shell's items are one run of the cycle exactly when the siblings are
          // next to each other.
          bool siblingsAdjacent(({List<Rect> cycle, int button, int player}) order) {
            final distance = (order.button - order.player) % order.cycle.length;
            return distance == 1 || distance == order.cycle.length - 1;
          }

          final shell = await visit(plain: false);
          expect(shell.button, isNonNegative);
          expect(shell.player, isNonNegative);
          // The shell has items on its own, besides the two siblings.
          expect(shell.cycle.length, greaterThan(3));
          expect(siblingsAdjacent(shell), isTrue, reason: '${shell.cycle}');
          if (!enabled) {
            // The plain row visits the same items, with the button among the rail's destinations.
            final plain = await visit(plain: true);
            expect(plain.cycle.toSet(), shell.cycle.toSet());
            expect(siblingsAdjacent(plain), isFalse, reason: '${plain.cycle}');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  testWidgets('while the column is used, the column layer passes taps outside its cells to the rail and the content', (
    tester,
  ) async {
    useWindow(tester, innerLandscape);
    final harness = ShellHarness();
    await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, textField: true));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(VerticalBarShell)), Offset.zero & innerLandscape.size);
    await tester.tap(find.byKey(const ValueKey('rail:1')));
    await tester.pump();
    expect(harness.host.index, 1);
    await tester.tap(find.byKey(const ValueKey('field:1')));
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>()?.key,
      const ValueKey('field:1'),
    );
    expect(tester.takeException(), isNull);
  });

  group('railPaddingOf', () {
    for (final (window, reservesBack, top) in [
      (innerLandscape, false, 184.0),
      (rightWindow, false, 184.0),
      (innerLandscape, true, 244.0),
      (outerPortrait, false, 234.0),
    ]) {
      testWidgets('raises the top to $top on ${window.name}${reservesBack ? ' with reservesBack' : ''}', (
        tester,
      ) async {
        final record = await _pumpProbe(tester, window, railEdge: HorizontalEdge.right, reservesBack: reservesBack);
        expect(record.padding, _probeInput.copyWith(top: top));
        expect(record.noTopPadding, _noTopInput.copyWith(top: top));
      });
    }

    testWidgets('keeps a higher top', (tester) async {
      useWindow(tester, innerLandscape);
      late EdgeInsets padding;
      await tester.pumpWidget(
        duoApp(
          innerLandscape,
          home: VerticalBarShell(
            railEdge: HorizontalEdge.right,
            rail: Builder(
              builder: (context) {
                padding = VerticalBarShell.railPaddingOf(context, const EdgeInsets.only(top: 300));
                return const SizedBox(width: 84);
              },
            ),
            content: const SizedBox.expand(),
          ),
        ),
      );
      expect(padding, const EdgeInsets.only(top: 300));
    });

    testWidgets('returns the padding unchanged outside a shell', (tester) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            padding = VerticalBarShell.railPaddingOf(context, _probeInput);
            return const SizedBox();
          },
        ),
      );
      expect(padding, _probeInput);
    });

    for (final (window, label, railEdge, enabled) in [
      (innerLandscape, 'enabled: false', HorizontalEdge.right, false),
      (firstFrame, 'no column yet', HorizontalEdge.right, true),
      (iPhone17, 'no column', HorizontalEdge.right, true),
      (iPad, 'no column', HorizontalEdge.left, true),
      (android, 'no column', HorizontalEdge.left, true),
      (innerPortrait, 'no column', HorizontalEdge.right, true),
      (mixedRotation, 'a sample mixed from a rotation', HorizontalEdge.right, true),
      (outerLandscapeRight, 'status bar hidden', HorizontalEdge.right, true),
      (outerLandscapeLeft, 'status bar hidden', HorizontalEdge.left, true),
      (leftWindow, 'no OS inset on the column edge', HorizontalEdge.left, true),
      (innerLandscape, 'the rail on the other edge', HorizontalEdge.left, true),
    ]) {
      testWidgets('is unchanged on ${window.name} ($label)', (tester) async {
        final record = await _pumpProbe(tester, window, railEdge: railEdge, enabled: enabled);
        expect(record.padding, _probeInput);
        expect(record.noTopPadding, _noTopInput);
      });
    }

    testWidgets('uses the column while the reserved cells fit in its items', (tester) async {
      final fits = innerLandscape.copyWith(
        name: 'a short region, 124 to 231.5',
        region: const VerticalBarRegion(
          rect: Rect.fromLTRB(879, 124, 927, 231.5),
          edge: HorizontalEdge.right,
          viewSize: Size(951, 669),
          topBarTop: 24,
        ),
      );
      final record = await _pumpProbe(tester, fits, railEdge: HorizontalEdge.right, reservesBack: true);
      expect(record.padding, _probeInput.copyWith(top: 244));
      expect(record.noTopPadding, _noTopInput.copyWith(top: 244));
    });

    testWidgets('leaves the column when the reserved cells do not fit in its items', (tester) async {
      final short = innerLandscape.copyWith(
        name: 'a short region, 124 to 231.4',
        region: const VerticalBarRegion(
          rect: Rect.fromLTRB(879, 124, 927, 231.4),
          edge: HorizontalEdge.right,
          viewSize: Size(951, 669),
          topBarTop: 24,
        ),
      );
      final record = await _pumpProbe(tester, short, railEdge: HorizontalEdge.right, reservesBack: true);
      expect(record.padding, _probeInput);
      expect(record.noTopPadding, _noTopInput);
    });

    testWidgets('does not rebuild the rail for a keyboard or a text scale', (tester) async {
      final record = await _pumpProbe(tester, innerLandscape, railEdge: HorizontalEdge.right);
      expect(record.builds, 1);
      useWindow(tester, innerLandscape, keyboard: 300);
      await tester.pump();
      expect(record.builds, 1);
      useWindow(tester, innerLandscape);
      await tester.pump();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(record.builds, 1);
      expect(record.padding, _probeInput.copyWith(top: 184));
    });

    testWidgets('follows the column as the native values arrive and leave', (tester) async {
      useWindow(tester, innerLandscape);
      final record = _ProbeRecord();
      Widget app(DuoWindow window) => duoApp(
        window,
        home: VerticalBarShell(railEdge: HorizontalEdge.right, rail: _Probe(record), content: const SizedBox.expand()),
      );
      await tester.pumpWidget(app(firstFrame));
      expect((record.padding, record.noTopPadding), (_probeInput, _noTopInput));
      await tester.pumpWidget(app(innerLandscape));
      expect((record.padding, record.noTopPadding), (_probeInput.copyWith(top: 184), _noTopInput.copyWith(top: 184)));
      await tester.pumpWidget(app(firstFrame));
      expect((record.padding, record.noTopPadding), (_probeInput, _noTopInput));
    });
  });

  group('cells beside the rail', () {
    setUp(VerticalBarShellDebugStats.reset);

    group('placement', () {
      for (final (window, left, top) in [
        (innerLandscape, 885.0, 124.0),
        (rightWindow, 403.0, 124.0),
        (outerPortrait, 400.0, 174.0),
      ]) {
        testWidgets('${window.name}: four actions beside the scrolling rail, centred on it', (tester) async {
          useWindow(tester, window);
          await tester.pumpWidget(shellApp(window, ShellHarness(), railEdge: HorizontalEdge.right));
          await tester.pumpAndSettle();
          expect(cellsOf(tester), [
            for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
              (id, Rect.fromLTWH(left, top + 52.0 * index, 48, 48)),
          ]);
          expect(VerticalBarShellDebugStats.deferredNotifications, 0);
          expectClean(tester);
        });
      }

      for (final (window, left, right) in [
        (innerLandscape, 879.0, 927.0),
        (rightWindow, 397.0, 445.0),
        (outerPortrait, 394.0, 442.0),
      ]) {
        for (final (label, rail, shape) in [
          ('scrolling rail', scrollingRailWithWidth(RailPlacement.systemRailWidth), ShellShape.outside),
          (
            'NavigationRail',
            navigationRail(
              destinations: 3,
              width: RailPlacement.systemRailWidth,
              minWidth: RailPlacement.systemRailWidth,
            ),
            ShellShape.inBody,
          ),
        ]) {
          testWidgets('${window.name}: a systemRailWidth-wide $label puts the cells where a VerticalBarPage has them', (
            tester,
          ) async {
            useWindow(tester, window);
            await tester.pumpWidget(
              duoApp(
                window,
                home: harnessPage(ShellHarness(), title: 'Page', actions: ['a0']),
              ),
            );
            await tester.pumpAndSettle();
            final page = cellsOf(tester).single.$2;
            expect((page.left, page.right), (left, right));
            await tester.pumpWidget(const SizedBox());

            await tester.pumpWidget(
              shellApp(window, ShellHarness(), railEdge: HorizontalEdge.right, rail: rail, shape: shape),
            );
            await tester.pumpAndSettle();
            final rail0 = tester.getRect(find.byKey(const ValueKey('rail:0'), skipOffstage: false).first);
            expect(rail0.center.dx, window.size.width - RailPlacement.systemRailWidth / 2);
            final cells = cellsOf(tester);
            expect(cells, isNotEmpty);
            for (final (id, rect) in cells) {
              expect((rect.left, rect.right), (left, right), reason: id);
            }
            expectClean(tester);
          });
        }
      }

      testWidgets('two actions beside a NavigationRail with three destinations', (tester) async {
        useWindow(tester, innerLandscape);
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            ShellHarness(),
            railEdge: HorizontalEdge.right,
            rail: navigationRail(destinations: 3),
            shape: ShellShape.inBody,
            branchActions: const [
              ['a0', 'b0'],
              ['a1', 'b1'],
              <String>[],
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(cellsOf(tester), const [
          ('a0', Rect.fromLTRB(885, 124, 933, 172)),
          ('b0', Rect.fromLTRB(885, 176, 933, 224)),
        ]);
        expectClean(tester);
      });

      testWidgets('the cells, the slots, and the rail padding arrive with the column in one frame', (tester) async {
        useWindow(tester, firstFrame);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(firstFrame, harness, railEdge: HorizontalEdge.right));
        await tester.pumpAndSettle();
        expect(cellsOf(tester), isEmpty);
        expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
        expect(harness.slots['Branch 0'], const VerticalBarSlots());
        // Same size and safe area; the native values arrive.
        useWindow(tester, innerLandscape);
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
        expect(find.byKey(const ValueKey('appBar:a0')), findsNothing);
        expect(harness.slots['Branch 0']?.active, isTrue);
        expect(cellsOf(tester), [
          for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
            (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
        ]);
        expect(_scrollingRailTop(tester), 184);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      for (final window in [innerLandscape, rightWindow, outerPortrait]) {
        for (final (label, rail, items, shape) in [
          ('the scrolling rail', scrollingRail, 4, ShellShape.outside),
          ('a NavigationRail with five destinations', navigationRail(destinations: 5), 5, ShellShape.inBody),
        ]) {
          testWidgets('${window.name}: $label keeps its destinations where a marker-free RailSideRow has them', (
            tester,
          ) async {
            useWindow(tester, window);
            Future<(List<Rect>, List<String>, double?)> rects({required bool plain}) async {
              await tester.pumpWidget(
                shellApp(
                  window,
                  ShellHarness(),
                  railEdge: HorizontalEdge.right,
                  rail: rail,
                  shape: shape,
                  plain: plain,
                ),
              );
              await tester.pumpAndSettle();
              final result = (_railRects(tester, items), cellLabels(tester), plain ? null : markerFlexTop(tester));
              await tester.pumpWidget(const SizedBox());
              return result;
            }

            final (expected, plainCells, _) = await rects(plain: true);
            final (actual, cells, railTop) = await rects(plain: false);
            expect(actual, expected);
            expect(plainCells, isEmpty);
            // As many cells as end the group gap above the rail's first destination.
            final itemsTop = window.region!.rect.top;
            final capacity = VerticalBarColumn.capacity(
              math.max(railTop!, itemsTop + 60) - VerticalBarColumn.groupGap - itemsTop,
            );
            expect(capacity, greaterThanOrEqualTo(2));
            expect(cells, _labelsFitting(const ['a0', 'b0', 'c0', 'd0'], capacity));
            expectClean(tester);
          });
        }
      }
    });

    testWidgets('the slots are active without a back control, keep the column of the window, and reach a sliver '
        'app bar in the same frame', (tester) async {
      useWindow(tester, firstFrame);
      final harness = ShellHarness();
      final pageSlots = <int, VerticalBarSlots>{};
      final sliverSlots = <int, VerticalBarSlots?>{};
      Widget app(DuoWindow window) => shellApp(
        window,
        harness,
        railEdge: HorizontalEdge.right,
        branchPage: (branch) {
          final index = branch.widget.index;
          return VerticalBarPage(
            actions: [for (final id in branch.actions) _action(id)],
            builder: (context, slots) {
              pageSlots[index] = slots;
              return Scaffold(
                body: CustomScrollView(
                  slivers: [
                    Builder(
                      builder: (context) {
                        final sliver = sliverSlots[index] = VerticalBarSlots.maybeOf(context);
                        return SliverAppBar(
                          title: Text('Branch $index'),
                          actions: sliver?.active ?? false
                              ? null
                              : [
                                  for (final id in branch.actions)
                                    IconButton(
                                      key: ValueKey('appBar:$id'),
                                      onPressed: () {},
                                      icon: const Icon(Icons.star),
                                    ),
                                ],
                        );
                      },
                    ),
                    const SliverFillRemaining(child: SizedBox()),
                  ],
                ),
              );
            },
          );
        },
      );
      await tester.pumpWidget(app(firstFrame));
      await tester.pumpAndSettle();
      expect(pageSlots[0], const VerticalBarSlots());
      expect(sliverSlots[0], const VerticalBarSlots());
      expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(app(innerLandscape));
      final column = VerticalBarColumn.of(tester.element(find.byType(VerticalBarShell)));
      expect(column, isNotNull);
      for (final index in [0, 1]) {
        expect(pageSlots[index], VerticalBarSlots(column: column), reason: 'branch $index');
        expect(sliverSlots[index], pageSlots[index], reason: 'branch $index');
      }
      // The cells are centred on the rail; the slots keep the window's column.
      expect(pageSlots[0]!.column!.items.center.dx, 903);
      expect(pageSlots[0]!.backInColumn, isFalse);
      expect(find.byKey(const ValueKey('appBar:a0')), findsNothing);
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expectClean(tester);
    });

    group('notifications', () {
      for (final layoutBuilderAboveShell in [false, true]) {
        for (final (label, rail, shape) in [
          ('a NavigationRail', navigationRail(destinations: 4), ShellShape.inBody),
          ('the scrolling rail', scrollingRail, ShellShape.outside),
        ]) {
          testWidgets('$label${layoutBuilderAboveShell ? ', the root Navigator in a LayoutBuilder' : ''}: a switch, a '
              'rail tap, and new actions show in the first frame', (tester) async {
            useWindow(tester, innerLandscape);
            final harness = ShellHarness();
            await tester.pumpWidget(
              shellApp(
                innerLandscape,
                harness,
                railEdge: HorizontalEdge.right,
                rail: rail,
                shape: shape,
                layoutBuilderAboveShell: layoutBuilderAboveShell,
                branchActions: _fourTabs,
              ),
            );
            await tester.pumpAndSettle();
            final capacity = VerticalBarColumn.capacity(
              math.max(markerFlexTop(tester), 184) - VerticalBarColumn.groupGap - 124,
            );
            expect(capacity, greaterThanOrEqualTo(4));
            expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
            harness.host.select(1);
            await tester.pump();
            expect(cellLabels(tester), ['a1', 'b1']);
            await tester.tap(find.byKey(const ValueKey('rail:2')));
            await tester.pump();
            expect(cellLabels(tester), ['a2', 'b2']);
            harness.branches[2]!.setActions(['x2', 'y2', 'z2']);
            await tester.pump();
            expect(cellLabels(tester), ['x2', 'y2', 'z2']);
            const six = ['p2', 'q2', 'r2', 's2', 't2', 'u2'];
            harness.branches[2]!.setActions(six);
            await tester.pump();
            expect(cellLabels(tester), _labelsFitting(six, capacity));
            harness.branches[2]!.setActions(const []);
            await tester.pump();
            expect(cellsOf(tester), isEmpty);
            expect(harness.slots['Branch 2'], const VerticalBarSlots());
            await tester.pumpAndSettle();
            expect(VerticalBarShellDebugStats.deferredNotifications, 0);
            expectClean(tester);
          });
        }
      }

      testWidgets('pages built inside their own LayoutBuilder update their cells a frame late, with one note', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final notes = await notesDuring(() async {
          await tester.pumpWidget(
            shellApp(
              innerLandscape,
              harness,
              railEdge: HorizontalEdge.right,
              pagesInLayoutBuilder: true,
              branchActions: _fourTabs,
            ),
          );
          await tester.pumpAndSettle();
          expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
          expect(VerticalBarShellDebugStats.deferredNotifications, 0);
          harness.branches[0]!.setActions(['k0']);
          await tester.pump();
          expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
          await tester.pump();
          expect(cellLabels(tester), ['k0']);
          final afterActions = VerticalBarShellDebugStats.deferredNotifications;
          expect(afterActions, greaterThanOrEqualTo(1));
          harness.host.select(1);
          await tester.pump();
          // The rail changed too, so the shell laid out again in this frame and read the switch.
          expect(cellLabels(tester), ['a1', 'b1']);
          expect(VerticalBarShellDebugStats.deferredNotifications, greaterThan(afterActions));
          // That layout came after the deferred notifications, so they did not lay the shell out again.
          expect(shellLayout(tester).debugNeedsLayout, isFalse);
          await tester.pumpAndSettle();
          expect(tester.binding.hasScheduledFrame, isFalse);
        });
        expect(notes, hasLength(1));
        expect(notes.single, contains('LayoutBuilder'));
        expectClean(tester);
      });

      testWidgets('a page in another VerticalBarPage that does not use the column updates its cells a frame late, '
          'with one note on the nesting', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final notes = await notesDuring(() async {
          await tester.pumpWidget(
            shellApp(
              innerLandscape,
              harness,
              railEdge: HorizontalEdge.right,
              branchActions: _fourTabs,
              branchPage: (branch) => VerticalBarPage(
                builder: (context, slots) =>
                    harnessPage(harness, title: 'Branch ${branch.widget.index}', actions: branch.actions),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
          harness.branches[0]!.setActions(['x', 'y']);
          await tester.pump();
          expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
          await tester.pump();
          expect(cellLabels(tester), ['x', 'y']);
          expect(VerticalBarShellDebugStats.deferredNotifications, greaterThanOrEqualTo(1));
          await tester.pumpAndSettle();
          expect(tester.binding.hasScheduledFrame, isFalse);
        });
        // The LayoutBuilder is the outer page's own, so the note names the outer page, not LayoutBuilders.
        expect(notes, hasLength(1));
        expect(notes.single, contains('inside another VerticalBarPage'));
        expect(notes.single, isNot(contains('LayoutBuilders')));
        expectClean(tester);
      });

      testWidgets('below a shell that is itself in a VerticalBarPage, pages in their own LayoutBuilder get the '
          'LayoutBuilder note', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final notes = await notesDuring(() async {
          await tester.pumpWidget(
            shellApp(
              innerLandscape,
              harness,
              railEdge: HorizontalEdge.right,
              pagesInLayoutBuilder: true,
              around: (context, child) => VerticalBarPage(builder: (context, slots) => child!),
            ),
          );
          await tester.pumpAndSettle();
          harness.branches[0]!.setActions(['k0']);
          await tester.pump();
          await tester.pump();
          expect(cellLabels(tester), ['k0']);
          await tester.pumpAndSettle();
        });
        expect(notes, hasLength(1));
        expect(notes.single, contains('LayoutBuilders'));
        expectClean(tester);
      });

      testWidgets('with a fade-through container the cells switch at t = 0, also back in the middle of the fade', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            container: ShellContainer.fadeThrough,
            branchActions: _fourTabs,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rail:1')));
        await tester.pump();
        expect(cellLabels(tester), ['a1', 'b1']);
        await tester.pump(const Duration(milliseconds: 100));
        expect(cellLabels(tester), ['a1', 'b1']);
        await tester.tap(find.byKey(const ValueKey('rail:0')));
        await tester.pump();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a page pushed in a branch owns the cells from its first frame, and its pop gives them back', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        harness.branches[0]!.push();
        await tester.pump();
        expect(cellLabels(tester), ['Back', 'pushed']);
        await tester.pumpAndSettle();
        expect(cellsOf(tester), const [
          ('Back', Rect.fromLTRB(885, 124, 933, 172)),
          ('pushed', Rect.fromLTRB(885, 184, 933, 232)),
        ]);
        harness.branches[0]!.pop();
        await tester.pump();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a pop during the push gives the cells back in its first frame', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
        await tester.pumpAndSettle();
        harness.branches[0]!.push();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(cellLabels(tester), ['Back', 'pushed']);
        harness.branches[0]!.pop();
        await tester.pump();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a popped page with no page below to take the cells drops them in the first frame of the pop', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
        await tester.pumpAndSettle();
        harness.host.select(2);
        await tester.pumpAndSettle();
        expect(cellsOf(tester), isEmpty);
        harness.branches[2]!.push();
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['Back', 'pushed']);
        // Settings has no actions, so the popped page is the only one registered while it animates out.
        harness.branches[2]!.pop();
        await tester.pump();
        expect(cellsOf(tester), isEmpty);
        await tester.pumpAndSettle();
        expect(cellsOf(tester), isEmpty);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });
    });

    for (final container in ShellContainer.values) {
      testWidgets('${container.name}: Home, Settings, and Home again keep the rail and its scroll State in every '
          'frame, with every page ready', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, container: container),
        );
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byKey(const ValueKey('railScroll')),
          matching: find.byType(Scrollable),
        );
        final rail = _railRects(tester, 4);
        final scroll = tester.state<ScrollableState>(scrollable);
        final ready = harness.slots['Branch 0'];
        expect(ready?.active, isTrue);
        for (final (branch, cells) in [
          (2, <String>[]),
          (0, ['a0', 'b0', 'c0', 'd0']),
        ]) {
          harness.host.select(branch);
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
            final label = 'branch $branch, frame $frame';
            expect(_railRects(tester, 4), rail, reason: label);
            expect(tester.state<ScrollableState>(scrollable), same(scroll), reason: label);
            expect(cellLabels(tester), cells, reason: label);
            // Hidden or shown, the pages with actions keep their slots.
            expect(harness.slots['Branch 0'], ready, reason: label);
            expect(harness.slots['Branch 1'], ready, reason: label);
            expect(harness.slots['Branch 2'], const VerticalBarSlots(), reason: label);
          }
        }
        expect(_scrollingRailTop(tester), 184);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });
    }

    group('owner', () {
      testWidgets('a hidden branch never owns the cells, and its new actions rebuild nothing until it shows', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
        await tester.pumpAndSettle();
        final builds = VerticalBarShellDebugStats.layerBuilds;
        harness.branches[1]!.setActions(['a1', 'b1', 'badge1']);
        await tester.pump();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        expect(VerticalBarShellDebugStats.layerBuilds, builds);
        harness.host.select(1);
        await tester.pump();
        expect(cellLabels(tester), ['a1', 'b1', 'badge1']);
        expectClean(tester);
      });

      testWidgets('of two current pages in one route, the one mounted later owns the cells, with one note', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final leftActions = ValueNotifier<List<String>>(const ['left']);
        addTearDown(leftActions.dispose);
        final notes = await notesDuring(() async {
          await tester.pumpWidget(
            shellApp(
              innerLandscape,
              harness,
              railEdge: HorizontalEdge.right,
              branchPage: (branch) => branch.widget.index == 0
                  ? Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<List<String>>(
                            valueListenable: leftActions,
                            builder: (context, actions, _) => harnessPage(harness, title: 'Left', actions: actions),
                          ),
                        ),
                        Expanded(
                          child: harnessPage(harness, title: 'Right', actions: const ['right']),
                        ),
                      ],
                    )
                  : harnessPage(harness, title: 'Branch ${branch.widget.index}', actions: branch.actions),
            ),
          );
          await tester.pumpAndSettle();
          expect(cellLabels(tester), ['right']);
          harness.host.select(1);
          await tester.pump();
          harness.host.select(0);
          await tester.pump();
          expect(cellLabels(tester), ['right']);
          // Left leaves the shell and registers again, after Right: it was still mounted first.
          leftActions.value = const [];
          await tester.pump();
          expect(cellLabels(tester), ['right']);
          leftActions.value = const ['left'];
          await tester.pump();
          expect(cellLabels(tester), ['right']);
        });
        expect(notes, hasLength(1));
        expect(notes.single, contains('mounted last'));
        expect(harness.slots['Left']?.active, isTrue);
        expectClean(tester);
      });

      testWidgets('equal action ids in two branches get separate cells', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            branchPage: (branch) => VerticalBarPage(
              actions: [
                VerticalBarAction.custom(
                  id: 'search',
                  label: 'Search ${branch.widget.index}',
                  cellBuilder: (context, cell) => const CounterCell(),
                ),
              ],
              builder: (context, slots) => Scaffold(appBar: AppBar(title: Text('Branch ${branch.widget.index}'))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final counter = find.byKey(const ValueKey('counter'));
        expect(tester.getRect(counter), const Rect.fromLTRB(885, 124, 933, 172));
        await tester.tap(counter);
        await tester.tap(counter);
        await tester.pump();
        final first = tester.state<CounterCellState>(find.byType(CounterCell));
        expect(first.taps, 2);
        harness.host.select(1);
        await tester.pump();
        final second = tester.state<CounterCellState>(find.byType(CounterCell));
        expect(second, isNot(same(first)));
        expect(second.taps, 0);
        expect(tester.getRect(counter), const Rect.fromLTRB(885, 124, 933, 172));
        expectClean(tester);
      });
    });

    group('pages that do not use the column', () {
      testWidgets('a tab root with enabled: false keeps its actions in its app bar', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            branchPage: (branch) => harnessPage(
              harness,
              title: 'Branch ${branch.widget.index}',
              actions: branch.actions,
              enabled: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cellsOf(tester), isEmpty);
        expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
        expect(harness.slots['Branch 0'], const VerticalBarSlots());
        expect(_scrollingRailTop(tester), 184);
        expectClean(tester);
      });

      for (final (label, open) in <(String, void Function(BuildContext context, Widget page))>[
        (
          'a bottom sheet',
          (context, page) => unawaited(
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(height: 400, child: page),
            ),
          ),
        ),
        (
          'a CupertinoSheetRoute',
          (context, page) => Navigator.of(context).push(CupertinoSheetRoute<void>(scrollableBuilder: (_, _) => page)),
        ),
        (
          'a Navigator in a bottom sheet',
          (context, page) => unawaited(
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(
                height: 400,
                child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page)),
              ),
            ),
          ),
        ),
      ]) {
        testWidgets('a page in $label in a branch keeps its actions in its app bar; the tab root keeps the cells', (
          tester,
        ) async {
          useWindow(tester, innerLandscape);
          final harness = ShellHarness();
          // With a back control reserved, only the route rule keeps the page out of the column.
          await tester.pumpWidget(
            shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true),
          );
          await tester.pumpAndSettle();
          open(harness.branches[0]!.context, harnessPage(harness, title: 'Sheet', actions: const ['sheet']));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('appBar:sheet')), findsOneWidget);
          expect(harness.slots['Sheet'], const VerticalBarSlots());
          expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
          expectClean(tester);
        });
      }

      testWidgets('a VerticalBarPage in a tab root that uses the column keeps its actions', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        VerticalBarSlots? inner;
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            branchPage: (branch) => branch.widget.index != 0
                ? harnessPage(harness, title: 'Branch ${branch.widget.index}', actions: branch.actions)
                : VerticalBarPage(
                    actions: [_action('outer')],
                    builder: (context, slots) => Scaffold(
                      appBar: AppBar(title: const Text('Outer')),
                      body: VerticalBarPage(
                        actions: [_action('inner')],
                        builder: (context, slots) {
                          inner = slots;
                          return const SizedBox.expand();
                        },
                      ),
                    ),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['outer']);
        expect(inner, const VerticalBarSlots());
        expectClean(tester);
      });

      testWidgets('a shell without a rail draws no cells, though its pages are as wide as the window', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: null));
        await tester.pumpAndSettle();
        // Without a shell, such a page uses the column itself.
        expect(tester.getSize(find.byType(Scaffold).first).width, innerLandscape.size.width);
        expect(cellsOf(tester), isEmpty);
        expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
        expect(harness.slots['Branch 0'], const VerticalBarSlots());
        expectClean(tester);
      });

      testWidgets('without reservesBack, a page pushed in a branch keeps its back control and actions', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
        await tester.pumpAndSettle();
        harness.branches[0]!.push();
        await tester.pumpAndSettle();
        expect(harness.slots['Pushed'], const VerticalBarSlots());
        expect(find.byKey(const ValueKey('appBar:pushed')), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        // The tab root below, covered and so without tickers, owns nothing either.
        expect(cellsOf(tester), isEmpty);
        expect(_scrollingRailTop(tester), 184);
        expectClean(tester);
      });

      testWidgets('a branch without actions gets no cells, and the rail keeps the floor', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
        await tester.pumpAndSettle();
        harness.host.select(2);
        await tester.pump();
        expect(cellsOf(tester), isEmpty);
        expect(_scrollingRailTop(tester), 184);
        expectClean(tester);
      });
    });

    for (final pinned in ['p0', 'p2']) {
      testWidgets('a pinned action, $pinned, stays in the column when the others fold', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            rail: navigationRail(destinations: 6),
            shape: ShellShape.inBody,
            branchActions: const [
              ['p0', 'p1', 'p2'],
              ['a1', 'b1'],
              <String>[],
            ],
            branchPage: (branch) => harnessPage(
              harness,
              title: 'Branch ${branch.widget.index}',
              actions: branch.actions,
              pinned: {pinned},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(VerticalBarColumn.capacity(math.max(markerFlexTop(tester), 184) - VerticalBarColumn.groupGap - 124), 2);
        expect(cellsOf(tester), [
          (pinned, const Rect.fromLTRB(885, 124, 933, 172)),
          ('Show menu', const Rect.fromLTRB(885, 176, 933, 224)),
        ]);
        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();
        final folded = [
          for (final id in ['p0', 'p1', 'p2'])
            if (id != pinned) id,
        ];
        expect(find.text(folded.first), findsOneWidget);
        expect(find.text(folded.last), findsOneWidget);
        expect(tester.getRect(find.text(folded.first)).top, lessThan(tester.getRect(find.text(folded.last)).top));
        expect(find.text(pinned), findsNothing);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expectClean(tester);
      });
    }

    testWidgets('a pinned action behind a back control stays in the column', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          reservesBack: true,
          rail: navigationRail(destinations: 5),
          shape: ShellShape.inBody,
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(harness.branches[0]!.context).push(
        MaterialPageRoute<void>(
          builder: (_) => harnessPage(harness, title: 'P', actions: const ['p0', 'p1', 'p2'], pinned: const {'p2'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(cellsOf(tester), const [
        ('Back', Rect.fromLTRB(885, 124, 933, 172)),
        ('p2', Rect.fromLTRB(885, 184, 933, 232)),
        ('Show menu', Rect.fromLTRB(885, 236, 933, 284)),
      ]);
      expectClean(tester);
    });

    group('rail end marker', () {
      testWidgets('a second marker is reported, and the higher one is used', (tester) async {
        useWindow(tester, innerLandscape);
        await tester.pumpWidget(
          _railApp(
            ShellHarness(),
            SizedBox(
              width: 84,
              child: Material(
                child: Column(
                  children: [
                    const Column(mainAxisSize: MainAxisSize.min, children: [VerticalBarRailEnd()]),
                    const Spacer(),
                    Column(mainAxisSize: MainAxisSize.min, children: [..._railItems(), const VerticalBarRailEnd()]),
                    const SizedBox(height: 34),
                  ],
                ),
              ),
            ),
          ),
        );
        final error = tester.takeException();
        expect(error, isA<FlutterError>());
        expect('$error', contains('more than one VerticalBarRailEnd'));
        await tester.pumpAndSettle();
        // The higher marker's Flex is at the top of the rail, so only the floor cell is left.
        expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(885, 124, 933, 172))]);
        expectClean(tester);
      });

      for (final (label, group) in [
        (
          'spaces its children evenly',
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [..._railItems(), const VerticalBarRailEnd()],
            ),
          ),
        ),
        (
          'has spacing',
          Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [..._railItems(), const VerticalBarRailEnd()]),
        ),
      ]) {
        testWidgets('a marker in a Flex that $label is reported', (tester) async {
          useWindow(tester, innerLandscape);
          await tester.pumpWidget(_railApp(ShellHarness(), _customRail(group)));
          final error = tester.takeException();
          expect(error, isA<FlutterError>());
          expect('$error', contains('VerticalBarRailEnd is in a Flex'));
          await tester.pumpAndSettle();
          expectClean(tester);
        });
      }

      testWidgets('a marker under IntrinsicHeight reads the rail top', (tester) async {
        useWindow(tester, innerLandscape);
        await tester.pumpWidget(
          _railApp(
            ShellHarness(),
            _customRail(
              IntrinsicHeight(
                child: Column(mainAxisSize: MainAxisSize.min, children: [..._railItems(), const VerticalBarRailEnd()]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(markerFlexTop(tester), 411);
        expect(cellsOf(tester), [
          for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
            (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
        ]);
        expectClean(tester);
      });

      testWidgets('a marker dropped behind a relayout boundary in the rail lays the shell out again', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, rail: movableRail));
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        await notesDuring(() async {
          harness.movableKey.currentState!.setMarker(value: false);
          await tester.pump();
          await tester.pump();
        });
        expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(879, 124, 927, 172))]);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a marker added behind a relayout boundary in the rail is read by frame 2', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await notesDuring(() async {
          await tester.pumpWidget(
            shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, rail: movableRail, marker: false),
          );
          await tester.pumpAndSettle();
        });
        expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(879, 124, 927, 172))]);
        harness.movableKey.currentState!.setMarker(value: true);
        await tester.pump();
        await tester.pump();
        expect(cellsOf(tester), [
          for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
            (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
        ]);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a marker replaced behind a relayout boundary in the rail is read by frame 2, with no note', (
        tester,
      ) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, rail: movableRail));
        await tester.pumpAndSettle();
        final notes = await notesDuring(() async {
          harness.movableKey.currentState!.replaceMarker();
          await tester.pump();
          await tester.pump();
        });
        expect(cellsOf(tester), [
          for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
            (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
        ]);
        // The new marker is laid out after the shell in frame 1, so it is read after the frame, not missing.
        expect(notes, isEmpty);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expectClean(tester);
      });

      testWidgets('a marker that is never laid out, as in a covered route, lays the shell out once more, not in '
          'every frame', (tester) async {
        useWindow(tester, innerLandscape);
        await tester.pumpWidget(
          duoApp(
            innerLandscape,
            home: VerticalBarShell(
              railEdge: HorizontalEdge.right,
              rail: _customRail(
                Column(mainAxisSize: MainAxisSize.min, children: [..._railItems(), const VerticalBarRailEnd()]),
              ),
              // The lower page is built offstage below the opaque one and never laid out.
              content: Navigator(
                pages: [
                  const MaterialPage<void>(child: Column(children: [VerticalBarRailEnd()])),
                  MaterialPage<void>(
                    child: VerticalBarPage(
                      back: VerticalBarBack.none,
                      actions: [
                        for (final id in ['a0', 'b0', 'c0', 'd0']) _action(id),
                      ],
                      builder: (context, slots) => const Scaffold(),
                    ),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(cellsOf(tester), [
          for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
            (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
        ]);
        expectClean(tester);
      });

      for (final (label, group) in [
        (
          'wrapped in a Padding',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._railItems(),
              const Padding(padding: EdgeInsets.zero, child: VerticalBarRailEnd()),
            ],
          ),
        ),
        (
          'at the end of a ListView',
          SizedBox(
            height: 224,
            child: ListView(primary: false, children: [..._railItems(), const VerticalBarRailEnd()]),
          ),
        ),
      ]) {
        testWidgets('a marker $label is reported and not read, so the cells keep off the destinations', (
          tester,
        ) async {
          useWindow(tester, innerLandscape);
          final notes = await notesDuring(() async {
            await tester.pumpWidget(_railApp(ShellHarness(), _customRail(group)));
            final error = tester.takeException();
            expect(error, isA<FlutterError>());
            expect('$error', contains('must be a direct child of the Flex that holds the destinations'));
            await tester.pumpAndSettle();
          });
          // Its own top is the destinations' bottom; without it, only the floor cell is used.
          expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(879, 124, 927, 172))]);
          expect(notes, isEmpty);
          expectClean(tester);
        });
      }

      testWidgets('without a marker only the floor cell is used, centred on the column, with one note', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final notes = await notesDuring(() async {
          await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, marker: false));
          await tester.pumpAndSettle();
          harness.host.select(1);
          await tester.pump();
        });
        expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(879, 124, 927, 172))]);
        expect(notes, hasLength(1));
        expect(notes.single, contains('no VerticalBarRailEnd'));
        expectClean(tester);
      });

      for (final (label, content) in <(String, Widget Function(Widget page))>[
        (
          'in a covered route that is never laid out',
          (page) => Navigator(
            pages: [
              const MaterialPage<void>(child: Column(children: [VerticalBarRailEnd()])),
              MaterialPage<void>(child: page),
            ],
            onDidRemovePage: (_) {},
          ),
        ),
        (
          'in the root overlay, outside the shell',
          (page) => OverlayPortal(
            controller: OverlayPortalController()..show(),
            overlayLocation: OverlayChildLocation.rootOverlay,
            overlayChildBuilder: (_) => const Column(mainAxisSize: MainAxisSize.min, children: [VerticalBarRailEnd()]),
            child: page,
          ),
        ),
      ]) {
        testWidgets('a marker only $label does not hide the no-marker note', (tester) async {
          useWindow(tester, innerLandscape);
          final notes = await notesDuring(() async {
            await tester.pumpWidget(
              duoApp(
                innerLandscape,
                home: VerticalBarShell(
                  railEdge: HorizontalEdge.right,
                  rail: _customRail(Column(mainAxisSize: MainAxisSize.min, children: _railItems())),
                  content: content(
                    VerticalBarPage(
                      back: VerticalBarBack.none,
                      actions: [
                        for (final id in ['a0', 'b0', 'c0', 'd0']) _action(id),
                      ],
                      builder: (context, slots) => const Scaffold(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          });
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(cellsOf(tester), const [('Show menu', Rect.fromLTRB(879, 124, 927, 172))]);
          expect(notes, hasLength(1));
          expect(notes.single, contains('no VerticalBarRailEnd'));
          expectClean(tester);
        });
      }
    });

    testWidgets('the rail goes and returns: no cells while it is gone, cells in the first frame after it returns', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, textField: true));
      await tester.pumpAndSettle();
      final rail = _railRects(tester, 4);
      final branch = harness.branches[0];
      final page = tester.state(find.byType(VerticalBarPage));
      final navigator = tester.state(
        find.ancestor(of: find.byType(VerticalBarPage), matching: find.byType(Navigator)).first,
      );
      harness.host.setRailEdge(null);
      await tester.pump();
      expect(cellsOf(tester), isEmpty);
      expect(find.byKey(const ValueKey('appBar:a0')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(cellsOf(tester), isEmpty);
      harness.host.setRailEdge(HorizontalEdge.right);
      await tester.pump();
      expect(cellsOf(tester), [
        for (final (index, id) in ['a0', 'b0', 'c0', 'd0'].indexed)
          (id, Rect.fromLTWH(885, 124 + 52.0 * index, 48, 48)),
      ]);
      expect(find.byKey(const ValueKey('appBar:a0')), findsNothing);
      expect(_railRects(tester, 4), rail);
      expect(harness.branches[0], same(branch));
      expect(tester.state(find.byType(VerticalBarPage)), same(page));
      expect(
        tester.state(find.ancestor(of: find.byType(VerticalBarPage), matching: find.byType(Navigator)).first),
        same(navigator),
      );
      expect(VerticalBarShellDebugStats.deferredNotifications, 0);
      expectClean(tester);
    });
  });
}
