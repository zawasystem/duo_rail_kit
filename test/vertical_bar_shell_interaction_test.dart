import 'dart:async';

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/toolbar/vertical_bar_toolbar.dart' show VerticalBarShellDebugStats;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/actions.dart';
import 'support/cells.dart';
import 'support/diagnostics.dart';
import 'support/duo_windows.dart';
import 'support/shell_harness.dart';
import 'support/traversal.dart';

/// Home with two actions, a second tab with two, and Settings with none.
const List<List<String>> _twoActions = [
  ['a0', 'b0'],
  ['a1', 'b1'],
  <String>[],
];

/// The cell whose control has the tooltip [label].
Rect _cellRect(WidgetTester tester, String label) => cellsOf(tester).firstWhere((cell) => cell.$1 == label).$2;

NavigatorState _rootNavigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

/// The Navigator of the route that shows [text].
NavigatorState? _navigatorShowing(WidgetTester tester, String text) =>
    ModalRoute.of(tester.element(find.text(text)))?.navigator;

/// The colour of the first icon glyph below [finder].
Color? _iconColor(WidgetTester tester, Finder finder) =>
    tester.widget<RichText>(find.descendant(of: finder, matching: find.byType(RichText)).first).text.style?.color;

/// The icon colour that the first button below [finder] resolves from its theme. Buttons animate their
/// icon colour to it over [kThemeChangeDuration], in the column as in an app bar.
Color? _buttonIconColor(WidgetTester tester, Finder finder) => tester
    .widget<AnimatedTheme>(find.descendant(of: finder, matching: find.byType(AnimatedTheme)).first)
    .data
    .iconTheme
    .color;

/// [cycle] rotated to start with [first].
List<Rect> _startingAt(List<Rect> cycle, Rect first) {
  final index = cycle.indexOf(first);
  expect(index, isNonNegative, reason: '$first in $cycle');
  return [...cycle.skip(index), ...cycle.take(index)];
}

/// One icon instance for every numbered action in this file: under widget-creation tracking, which flutter test
/// turns on, each const Icon call site is a separate instance.
const Widget _numberedIcon = Icon(Icons.star);

/// A standard action labelled and identified by [id] that adds [id] to [taps].
VerticalBarAction _action(String id, List<Object> taps) =>
    VerticalBarAction(id: id, icon: const Icon(Icons.star), label: id, onPressed: (invocation) => taps.add(id));

/// A branch page with the branch's actions whose app bar never shows them, so that a plain RailSideRow host
/// reads and traverses everything but the cells; [field] puts a TextField in its body.
Widget _quietPage(BranchRootState branch, {bool field = false}) => VerticalBarPage(
  actions: [for (final id in branch.actions) _action(id, <Object>[])],
  builder: (context, slots) => Scaffold(
    appBar: AppBar(title: Text('Branch ${branch.widget.index}')),
    body: Center(
      child: field ? TextField(key: ValueKey('field:${branch.widget.index}')) : Text('Body ${branch.widget.index}'),
    ),
  ),
);

/// A pushed page with the back control and ten actions whose [kind] cell, 'back' or 'overflow', hands its
/// first invoke to [save], as an application control that keeps it for later would.
Widget _savingPage(String kind, void Function(VoidCallback? invoke) save) {
  Widget saving(BuildContext context, VerticalBarCell cell) {
    save(cell.invoke);
    return const SizedBox.square(dimension: VerticalBarColumn.cellExtent);
  }

  return VerticalBarPage(
    actions: numberedActions(10, icon: _numberedIcon),
    backBuilder: kind == 'back' ? saving : null,
    overflowBuilder: kind == 'overflow' ? saving : null,
    builder: (context, slots) => Scaffold(
      appBar: AppBar(title: const Text('Saving'), automaticallyImplyLeading: !slots.backInColumn),
    ),
  );
}

/// What covers or hides the shell's owner, and how it ends.
enum _Cover {
  rootPage('while an opaque root page covers the shell'),
  rootDialog('while a root dialog is open'),
  hiddenBranch('while its branch is hidden'),
  backSwipe('during a back swipe in its branch');

  const _Cover(this.during);

  final String during;

  /// Starts this cover and returns what ends it.
  Future<Future<void> Function()> start(WidgetTester tester, ShellHarness harness) async {
    switch (this) {
      case _Cover.rootPage:
        _rootNavigator(tester).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('Upper'))),
          ),
        );
        await tester.pumpAndSettle();
        return () async {
          _rootNavigator(tester).pop();
          await tester.pumpAndSettle();
        };
      case _Cover.rootDialog:
        unawaited(
          showDialog<void>(
            context: _rootNavigator(tester).context,
            builder: (_) => const AlertDialog(content: Text('Dialog')),
          ),
        );
        await tester.pumpAndSettle();
        return () async {
          Navigator.of(tester.element(find.text('Dialog'))).pop();
          await tester.pumpAndSettle();
        };
      case _Cover.hiddenBranch:
        harness.host.select(1);
        await tester.pumpAndSettle();
        return () async {
          harness.host.select(0);
          await tester.pumpAndSettle();
        };
      case _Cover.backSwipe:
        final gesture = await tester.startGesture(const Offset(5, 300));
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();
        expect(_branchNavigator(harness).userGestureInProgress, isTrue);
        return () async {
          // Back to where it started, so that the page stays.
          await gesture.moveBy(const Offset(-100, 0));
          await gesture.up();
          await tester.pumpAndSettle();
        };
    }
  }
}

/// The Navigator of the branch at [index].
NavigatorState _branchNavigator(ShellHarness harness, [int index = 0]) =>
    Navigator.of(harness.branches[index]!.context);

void main() {
  setUp(VerticalBarShellDebugStats.reset);

  group('menus', () {
    testWidgets('the overflow menu opens on the root Navigator, its barrier covers the rail, and a choice calls the '
        'action once with the overflow cell', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final invocations = <(int, VerticalBarInvocation)>[];
      List<VerticalBarAction>? overflowed;
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          branchPage: (branch) => VerticalBarPage(
            actions: numberedActions(
              10,
              icon: _numberedIcon,
              onPressed: (n, invocation) => invocations.add((n, invocation)),
            ),
            overflowBuilder: (context, cell) {
              overflowed = cell.overflowed;
              // As the default controls: the tooltip around a 48-point target.
              return Tooltip(
                message: 'More',
                child: IconButton(
                  onPressed: cell.invoke,
                  style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
                  icon: const Icon(Icons.more_horiz),
                ),
              );
            },
            builder: (context, slots) => Scaffold(appBar: AppBar(title: Text('Branch ${branch.widget.index}'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const overflowCell = Rect.fromLTRB(885, 332, 933, 380);
      expect(cellsOf(tester), [
        for (var n = 0; n < 4; n++) ('Action $n', Rect.fromLTWH(885, 124 + 52.0 * n, 48, 48)),
        ('More', overflowCell),
      ]);
      expect(overflowed?.map((action) => action.id), [4, 5, 6, 7, 8, 9]);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(_navigatorShowing(tester, 'Action 4'), same(_rootNavigator(tester)));
      expect(menuRect(tester, 'Action 4').right, lessThanOrEqualTo(859));
      // The barrier covers the rail: a destination tap only closes the menu.
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('rail:1'))));
      await tester.pumpAndSettle();
      expect(find.text('Action 4'), findsNothing);
      expect(harness.host.index, 0);
      expect(invocations, isEmpty);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action 7'));
      await tester.pumpAndSettle();
      expect(invocations, [(7, const VerticalBarInvocation(anchor: overflowCell, fromOverflowMenu: true))]);
      expect(find.text('Action 7'), findsNothing);
      expectClean(tester);
    });

    testWidgets('the menu of an action with menu items opens on the root Navigator, whose barrier covers the rail', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final chosen = <String>[];
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          branchPage: (branch) => VerticalBarPage(
            actions: [
              VerticalBarAction(
                id: 'more',
                icon: const Icon(Icons.more_vert),
                label: 'More',
                menuItems: [VerticalBarMenuItem(label: 'Delete', onSelected: () => chosen.add('Delete'))],
              ),
            ],
            builder: (context, slots) => Scaffold(appBar: AppBar(title: Text('Branch ${branch.widget.index}'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cellsOf(tester), const [('More', Rect.fromLTRB(885, 124, 933, 172))]);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(_navigatorShowing(tester, 'Delete'), same(_rootNavigator(tester)));
      expect(menuRect(tester, 'Delete').right, lessThanOrEqualTo(859));
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('rail:1'))));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsNothing);
      expect(harness.host.index, 0);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chosen, ['Delete']);
      expectClean(tester);
    });

    for (final (opened, label, text) in const [
      ('the overflow menu', 'Show menu', 'Action 4'),
      ('a root dialog that an action shows', 'Action 0', 'Dialog'),
    ]) {
      testWidgets('$opened, opened from a focused cell, takes the focus, closes with Escape, and gives the focus '
          'back to the cell', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        late BuildContext pageContext;
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            branchPage: (branch) => VerticalBarPage(
              actions: [
                VerticalBarAction(
                  id: 0,
                  icon: const Icon(Icons.star),
                  label: 'Action 0',
                  onPressed: (invocation) => unawaited(
                    showDialog<void>(
                      context: pageContext,
                      builder: (_) => const AlertDialog(content: Text('Dialog')),
                    ),
                  ),
                ),
                ...numberedActions(10, icon: _numberedIcon).skip(1),
              ],
              builder: (context, slots) {
                pageContext = context;
                return Scaffold(appBar: AppBar(title: Text('Branch ${branch.widget.index}')));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['Action 0', 'Action 1', 'Action 2', 'Action 3', 'Show menu']);
        final cell = Focus.of(tester.element(find.descendant(of: find.byTooltip(label), matching: find.byType(Icon))))
          ..requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(cell));

        expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
        await tester.pumpAndSettle();
        final route = ModalRoute.of(tester.element(find.text(text)))!;
        expect(route, isA<PopupRoute<Object?>>());
        expect(route.navigator, same(_rootNavigator(tester)));
        expect(ModalRoute.of(FocusManager.instance.primaryFocus!.context!), same(route));

        expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue);
        await tester.pumpAndSettle();
        expect(find.text(text), findsNothing);
        expect(FocusManager.instance.primaryFocus, same(cell));
        expect(harness.taps, isEmpty);
        expectClean(tester);
      });
    }

    testWidgets('a tap between two cells reaches neither a cell nor a destination', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      expect(_cellRect(tester, 'a0'), const Rect.fromLTRB(885, 124, 933, 172));
      expect(_cellRect(tester, 'b0'), const Rect.fromLTRB(885, 176, 933, 224));
      await tester.tapAt(const Offset(909, 174));
      await tester.pumpAndSettle();
      expect(harness.taps, isEmpty);
      expect(harness.host.index, 0);
      expectClean(tester);
    });

    testWidgets('with the column on the left, the overflow menu opens right of the column', (tester) async {
      useWindow(tester, outerLandscapeLeft);
      final harness = ShellHarness();
      // The status bar is hidden there, so the shell would not use the column; as on a later display.
      await tester.pumpWidget(
        shellApp(outerLandscapeLeft, harness, railEdge: HorizontalEdge.left, statusBarHidden: false),
      );
      await tester.pumpAndSettle();
      expect(cellsOf(tester), const [
        ('a0', Rect.fromLTRB(18, 82, 66, 130)),
        ('Show menu', Rect.fromLTRB(18, 134, 66, 182)),
      ]);
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(_navigatorShowing(tester, 'b0'), same(_rootNavigator(tester)));
      expect(menuRect(tester, 'b0').left, greaterThanOrEqualTo(92));
      await tester.tap(find.text('c0'));
      await tester.pumpAndSettle();
      expect(harness.taps, ['c0']);
      expectClean(tester);
    });

    testWidgets('a choice in the menu of a pushed page that its branch pops meanwhile is dropped', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final invocations = <(int, VerticalBarInvocation)>[];
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
      await tester.pumpAndSettle();
      _branchNavigator(harness).push(
        MaterialPageRoute<void>(
          builder: (_) => VerticalBarPage(
            actions: numberedActions(
              6,
              icon: _numberedIcon,
              onPressed: (n, invocation) => invocations.add((n, invocation)),
            ),
            builder: (context, slots) => Scaffold(
              appBar: AppBar(title: const Text('Pushed'), automaticallyImplyLeading: !slots.backInColumn),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cellLabels(tester), ['Back', 'Action 0', 'Action 1', 'Action 2', 'Show menu']);
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(_navigatorShowing(tester, 'Action 3'), same(_rootNavigator(tester)));

      _branchNavigator(harness).pop();
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsNothing);
      // The menu outlives the page on the root Navigator.
      expect(find.text('Action 3'), findsOneWidget);
      await tester.tap(find.text('Action 3'));
      await tester.pumpAndSettle();
      expect(invocations, isEmpty);
      expect(find.text('Action 3'), findsNothing);
      expect(_rootNavigator(tester).canPop(), isFalse);
      // The tab root owns the cells again, and they work once the menu has gone.
      await tester.tapAt(_cellRect(tester, 'a0').center);
      await tester.pump();
      expect(harness.taps, ['a0']);
      expectClean(tester);
    });
  });

  group('themes', () {
    testWidgets('light to dark gives the default controls their new colour in the first frame', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final light = ThemeData(platform: TargetPlatform.iOS);
      final dark = ThemeData(platform: TargetPlatform.iOS, brightness: Brightness.dark);
      Widget app(ThemeMode mode) => shellApp(
        innerLandscape,
        harness,
        railEdge: HorizontalEdge.right,
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        themeAnimationStyle: AnimationStyle.noAnimation,
      );
      await tester.pumpWidget(app(ThemeMode.light));
      await tester.pumpAndSettle();
      final cell = find.byTooltip('a0');
      expect(_iconColor(tester, cell), light.colorScheme.onSurfaceVariant);
      expect(dark.colorScheme.onSurfaceVariant, isNot(light.colorScheme.onSurfaceVariant));
      for (final (mode, data) in [(ThemeMode.dark, dark), (ThemeMode.light, light)]) {
        await tester.pumpWidget(app(mode));
        expect(_buttonIconColor(tester, cell), data.colorScheme.onSurfaceVariant, reason: mode.name);
        await tester.pumpAndSettle();
        expect(_iconColor(tester, cell), data.colorScheme.onSurfaceVariant, reason: mode.name);
      }
      expectClean(tester);
    });

    testWidgets('a Theme in the branch above the page gives the cells the colours of the page\'s app bar, also in '
        'the frame it changes', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      ThemeData themed(Color color) => ThemeData(
        platform: TargetPlatform.iOS,
        colorScheme: ColorScheme.fromSeed(seedColor: color).copyWith(onSurfaceVariant: color),
      );
      final theme = ValueNotifier<ThemeData>(themed(const Color(0xFF336600)));
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          branchPage: (branch) => ValueListenableBuilder<ThemeData>(
            valueListenable: theme,
            builder: (context, data, _) => Theme(
              data: data,
              child: VerticalBarPage(
                actions: [for (final id in branch.actions) _action(id, harness.taps)],
                builder: (context, slots) => Scaffold(
                  appBar: AppBar(
                    title: Text('Branch ${branch.widget.index}'),
                    actions: [
                      IconButton(key: const ValueKey('palette'), onPressed: () {}, icon: const Icon(Icons.palette)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byTooltip('a0');
      final appBar = find.byKey(const ValueKey('palette'));
      expect(_iconColor(tester, cell), const Color(0xFF336600));
      expect(_iconColor(tester, appBar), const Color(0xFF336600));
      theme.value = themed(const Color(0xFF990033));
      await tester.pump();
      expect(_buttonIconColor(tester, appBar), const Color(0xFF990033));
      expect(_buttonIconColor(tester, cell), const Color(0xFF990033));
      // Both buttons fade to it together.
      for (var frame = 0; frame < 5; frame++) {
        expect(_iconColor(tester, cell), _iconColor(tester, appBar), reason: 'frame $frame');
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_iconColor(tester, cell), const Color(0xFF990033));
      expectClean(tester);
    });
  });

  group('covered cells', () {
    for (final (label, text, open) in <(String, String, void Function(BuildContext context))>[
      (
        'a root bottom sheet',
        'Sheet',
        (context) => unawaited(
          showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            isDismissible: false,
            builder: (_) => const SizedBox(height: 200, child: Center(child: Text('Sheet'))),
          ),
        ),
      ),
      (
        'a root dialog',
        'Dialog',
        (context) => unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(content: Text('Dialog')),
          ),
        ),
      ),
      (
        'a bottom sheet in the branch',
        'Sheet',
        (context) => unawaited(
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => const SizedBox(height: 200, child: Center(child: Text('Sheet'))),
          ),
        ),
      ),
    ]) {
      testWidgets('below $label the cells stay drawn but take no taps and are skipped by Tab and screen readers, '
          'and they work in the first frame after it closes', (tester) async {
        useWindow(tester, innerLandscape);
        final semantics = tester.ensureSemantics();
        final harness = ShellHarness();
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            textField: true,
            branchActions: _twoActions,
          ),
        );
        await tester.pumpAndSettle();
        final cells = cellsOf(tester);
        expect(cells, const [('a0', Rect.fromLTRB(885, 124, 933, 172)), ('b0', Rect.fromLTRB(885, 176, 933, 224))]);
        expect(readingOrderOf(tester), containsAllInOrder(<String>['a0', 'b0']));
        var builds = VerticalBarShellDebugStats.layerBuilds;

        open(harness.branches[0]!.context);
        await tester.pumpAndSettle();
        expect(cellsOf(tester), cells);
        // Inert in the shell itself, also where the popup's barrier already takes the taps.
        expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
        expect(VerticalBarShellDebugStats.layerBuilds - builds, lessThanOrEqualTo(1));
        builds = VerticalBarShellDebugStats.layerBuilds;
        await tester.tapAt(cells.first.$2.center);
        await tester.pumpAndSettle();
        expect(harness.taps, isEmpty);
        expect(harness.host.index, 0);
        expect(find.text(text), findsOneWidget);
        final order = readingOrderOf(tester);
        expect(order, contains(text));
        expect(order, isNot(contains('a0')));
        expect(order, isNot(contains('b0')));
        // Tab focuses a default control's visible button.
        final buttons = [for (final (_, rect) in cells) button(rect)];
        for (final rect in await tabOrderOf(tester, 8)) {
          expect(buttons, isNot(contains(rect)));
        }
        expect(VerticalBarShellDebugStats.layerBuilds, builds);

        Navigator.of(tester.element(find.text(text))).pop();
        await tester.pump();
        expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isFalse);
        expect(VerticalBarShellDebugStats.layerBuilds - builds, lessThanOrEqualTo(1));
        await tester.tapAt(cells.first.$2.center);
        await tester.pump();
        expect(harness.taps, ['a0']);
        await tester.pumpAndSettle();
        // Also once the closing animation has ended.
        expect(VerticalBarShellDebugStats.layerBuilds - builds, lessThanOrEqualTo(1));
        expect(readingOrderOf(tester), containsAllInOrder(<String>['a0', 'b0']));
        semantics.dispose();
        expectClean(tester);
      });
    }

    testWidgets('a root page pushed over the shell keeps the owner, inert, without building the cells again, and '
        'its pop gives the same cells back, working', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final taps = <Object>[];
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          branchPage: (branch) => VerticalBarPage(
            actions: [
              VerticalBarAction.custom(
                id: 'counter',
                label: 'Counter',
                cellBuilder: (context, cell) => const CounterCell(),
                onPressed: (invocation) {},
              ),
              _action('b${branch.widget.index}', taps),
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
      final state = tester.state<CounterCellState>(find.byType(CounterCell));
      expect(state.taps, 2);
      final b0 = _cellRect(tester, 'b0');
      final builds = VerticalBarShellDebugStats.layerBuilds;

      _rootNavigator(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => VerticalBarPage(
            actions: [_action('upper', taps)],
            builder: (context, slots) => Scaffold(
              appBar: AppBar(title: const Text('Upper'), automaticallyImplyLeading: !slots.backInColumn),
            ),
          ),
        ),
      );
      await tester.pump();
      // The pushed page is still off the window, so the tap meets the shell's route, or its barrier.
      expect(ignoresPointersAbove(tester, find.byTooltip('b0')), isTrue);
      await tester.tapAt(b0.center);
      expect(taps, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      expect(ignoresPointersAbove(tester, find.byTooltip('b0')), isTrue);
      final flipped = VerticalBarShellDebugStats.layerBuilds;
      expect(flipped - builds, lessThanOrEqualTo(1));
      await tester.pumpAndSettle();
      // The covered shell's tickers are off, and it keeps its owner instead of dropping the cells.
      expect(VerticalBarShellDebugStats.layerBuilds, flipped);
      // The pushed page draws its own column, which is not centred on a rail.
      expect(cellsOf(tester), const [
        ('Back', Rect.fromLTRB(879, 124, 927, 172)),
        ('upper', Rect.fromLTRB(879, 184, 927, 232)),
      ]);

      _rootNavigator(tester).pop();
      await tester.pump();
      expect(tester.state<CounterCellState>(find.byType(CounterCell)), same(state));
      expect(state.taps, 2);
      expect(ignoresPointersAbove(tester, find.byTooltip('b0')), isFalse);
      await tester.pumpAndSettle();
      expect(VerticalBarShellDebugStats.layerBuilds - flipped, lessThanOrEqualTo(1));
      expect(cellLabels(tester), ['b0']);
      await tester.tapAt(b0.center);
      await tester.pump();
      expect(taps, ['b0']);
      expectClean(tester);
    });

    testWidgets('while the shell\'s own tickers are disabled, it keeps its owner, inert, and gives the cells back '
        'working once they are enabled', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final ticking = ValueNotifier<bool>(true);
      addTearDown(ticking.dispose);
      await tester.pumpWidget(
        shellApp(
          innerLandscape,
          harness,
          railEdge: HorizontalEdge.right,
          textField: true,
          // Above the root Navigator, so that the shell's route stays current.
          around: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: ticking,
            builder: (context, enabled, child) => TickerMode(enabled: enabled, child: child!),
            child: child,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final a0 = _cellRect(tester, 'a0');
      final buttons = [for (final (_, rect) in cellsOf(tester)) button(rect)];
      final builds = VerticalBarShellDebugStats.layerBuilds;
      ticking.value = false;
      await tester.pump();
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
      expect(VerticalBarShellDebugStats.layerBuilds - builds, 1);
      await tester.tapAt(a0.center);
      await tester.pump();
      expect(harness.taps, isEmpty);
      // The shell's route is current, so Tab moves through it, but past the cells.
      final inertOrder = await tabOrderOf(tester, 12);
      expect(inertOrder.where((rect) => rect != Rect.zero), isNotEmpty);
      expect(inertOrder.where(buttons.contains), isEmpty);
      // A switch while the tickers are off does not choose another owner.
      harness.host.select(1);
      await tester.pump();
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      ticking.value = true;
      await tester.pump();
      expect(cellLabels(tester), ['a1', 'b1']);
      harness.host.select(0);
      await tester.pump();
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isFalse);
      await tester.tapAt(a0.center);
      await tester.pump();
      expect(harness.taps, ['a0']);
      expect((await tabOrderOf(tester, 12)).where(buttons.contains), isNotEmpty);
      expectClean(tester);
    });

    testWidgets('a page pushed in a branch without a VerticalBarPage leaves the old cells inert until its push '
        'completes, then none', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      final a0 = _cellRect(tester, 'a0');
      _branchNavigator(harness).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Plain'))),
        ),
      );
      await tester.pump();
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
      await tester.tapAt(a0.center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      await tester.tapAt(a0.center);
      expect(harness.taps, isEmpty);
      await tester.pumpAndSettle();
      expect(cellsOf(tester), isEmpty);
      expectClean(tester);
    });

    testWidgets('without reservesBack, a page pushed in a branch with a back control leaves the old cells inert '
        'until its push completes, then none', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      final a0 = _cellRect(tester, 'a0');
      harness.branches[0]!.push();
      await tester.pump();
      expect(harness.slots['Pushed'], const VerticalBarSlots());
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
      await tester.tapAt(a0.center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      await tester.tapAt(a0.center);
      expect(harness.taps, isEmpty);
      await tester.pumpAndSettle();
      expect(cellsOf(tester), isEmpty);
      expectClean(tester);
    });

    testWidgets('inert cells keep the semantics grouping of the column', (tester) async {
      useWindow(tester, innerLandscape);
      final semantics = tester.ensureSemantics();
      final harness = ShellHarness();
      // The player below the shell is a sibling in the shell's route, outside the shell's container.
      await tester.pumpWidget(
        shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, playerBelowShell: true),
      );
      await tester.pumpAndSettle();
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      // A bottom sheet in the branch leaves the shell's nodes in the tree; a root popup's barrier hides them.
      unawaited(
        showModalBottomSheet<void>(
          context: harness.branches[0]!.context,
          builder: (_) => const SizedBox(height: 200, child: Center(child: Text('Sheet'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);

      final shell = tester.getSemantics(find.byType(VerticalBarShell));
      expect(isSemanticsContainer(tester, shell), isTrue);
      final children = semanticsChildren(shell);
      expect(children, hasLength(2), reason: 'the column layer\'s container, then the row\'s');
      final (layer, row) = (children.first, children.last);
      expect(isSemanticsContainer(tester, layer), isTrue);
      expect(semanticsChildren(layer), isEmpty, reason: 'inert cells are not read');
      expect(isSemanticsContainer(tester, row), isTrue);
      expect(textsFrom(row), containsAll(<String>['Sheet', 'Tab 0', 'Tab 3']));
      expect(textsFrom(row), isNot(contains('Player')));
      final texts = readingOrderOf(tester);
      for (final label in const ['a0', 'b0', 'c0', 'd0']) {
        expect(texts, isNot(contains(label)), reason: 'no cell node anywhere');
      }
      semantics.dispose();
      expectClean(tester);
    });
  });

  group('saved invokes', () {
    for (final kind in ['back', 'overflow']) {
      for (final cover in _Cover.values) {
        testWidgets('a saved $kind invoke does nothing ${cover.during}, and acts once that ends', (tester) async {
          useWindow(tester, innerLandscape);
          final harness = ShellHarness();
          await tester.pumpWidget(
            shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true),
          );
          await tester.pumpAndSettle();
          VoidCallback? invoke;
          final saving = MaterialPageRoute<void>(builder: (_) => _savingPage(kind, (saved) => invoke ??= saved));
          _branchNavigator(harness).push(saving);
          await tester.pumpAndSettle();
          expect(invoke, isNotNull);
          // The saving cell draws no tooltip.
          expect(
            cellLabels(tester),
            kind == 'back'
                ? ['Action 0', 'Action 1', 'Action 2', 'Show menu']
                : ['Back', 'Action 0', 'Action 1', 'Action 2'],
          );

          final end = await cover.start(tester, harness);
          invoke!();
          // A deferred invoke decides once a frame has ended.
          await tester.pump();
          await tester.pump();
          expect(find.text('Action 9'), findsNothing);
          expect(_branchNavigator(harness).canPop(), isTrue);
          await end();
          expect(find.text('Saving'), findsOneWidget);

          invoke!();
          await tester.pumpAndSettle();
          if (kind == 'back') {
            expect(find.text('Saving'), findsNothing);
            expect(_branchNavigator(harness).canPop(), isFalse);
          } else {
            expect(_navigatorShowing(tester, 'Action 9'), same(_rootNavigator(tester)));
            Navigator.of(tester.element(find.text('Action 9'))).pop();
            await tester.pumpAndSettle();
          }
          expectClean(tester);
        });
      }
    }

    testWidgets('a saved overflow invoke of a page that another page took the cells from does nothing until it owns '
        'them again', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final right = ValueNotifier<bool>(false);
      addTearDown(right.dispose);
      VoidCallback? invoke;
      final notes = await notesDuring(() async {
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            branchPage: (branch) => branch.widget.index != 0
                ? _quietPage(branch)
                : Row(
                    children: [
                      Expanded(
                        child: VerticalBarPage(
                          actions: numberedActions(10, icon: _numberedIcon),
                          overflowBuilder: (context, cell) {
                            invoke ??= cell.invoke;
                            return const SizedBox.square(dimension: VerticalBarColumn.cellExtent);
                          },
                          builder: (context, slots) => const Scaffold(body: Center(child: Text('Left'))),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: right,
                        builder: (context, shown, _) => shown
                            ? Expanded(
                                child: harnessPage(harness, title: 'Right', actions: const ['right']),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
          ),
        );
        await tester.pumpAndSettle();
        expect(invoke, isNotNull);
        // The page mounted later owns the cells.
        right.value = true;
        await tester.pump();
        expect(cellLabels(tester), ['right']);
        invoke!();
        await tester.pumpAndSettle();
        expect(find.text('Action 9'), findsNothing);
        right.value = false;
        await tester.pumpAndSettle();
        invoke!();
        await tester.pumpAndSettle();
        expect(_navigatorShowing(tester, 'Action 9'), same(_rootNavigator(tester)));
        Navigator.of(tester.element(find.text('Action 9'))).pop();
        await tester.pumpAndSettle();
      });
      expect(notes, hasLength(1));
      expect(notes.single, contains('mounted last'));
      expectClean(tester);
    });
  });

  group('pages pushed in a branch', () {
    testWidgets('with reservesBack, a pushed page shows its back control from the first frame, which pops only '
        'the branch', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
      await tester.pumpAndSettle();
      _branchNavigator(harness).push(
        MaterialPageRoute<void>(
          builder: (_) => harnessPage(harness, title: 'Pushed', actions: const ['p0', 'p1']),
        ),
      );
      await tester.pump();
      expect(cellsOf(tester), const [
        ('Back', Rect.fromLTRB(885, 124, 933, 172)),
        ('p0', Rect.fromLTRB(885, 184, 933, 232)),
        ('p1', Rect.fromLTRB(885, 236, 933, 284)),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsNothing);
      expect(_branchNavigator(harness).canPop(), isFalse);
      expect(_rootNavigator(tester).canPop(), isFalse);
      expect(find.byType(VerticalBarShell), findsOneWidget);
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expectClean(tester);
    });

    testWidgets('the back control of a page that refuses to pop calls its PopScope', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final pops = <bool>[];
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
      await tester.pumpAndSettle();
      _branchNavigator(harness).push(
        MaterialPageRoute<void>(
          builder: (_) => PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) => pops.add(didPop),
            child: harnessPage(harness, title: 'Guarded', actions: const ['g0']),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(pops, [false]);
      expect(find.text('Guarded'), findsWidgets);
      expect(_branchNavigator(harness).canPop(), isTrue);
      expectClean(tester);
    });

    testWidgets('a back swipe leaves the cells inert, and the page below owns them from the pop', (tester) async {
      useWindow(tester, innerLandscape);
      final semantics = tester.ensureSemantics();
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
      await tester.pumpAndSettle();
      _branchNavigator(harness).push(
        MaterialPageRoute<void>(
          builder: (_) => harnessPage(harness, title: 'Pushed', actions: const ['p0', 'p1']),
        ),
      );
      await tester.pumpAndSettle();
      final p0 = _cellRect(tester, 'p0');
      final gesture = await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(cellLabels(tester), ['Back', 'p0', 'p1']);
      expect(ignoresPointersAbove(tester, find.byTooltip('p0')), isTrue);
      expect(readingOrderOf(tester), isNot(contains('p0')));
      await tester.tapAt(p0.center);
      await tester.pump();
      expect(harness.taps, isEmpty);

      await gesture.moveBy(const Offset(600, 0));
      await gesture.up();
      await tester.pump();
      // The swipe popped the page; its animation still runs.
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsNothing);
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isFalse);
      await tester.tapAt(_cellRect(tester, 'a0').center);
      await tester.pump();
      expect(harness.taps, ['a0']);
      semantics.dispose();
      expectClean(tester);
    });

    testWidgets('over a tab root without actions, a back swipe still makes the cells inert, and a cancelled swipe '
        'gives them back', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right, reservesBack: true));
      await tester.pumpAndSettle();
      harness.host.select(2);
      await tester.pumpAndSettle();
      expect(cellsOf(tester), isEmpty);
      _branchNavigator(harness, 2).push(
        MaterialPageRoute<void>(
          builder: (_) => harnessPage(harness, title: 'Pushed', actions: const ['p0', 'p1']),
        ),
      );
      await tester.pumpAndSettle();
      expect(cellLabels(tester), ['Back', 'p0', 'p1']);
      final p0 = _cellRect(tester, 'p0');
      final gesture = await tester.startGesture(const Offset(5, 300));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(_branchNavigator(harness, 2).userGestureInProgress, isTrue);
      expect(ignoresPointersAbove(tester, find.byTooltip('p0')), isTrue);
      await tester.tapAt(p0.center);
      await tester.pump();
      expect(harness.taps, isEmpty);
      await gesture.moveBy(const Offset(-100, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_branchNavigator(harness, 2).userGestureInProgress, isFalse);
      expect(ignoresPointersAbove(tester, find.byTooltip('p0')), isFalse);
      await tester.tapAt(p0.center);
      await tester.pump();
      expect(harness.taps, ['p0']);
      expectClean(tester);
    });

    testWidgets('a user gesture that the owner\'s Navigator reports without moving a route, as an app\'s own pop '
        'gesture does, makes the cells inert until it stops', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      final a0 = _cellRect(tester, 'a0');
      final navigator = _branchNavigator(harness)..didStartUserGesture();
      await tester.pump();
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isTrue);
      await tester.tapAt(a0.center);
      await tester.pump();
      expect(harness.taps, isEmpty);
      navigator.didStopUserGesture();
      await tester.pump();
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isFalse);
      await tester.tapAt(a0.center);
      await tester.pump();
      expect(harness.taps, ['a0']);
      expectClean(tester);
    });

    testWidgets('after a branch switch, a user gesture in the new owner\'s Navigator makes the cells inert until it '
        'stops', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      harness.host.select(1);
      await tester.pumpAndSettle();
      final a1 = _cellRect(tester, 'a1');
      final navigator = _branchNavigator(harness, 1)..didStartUserGesture();
      await tester.pump();
      expect(ignoresPointersAbove(tester, find.byTooltip('a1')), isTrue);
      await tester.tapAt(a1.center);
      await tester.pump();
      expect(harness.taps, isEmpty);
      navigator.didStopUserGesture();
      await tester.pump();
      expect(ignoresPointersAbove(tester, find.byTooltip('a1')), isFalse);
      await tester.tapAt(a1.center);
      await tester.pump();
      expect(harness.taps, ['a1']);
      expectClean(tester);
    });

    testWidgets('a pop during the push gives the page below its cells, working, in the first frame', (tester) async {
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
      expect(ignoresPointersAbove(tester, find.byTooltip('a0')), isFalse);
      await tester.tapAt(_cellRect(tester, 'a0').center);
      await tester.pump();
      expect(harness.taps, ['a0']);
      await tester.pumpAndSettle();
      expectClean(tester);
    });

    testWidgets('without reservesBack a pushed page keeps its back control and actions in its app bar', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      harness.branches[0]!.push();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appBar:pushed')), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(cellsOf(tester), isEmpty);
      expectClean(tester);
    });
  });

  group('order and State', () {
    final windows = <(DuoWindow, HorizontalEdge, TextDirection?, String)>[
      (innerLandscape, HorizontalEdge.right, null, ''),
      (outerLandscapeLeft, HorizontalEdge.left, null, ', with the status bar shown'),
      (innerLandscape, HorizontalEdge.right, TextDirection.rtl, ', right to left'),
    ];
    for (final (window, edge, direction, suffix) in windows) {
      testWidgets('${window.name}$suffix: screen readers read the cells first, then what a RailSideRow reads, then '
          'the sibling below the Navigator', (tester) async {
        useWindow(tester, window);
        final semantics = tester.ensureSemantics();
        Future<(List<String>, List<String>)> read({required bool plain}) async {
          await tester.pumpWidget(
            shellApp(
              window,
              ShellHarness(),
              railEdge: edge,
              plain: plain,
              statusBarHidden: false,
              textDirection: direction,
              around: miniPlayerAround,
              branchPage: _quietPage,
            ),
          );
          await tester.pumpAndSettle();
          final result = (readingOrderOf(tester), cellLabels(tester));
          if (!plain) {
            // Physical edges: the cells and the rail stay on the column's side, also right to left.
            expect(cellsOf(tester).first.$2.left, edge == HorizontalEdge.right ? 885 : 18);
            expect(tester.getRect(find.byKey(const ValueKey('rail:0'))).left, edge == HorizontalEdge.right ? 867 : 0);
          }
          await tester.pumpWidget(const SizedBox());
          return result;
        }

        final (expected, plainCells) = await read(plain: true);
        final (actual, cells) = await read(plain: false);
        expect(plainCells, isEmpty);
        expect(cells, isNotEmpty);
        expect(expected.last, 'Player');
        const railLabels = ['Tab 0', 'Tab 1', 'Tab 2', 'Tab 3'];
        if (edge == HorizontalEdge.left) {
          // A known gap, in a plain RailSideRow too: the ModalBarrier of the branch Navigator's route blocks
          // the semantics painted before it in the same container, which includes a left rail. Once that is
          // fixed, expect containsAll(railLabels) here as on the right. The workaround is tested below.
          expect(expected, isNot(contains(railLabels.first)));
        } else {
          expect(expected, containsAll(railLabels));
        }
        expect(actual, [...cells, ...expected]);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${window.name}$suffix: Tab visits the cells first, then a RailSideRow\'s order, then the player '
          'below the shell', (tester) async {
        useWindow(tester, window);
        Future<({List<Rect> cycle, Rect player, List<Rect> cells})> visit({required bool plain}) async {
          await tester.pumpWidget(
            shellApp(
              window,
              ShellHarness(),
              railEdge: edge,
              plain: plain,
              statusBarHidden: false,
              textDirection: direction,
              playerBelowShell: true,
              branchPage: (branch) => _quietPage(branch, field: true),
            ),
          );
          await tester.pumpAndSettle();
          final player = tester.getRect(find.byKey(routePlayerKey));
          final cells = [for (final (_, rect) in cellsOf(tester)) button(rect)];
          final cycle = tabCycleOf(await tabOrderOf(tester, 20));
          await tester.pumpWidget(const SizedBox());
          // The focus rect of a TextButton is its visible button, inside its box.
          return (cycle: cycle, player: cycle.firstWhere((rect) => player.contains(rect.center)), cells: cells);
        }

        final plain = await visit(plain: true);
        final shell = await visit(plain: false);
        expect(plain.cells, isEmpty);
        expect(shell.cells, isNotEmpty);
        // From the player on: the cells, then the row in the order the plain row has from its player on.
        final afterPlayer = _startingAt(shell.cycle, shell.player).skip(1).toList();
        expect(afterPlayer.take(shell.cells.length), shell.cells);
        final row = afterPlayer.skip(shell.cells.length).toList();
        expect(row, _startingAt(plain.cycle, plain.player).skip(1).toList());
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${outerLandscapeLeft.name}, with the status bar shown and the branches in a semantics container: '
        'screen readers read the cells, the left rail, then the content', (tester) async {
      useWindow(tester, outerLandscapeLeft);
      final semantics = tester.ensureSemantics();
      Future<(List<String>, List<String>)> read({required bool plain}) async {
        await tester.pumpWidget(
          shellApp(
            outerLandscapeLeft,
            ShellHarness(),
            railEdge: HorizontalEdge.left,
            plain: plain,
            statusBarHidden: false,
            contentSemanticsContainer: true,
            around: miniPlayerAround,
            branchPage: _quietPage,
          ),
        );
        await tester.pumpAndSettle();
        final result = (readingOrderOf(tester), cellLabels(tester));
        await tester.pumpWidget(const SizedBox());
        return result;
      }

      final (expected, plainCells) = await read(plain: true);
      final (actual, cells) = await read(plain: false);
      expect(plainCells, isEmpty);
      expect(cells, isNotEmpty);
      const railLabels = ['Tab 0', 'Tab 1', 'Tab 2', 'Tab 3'];
      // The container bounds the BlockSemantics of the branch routes' modal barriers, so the rail painted
      // before the branches stays in the tree, ahead of them.
      expect(expected.take(railLabels.length), railLabels);
      expect(expected.last, 'Player');
      expect(actual, [...cells, ...expected]);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    Widget fieldAndList(BranchRootState branch) => VerticalBarPage(
      actions: [for (final id in branch.actions) _action(id, <Object>[])],
      builder: (context, slots) => Scaffold(
        appBar: AppBar(title: Text('Branch ${branch.widget.index}')),
        body: Column(
          children: [
            TextField(key: ValueKey('field:${branch.widget.index}')),
            Expanded(
              child: ListView(
                key: ValueKey('list:${branch.widget.index}'),
                children: [for (var item = 0; item < 40; item++) SizedBox(height: 48, child: Text('Item $item'))],
              ),
            ),
          ],
        ),
      ),
    );

    Future<({EditableTextState field, ScrollableState list})> focusAndScroll(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('field:0')));
      await tester.pump();
      final field = tester.state<EditableTextState>(find.byType(EditableText));
      final list = tester.state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('list:0')), matching: find.byType(Scrollable)),
      );
      list.position.jumpTo(120);
      await tester.pump();
      expect(field.widget.focusNode.hasFocus, isTrue);
      expect(list.position.pixels, 120);
      return (field: field, list: list);
    }

    void expectKept(WidgetTester tester, ({EditableTextState field, ScrollableState list}) kept) {
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(kept.field));
      expect(kept.field.widget.focusNode.hasFocus, isTrue);
      expect(
        tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('list:0')), matching: find.byType(Scrollable)),
        ),
        same(kept.list),
      );
      expect(kept.list.position.pixels, 120);
    }

    testWidgets('a focused TextField and a scroll offset in the content survive the column leaving and returning', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      Widget app(DuoWindow window) =>
          shellApp(window, harness, railEdge: HorizontalEdge.right, branchPage: fieldAndList);
      await tester.pumpWidget(app(innerLandscape));
      await tester.pumpAndSettle();
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      final kept = await focusAndScroll(tester);
      // The native values leave, as at the start of a rotation, and come back.
      useWindow(tester, firstFrame);
      await tester.pumpWidget(app(firstFrame));
      expect(cellsOf(tester), isEmpty);
      expectKept(tester, kept);
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(app(innerLandscape));
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expectKept(tester, kept);
      expectClean(tester);
    });

    testWidgets('a focused TextField and a scroll offset in the content survive the column and the rail moving to '
        'the other edge', (tester) async {
      useWindow(tester, outerLandscapeRight);
      final harness = ShellHarness();
      Widget app(DuoWindow window) => shellApp(
        window,
        harness,
        railEdge: HorizontalEdge.right,
        statusBarHidden: false,
        branchPage: fieldAndList,
      );
      await tester.pumpWidget(app(outerLandscapeRight));
      await tester.pumpAndSettle();
      expect(_cellRect(tester, 'a0').left, 612);
      final kept = await focusAndScroll(tester);
      useWindow(tester, outerLandscapeLeft);
      harness.host.setRailEdge(HorizontalEdge.left);
      await tester.pumpWidget(app(outerLandscapeLeft));
      expect(_cellRect(tester, 'a0').left, 18);
      expectKept(tester, kept);
      expectClean(tester);
    });

    testWidgets('the shell keeps one traversal policy across rebuilds', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
      await tester.pumpAndSettle();
      // The policies of the groups around a cell, from the nearest out.
      List<FocusTraversalPolicy> policies() => [
        for (final group in tester.widgetList<FocusTraversalGroup>(
          find.ancestor(of: find.byTooltip('a0'), matching: find.byType(FocusTraversalGroup)),
        ))
          group.policy,
      ];
      final previous = policies();
      final ambient = FocusTraversalGroup.maybeOf(tester.element(find.byType(VerticalBarShell)));
      expect(previous.first, same(ambient), reason: 'the column layer sorts its cells with the policy above the shell');

      // Rebuilds the shell's parent with the same values, so the ambient policy stays.
      final shellBefore = tester.widget(find.byType(VerticalBarShell));
      harness.host.setRailEdge(HorizontalEdge.right);
      await tester.pump();
      expect(
        tester.widget(find.byType(VerticalBarShell)),
        isNot(same(shellBefore)),
        reason: 'the shell was built again',
      );
      expect(FocusTraversalGroup.maybeOf(tester.element(find.byType(VerticalBarShell))), same(ambient));
      final current = policies();
      expect(current, hasLength(previous.length));
      for (var i = 0; i < previous.length; i++) {
        expect(current[i], same(previous[i]), reason: 'group $i: traversal history lives in the policy');
      }
      expectClean(tester);
    });

    testWidgets('the cells form one semantics container, read before the rail and the content', (tester) async {
      useWindow(tester, innerLandscape);
      final semantics = tester.ensureSemantics();
      // The player below the shell is a sibling in the shell's route, outside the shell's container.
      await tester.pumpWidget(
        shellApp(innerLandscape, ShellHarness(), railEdge: HorizontalEdge.right, playerBelowShell: true),
      );
      await tester.pumpAndSettle();
      const labels = ['a0', 'b0', 'c0', 'd0'];
      expect(cellLabels(tester), labels);

      final cells = [
        for (final node in semanticsNodesFrom(semanticsRootOf(tester)))
          if (labels.contains(node.tooltip)) node,
      ];
      expect([for (final node in cells) node.tooltip], labels);
      final container = cells.first.parent!;
      expect(semanticsChildren(container), cells, reason: 'the cells, and nothing else');
      expect(isSemanticsContainer(tester, container), isTrue);

      final shell = tester.getSemantics(find.byType(VerticalBarShell));
      expect(isSemanticsContainer(tester, shell), isTrue);
      final children = semanticsChildren(shell);
      expect(children, hasLength(2));
      expect(children.first, same(container));
      final rest = textsFrom(children.last);
      expect(rest, containsAll(<String>['Tab 0', 'Tab 3', 'Branch 0', 'Body 0']));
      expect(rest, isNot(contains('Player')));
      semantics.dispose();
      expectClean(tester);
    });
  });

  group('origin check', () {
    testWidgets('stays quiet while a root page is pushed over the shell and swiped back', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final errors = await collectErrors(() async {
        await tester.pumpWidget(shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right));
        await tester.pumpAndSettle();
        _rootNavigator(tester).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('Upper'))),
          ),
        );
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(const Offset(5, 300));
        for (var step = 0; step < 7; step++) {
          await gesture.moveBy(const Offset(100, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
      });
      expect(find.text('Upper'), findsNothing);
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(errors, isEmpty);
      expectClean(tester);
    });

    testWidgets('stays quiet while the shell\'s own route is pushed and swiped back', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final navigatorKey = GlobalKey<NavigatorState>();
      // The ShellHost that shellApp shows as its home, pushed here as a page.
      final host = (shellApp(innerLandscape, harness, railEdge: HorizontalEdge.right) as MaterialApp).home!;
      final errors = await collectErrors(() async {
        await tester.pumpWidget(
          duoApp(
            innerLandscape,
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Start')),
          ),
        );
        navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => host));
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
        final gesture = await tester.startGesture(const Offset(5, 300));
        for (var step = 0; step < 3; step++) {
          await gesture.moveBy(const Offset(100, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Lays the shell out while its route follows the swipe.
        harness.branches[0]!.setActions(['k0']);
        await tester.pump();
        await gesture.moveBy(const Offset(-300, 0));
        await gesture.up();
        await tester.pumpAndSettle();
      });
      expect(cellLabels(tester), ['k0']);
      expect(errors, isEmpty);
      expectClean(tester);
    });

    testWidgets('stays quiet while a Navigator around the shell\'s Navigator pushes a page and pops it', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final outerKey = GlobalKey<NavigatorState>();
      final errors = await collectErrors(() async {
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            // As a go_router ShellRoute around the tab shell, with pages pushed on the root Navigator.
            around: (context, child) => Navigator(
              key: outerKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child!),
            ),
          ),
        );
        await tester.pumpAndSettle();
        outerKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('Upper'))),
          ),
        );
        await tester.pumpAndSettle();
        outerKey.currentState!.pop();
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pumpAndSettle();
      });
      expect(find.text('Upper'), findsNothing);
      expect(cellLabels(tester), ['a0', 'b0', 'c0', 'd0']);
      expect(errors, isEmpty);
      expectClean(tester);
    });

    for (final (label, padding, expected) in [
      ('does not start at the window\'s left edge', const EdgeInsets.only(left: 10), '(10.0, 0.0) and is 941.0 wide'),
      ('is narrower than the window', const EdgeInsets.only(right: 10), '(0.0, 0.0) and is 941.0 wide'),
      ('does not start at the window\'s top edge', const EdgeInsets.only(top: 10), '(0.0, 10.0) and is 951.0 wide'),
    ]) {
      testWidgets('reports a shell that $label, once', (tester) async {
        useWindow(tester, innerLandscape);
        final harness = ShellHarness();
        final errors = await collectErrors(() async {
          await tester.pumpWidget(
            shellApp(
              innerLandscape,
              harness,
              railEdge: HorizontalEdge.right,
              around: (context, child) => Padding(padding: padding, child: child),
            ),
          );
          await tester.pumpAndSettle();
          harness.branches[0]!.setActions(['k0']);
          await tester.pumpAndSettle();
        });
        expect(errors, hasLength(1));
        expect('${errors.single.exception}', contains("must start at the window's top-left corner"));
        expect('${errors.single.exception}', contains(expected));
        expectClean(tester);
      });
    }

    testWidgets('reports a shell that does not start at the window\'s left edge inside a Navigator around the '
        'shell\'s Navigator, once', (tester) async {
      useWindow(tester, innerLandscape);
      final harness = ShellHarness();
      final errors = await collectErrors(() async {
        await tester.pumpWidget(
          shellApp(
            innerLandscape,
            harness,
            railEdge: HorizontalEdge.right,
            around: (context, child) => Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Padding(padding: const EdgeInsets.only(left: 10), child: child),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        harness.branches[0]!.setActions(['k0']);
        await tester.pumpAndSettle();
      });
      expect(errors, hasLength(1));
      expect('${errors.single.exception}', contains('(10.0, 0.0) and is 941.0 wide'));
      expectClean(tester);
    });
  });
}
