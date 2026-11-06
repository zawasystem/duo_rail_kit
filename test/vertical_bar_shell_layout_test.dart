import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/toolbar/vertical_bar_toolbar.dart' show VerticalBarShellDebugStats;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cells.dart';
import 'support/duo_windows.dart';
import 'support/shell_harness.dart';

/// The cell for one action, or for the overflow menu, that the shell always keeps above the rail on the
/// inner landscape display, centred on the rail.
const Rect _floorCell = Rect.fromLTRB(885, 124, 933, 172);

/// One of the two shell shapes, with its rail.
typedef _Shape = ({String name, ShellShape shape, HarnessRail rail});

final List<_Shape> _shapes = [
  (name: 'in a Scaffold body with a NavigationRail', shape: ShellShape.inBody, rail: navigationRail(destinations: 5)),
  (name: 'outside the Scaffold with the scrolling rail', shape: ShellShape.outside, rail: scrollingRail),
];

/// The rail's scroll view.
Finder _railScrollable(HarnessRail rail) => find.descendant(
  of: rail.kind == HarnessRailKind.navigationRail
      ? find.byType(NavigationRail)
      : find.byKey(const ValueKey('railScroll')),
  matching: find.byType(Scrollable),
);

/// The rectangles of the rail's items: NavigationRail destinations, or the scrolling rail's destinations.
List<Rect> _railItems(WidgetTester tester, HarnessRail rail) => rail.kind == HarnessRailKind.navigationRail
    ? [
        for (final element
            in find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_RailDestination').evaluate())
          globalRect(element),
      ]
    : [for (var item = 0; item < rail.destinations; item++) tester.getRect(find.byKey(ValueKey('rail:$item')))];

ScrollPosition _railPosition(WidgetTester tester, HarnessRail rail) =>
    tester.state<ScrollableState>(_railScrollable(rail)).position;

/// Expects the cells in this frame to keep off every rail item, as far as the rail's viewport shows it,
/// the floor cell to be in place, no paint-phase fix, and no exception.
void _expectCellsClear(WidgetTester tester, HarnessRail rail, String step) {
  final viewport = tester.getRect(_railScrollable(rail));
  final cells = cellsOf(tester);
  expect(cells, isNotEmpty, reason: step);
  expect(cells.first.$2, _floorCell, reason: step);
  // The NavigationRail finder matches a private type name, which an SDK update could rename.
  final items = _railItems(tester, rail);
  expect(items, hasLength(rail.destinations), reason: step);
  for (final (index, item) in items.indexed) {
    final visible = item.intersect(viewport);
    if (visible.width <= 0 || visible.height <= 0) {
      continue;
    }
    for (final (label, cell) in cells) {
      final overlap = cell.intersect(visible);
      expect(
        overlap.width <= 0 || overlap.height <= 0,
        isTrue,
        reason: '$step: $label $cell over item $index $visible',
      );
    }
  }
  expect(VerticalBarShellDebugStats.paintFixes, 0, reason: step);
  expect(tester.takeException(), isNull, reason: step);
}

/// Pumps frames until none is scheduled, expecting [cells] clear of [rail] in each; [onFrame] runs after
/// each frame.
Future<void> _expectSameCellsUntilSettled(
  WidgetTester tester,
  HarnessRail rail,
  List<(String, Rect)> cells,
  String step, {
  VoidCallback? onFrame,
}) async {
  for (var frame = 0; tester.binding.hasScheduledFrame; frame++) {
    expect(frame, lessThan(600), reason: '$step: settles');
    await tester.pump(const Duration(milliseconds: 16));
    onFrame?.call();
    _expectCellsClear(tester, rail, '$step, frame $frame');
    expect(cellsOf(tester), cells, reason: '$step, frame $frame');
  }
}

/// Pumps a four-action Home beside [shape]'s rail on the inner landscape display and returns its harness.
Future<ShellHarness> _pumpShell(WidgetTester tester, _Shape shape) async {
  useWindow(tester, innerLandscape);
  final harness = ShellHarness();
  await tester.pumpWidget(
    shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, rail: shape.rail, shape: shape.shape),
  );
  await tester.pumpAndSettle();
  expect(harness.slots['Branch 0']?.active, isTrue);
  VerticalBarShellDebugStats.reset();
  return harness;
}

void main() {
  setUp(VerticalBarShellDebugStats.reset);

  for (final shape in _shapes) {
    group(shape.name, () {
      testWidgets('a keyboard rising to 300 and back keeps the cells off the rail in every frame', (tester) async {
        final harness = await _pumpShell(tester, shape);
        final slots = harness.slots['Branch 0'];
        _expectCellsClear(tester, shape.rail, 'before the keyboard');
        var cells = cellsOf(tester);
        var builds = VerticalBarShellDebugStats.layerBuilds;
        const steps = <double>[50, 100, 150, 200, 250, 300, 250, 200, 150, 100, 50, 0];
        for (final keyboard in steps) {
          useWindow(tester, innerLandscape, keyboard: keyboard);
          await tester.pump();
          _expectCellsClear(tester, shape.rail, 'keyboard $keyboard');
          expect(harness.slots['Branch 0'], slots, reason: 'keyboard $keyboard');
          // The layer is built again once in a frame whose cells change, and never in the others.
          final now = cellsOf(tester);
          expect(
            VerticalBarShellDebugStats.layerBuilds,
            listEquals(now, cells) ? builds : builds + 1,
            reason: 'keyboard $keyboard',
          );
          (cells, builds) = (now, VerticalBarShellDebugStats.layerBuilds);
          if (keyboard == 300) {
            expect(_railPosition(tester, shape.rail).pixels, 0);
            expect(_railPosition(tester, shape.rail).maxScrollExtent, greaterThan(0));
            // The floor (184) and the rail's 8-point spacer.
            expect(markerFlexTop(tester), 192);
            expect(_railItems(tester, shape.rail).first.top, 192);
            expect(cellsOf(tester), const [('Show menu', _floorCell)]);
          }
        }
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(VerticalBarShellDebugStats.deferredNotifications, 0);
        expect(VerticalBarShellDebugStats.paintFixes, 0);
      });

      testWidgets('a text scale of 2.0 and back keeps the cells off the rail and rebuilds them only when they '
          'change', (tester) async {
        final harness = await _pumpShell(tester, shape);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final slots = harness.slots['Branch 0'];
        var cells = cellsOf(tester);
        var builds = VerticalBarShellDebugStats.layerBuilds;
        for (final scale in const <double>[2, 1]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump();
          _expectCellsClear(tester, shape.rail, 'text scale $scale');
          expect(harness.slots['Branch 0'], slots, reason: 'text scale $scale');
          final now = cellsOf(tester);
          if (scale == 2) {
            // NavigationRail labels grow to the floor; the scrolling rail has none.
            expect(
              now,
              shape.shape == ShellShape.inBody ? const [('Show menu', _floorCell)] : cells,
              reason: 'text scale $scale',
            );
          }
          if (listEquals(now, cells)) {
            expect(VerticalBarShellDebugStats.layerBuilds, builds, reason: 'text scale $scale');
          } else {
            expect(VerticalBarShellDebugStats.layerBuilds, greaterThan(builds), reason: 'text scale $scale');
          }
          (cells, builds) = (now, VerticalBarShellDebugStats.layerBuilds);
        }
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(VerticalBarShellDebugStats.paintFixes, 0);
      });

      testWidgets('scrolling the rail under a keyboard neither fixes nor rebuilds the cells', (tester) async {
        await _pumpShell(tester, shape);
        useWindow(tester, innerLandscape, keyboard: 300);
        await tester.pumpAndSettle();
        _expectCellsClear(tester, shape.rail, 'keyboard 300');
        final cells = cellsOf(tester);
        final builds = VerticalBarShellDebugStats.layerBuilds;
        final position = _railPosition(tester, shape.rail);
        for (final offset in [10.0, 25.0, position.maxScrollExtent, 5.0, 0.0]) {
          position.jumpTo(offset);
          await tester.pump();
          expect(markerFlexTop(tester), 192 - offset, reason: 'offset $offset');
          _expectCellsClear(tester, shape.rail, 'offset $offset');
          expect(cellsOf(tester), cells, reason: 'offset $offset');
        }
        await tester.drag(_railScrollable(shape.rail), const Offset(0, -120));
        await tester.pump();
        expect(position.pixels, greaterThan(0));
        _expectCellsClear(tester, shape.rail, 'drag');
        await tester.pumpAndSettle();
        _expectCellsClear(tester, shape.rail, 'drag settled');
        expect(cellsOf(tester), cells);

        // An iOS bounce at the top pulls the items below where they can rest; the cells stay as at rest.
        position.jumpTo(0);
        await tester.pump();
        final viewport = tester.getRect(_railScrollable(shape.rail));
        final pull = await tester.startGesture(viewport.topCenter + const Offset(0, 20));
        for (var frame = 0; frame < 20; frame++) {
          await pull.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
          _expectCellsClear(tester, shape.rail, 'pulled down, frame $frame');
          expect(cellsOf(tester), cells, reason: 'pulled down, frame $frame');
        }
        expect(position.pixels, lessThan(-40));
        expect(markerFlexTop(tester), greaterThan(192 + 40));
        await pull.up();
        await _expectSameCellsUntilSettled(tester, shape.rail, cells, 'released');
        expect(position.pixels, 0);

        // A fling past the end lifts the items above where they can rest, below the floor cell.
        var pastEnd = false;
        await tester.fling(_railScrollable(shape.rail), const Offset(0, -200), 3000);
        await _expectSameCellsUntilSettled(
          tester,
          shape.rail,
          cells,
          'flung',
          onFrame: () => pastEnd |= position.pixels > position.maxScrollExtent,
        );
        expect(pastEnd, isTrue);
        expect(position.pixels, position.maxScrollExtent);
        expect(VerticalBarShellDebugStats.layerBuilds, builds);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('a change of the bottom view padding alone moves nothing', (tester) async {
        await _pumpShell(tester, shape);
        final cells = cellsOf(tester);
        final items = _railItems(tester, shape.rail);
        final builds = VerticalBarShellDebugStats.layerBuilds;
        tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 20);
        await tester.pump();
        expect(cellsOf(tester), cells);
        expect(_railItems(tester, shape.rail), items);
        expect(VerticalBarShellDebugStats.layerBuilds, builds);
        _expectCellsClear(tester, shape.rail, 'view padding 20');
      });
    });
  }

  testWidgets('a rail in a reversed scroll view is read where its items rest, also while a bounce pulls them down', (
    tester,
  ) async {
    useWindow(tester, innerLandscape);
    const railKey = ValueKey('reversedRail');
    // Six 56-point items that a reversed scroll view keeps at its bottom while they fit.
    final rail = Builder(
      builder: (context) {
        final padding = MediaQuery.paddingOf(context);
        // As tall as the shell, like a NavigationRail.
        return SizedBox(
          width: 84,
          height: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(top: VerticalBarShell.railPaddingOf(context, padding).top, bottom: padding.bottom),
            child: SingleChildScrollView(
              key: railKey,
              reverse: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var item = 0; item < 6; item++) SizedBox(key: ValueKey('rail:$item'), width: 84, height: 56),
                  const VerticalBarRailEnd(),
                ],
              ),
            ),
          ),
        );
      },
    );
    await tester.pumpWidget(
      duoApp(
        innerLandscape,
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: VerticalBarShell(
            railEdge: HorizontalEdge.right,
            rail: rail,
            content: VerticalBarPage(
              actions: [
                for (final id in ['a0', 'b0', 'c0', 'd0'])
                  VerticalBarAction(id: id, icon: const Icon(Icons.star), label: id, onPressed: (invocation) {}),
              ],
              builder: (context, slots) => const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The items rest at the bottom of the viewport (184 to 635), from 299: room for three cells.
    expect(markerFlexTop(tester), 299);
    expect(cellLabels(tester), ['a0', 'b0', 'Show menu']);

    useWindow(tester, innerLandscape, keyboard: 300);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.descendant(of: find.byKey(railKey), matching: find.byType(Scrollable)))
        .position;
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(0));
    final cells = cellsOf(tester);
    expect(cells, const [('Show menu', _floorCell)]);
    VerticalBarShellDebugStats.reset();
    final builds = VerticalBarShellDebugStats.layerBuilds;
    // Pulling down at the top scrolls to the first item and on past the end of the scroll view.
    final pull = await tester.startGesture(tester.getRect(find.byKey(railKey)).topCenter + const Offset(0, 20));
    for (var frame = 0; frame < 30; frame++) {
      await pull.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
      expect(cellsOf(tester), cells, reason: 'pulled down, frame $frame');
    }
    expect(position.pixels, greaterThan(position.maxScrollExtent + 40));
    expect(markerFlexTop(tester), greaterThan(184 + 40));
    await pull.up();
    for (var frame = 0; tester.binding.hasScheduledFrame; frame++) {
      expect(frame, lessThan(600));
      await tester.pump(const Duration(milliseconds: 16));
      expect(cellsOf(tester), cells, reason: 'released, frame $frame');
    }
    expect(position.pixels, position.maxScrollExtent);
    expect(VerticalBarShellDebugStats.paintFixes, 0);
    expect(VerticalBarShellDebugStats.layerBuilds, builds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rail item moved behind a relayout boundary in the rail is caught when painted and fixed once, '
      'a frame late', (tester) async {
    await _expectMoveFixedOnce(tester, movableRail);
  });

  // The rail moves the items' layer without painting the marker; the shell, which the move repaints,
  // checks the cells.
  for (final (items, holder) in const [
    (MovableItems.repaintBoundary, 'a RepaintBoundary'),
    (MovableItems.scrollView, 'a scroll view of fixed height'),
  ]) {
    testWidgets('a rail item moved behind a relayout boundary in the rail, with the items in $holder, is caught '
        'when the shell paints and fixed once, a frame late', (tester) async {
      await _expectMoveFixedOnce(tester, movableRailWith(items));
    });
  }
}

/// Moves [rail]'s items from 411 to 245 behind its relayout boundary and expects the old cells in that
/// frame, one paint-phase fix, and the cells for the new top in the next frame.
Future<void> _expectMoveFixedOnce(WidgetTester tester, HarnessRail rail) async {
  useWindow(tester, innerLandscape);
  final harness = ShellHarness();
  await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, rail: rail));
  await tester.pumpAndSettle();
  expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
  VerticalBarShellDebugStats.reset();
  // The items' top moves from 411 to 245, which leaves room for two cells.
  harness.movableKey.currentState!.setGap(200);
  await tester.pump();
  expect(markerFlexTop(tester), 245);
  expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
  expect(VerticalBarShellDebugStats.paintFixes, 1);
  await tester.pump();
  expect(cellsOf(tester), const [
    ('a0', Rect.fromLTRB(885, 124, 933, 172)),
    ('Show menu', Rect.fromLTRB(885, 176, 933, 224)),
  ]);
  expect(shellLayout(tester).debugNeedsLayout, isFalse);
  await tester.pumpAndSettle();
  expect(VerticalBarShellDebugStats.paintFixes, 1);
  expect(VerticalBarShellDebugStats.deferredNotifications, 0);
  expect(tester.binding.hasScheduledFrame, isFalse);
  expect(tester.takeException(), isNull);
}
