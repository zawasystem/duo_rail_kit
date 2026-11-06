import 'dart:async';

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/actions.dart';
import 'support/cells.dart';
import 'support/diagnostics.dart';
import 'support/duo_windows.dart';
import 'support/traversal.dart';

/// The outer landscape displays, with the status bar shown in these page tests.
final DuoWindow _outerRightStatusBarShown = outerLandscapeRight.copyWith(statusBarHidden: false);
final DuoWindow _outerLeftStatusBarShown = outerLandscapeLeft.copyWith(statusBarHidden: false);

/// The inner landscape back cell and the first two action cells.
const Rect _backCell = Rect.fromLTRB(879, 124, 927, 172);
const Rect _firstCell = Rect.fromLTRB(879, 184, 927, 232);
const Rect _secondCell = Rect.fromLTRB(879, 236, 927, 284);

const Key _scaffoldKey = ValueKey('scaffold');
const Key _titleKey = ValueKey('title');
const Key _bodyKey = ValueKey('body');
const Key _noteKey = ValueKey('note');
const Key _fieldKey = ValueKey('field');
const Key _buttonKey = ValueKey('button');

/// Page parts whose rectangles must not change where no column applies.
const List<Key> _pageKeys = [_scaffoldKey, _titleKey, _bodyKey, _noteKey, _fieldKey, _buttonKey];

/// [duoApp] for [window], with [HomePage] unless [home] is given.
Widget _app(
  DuoWindow window, {
  required GlobalKey<NavigatorState> navigatorKey,
  Widget home = const HomePage(),
  ThemeData? theme,
  TextDirection? textDirection,
  double? maxTextScale,
}) => duoApp(
  window,
  navigatorKey: navigatorKey,
  theme: theme,
  home: home,
  textDirection: textDirection,
  maxTextScale: maxTextScale,
);

Future<void> _push(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) async {
  navigator.currentState!.push(MaterialPageRoute<void>(builder: builder, fullscreenDialog: fullscreenDialog));
  await tester.pumpAndSettle();
}

void _noop(VerticalBarInvocation invocation) {}

VerticalBarAction _share({VerticalBarActionCallback? onPressed}) =>
    VerticalBarAction(id: 'share', icon: const Icon(Icons.share), label: 'Share', onPressed: onPressed ?? _noop);

VerticalBarAction _favorite({VerticalBarActionCallback? onPressed}) => VerticalBarAction(
  id: 'favorite',
  icon: const Icon(Icons.star_border),
  label: 'Favorite',
  onPressed: onPressed ?? _noop,
);

/// A page's Scaffold that follows [slots] like an application app bar would.
Widget _scaffold(VerticalBarSlots slots, List<VerticalBarAction> actions, {Widget? body, Widget? drawer}) => Scaffold(
  key: _scaffoldKey,
  drawer: drawer,
  appBar: AppBar(
    title: const Text('Detail', key: _titleKey),
    automaticallyImplyLeading: !slots.backInColumn,
    actions: slots.active
        ? null
        : [for (final action in actions) IconButton(tooltip: action.label, icon: action.icon!, onPressed: () {})],
  ),
  body: body ?? const _Body(),
);

class _Body extends StatelessWidget {
  const _Body({this.buttonOrder});

  /// When non-null, the body is an [OrderedTraversalPolicy] group in which only the button has this order,
  /// so that it comes before the field, which has none.
  final FocusOrder? buttonOrder;

  @override
  Widget build(BuildContext context) {
    final order = buttonOrder;
    Widget button = ElevatedButton(key: _buttonKey, onPressed: () {}, child: const Text('Go'));
    if (order != null) {
      button = FocusTraversalOrder(order: order, child: button);
    }
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Body', key: _bodyKey),
          const Text('Note', key: _noteKey),
          const TextField(key: _fieldKey),
          button,
        ],
      ),
    );
    return order == null ? body : FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: body);
  }
}

/// Focus orders a page body may use in an [OrderedTraversalPolicy] group, by name.
const List<(String, FocusOrder?)> _bodyOrders = [
  ('', null),
  (', a numeric order in an ordered group', NumericFocusOrder(2)),
  (', a lexical order in an ordered group', LexicalFocusOrder('a')),
];

/// Records what the page builder received.
class _Record {
  int builds = 0;
  VerticalBarSlots? slots;

  void call(VerticalBarSlots value) {
    builds++;
    slots = value;
  }
}

/// A wrapped detail page whose app bar follows the slots.
VerticalBarPage _page({
  List<VerticalBarAction>? actions,
  VerticalBarBack back = VerticalBarBack.automatic,
  bool enabled = true,
  VerticalBarItemBuilder? itemBuilder,
  VerticalBarCellBuilder? backBuilder,
  VerticalBarCellBuilder? overflowBuilder,
  Decoration? groupDecoration,
  Widget? body,
  Widget? drawer,
  _Record? record,
  Widget Function(Widget scaffold)? wrap,
}) {
  final list = actions ?? [_share(), _favorite()];
  return VerticalBarPage(
    enabled: enabled,
    back: back,
    actions: list,
    itemBuilder: itemBuilder,
    backBuilder: backBuilder,
    overflowBuilder: overflowBuilder,
    groupDecoration: groupDecoration,
    builder: (context, slots) {
      record?.call(slots);
      final scaffold = _scaffold(slots, list, body: body, drawer: drawer);
      return wrap == null ? scaffold : wrap(scaffold);
    },
  );
}

/// A wrapped page whose content only records the slots.
VerticalBarPage _recordingPage(_Record record, {List<VerticalBarAction>? actions}) => VerticalBarPage(
  actions: actions ?? [_share()],
  builder: (context, slots) {
    record(slots);
    return const Material(child: Center(child: Text('Content')));
  },
);

/// What holds the primary focus after each Tab press: the nearest page part key, or the nearest
/// tooltip message, above the focused node; null for anything else.
Future<List<Object?>> _tabTargets(WidgetTester tester, int presses) async {
  final targets = <Object?>[];
  for (var press = 0; press < presses; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    Object? target;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
      final widget = element.widget;
      if (_pageKeys.contains(widget.key)) {
        target = widget.key;
      } else if (widget is Tooltip) {
        target = widget.message;
      }
      return target == null;
    });
    targets.add(target);
  }
  return targets;
}

typedef _Snapshot = ({List<Rect> rects, String semantics, List<Rect> tabOrder});

/// Pushes [page] in a fresh app for [window] and records what must stay identical.
Future<_Snapshot> _snapshot(WidgetTester tester, DuoWindow window, WidgetBuilder page) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(_app(window, navigatorKey: navigator));
  await _push(tester, navigator, page);
  final rects = [
    for (final key in _pageKeys) tester.getRect(find.byKey(key)),
    for (final element in find.byType(IconButton).evaluate()) globalRect(element),
  ];
  final snapshot = (rects: rects, semantics: semanticsTreeOf(tester), tabOrder: await tabOrderOf(tester, 7));
  await tester.pumpWidget(const SizedBox());
  return snapshot;
}

/// The inner landscape overflow cell after the back control and seven actions.
const Rect _overflowCell = Rect.fromLTRB(879, 548, 927, 596);

/// Menus of the inner landscape column end 8 points left of its inner edge, x 867.
const double _rightMenuEdge = 859;

/// Seven actions that fill the inner landscape column after the back control, then [rest], which
/// must hold at least two actions so that all of them move to the overflow menu.
List<VerticalBarAction> _overflowing(List<VerticalBarAction> rest) => [...numberedActions(7), ...rest];

/// Pushes [page] in a fresh app for [window] and returns the app's Navigator.
Future<GlobalKey<NavigatorState>> _showPage(
  WidgetTester tester,
  WidgetBuilder page, {
  DuoWindow window = innerLandscape,
  ThemeData? theme,
  double? maxTextScale,
}) async {
  useWindow(tester, window);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(_app(window, navigatorKey: navigator, theme: theme, maxTextScale: maxTextScale));
  await _push(tester, navigator, page);
  return navigator;
}

/// Pushes [page] for [window] into a Navigator below a MediaQuery without padding, where menus are
/// kept only 8 points inside the Navigator's edges, so the safe area cannot push them off the column.
/// The view padding keeps the column's inset.
Future<void> _showPageWithoutPadding(WidgetTester tester, DuoWindow window, WidgetBuilder page) async {
  useWindow(tester, window);
  final navigator = GlobalKey<NavigatorState>();
  final inner = GlobalKey<NavigatorState>();
  final home = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
      child: Navigator(
        key: inner,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomePage()),
      ),
    ),
  );
  await tester.pumpWidget(_app(window, navigatorKey: navigator, home: home));
  await _push(tester, inner, page);
}

/// The column of [window].
VerticalBarColumn _columnOf(DuoWindow window) => VerticalBarColumn.resolve(
  region: window.region,
  edge: window.edge,
  osViewPadding: window.padding,
  windowSize: window.size,
)!;

/// An action labelled `More` whose menu holds `Delete`, which adds 'Delete' to [chosen].
VerticalBarAction _more(List<String> chosen) => VerticalBarAction(
  id: 'more',
  icon: const Icon(Icons.more_vert),
  label: 'More',
  menuItems: [VerticalBarMenuItem(label: 'Delete', onSelected: () => chosen.add('Delete'))],
);

/// The menu row labelled [label].
PopupMenuItem<Object?> _menuRow(WidgetTester tester, String label) => tester.widget<PopupMenuItem<Object?>>(
  find
      .ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem<Object?>))
      .first,
);

/// The shown tooltip box with [message].
Rect _tooltipRect(WidgetTester tester, String message) =>
    tester.getRect(find.ancestor(of: find.text(message), matching: find.byType(DecoratedBox)).first);

/// The font size of the text [label] after text scaling; unlike its layout, independent of glyph widths.
double _fontSize(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
}

/// Whether [rect] lies within a window of [size].
bool _inside(Rect rect, Size size) =>
    rect.left >= 0 && rect.top >= 0 && rect.right <= size.width && rect.bottom <= size.height;

/// Long-presses the control with [tooltip] and returns its shown tooltip box, then lets it hide.
Future<Rect> _showTooltip(WidgetTester tester, String tooltip) async {
  await tester.longPress(find.byTooltip(tooltip));
  await tester.pump(const Duration(milliseconds: 300));
  final rect = _tooltipRect(tester, tooltip);
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  return rect;
}

/// Keeps a State to prove that a cell or page part was not recreated.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 40);
}

/// Rebuilds its child builder on request, as an application parent would.
class _Rebuilder extends StatefulWidget {
  const _Rebuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<_Rebuilder> createState() => _RebuilderState();
}

class _RebuilderState extends State<_Rebuilder> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Hosts a nested Navigator with a page of [height] at the window's top-left corner.
class _ShortHost extends StatefulWidget {
  const _ShortHost({
    super.key,
    required this.height,
    required this.page,
    this.bottomViewPadding,
    this.navigatorKey,
  });

  final double height;
  final double? bottomViewPadding;
  final Widget page;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<_ShortHost> createState() => _ShortHostState();
}

class _ShortHostState extends State<_ShortHost> {
  late double height = widget.height;

  void resize(double value) => setState(() => height = value);

  @override
  Widget build(BuildContext context) {
    Widget navigator = Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => widget.page),
    );
    final bottom = widget.bottomViewPadding;
    if (bottom != null) {
      final data = MediaQuery.of(context);
      navigator = MediaQuery(
        data: data.copyWith(
          padding: data.padding.copyWith(bottom: bottom),
          viewPadding: data.viewPadding.copyWith(bottom: bottom),
        ),
        child: navigator,
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: MediaQuery.sizeOf(context).width, height: height, child: navigator),
    );
  }
}

/// Reads the slots from deep inside a page.
class _SlotsReader extends StatelessWidget {
  const _SlotsReader(this.record);

  final _Record record;

  @override
  Widget build(BuildContext context) {
    record.slots = VerticalBarSlots.maybeOf(context);
    return const SizedBox();
  }
}

void main() {
  group('VerticalBarSlots', () {
    const column = VerticalBarColumn(
      edge: HorizontalEdge.right,
      viewSize: Size(951, 669),
      column: Rect.fromLTRB(867, 0, 951, 669),
      items: Rect.fromLTRB(879, 124, 927, 635),
    );

    test('is active with a column', () {
      expect(const VerticalBarSlots().active, isFalse);
      expect(const VerticalBarSlots().backInColumn, isFalse);
      expect(const VerticalBarSlots(column: column).active, isTrue);
      expect(const VerticalBarSlots(column: column, backInColumn: true).backInColumn, isTrue);
    });

    test('compares column and backInColumn', () {
      expect(const VerticalBarSlots(column: column), const VerticalBarSlots(column: column));
      expect(
        const VerticalBarSlots(column: column).hashCode,
        const VerticalBarSlots(column: column).hashCode,
      );
      expect(const VerticalBarSlots(column: column), isNot(const VerticalBarSlots()));
      expect(
        const VerticalBarSlots(column: column),
        isNot(const VerticalBarSlots(column: column, backInColumn: true)),
      );
      expect(const VerticalBarSlots(column: column, backInColumn: true).toString(), contains('backInColumn: true'));
    });

    test('asserts a column when the back control is in it', () {
      expect(() => VerticalBarSlots(backInColumn: _runtime(true)), throwsAssertionError);
    });
  });

  group('VerticalBarBack', () {
    test('has two distinct kinds', () {
      expect(VerticalBarBack.automatic, isNot(VerticalBarBack.none));
      expect(VerticalBarBack.automatic.toString(), 'VerticalBarBack.automatic');
      expect(VerticalBarBack.none.toString(), 'VerticalBarBack.none');
    });
  });

  group('where no column applies, the page lays out, reads, and traverses as without the wrapper', () {
    for (final window in [iPhone17, iPad, android, innerPortrait, mixedRotation, firstFrame, leftWindow]) {
      for (final (name, order) in _bodyOrders) {
        testWidgets('${window.name}$name', (tester) async {
          final semantics = tester.ensureSemantics();
          useWindow(tester, window);
          final record = _Record();
          final body = _Body(buttonOrder: order);
          final wrapped = await _snapshot(tester, window, (_) => _page(record: record, body: body));
          expect(tester.takeException(), isNull);
          expect(record.slots, const VerticalBarSlots());
          final plain = await _snapshot(
            tester,
            window,
            (_) => _scaffold(const VerticalBarSlots(), [_share(), _favorite()], body: body),
          );
          expect(wrapped.rects, plain.rects);
          expect(wrapped.semantics, plain.semantics);
          expect(wrapped.tabOrder, plain.tabOrder);
          semantics.dispose();
        });
      }
    }
  });

  group('inner landscape', () {
    testWidgets('places the back control at x 879-927, y 124-172 and actions from y 184', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(record: record));

      expect(record.slots?.active, isTrue);
      expect(record.slots?.backInColumn, isTrue);
      expect(
        record.slots?.column,
        VerticalBarColumn.resolve(
          region: innerLandscape.region,
          edge: HorizontalEdge.right,
          osViewPadding: innerLandscape.padding,
          windowSize: innerLandscape.size,
        ),
      );
      expect(tester.getRect(find.byTooltip('Back')), _backCell);
      expect(tester.getRect(find.byTooltip('Share')), _firstCell);
      expect(tester.getRect(find.byTooltip('Favorite')), _secondCell);
      expect(find.byType(BackButton), findsNothing, reason: 'the app bar omits its implied back button');
      expect(find.byType(IconButton), findsNWidgets(3), reason: 'the app bar omits its actions');
    });

    testWidgets('places cells in the right Split View window at x 397-445', (tester) async {
      useWindow(tester, rightWindow);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(rightWindow, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(397, 124, 445, 172));
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(397, 184, 445, 232));
    });

    testWidgets('places cells in a left column from the region top (outer landscape)', (tester) async {
      useWindow(tester, _outerLeftStatusBarShown);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(_outerLeftStatusBarShown, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(24, 82, 72, 130));
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(24, 142, 72, 190));
    });

    testWidgets('taps in the gaps and in the empty column reach the page', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final taps = <Offset>[];
      final body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => taps.add(details.globalPosition),
        child: const SizedBox.expand(),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _page(
          body: body,
          groupDecoration: const BoxDecoration(color: Colors.red),
        ),
      );

      const points = [Offset(903, 178), Offset(903, 234), Offset(903, 500), Offset(870, 150), Offset(940, 208)];
      for (final point in points) {
        await tester.tapAt(point);
        await tester.pump();
      }
      expect(taps, points);
    });

    testWidgets('paints groupDecoration behind each group', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      const decoration = BoxDecoration(color: Colors.red);
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(groupDecoration: decoration));
      final groups = find.byWidgetPredicate((widget) => widget is DecoratedBox && widget.decoration == decoration);
      expect(
        [for (final element in groups.evaluate()) globalRect(element)],
        [
          _backCell,
          const Rect.fromLTRB(879, 184, 927, 284),
        ],
      );
    });

    testWidgets('default controls stay 38 points in a 48-point target with a 24-point icon', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final theme = ThemeData(
        platform: TargetPlatform.iOS,
        visualDensity: VisualDensity.compact,
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size.square(64), iconSize: 40, padding: EdgeInsets.zero),
        ),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, theme: theme));
      await _push(tester, navigator, (_) => _page());

      for (final (label, cell) in [('Back', _backCell), ('Share', _firstCell), ('Favorite', _secondCell)]) {
        final control = find.byTooltip(label);
        expect(tester.getRect(find.descendant(of: control, matching: find.byType(IconButton))), cell);
        expect(tester.getRect(find.descendant(of: control, matching: find.byType(Material)).first), button(cell));
        expect(tester.getSize(find.descendant(of: control, matching: find.byType(Icon))), const Size.square(24));
      }
    });

    testWidgets('under Material 2 default controls follow the theme density, a documented limitation', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final theme = ThemeData(useMaterial3: false, platform: TargetPlatform.iOS, visualDensity: VisualDensity.compact);
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, theme: theme));
      await _push(tester, navigator, (_) => _page());

      // IconButton applies a ButtonStyle only under Material 3: the cells stay, the controls shrink.
      for (final (label, cell) in [('Back', _backCell), ('Share', _firstCell), ('Favorite', _secondCell)]) {
        final control = find.descendant(of: find.byTooltip(label), matching: find.byType(IconButton));
        expect(tester.getRect(control), Rect.fromCenter(center: cell.center, width: 40, height: 40), reason: label);
      }
    });

    testWidgets('under Material 2 a toggle shows no selected state in the column, a documented limitation', (
      tester,
    ) async {
      const on = VerticalBarAction(id: 'on', icon: Icon(Icons.star), label: 'On', selected: true, onPressed: _noop);
      const off = VerticalBarAction(id: 'off', icon: Icon(Icons.star), label: 'Off', selected: false, onPressed: _noop);
      Color? iconColor(String label) => tester
          .widget<RichText>(find.descendant(of: find.byTooltip(label), matching: find.byType(RichText)))
          .text
          .style
          ?.color;
      for (final material3 in [true, false]) {
        await _showPage(
          tester,
          (_) => _page(actions: [on, off]),
          theme: ThemeData(useMaterial3: material3, platform: TargetPlatform.iOS),
        );
        final selected = iconColor('On');
        expect(selected, isNotNull);
        if (material3) {
          expect(selected, isNot(iconColor('Off')), reason: 'Material 3 draws the selected state');
        } else {
          // IconButton reads isSelected only under Material 3.
          expect(selected, iconColor('Off'), reason: 'Material 2 draws no selected state, as the docs state');
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('plain Text in the page keeps its own semantics node', (tester) async {
      final semantics = tester.ensureSemantics();
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      expect(tester.getSemantics(find.byKey(_bodyKey)).label, 'Body');
      expect(tester.getSemantics(find.byKey(_noteKey)).label, 'Note');
      semantics.dispose();
    });

    testWidgets('reads and traverses back, actions, title, then the page', (tester) async {
      final semantics = tester.ensureSemantics();
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      // A control above the column's first cell, which reading order alone would visit first.
      final body = Align(
        alignment: Alignment.topLeft,
        child: ElevatedButton(key: _buttonKey, onPressed: () {}, child: const Text('Go')),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(body: body));

      final order = readingOrderOf(tester);
      const expected = ['Back', 'Share', 'Favorite', 'Detail', 'Go'];
      expect(order.where(expected.contains).toList(), expected);

      expect(tester.getRect(find.byKey(_buttonKey)).bottom, lessThan(_backCell.top));
      Rect focusRect(Finder finder) => Focus.of(tester.element(finder)).rect;
      final expectedTabs = [
        for (final label in ['Back', 'Share', 'Favorite'])
          focusRect(find.descendant(of: find.byTooltip(label), matching: find.byType(Icon))),
        focusRect(find.text('Go')),
      ];
      expect(expectedTabs.take(3), [button(_backCell), button(_firstCell), button(_secondCell)]);
      expect(await tabOrderOf(tester, 4), expectedTabs);
      semantics.dispose();
    });

    testWidgets('lexical focus orders in the page do not break Tab', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      // Orders of another type than the column's; the ambient reading order ignores them.
      final body = Column(
        children: [
          for (final name in ['B', 'A'])
            FocusTraversalOrder(
              order: LexicalFocusOrder(name),
              child: TextButton(onPressed: () {}, child: Text(name)),
            ),
        ],
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(body: body));

      final order = await tabOrderOf(tester, 5);
      expect(tester.takeException(), isNull);
      Rect focusRect(Finder finder) => Focus.of(tester.element(finder)).rect;
      expect(order, [
        button(_backCell),
        button(_firstCell),
        button(_secondCell),
        focusRect(find.text('B')),
        focusRect(find.text('A')),
      ]);
    });

    testWidgets('a numeric focus order in the page does not move it before the column', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final body = Align(
        alignment: Alignment.topLeft,
        child: FocusTraversalOrder(
          order: const NumericFocusOrder(-1),
          child: ElevatedButton(key: _buttonKey, onPressed: () {}, child: const Text('Go')),
        ),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(body: body));

      expect(await tabOrderOf(tester, 4), [
        button(_backCell),
        button(_firstCell),
        button(_secondCell),
        Focus.of(tester.element(find.text('Go'))).rect,
      ]);
    });

    for (final (name, order) in _bodyOrders.skip(1)) {
      testWidgets('Tab visits the column, then the page in its own order$name', (tester) async {
        useWindow(tester, innerLandscape);
        final body = _Body(buttonOrder: order);
        var navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
        await _push(tester, navigator, (_) => _page(body: body));
        final wrapped = await _tabTargets(tester, 5);
        expect(tester.takeException(), isNull);
        expect(wrapped, ['Back', 'Share', 'Favorite', _buttonKey, _fieldKey]);

        // Without the wrapper, the app bar holds the same controls and the page has the same order.
        await tester.pumpWidget(const SizedBox());
        navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
        await _push(tester, navigator, (_) => _scaffold(const VerticalBarSlots(), [_share(), _favorite()], body: body));
        expect(await _tabTargets(tester, 5), wrapped);
      });
    }

    // Orders around the whole page, such as an application shell's around its Navigator.
    for (final (name, order) in const [
      ('a lexical', LexicalFocusOrder('x')),
      ('a negative numeric', NumericFocusOrder(-1)),
      ('a zero numeric', NumericFocusOrder(0)),
    ]) {
      for (final ordered in [false, true]) {
        testWidgets(
          '$name focus order around the page${ordered ? ' in an ordered group' : ''} keeps the column first',
          (
            tester,
          ) async {
            useWindow(tester, innerLandscape);
            final navigator = GlobalKey<NavigatorState>();
            Widget page(BuildContext context) {
              final wrapped = FocusTraversalOrder(order: order, child: _page());
              return ordered ? FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: wrapped) : wrapped;
            }

            await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
            await _push(tester, navigator, page);
            expect(await _tabTargets(tester, 5), ['Back', 'Share', 'Favorite', _fieldKey, _buttonKey]);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('text scale 2.0 and a 1.3 cap keep the cells and controls', (tester) async {
      useWindow(tester, innerLandscape);
      Future<List<Rect>> measure({double? maxTextScale}) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, maxTextScale: maxTextScale));
        await _push(tester, navigator, (_) => _page());
        final rects = [
          for (final label in ['Back', 'Share', 'Favorite']) ...[
            tester.getRect(find.byTooltip(label)),
            tester.getRect(find.descendant(of: find.byTooltip(label), matching: find.byType(Material)).first),
            tester.getRect(find.descendant(of: find.byTooltip(label), matching: find.byType(Icon))),
          ],
        ];
        await tester.pumpWidget(const SizedBox());
        return rects;
      }

      final normal = await measure();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      expect(await measure(), normal);
      expect(await measure(maxTextScale: 1.3), normal);
    });

    testWidgets('RTL keeps the right column and its order and mirrors only the back glyph', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      Finder mirrored(String label) => find.descendant(of: find.byTooltip(label), matching: find.byType(Transform));
      expect(mirrored('Back'), findsNothing);

      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, textDirection: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byTooltip('Back')), _backCell);
      expect(tester.getRect(find.byTooltip('Share')), _firstCell);
      expect(tester.getRect(find.byTooltip('Favorite')), _secondCell);
      expect(mirrored('Back'), findsOneWidget);
      expect(mirrored('Share'), findsNothing);
      expect(mirrored('Favorite'), findsNothing);
    });

    testWidgets('a fixed SnackBar keeps its action left of the column at x 867', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      ScaffoldMessenger.of(tester.element(find.byKey(_bodyKey))).showSnackBar(
        SnackBar(
          content: const Text('Saved'),
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.widgetWithText(TextButton, 'Undo')).right, lessThanOrEqualTo(867));
    });

    testWidgets('renders an overflow cell when the actions do not fit', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: numberedActions(10)));
      // Back + 7 + overflow, as UIKit places 10 items.
      for (var n = 0; n < 7; n++) {
        expect(tester.getRect(find.byTooltip('Action $n')), Rect.fromLTWH(879, 184 + 52.0 * n, 48, 48));
      }
      expect(find.byTooltip('Action 7'), findsNothing);
      expect(tester.getRect(find.byTooltip('Show menu')), const Rect.fromLTRB(879, 548, 927, 596));
      expect(find.descendant(of: find.byTooltip('Show menu'), matching: find.byIcon(Icons.more_horiz)), findsOneWidget);
    });

    testWidgets('a pinned action stays in the column after the back control', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final actions = [
        for (var n = 0; n < 10; n++)
          VerticalBarAction(
            id: n,
            icon: const Icon(Icons.circle),
            label: 'Action $n',
            onPressed: _noop,
            pinned: n == 9,
          ),
      ];
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: actions));
      // Back + 7 + overflow, with the pinned last action kept in the 7th action cell.
      for (var n = 0; n < 6; n++) {
        expect(tester.getRect(find.byTooltip('Action $n')), Rect.fromLTWH(879, 184 + 52.0 * n, 48, 48));
      }
      expect(tester.getRect(find.byTooltip('Action 9')), const Rect.fromLTRB(879, 496, 927, 544));
      expect(find.byTooltip('Action 6'), findsNothing);
      expect(find.byTooltip('Action 8'), findsNothing);
      expect(tester.getRect(find.byTooltip('Show menu')), const Rect.fromLTRB(879, 548, 927, 596));
    });
  });

  group('actions and builders', () {
    testWidgets('a standard action is invoked with its cell as the anchor', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final invocations = <VerticalBarInvocation>[];
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _page(
          actions: [
            _share(onPressed: invocations.add),
            _favorite(),
          ],
        ),
      );
      await tester.tap(find.byTooltip('Share'));
      expect(invocations, [const VerticalBarInvocation(anchor: _firstCell, fromOverflowMenu: false)]);
    });

    testWidgets('a disabled action is drawn disabled', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      const disabled = VerticalBarAction(id: 'off', icon: Icon(Icons.block), label: 'Off');
      const emptyMenu = VerticalBarAction(
        id: 'menu',
        icon: Icon(Icons.more_vert),
        label: 'Menu',
        menuItems: [VerticalBarMenuItem(label: 'Delete', onSelected: _noopItem, enabled: false)],
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: [disabled, emptyMenu]));
      for (final label in ['Off', 'Menu']) {
        final button = tester.widget<IconButton>(
          find.descendant(of: find.byTooltip(label), matching: find.byType(IconButton)),
        );
        expect(button.onPressed, isNull, reason: label);
      }
    });

    testWidgets('toggles pass selected to the default control', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      const toggle = VerticalBarAction(
        id: 'fav',
        icon: Icon(Icons.star_border),
        label: 'Favorite',
        selected: true,
        onPressed: _noop,
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: [toggle]));
      final button = tester.widget<IconButton>(
        find.descendant(of: find.byTooltip('Favorite'), matching: find.byType(IconButton)),
      );
      expect(button.isSelected, isTrue);
    });

    testWidgets('itemBuilder replaces standard controls unless it returns null', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final invocations = <VerticalBarInvocation>[];
      final cells = <VerticalBarCell>[];
      Widget? itemBuilder(BuildContext context, VerticalBarAction action, VerticalBarCell cell) {
        if (action.id != 'share') {
          return null;
        }
        cells.add(cell);
        return TextButton(key: const ValueKey('custom-share'), onPressed: cell.invoke, child: const Text('S'));
      }

      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _page(
          actions: [
            _share(onPressed: invocations.add),
            _favorite(),
          ],
          itemBuilder: itemBuilder,
        ),
      );
      expect(cells.last.rect, _firstCell);
      expect(cells.last.edge, HorizontalEdge.right);
      expect(tester.getCenter(find.byKey(const ValueKey('custom-share'))), _firstCell.center);
      expect(find.byTooltip('Share'), findsNothing, reason: 'application controls carry their own tooltips');
      expect(tester.getRect(find.byTooltip('Favorite')), _secondCell);
      await tester.tap(find.byKey(const ValueKey('custom-share')));
      expect(invocations, [const VerticalBarInvocation(anchor: _firstCell, fromOverflowMenu: false)]);
    });

    testWidgets('custom actions use their cellBuilder within the cell', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final invocations = <VerticalBarInvocation>[];
      final custom = VerticalBarAction.custom(
        id: 'translate',
        label: 'Translate',
        onPressed: invocations.add,
        // A control larger than the cell is constrained to it.
        cellBuilder: (context, cell) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cell.invoke,
          child: const SizedBox.square(key: ValueKey('translate'), dimension: 80),
        ),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: [custom]));
      expect(tester.getRect(find.byKey(const ValueKey('translate'))), _firstCell);
      await tester.tap(find.byKey(const ValueKey('translate')));
      expect(invocations, [const VerticalBarInvocation(anchor: _firstCell, fromOverflowMenu: false)]);
    });

    for (final (name, order) in const [('lexical', LexicalFocusOrder('a')), ('numeric', NumericFocusOrder(2))]) {
      testWidgets('a $name focus order in a custom cell keeps the cell in the column order', (tester) async {
        useWindow(tester, innerLandscape);
        final navigator = GlobalKey<NavigatorState>();
        final custom = VerticalBarAction.custom(
          id: 'translate',
          label: 'Translate',
          onPressed: _noop,
          cellBuilder: (context, cell) => FocusTraversalOrder(
            order: order,
            child: IconButton(tooltip: 'Translate', onPressed: cell.invoke, icon: const Icon(Icons.translate)),
          ),
        );
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
        await _push(tester, navigator, (_) => _page(actions: [custom, _share()]));
        expect(await _tabTargets(tester, 4), ['Back', 'Translate', 'Share', _fieldKey]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('VerticalBarSlots.maybeOf reads the page slots deep in the page and null outside', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final page = _Record();
      final deep = _Record();
      final outside = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: _SlotsReader(outside)));
      expect(outside.slots, isNull);
      await _push(tester, navigator, (_) => _page(record: page, body: _SlotsReader(deep)));
      expect(deep.slots, page.slots);
      expect(deep.slots?.active, isTrue);
    });

    testWidgets('VerticalBarSlots.maybeOf deep in the page follows the slots when the region goes away', (
      tester,
    ) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final deep = _Record();
      // One instance, so that only the page's scope can rebuild it.
      final reader = _SlotsReader(deep);
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(body: reader));
      expect(deep.slots?.active, isTrue);

      await tester.pumpWidget(_app(firstFrame, navigatorKey: navigator));
      expect(deep.slots, const VerticalBarSlots());
    });
  });

  group('back', () {
    testWidgets('pops the page', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page());
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(_scaffoldKey), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('respects PopScope(canPop: false)', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final invoked = <bool>[];
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _page(
          wrap: (scaffold) => PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) => invoked.add(didPop),
            child: scaffold,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(invoked, [false]);
      expect(find.byKey(_scaffoldKey), findsOneWidget);
    });

    testWidgets('shows a close control for a fullscreen dialog and pops it', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(), fullscreenDialog: true);
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.getRect(find.byTooltip('Close')), _backCell);
      expect(find.descendant(of: find.byTooltip('Close'), matching: find.byType(CloseButtonIcon)), findsOneWidget);
      expect(find.byType(CloseButton), findsNothing, reason: 'the app bar omits its implied close button');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(_scaffoldKey), findsNothing);
    });

    testWidgets('pops the inner Navigator of a nested page', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final home = Navigator(
        key: inner,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Inner home'))),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
      await _push(tester, inner, (_) => _page());
      expect(tester.getRect(find.byTooltip('Back')), _backCell);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Inner home'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    });

    testWidgets('does not add a Drawer button', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(drawer: const Drawer()));
      expect(tester.state<ScaffoldState>(find.byKey(_scaffoldKey)).hasDrawer, isTrue);
      expect(find.byType(DrawerButton), findsNothing);
      expect(tester.getRect(find.byTooltip('Back')), _backCell);
    });

    testWidgets('uses backBuilder, whose invoke pops', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final cells = <VerticalBarCell>[];
      Widget backBuilder(BuildContext context, VerticalBarCell cell) {
        cells.add(cell);
        return TextButton(key: const ValueKey('up'), onPressed: cell.invoke, child: const Text('Up'));
      }

      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(backBuilder: backBuilder));
      expect(find.byTooltip('Back'), findsNothing);
      expect(cells.last.rect, _backCell);
      expect(tester.getCenter(find.byKey(const ValueKey('up'))), _backCell.center);
      await tester.tap(find.byKey(const ValueKey('up')));
      await tester.pumpAndSettle();
      expect(find.byKey(_scaffoldKey), findsNothing);
    });

    testWidgets('a back invoke called after the page is gone does nothing', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      VoidCallback? invoke;
      // An application control may call invoke after an await, for example a confirmation.
      Widget backBuilder(BuildContext context, VerticalBarCell cell) {
        invoke = cell.invoke;
        return TextButton(onPressed: cell.invoke, child: const Text('Up'));
      }

      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(backBuilder: backBuilder));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_scaffoldKey), findsNothing);

      invoke!();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a back invoke called once a confirmation dialog closes pops the page', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      Widget backBuilder(BuildContext context, VerticalBarCell cell) => TextButton(
        onPressed: () async {
          final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave'))],
            ),
          );
          if (leave ?? false) {
            cell.invoke!();
          }
        },
        child: const Text('Up'),
      );

      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(backBuilder: backBuilder));
      await tester.tap(find.text('Up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byKey(_scaffoldKey), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('VerticalBarBack.none leaves the back control in the app bar', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(back: VerticalBarBack.none, record: record));
      expect(record.slots?.active, isTrue);
      expect(record.slots?.backInColumn, isFalse);
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(879, 124, 927, 172));
    });
  });

  group('the column is not used', () {
    Future<_Record> pushed(WidgetTester tester, Future<void> Function(GlobalKey<NavigatorState>, _Record) show) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await show(navigator, record);
      await tester.pumpAndSettle();
      expect(record.builds, greaterThan(0));
      return record;
    }

    testWidgets('in a dialog route at window size', (tester) async {
      final record = await pushed(tester, (navigator, record) async {
        showGeneralDialog<void>(
          context: navigator.currentContext!,
          pageBuilder: (context, animation, secondaryAnimation) => _recordingPage(record),
        );
      });
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('in a CupertinoSheetRoute', (tester) async {
      final record = await pushed(tester, (navigator, record) async {
        navigator.currentState!.push(
          CupertinoSheetRoute<void>(scrollableBuilder: (_, _) => _recordingPage(record)),
        );
      });
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('in a nested Navigator inside a window-wide bottom sheet', (tester) async {
      final record = await pushed(tester, (navigator, record) async {
        unawaited(
          showModalBottomSheet<void>(
            context: navigator.currentContext!,
            constraints: const BoxConstraints(),
            isScrollControlled: true,
            builder: (_) => SizedBox(
              height: 400,
              child: Navigator(
                key: const ValueKey('sheet'),
                onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _recordingPage(record)),
              ),
            ),
          ),
        );
      });
      expect(record.slots, const VerticalBarSlots());
      expect(tester.getSize(find.byKey(const ValueKey('sheet'))).width, 951, reason: 'only the route check applies');
    });

    testWidgets('in a pane narrower than the window', (tester) async {
      final record = _Record();
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final home = Row(
        children: [
          const SizedBox(width: 351),
          Expanded(
            child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _recordingPage(record))),
          ),
        ],
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('below an ancestor page that uses the column', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final outer = _Record();
      final inner = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => VerticalBarPage(
          actions: [_favorite()],
          builder: (context, slots) {
            outer(slots);
            return Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _recordingPage(inner)),
            );
          },
        ),
      );
      expect(outer.slots?.active, isTrue);
      expect(inner.slots, const VerticalBarSlots());
    });

    testWidgets('below an inactive page that is itself below a page using the column', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final outer = _Record();
      final middle = _Record();
      final inner = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => VerticalBarPage(
          actions: [_favorite()],
          builder: (context, slots) {
            outer(slots);
            return Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => VerticalBarPage(
                  enabled: false,
                  actions: [_share()],
                  builder: (context, slots) {
                    middle(slots);
                    return Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _recordingPage(inner)),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
      expect(outer.slots?.active, isTrue);
      expect(middle.slots, const VerticalBarSlots());
      expect(inner.slots, const VerticalBarSlots());
    });

    testWidgets('when disabled', (tester) async {
      final record = await pushed(tester, (navigator, record) async {
        navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _page(enabled: false, record: record)));
      });
      expect(record.slots, const VerticalBarSlots());
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('when there is nothing to place', (tester) async {
      final record = await pushed(tester, (navigator, record) async {
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => _page(back: VerticalBarBack.none, actions: const [], record: record),
          ),
        );
      });
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('when the page is too short for one cell', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      // 200 - 34 = 166 ends above the bottom of the first cell, 172.
      await tester.pumpWidget(
        _app(
          innerLandscape,
          navigatorKey: navigator,
          home: _ShortHost(height: 200, page: _recordingPage(record, actions: [_share()])),
        ),
      );
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('when the back control and one cell do not fit', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final record = _Record();
      // 200 ends below the back cell, 172, but above the first action cell, 232.
      await tester.pumpWidget(
        _app(
          innerLandscape,
          navigatorKey: navigator,
          home: _ShortHost(height: 200, bottomViewPadding: 0, navigatorKey: inner, page: const HomePage()),
        ),
      );
      await _push(tester, inner, (_) => _page(actions: [_share()], record: record, body: const SizedBox()));
      expect(record.slots, const VerticalBarSlots());
      expect(find.byType(BackButton), findsOneWidget, reason: 'the back control is not moved alone');
    });
  });

  group('transitions and modal routes', () {
    testWidgets('only the current page takes taps in its cells', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      var lowerTaps = 0;
      var upperTaps = 0;
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      navigator.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => _page(actions: [_share(onPressed: (_) => lowerTaps++)]),
        ),
      );
      await tester.pumpAndSettle();
      final upper = VerticalBarAction(
        id: 'edit',
        icon: const Icon(Icons.edit),
        label: 'Edit',
        onPressed: (_) => upperTaps++,
      );
      Future<void> pushUpper() async {
        navigator.currentState!.push(CupertinoPageRoute<void>(builder: (_) => _page(actions: [upper])));
        await tester.pump();
      }

      // The first frame of a push, while the upper page has not moved in yet, and later in the push:
      // the package's IgnorePointer is what these checks pin. The taps cannot pin it, because the incoming
      // route's modal barrier already absorbs them (a framework guarantee, not the package's).
      await pushUpper();
      expect(ignoresPointersAbove(tester, find.byTooltip('Share')), isTrue);
      await tester.tapAt(tester.getCenter(find.byTooltip('Share')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(ignoresPointersAbove(tester, find.byTooltip('Share')), isTrue);
      await tester.tapAt(tester.getCenter(find.byTooltip('Share')));
      await tester.pumpAndSettle();
      expect(lowerTaps, 0);
      // The lower page becomes current as soon as the upper page starts to pop, like its body.

      await tester.tap(find.byTooltip('Edit'));
      expect(upperTaps, 1);

      // The exiting page.
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tester.getCenter(find.byTooltip('Edit')));
      await tester.pumpAndSettle();
      expect(upperTaps, 1);
      expect(ignoresPointersAbove(tester, find.byTooltip('Share')), isFalse);

      // A back swipe in progress.
      await pushUpper();
      await tester.pumpAndSettle();
      final swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(60, 0));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byTooltip('Edit')));
      await tester.pump();
      expect(upperTaps, 1);
      await swipe.moveBy(const Offset(-60, 0));
      await swipe.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit'));
      expect(upperTaps, 2);
    });

    for (final kind in ['back', 'overflow', 'menu items']) {
      testWidgets('a saved $kind invoke does nothing while another page covers the page', (tester) async {
        useWindow(tester, innerLandscape);
        final navigator = GlobalKey<NavigatorState>();
        final chosen = <String>[];
        VoidCallback? invoke;
        // Application controls may keep invoke and call it after an await, for example a confirmation.
        Widget saving(BuildContext context, VerticalBarCell cell) {
          invoke = cell.invoke;
          return TextButton(onPressed: cell.invoke, child: const Text('Saved'));
        }

        final page = switch (kind) {
          'back' => _page(backBuilder: saving),
          'overflow' => _page(actions: numberedActions(10), overflowBuilder: saving),
          _ => _page(
            actions: [_more(chosen)],
            itemBuilder: (context, action, cell) => action.id == 'more' ? saving(context, cell) : null,
          ),
        };
        // What the invoke shows or leaves when it acts on the page.
        final shown = switch (kind) {
          'back' => find.text('Home'),
          'overflow' => find.text('Action 9'),
          _ => find.text('Delete'),
        };
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
        await _push(tester, navigator, (_) => page);
        await _push(tester, navigator, (_) => const Scaffold(body: Text('Upper')));

        invoke!();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Upper'), findsOneWidget, reason: 'the covering page stays');
        expect(shown, findsNothing);

        // Once the page is on top again, the same invoke acts on it.
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        invoke!();
        await tester.pumpAndSettle();
        expect(shown, findsOneWidget);
        expect(chosen, isEmpty);
      });
    }

    testWidgets('a dialog or bottom sheet scrim covers the cells', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      var taps = 0;
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: [_share(onPressed: (_) => taps++)]));

      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(ignoresPointersAbove(tester, find.byTooltip('Share')), isTrue);
      await tester.tapAt(_firstCell.center);
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing, reason: 'the tap reached the scrim');

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byKey(_bodyKey)),
          builder: (_) => const SizedBox(height: 120, child: Text('Sheet')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(_firstCell.center);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing, reason: 'the tap reached the scrim');
      expect(taps, 0);

      await tester.tap(find.byTooltip('Share'));
      expect(taps, 1);
    });

    testWidgets('a bottom sheet scrim in a branch Navigator covers the cells', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      var taps = 0;
      final home = Navigator(
        key: inner,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
      await _push(tester, inner, (_) => _page(actions: [_share(onPressed: (_) => taps++)]));
      expect(tester.getRect(find.byTooltip('Share')), _firstCell);

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byKey(_bodyKey)),
          builder: (_) => const SizedBox(height: 120, child: Text('Sheet')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(inner), matching: find.text('Sheet')), findsOneWidget);
      expect(ignoresPointersAbove(tester, find.byTooltip('Share')), isTrue);
      await tester.tapAt(_firstCell.center);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing, reason: 'the tap reached the scrim');
      expect(taps, 0);

      await tester.tap(find.byTooltip('Share'));
      expect(taps, 1);
    });

    testWidgets('an offstage branch with ticking disabled is neither hittable nor read', (tester) async {
      final semantics = tester.ensureSemantics();
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      var taps = 0;
      final home = Stack(
        children: [
          const Scaffold(body: Center(child: Text('Visible'))),
          Offstage(
            child: TickerMode(
              enabled: false,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => _recordingPage(record, actions: [_share(onPressed: (_) => taps++)]),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
      expect(record.slots?.active, isTrue, reason: 'the offstage page uses the column');
      await tester.tapAt(_backCell.center);
      await tester.pump();
      expect(taps, 0);
      expect(readingOrderOf(tester), isNot(contains('Share')));
      semantics.dispose();
    });
  });

  group('state and rebuilds', () {
    testWidgets('the page keeps its State and focus when the region appears and disappears', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(record: record));
      await tester.enterText(find.byKey(_fieldKey), 'draft');
      final scaffold = tester.state(find.byKey(_scaffoldKey));
      final field = tester.state(find.byType(EditableText));
      final focus = FocusManager.instance.primaryFocus;
      expect(record.slots?.active, isTrue);

      for (final window in [firstFrame, innerLandscape]) {
        await tester.pumpWidget(_app(window, navigatorKey: navigator));
        expect(record.slots?.active, window.region != null);
        expect(tester.state(find.byKey(_scaffoldKey)), same(scaffold));
        expect(tester.state(find.byType(EditableText)), same(field));
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(find.text('draft'), findsOneWidget);
      }
    });

    testWidgets('cells keep their State when the edge swaps', (tester) async {
      useWindow(tester, _outerRightStatusBarShown);
      final navigator = GlobalKey<NavigatorState>();
      Widget itemBuilder(BuildContext context, VerticalBarAction action, VerticalBarCell cell) => const _Probe();
      await tester.pumpWidget(_app(_outerRightStatusBarShown, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: [_share()], itemBuilder: itemBuilder));
      final probe = tester.state(find.byType(_Probe));
      final scaffold = tester.state(find.byKey(_scaffoldKey));
      expect(tester.getCenter(find.byType(_Probe)), const Offset(630, 108));

      useWindow(tester, _outerLeftStatusBarShown);
      await tester.pumpWidget(_app(_outerLeftStatusBarShown, navigatorKey: navigator));
      expect(tester.getCenter(find.byType(_Probe)), const Offset(48, 166));
      expect(tester.state(find.byType(_Probe)), same(probe));
      expect(tester.state(find.byKey(_scaffoldKey)), same(scaffold));
    });

    testWidgets('a fresh action list with the same ids keeps cell State, focus, and a press', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final parent = GlobalKey<_RebuilderState>();
      var taps = 0;
      Widget? itemBuilder(BuildContext context, VerticalBarAction action, VerticalBarCell cell) =>
          action.id == 'probe' ? const _Probe() : null;
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _Rebuilder(
          key: parent,
          // A new list and new actions on every build.
          builder: (_) => _page(
            itemBuilder: itemBuilder,
            actions: [
              _share(onPressed: (_) => taps++),
              VerticalBarAction(id: 'probe', icon: const Icon(Icons.circle), label: 'Probe', onPressed: (_) {}),
            ],
          ),
        ),
      );
      final probe = tester.state(find.byType(_Probe));

      final focusNode = Focus.of(tester.element(find.byIcon(Icons.share)))..requestFocus();
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      final press = await tester.startGesture(_firstCell.center);
      await tester.pump(const Duration(milliseconds: 10));
      parent.currentState!.rebuild();
      await tester.pump();
      await press.up();
      await tester.pump();

      expect(taps, 1, reason: 'the press survived the rebuild');
      expect(tester.state(find.byType(_Probe)), same(probe));
      expect(Focus.of(tester.element(find.byIcon(Icons.share))), same(focusNode));
      expect(focusNode.hasPrimaryFocus, isTrue);
    });

    testWidgets('cells keep their State when actions are inserted before them', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final parent = GlobalKey<_RebuilderState>();
      var inserted = 0;
      Widget? itemBuilder(BuildContext context, VerticalBarAction action, VerticalBarCell cell) =>
          action.id == 'probe' ? const _Probe() : null;
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _Rebuilder(
          key: parent,
          builder: (_) => _page(
            itemBuilder: itemBuilder,
            actions: [
              ...numberedActions(inserted),
              const VerticalBarAction(id: 'probe', icon: Icon(Icons.circle), label: 'Probe', onPressed: _noop),
            ],
          ),
        ),
      );
      final probe = tester.state(find.byType(_Probe));
      expect(tester.getCenter(find.byType(_Probe)), _firstCell.center);

      inserted = 2;
      parent.currentState!.rebuild();
      await tester.pump();
      expect(tester.getCenter(find.byType(_Probe)), const Offset(903, 312));
      expect(tester.state(find.byType(_Probe)), same(probe));
    });

    testWidgets('the builder is not called again when only the page height changes', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final host = GlobalKey<_ShortHostState>();
      final record = _Record();
      Widget app(DuoWindow window) => _app(
        window,
        navigatorKey: navigator,
        home: _ShortHost(key: host, height: 669, page: _recordingPage(record)),
      );
      await tester.pumpWidget(app(innerLandscape));
      expect(record.slots?.active, isTrue);
      final builds = record.builds;

      for (final height in [660.0, 640.0, 605.0, 669.0]) {
        host.currentState!.resize(height);
        await tester.pump();
      }
      expect(record.builds, builds);

      await tester.pumpWidget(app(firstFrame));
      expect(record.builds, builds + 1, reason: 'the slots changed');
      expect(record.slots, const VerticalBarSlots());
    });

    testWidgets('a keyboard neither rebuilds the page nor moves the cells', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(record: record, actions: numberedActions(8)));
      final cells = [for (var n = 0; n < 8; n++) tester.getRect(find.byTooltip('Action $n'))];
      final builds = record.builds;

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(record.builds, builds);
      expect([for (var n = 0; n < 8; n++) tester.getRect(find.byTooltip('Action $n'))], cells);
    });

    testWidgets('groups stop at the bottom of a shrunken page', (tester) async {
      useWindow(tester, innerLandscape);
      for (final (bottom, shown, overflow) in [
        (0.0, 9, false),
        (34.0, 7, true),
      ]) {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          _app(
            innerLandscape,
            navigatorKey: navigator,
            home: _ShortHost(
              height: 605,
              bottomViewPadding: bottom,
              page: _page(actions: numberedActions(9)),
            ),
          ),
        );
        final limit = 605 - bottom;
        for (var n = 0; n < 9; n++) {
          final cell = find.byTooltip('Action $n');
          if (n < shown) {
            final rect = tester.getRect(cell);
            expect(rect, Rect.fromLTWH(879, 124 + 52.0 * n, 48, 48));
            expect(rect.bottom, lessThanOrEqualTo(limit));
          } else {
            expect(cell, findsNothing);
          }
        }
        expect(find.byTooltip('Show menu'), overflow ? findsOneWidget : findsNothing);
        if (overflow) {
          expect(tester.getRect(find.byTooltip('Show menu')), const Rect.fromLTRB(879, 488, 927, 536));
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a page shorter than the window places fewer cells than the window would allow', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _app(
          innerLandscape,
          navigatorKey: navigator,
          home: _ShortHost(height: 560, bottomViewPadding: 0, page: _page(actions: numberedActions(9))),
        ),
      );
      // 9 cells would end at 588, below 560: 7 actions and the overflow cell end at 536.
      expect(tester.getRect(find.byTooltip('Show menu')), const Rect.fromLTRB(879, 488, 927, 536));
    });

    testWidgets('an inner page takes the column when the outer page stops using it', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final parent = GlobalKey<_RebuilderState>();
      final inner = _Record();
      var outerEnabled = true;
      // One Navigator and one inner page, so that only the outer page's scope can rebuild the inner page.
      final innerPage = _recordingPage(inner);
      final nested = Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => innerPage));
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(
        tester,
        navigator,
        (_) => _Rebuilder(
          key: parent,
          builder: (_) => VerticalBarPage(
            enabled: outerEnabled,
            actions: [_favorite()],
            builder: (context, slots) => nested,
          ),
        ),
      );
      expect(inner.slots, const VerticalBarSlots());
      expect(find.byTooltip('Favorite'), findsOneWidget);

      outerEnabled = false;
      parent.currentState!.rebuild();
      await tester.pump();
      expect(inner.slots?.active, isTrue);
      expect(find.byTooltip('Favorite'), findsNothing);
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(879, 124, 927, 172));
    });

    testWidgets('the column keeps one traversal policy across rebuilds', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final parent = GlobalKey<_RebuilderState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _Rebuilder(key: parent, builder: (_) => _page()));
      // The policies of the groups around a cell, from the nearest out: the column layer's, then the one
      // around both layers.
      List<FocusTraversalPolicy> policies() => [
        for (final group in tester.widgetList<FocusTraversalGroup>(
          find.ancestor(of: find.byTooltip('Share'), matching: find.byType(FocusTraversalGroup)),
        ))
          group.policy,
      ];
      // The Navigator's group uses the app's policy, which the page sees around it.
      final ambient = FocusTraversalGroup.maybeOf(navigator.currentContext!);
      expect(ambient, isA<ReadingOrderTraversalPolicy>());
      final previous = policies();
      expect(previous[0], same(ambient), reason: 'the column layer sorts its cells as the page would');
      expect(previous[1], isNot(same(ambient)), reason: 'the kit puts the column first');

      parent.currentState!.rebuild();
      await tester.pump();
      expect(policies()[1], same(previous[1]), reason: 'traversal history lives in the policy');
    });

    testWidgets('the cells form one semantics container, read before the page', (tester) async {
      final semantics = tester.ensureSemantics();
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
      await _push(tester, navigator, (_) => _page(actions: numberedActions(7)));
      final labels = ['Back', for (var n = 0; n < 7; n++) 'Action $n'];
      final cells = [
        for (final node in semanticsNodesFrom(semanticsRootOf(tester)))
          if (labels.contains(node.tooltip)) node,
      ];
      expect([for (final node in cells) node.tooltip], labels);
      final container = cells.first.parent!;
      expect(semanticsChildren(container), cells, reason: 'the cells, and nothing else');
      expect(isSemanticsContainer(tester, container), isTrue);

      // The page's container follows the cells' one.
      final siblings = semanticsChildren(container.parent!);
      expect(siblings.first, same(container));
      expect(siblings, hasLength(2));
      expect(isSemanticsContainer(tester, siblings.last), isTrue);
      expect(textsFrom(siblings.last), containsAll(<String>['Detail', 'Body', 'Note', 'Go']));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    for (final width in [951.0, 867.0]) {
      testWidgets('a root dialog does not rebuild the routes of a Navigator ${width.toInt()} wide', (tester) async {
        useWindow(tester, innerLandscape);
        final navigator = GlobalKey<NavigatorState>();
        final inner = GlobalKey<NavigatorState>();
        var homeBuilds = 0;
        var pageBuilds = 0;
        final home = Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: innerLandscape.size.height,
            child: Navigator(
              key: inner,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) {
                  homeBuilds++;
                  return const HomePage();
                },
              ),
            ),
          ),
        );
        final record = _Record();
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
        await _push(tester, inner, (_) {
          pageBuilds++;
          return _page(record: record);
        });
        expect(record.slots?.active, width == 951, reason: 'a branch page does not use the column');
        final builds = (home: homeBuilds, page: pageBuilds);

        unawaited(
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) => const AlertDialog(content: Text('Dialog')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Dialog'), findsNothing);
        expect((home: homeBuilds, page: pageBuilds), builds);
      });
    }
  });

  group('overflow menu', () {
    testWidgets('the default overflow control opens the overflowed actions in their order', (tester) async {
      final navigator = await _showPage(tester, (_) => _page(actions: numberedActions(10)));
      final overflow = find.byTooltip(MaterialLocalizations.of(navigator.currentContext!).showMenuTooltip);
      expect(tester.getRect(overflow), _overflowCell);
      expect(find.descendant(of: overflow, matching: find.byIcon(Icons.more_horiz)), findsOneWidget);
      expect(find.text('Action 7'), findsNothing);

      await tester.tap(overflow);
      await tester.pumpAndSettle();
      final rows = [
        for (final n in [7, 8, 9]) tester.getRect(find.text('Action $n')),
      ];
      expect(rows[0].top, lessThan(rows[1].top));
      expect(rows[1].top, lessThan(rows[2].top));
      expect(find.text('Action 6'), findsNothing, reason: 'actions shown in the column stay out of the menu');
    });

    testWidgets('a row invokes its action once with the overflow cell as the anchor', (tester) async {
      final invocations = <(int, VerticalBarInvocation)>[];
      final actions = [
        for (var n = 0; n < 10; n++)
          VerticalBarAction(
            id: n,
            icon: const Icon(Icons.circle),
            label: 'Action $n',
            onPressed: (invocation) => invocations.add((n, invocation)),
          ),
      ];
      await _showPage(tester, (_) => _page(actions: actions));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action 8'));
      await tester.pumpAndSettle();
      expect(invocations, [(8, const VerticalBarInvocation(anchor: _overflowCell, fromOverflowMenu: true))]);
      expect(find.text('Action 7'), findsNothing, reason: 'the menu closed');
    });

    testWidgets('overflowBuilder draws the overflow cell and its invoke opens the menu', (tester) async {
      final cells = <VerticalBarCell>[];
      Widget overflowBuilder(BuildContext context, VerticalBarCell cell) {
        cells.add(cell);
        return TextButton(key: const ValueKey('more'), onPressed: cell.invoke, child: const Text('M'));
      }

      await _showPage(tester, (_) => _page(actions: numberedActions(10), overflowBuilder: overflowBuilder));
      expect(find.byTooltip('Show menu'), findsNothing, reason: 'application controls carry their own tooltips');
      expect(cells.last.rect, _overflowCell);
      expect(cells.last.edge, HorizontalEdge.right);
      expect(tester.getCenter(find.byKey(const ValueKey('more'))), _overflowCell.center);

      await tester.tap(find.byKey(const ValueKey('more')));
      await tester.pumpAndSettle();
      expect(find.text('Action 9'), findsOneWidget);
      expect(menuRect(tester, 'Action 9').right, _rightMenuEdge);
    });

    testWidgets('a choice made after the column goes away is delivered once with the anchor from when it opened', (
      tester,
    ) async {
      final invocations = <VerticalBarInvocation>[];
      final actions = _overflowing([_share(onPressed: invocations.add), _favorite()]);
      final navigator = await _showPage(tester, (_) => _page(actions: actions));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();

      // A rotation to the inner portrait display, where no column applies.
      useWindow(tester, innerPortrait);
      await tester.pumpWidget(_app(innerPortrait, navigatorKey: navigator));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show menu'), findsNothing, reason: 'the overflow cell is gone');
      expect(find.text('Share'), findsOneWidget, reason: 'the menu stays open');

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(invocations, [const VerticalBarInvocation(anchor: _overflowCell, fromOverflowMenu: true)]);
    });

    testWidgets('a choice goes to the actions as they were when the menu opened', (tester) async {
      final invocations = <VerticalBarInvocation>[];
      final parent = GlobalKey<_RebuilderState>();
      var actions = _overflowing([_share(onPressed: invocations.add), _favorite()]);
      await _showPage(
        tester,
        (_) => _Rebuilder(
          key: parent,
          builder: (_) => _page(actions: actions),
        ),
      );
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();

      // The application drops Share while the menu is open; the rest fits in the column.
      actions = [...numberedActions(7), _favorite()];
      parent.currentState!.rebuild();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show menu'), findsNothing, reason: 'the overflow cell is gone');
      expect(find.text('Share'), findsOneWidget, reason: 'the menu stays open');

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(invocations, [const VerticalBarInvocation(anchor: _overflowCell, fromOverflowMenu: true)]);
    });

    for (final (window, edge) in [(innerLandscape, _rightMenuEdge), (_outerLeftStatusBarShown, 92.0)]) {
      testWidgets('the menu opens 8 points beside the column without overlapping it: ${window.name}', (tester) async {
        await _showPage(tester, (_) => _page(actions: numberedActions(10)), window: window);
        final column = _columnOf(window);
        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();
        final menu = menuRect(tester, 'Action 9');
        expect(menu.overlaps(column.column), isFalse);
        switch (column.edge) {
          case HorizontalEdge.right:
            expect(menu.right, edge);
            expect(column.column.left - 8, edge);
          case HorizontalEdge.left:
            expect(menu.left, edge);
            expect(column.column.right + 8, edge);
        }
      });
    }

    for (final (window, edge) in [(innerLandscape, _rightMenuEdge), (_outerLeftStatusBarShown, 92.0)]) {
      testWidgets('the menu keeps its gap where the safe area does not push it off the column: ${window.name}', (
        tester,
      ) async {
        await _showPageWithoutPadding(tester, window, (_) => _page(actions: numberedActions(10)));
        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();
        final menu = menuRect(tester, 'Action 9');
        switch (window.edge!) {
          case HorizontalEdge.right:
            expect(menu.right, edge);
          case HorizontalEdge.left:
            expect(menu.left, edge);
        }
      });
    }

    testWidgets('the second menu keeps the gap where the safe area does not push it off the column', (tester) async {
      await _showPageWithoutPadding(
        tester,
        innerLandscape,
        (_) => _page(actions: _overflowing([_share(), _more([])])),
      );
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(menuRect(tester, 'Delete').right, _rightMenuEdge);
    });

    testWidgets('a page in a nested Navigator opens its menu in that Navigator', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final home = Navigator(
        key: inner,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
      await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator, home: home));
      await _push(tester, inner, (_) => _page(actions: numberedActions(10)));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(inner), matching: find.text('Action 9')), findsOneWidget);
      expect(menuRect(tester, 'Action 9').right, _rightMenuEdge);
    });

    testWidgets('disabled actions are disabled rows; custom actions use their label, icon, and onPressed', (
      tester,
    ) async {
      final invocations = <VerticalBarInvocation>[];
      Widget cellBuilder(BuildContext context, VerticalBarCell cell) => const SizedBox();
      final actions = _overflowing([
        const VerticalBarAction(id: 'off', icon: Icon(Icons.block), label: 'Off'),
        VerticalBarAction.custom(
          id: 'translate',
          label: 'Translate',
          onPressed: invocations.add,
          cellBuilder: cellBuilder,
        ),
        VerticalBarAction.custom(
          id: 'pin',
          label: 'Pin',
          icon: const Icon(Icons.push_pin),
          onPressed: invocations.add,
          cellBuilder: cellBuilder,
        ),
      ]);
      await _showPage(tester, (_) => _page(actions: actions));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();

      expect(_menuRow(tester, 'Off').enabled, isFalse);
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget, reason: 'a disabled row keeps the menu open');

      expect(_menuRow(tester, 'Translate').enabled, isTrue);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(
        tester.getRect(find.text('Translate')).left,
        tester.getRect(find.text('Pin')).left,
        reason: 'a row without an icon keeps its label aligned',
      );
      await tester.tap(find.text('Translate'));
      await tester.pumpAndSettle();
      expect(invocations, [const VerticalBarInvocation(anchor: _overflowCell, fromOverflowMenu: true)]);
    });

    testWidgets('toggle rows are checked menu items', (tester) async {
      final actions = _overflowing(const [
        VerticalBarAction(id: 'fav', icon: Icon(Icons.star), label: 'Favorite', selected: true, onPressed: _noop),
        VerticalBarAction(id: 'mute', icon: Icon(Icons.volume_off), label: 'Mute', selected: false, onPressed: _noop),
        VerticalBarAction(id: 'copy', icon: Icon(Icons.copy), label: 'Copy', onPressed: _noop),
      ]);
      await _showPage(tester, (_) => _page(actions: actions));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(
        _menuRow(tester, 'Favorite'),
        isA<CheckedPopupMenuItem<Object?>>().having((item) => item.checked, 'checked', isTrue),
      );
      expect(
        _menuRow(tester, 'Mute'),
        isA<CheckedPopupMenuItem<Object?>>().having((item) => item.checked, 'checked', isFalse),
      );
      expect(_menuRow(tester, 'Copy'), isNot(isA<CheckedPopupMenuItem<Object?>>()));
      expect(find.byIcon(Icons.copy), findsOneWidget);
      // The check mark takes the icon's column.
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.volume_off), findsNothing);
    });

    testWidgets('an overflowed action with menu items opens its menu at the same anchor once the first has closed', (
      tester,
    ) async {
      final chosen = <String>[];
      await _showPage(tester, (_) => _page(actions: _overflowing([_share(), _more(chosen)])));
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(menuRect(tester, 'More').right, _rightMenuEdge);

      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('More'), findsOneWidget, reason: 'the first menu is still closing');
      expect(find.text('Delete'), findsNothing, reason: 'the second menu waits for the first to close');
      await tester.pumpAndSettle();
      expect(find.text('More'), findsNothing, reason: 'the first menu closed');
      expect(find.text('Share'), findsNothing);
      final menu = menuRect(tester, 'Delete');
      expect(menu.right, _rightMenuEdge);
      // Short enough not to be moved up to stay inside the window: the overflow cell's top.
      expect(menu.top, _overflowCell.top);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chosen, ['Delete']);
      expect(find.text('Delete'), findsNothing);
    });

    for (final how in ['popped', 'removed']) {
      testWidgets('a page $how while the overflow menu closes opens no second menu', (tester) async {
        useWindow(tester, innerLandscape);
        final navigator = GlobalKey<NavigatorState>();
        final chosen = <String>[];
        final route = MaterialPageRoute<void>(
          builder: (_) => _page(actions: _overflowing([_share(), _more(chosen)])),
        );
        await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
        navigator.currentState!.push(route);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('More'));
        await tester.pump();
        switch (how) {
          case 'popped':
            navigator.currentState!.pop();
          case 'removed':
            navigator.currentState!.removeRoute(route);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(_scaffoldKey), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(chosen, isEmpty);
      });
    }
  });

  group('menu items', () {
    VerticalBarAction more(List<String> chosen, {bool archiveEnabled = true}) => VerticalBarAction(
      id: 'more',
      icon: const Icon(Icons.more_vert),
      label: 'More',
      menuItems: [
        VerticalBarMenuItem(
          label: 'Archive',
          icon: const Icon(Icons.archive),
          enabled: archiveEnabled,
          onSelected: () => chosen.add('Archive'),
        ),
        VerticalBarMenuItem(
          label: 'Delete',
          icon: const Icon(Icons.delete),
          destructive: true,
          onSelected: () => chosen.add('Delete'),
        ),
      ],
    );

    testWidgets('an action with menu items opens its menu from its cell', (tester) async {
      final chosen = <String>[];
      await _showPage(tester, (_) => _page(actions: [_share(), more(chosen)]));
      expect(tester.getRect(find.byTooltip('More')), _secondCell);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      final menu = menuRect(tester, 'Archive');
      expect(menu.right, _rightMenuEdge);
      expect(menu.top, _secondCell.top);
      expect(find.byIcon(Icons.archive), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chosen, ['Delete']);
      expect(find.text('Archive'), findsNothing, reason: 'the menu closed');
    });

    testWidgets('disabled menu items are disabled rows', (tester) async {
      final chosen = <String>[];
      await _showPage(tester, (_) => _page(actions: [more(chosen, archiveEnabled: false)]));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(_menuRow(tester, 'Archive').enabled, isFalse);
      expect(_menuRow(tester, 'Delete').enabled, isTrue);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
      expect(find.text('Archive'), findsOneWidget, reason: 'a disabled row keeps the menu open');
    });

    testWidgets('destructive items use the theme error color', (tester) async {
      await _showPage(tester, (_) => _page(actions: [more([])]));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      final error = Theme.of(tester.element(find.text('Delete'))).colorScheme.error;
      Color? textColor(String label) => tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;
      Color? iconColor(IconData icon) => IconTheme.of(tester.element(find.byIcon(icon))).color;
      expect(textColor('Delete'), error);
      expect(iconColor(Icons.delete), error);
      expect(textColor('Archive'), isNot(error));
      expect(iconColor(Icons.archive), isNot(error));
    });

    for (final (window, edge) in [(innerLandscape, _rightMenuEdge), (_outerLeftStatusBarShown, 92.0)]) {
      testWidgets('the menu opens 8 points beside the column where the safe area does not push it: ${window.name}', (
        tester,
      ) async {
        await _showPageWithoutPadding(tester, window, (_) => _page(actions: [_share(), _more([])]));
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        final menu = menuRect(tester, 'Delete');
        expect(menu.overlaps(_columnOf(window).column), isFalse);
        switch (window.edge!) {
          case HorizontalEdge.right:
            expect(menu.right, edge);
          case HorizontalEdge.left:
            expect(menu.left, edge);
        }
      });
    }

    testWidgets('a choice goes to the items as they were when the menu opened, after the cell goes away', (
      tester,
    ) async {
      final chosen = <String>[];
      final parent = GlobalKey<_RebuilderState>();
      final items = [
        VerticalBarMenuItem(label: 'Archive', onSelected: () => chosen.add('Archive')),
        VerticalBarMenuItem(label: 'Delete', onSelected: () => chosen.add('Delete')),
      ];
      var actions = [
        _share(),
        VerticalBarAction(id: 'more', icon: const Icon(Icons.more_vert), label: 'More', menuItems: items),
      ];
      await _showPage(
        tester,
        (_) => _Rebuilder(
          key: parent,
          builder: (_) => _page(actions: actions),
        ),
      );
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      // The application changes the items in place and drops the action while the menu is open.
      items.removeAt(0);
      actions = [_share()];
      parent.currentState!.rebuild();
      await tester.pumpAndSettle();
      expect(find.byTooltip('More'), findsNothing, reason: 'the cell is gone');
      expect(find.text('Archive'), findsOneWidget, reason: 'the menu stays open');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(chosen, ['Delete']);
    });

    testWidgets('labels start where icons would in a menu without icons or check marks', (tester) async {
      VerticalBarMenuItem item(String label, {Widget? icon}) =>
          VerticalBarMenuItem(label: label, icon: icon, onSelected: _noopItem);
      Widget cellBuilder(BuildContext context, VerticalBarCell cell) => const SizedBox();
      final actions = [
        VerticalBarAction(
          id: 'sort',
          icon: const Icon(Icons.sort),
          label: 'Sort',
          menuItems: [item('Newest'), item('Oldest')],
        ),
        VerticalBarAction(
          id: 'more',
          icon: const Icon(Icons.more_vert),
          label: 'More',
          menuItems: [
            item('Archive', icon: const Icon(Icons.archive)),
            item('Delete'),
          ],
        ),
        ...numberedActions(5),
        // In the overflow menu, without icons.
        VerticalBarAction.custom(id: 'translate', label: 'Translate', onPressed: _noop, cellBuilder: cellBuilder),
        VerticalBarAction.custom(id: 'read', label: 'Read aloud', onPressed: _noop, cellBuilder: cellBuilder),
      ];
      await _showPage(tester, (_) => _page(actions: actions));

      // Opens the menu of the control with `tooltip` and returns how far into the menu holding `row`
      // each of `content` starts.
      Future<List<double>> starts(String tooltip, String row, List<Finder> content) async {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        final menu = menuRect(tester, row);
        final starts = [for (final finder in content) tester.getRect(finder).left - menu.left];
        await tester.tapAt(const Offset(16, 400));
        await tester.pumpAndSettle();
        expect(find.text(row), findsNothing, reason: 'the menu closed');
        return starts;
      }

      final [icon, archive, delete] = await starts('More', 'Archive', [
        find.byIcon(Icons.archive),
        find.text('Archive'),
        find.text('Delete'),
      ]);
      expect(delete, archive, reason: 'a row without an icon keeps its label aligned with the others');
      expect(icon, lessThan(archive));
      expect(await starts('Sort', 'Newest', [find.text('Newest')]), [icon]);
      expect(await starts('Show menu', 'Translate', [find.text('Translate')]), [icon]);
    });
  });

  group('a page that goes away while its menu is open', () {
    for (final kind in ['overflow', 'action']) {
      for (final how in ['popped', 'removed', 'replaced']) {
        testWidgets('$how with its $kind menu open runs no callback', (tester) async {
          useWindow(tester, innerLandscape);
          final navigator = GlobalKey<NavigatorState>();
          final calls = <String>[];
          final share = _share(onPressed: (_) => calls.add('Share'));
          final more = VerticalBarAction(
            id: 'more',
            icon: const Icon(Icons.more_vert),
            label: 'More',
            menuItems: [VerticalBarMenuItem(label: 'Delete', onSelected: () => calls.add('Delete'))],
          );
          final overflow = kind == 'overflow';
          final actions = overflow ? _overflowing([share, more]) : [share, more];
          final route = MaterialPageRoute<void>(builder: (_) => _page(actions: actions));
          await tester.pumpWidget(_app(innerLandscape, navigatorKey: navigator));
          navigator.currentState!.push(route);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(overflow ? 'Show menu' : 'More'));
          await tester.pumpAndSettle();
          final row = overflow ? 'Share' : 'Delete';
          expect(find.text(row), findsOneWidget);

          switch (how) {
            case 'popped':
              navigator.currentState!.popUntil((route) => route.isFirst);
              await tester.pumpAndSettle();
              expect(find.text(row), findsNothing, reason: 'the menu closed with the page');
            case 'removed':
              navigator.currentState!.removeRoute(route);
              await tester.pumpAndSettle();
              await tester.tap(find.text(row));
              await tester.pumpAndSettle();
            case 'replaced':
              navigator.currentState!.replace(
                oldRoute: route,
                newRoute: MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Replacement'))),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text(row));
              await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(calls, isEmpty);
          expect(find.byKey(_scaffoldKey), findsNothing);
          expect(find.text(row), findsNothing);
        });
      }
    }
  });

  group('tooltips', () {
    for (final (window, cells) in [
      (innerLandscape, [('Back', _backCell), ('Action 0', _firstCell), ('Show menu', _overflowCell)]),
      (
        _outerLeftStatusBarShown,
        [
          ('Back', const Rect.fromLTRB(24, 82, 72, 130)),
          ('Action 0', const Rect.fromLTRB(24, 142, 72, 190)),
          ('Show menu', const Rect.fromLTRB(24, 350, 72, 398)),
        ],
      ),
    ]) {
      testWidgets('default controls show tooltips 8 points beside the cell on the inner side: ${window.name}', (
        tester,
      ) async {
        await _showPage(tester, (_) => _page(actions: numberedActions(10)), window: window);
        for (final (label, cell) in cells) {
          expect(tester.getRect(find.byTooltip(label)), cell, reason: label);
          final tooltip = await _showTooltip(tester, label);
          switch (window.edge!) {
            case HorizontalEdge.right:
              expect(tooltip.right, cell.left - 8, reason: label);
            case HorizontalEdge.left:
              expect(tooltip.left, cell.right + 8, reason: label);
          }
          expect(tooltip.center.dy, moreOrLessEquals(cell.center.dy), reason: label);
          expect(_inside(tooltip, window.size), isTrue, reason: label);
          expect(tooltip.height, 32, reason: "$label: Tooltip's default minimum height on iOS");
        }
      });
    }

    // The plain Tooltip's height is the expected one as well, so that a change to Flutter's defaults
    // shows up here and not only in the package's tooltips.
    for (final (name, theme, height) in [
      ('iOS', ThemeData(platform: TargetPlatform.iOS), 32.0),
      (
        // The default desktop text is taller than the desktop minimum height.
        'macOS, small text',
        ThemeData(
          platform: TargetPlatform.macOS,
          tooltipTheme: const TooltipThemeData(textStyle: TextStyle(fontSize: 10, height: 1)),
        ),
        24.0,
      ),
      (
        'deprecated theme height',
        // ignore: deprecated_member_use
        ThemeData(platform: TargetPlatform.iOS, tooltipTheme: const TooltipThemeData(height: 48)),
        48.0,
      ),
      (
        'theme constraints',
        ThemeData(
          platform: TargetPlatform.iOS,
          tooltipTheme: const TooltipThemeData(constraints: BoxConstraints(minHeight: 40)),
        ),
        40.0,
      ),
    ]) {
      testWidgets("default tooltips are as high as a plain Tooltip's: $name", (tester) async {
        const plain = 'Plain';
        await _showPage(
          tester,
          (_) => _page(
            actions: numberedActions(10),
            body: const Center(
              child: Tooltip(message: plain, child: SizedBox.square(dimension: 48)),
            ),
          ),
          theme: theme,
        );
        expect((await _showTooltip(tester, plain)).height, height, reason: plain);
        for (final label in ['Back', 'Action 0', 'Show menu']) {
          expect((await _showTooltip(tester, label)).height, height, reason: label);
        }
      });
    }

    for (final (name, theme) in [
      ('iOS', ThemeData(platform: TargetPlatform.iOS)),
      (
        // Small text, so that the desktop minimum height applies.
        'macOS, small text',
        ThemeData(
          platform: TargetPlatform.macOS,
          tooltipTheme: const TooltipThemeData(textStyle: TextStyle(fontSize: 10, height: 1)),
        ),
      ),
    ]) {
      testWidgets('an application control with cell.tooltipConstraints shows the default tooltip box: $name', (
        tester,
      ) async {
        final long = List.filled(40, 'Long').join(' ');
        final actions = [
          for (final label in ['Short', long])
            VerticalBarAction(id: label, icon: const Icon(Icons.info), label: label, onPressed: _noop),
        ];
        Future<List<Rect>> tooltips({VerticalBarItemBuilder? itemBuilder}) async {
          await _showPage(
            tester,
            (_) => _page(actions: actions, itemBuilder: itemBuilder),
            theme: theme,
          );
          return [for (final action in actions) await _showTooltip(tester, action.label)];
        }

        final defaults = await tooltips();
        final custom = await tooltips(
          itemBuilder: (context, action, cell) => Tooltip(
            message: action.label,
            positionDelegate: cell.tooltipPosition,
            constraints: cell.tooltipConstraints(context),
            child: IconButton(key: ValueKey(action.id), onPressed: cell.invoke, icon: action.icon!),
          ),
        );
        for (final action in actions) {
          expect(find.byKey(ValueKey(action.id)), findsOneWidget, reason: 'the application control is shown');
        }
        expect(custom, defaults);
      });
    }

    for (final window in [innerLandscape, _outerLeftStatusBarShown]) {
      testWidgets('a long tooltip wraps on the inner side, inside the overlay: ${window.name}', (tester) async {
        final label = List.filled(40, 'Long').join(' ');
        final long = VerticalBarAction(id: 'long', icon: const Icon(Icons.info), label: label, onPressed: _noop);
        await _showPage(tester, (_) => _page(actions: [long]), window: window);
        final cell = tester.getRect(find.byTooltip(label));
        final tooltip = await _showTooltip(tester, label);
        expect(_inside(tooltip, window.size), isTrue);
        switch (window.edge!) {
          case HorizontalEdge.right:
            expect(tooltip.right, lessThanOrEqualTo(cell.left - 8));
          case HorizontalEdge.left:
            expect(tooltip.left, greaterThanOrEqualTo(cell.right + 8));
        }
      });
    }

    testWidgets('text scale 2.0 and a 1.3 cap enlarge tooltip and menu text but keep the cells', (tester) async {
      Future<({List<Rect> cells, double tooltip, double menu})> measure({double? maxTextScale}) async {
        await _showPage(tester, (_) => _page(actions: numberedActions(10)), maxTextScale: maxTextScale);
        final cells = [
          for (final label in ['Back', 'Action 0', 'Show menu']) tester.getRect(find.byTooltip(label)),
        ];
        await tester.longPress(find.byTooltip('Action 0'));
        await tester.pump(const Duration(milliseconds: 300));
        final tooltip = _fontSize(tester, 'Action 0');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();
        final menu = _fontSize(tester, 'Action 7');
        await tester.pumpWidget(const SizedBox());
        return (cells: cells, tooltip: tooltip, menu: menu);
      }

      final normal = await measure();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final large = await measure();
      final capped = await measure(maxTextScale: 1.3);
      expect(large.cells, normal.cells);
      expect(capped.cells, normal.cells);
      expect(large.tooltip, moreOrLessEquals(normal.tooltip * 2));
      expect(capped.tooltip, moreOrLessEquals(normal.tooltip * 1.3));
      expect(large.menu, moreOrLessEquals(normal.menu * 2));
      expect(capped.menu, moreOrLessEquals(normal.menu * 1.3));
    });
  });

  group('documented requirements and limits', () {
    testWidgets('a window-wide first route with actions uses the column without a back control', (tester) async {
      useWindow(tester, innerLandscape);
      final record = _Record();
      await tester.pumpWidget(
        _app(
          innerLandscape,
          navigatorKey: GlobalKey<NavigatorState>(),
          home: _page(record: record),
        ),
      );
      // Nothing tells a root or tab page from a pushed page, so the docs say to wrap only pushed pages.
      expect(record.slots?.active, isTrue);
      expect(record.slots?.backInColumn, isFalse);
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(879, 124, 927, 172));
    });

    /// A CupertinoApp host for [window], with Material localizations when [materialLocalizations].
    Widget cupertinoApp(DuoWindow window, GlobalKey<NavigatorState> navigator, {required bool materialLocalizations}) =>
        CupertinoApp(
          navigatorKey: navigator,
          localizationsDelegates: materialLocalizations ? const [DefaultMaterialLocalizations.delegate] : null,
          home: const CupertinoPageScaffold(child: Center(child: Text('Home'))),
          builder: (context, child) => duoScopes(window, child!),
        );

    /// Pushes a page with [actions] in a CupertinoApp host for [window] and returns what its builder received.
    Future<_Record> showCupertinoPage(
      WidgetTester tester,
      DuoWindow window,
      List<VerticalBarAction> actions, {
      required bool materialLocalizations,
    }) async {
      useWindow(tester, window);
      final navigator = GlobalKey<NavigatorState>();
      final record = _Record();
      await tester.pumpWidget(cupertinoApp(window, navigator, materialLocalizations: materialLocalizations));
      navigator.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => VerticalBarPage(
            actions: actions,
            builder: (context, slots) {
              record(slots);
              return const CupertinoPageScaffold(child: Center(child: Text('Content')));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return record;
    }

    testWidgets('a CupertinoApp host that adds DefaultMaterialLocalizations gets the column, tooltips, and menus', (
      tester,
    ) async {
      final invocations = <VerticalBarInvocation>[];
      final record = await showCupertinoPage(tester, innerLandscape, [
        ...numberedActions(7),
        _share(onPressed: invocations.add),
        _favorite(),
      ], materialLocalizations: true);
      expect(tester.takeException(), isNull);
      expect(record.slots?.backInColumn, isTrue);
      expect(tester.getRect(find.byTooltip('Back')), _backCell);
      expect(_inside(await _showTooltip(tester, 'Back'), innerLandscape.size), isTrue);

      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(invocations, [const VerticalBarInvocation(anchor: _overflowCell, fromOverflowMenu: true)]);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without MaterialLocalizations only a page that uses the column fails, a documented requirement', (
      tester,
    ) async {
      final record = await showCupertinoPage(tester, iPhone17, [_share()], materialLocalizations: false);
      expect(tester.takeException(), isNull);
      expect(record.slots, const VerticalBarSlots());
      await tester.pumpWidget(const SizedBox());

      late _Record inColumn;
      final errors = await collectErrors(() async {
        inColumn = await showCupertinoPage(tester, innerLandscape, [_share()], materialLocalizations: false);
      });
      expect(inColumn.slots?.active, isTrue);
      expect(errors, isNotEmpty);
      for (final error in errors) {
        expect(error.exceptionAsString(), contains('No MaterialLocalizations found'));
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('under an intrinsic-size query the page throws in debug builds, also without a column', (
      tester,
    ) async {
      useWindow(tester, iPhone17);
      final page = VerticalBarPage(
        actions: [_share()],
        builder: (context, slots) => const SizedBox.square(dimension: 10),
      );
      for (final (name, host) in <(String, Widget)>[
        ('IntrinsicHeight', Center(child: IntrinsicHeight(child: page))),
        ('AlertDialog content', Center(child: AlertDialog(content: page))),
      ]) {
        final errors = await collectErrors(() => tester.pumpWidget(MaterialApp(home: Scaffold(body: host))));
        expect(errors, isNotEmpty, reason: name);
        expect(
          errors.first.exceptionAsString(),
          contains('LayoutBuilder does not support returning intrinsic dimensions'),
          reason: name,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('debug checks', () {
    testWidgets('duplicate action ids assert', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(
        MaterialApp(
          home: VerticalBarPage(
            actions: [_share(), _favorite(), _share()],
            builder: (context, slots) => const SizedBox(),
          ),
        ),
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect(error.toString(), contains('share'));
    });

    testWidgets('empty menu items assert', (tester) async {
      useWindow(tester, innerLandscape);
      await tester.pumpWidget(
        MaterialApp(
          home: VerticalBarPage(
            actions: const [
              VerticalBarAction(id: 'menu', icon: Icon(Icons.more_vert), label: 'Menu', menuItems: []),
            ],
            builder: (context, slots) => const SizedBox(),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });
}

void _noopItem() {}

/// Returns [value] unchanged; keeps a constructor call out of constant evaluation so its asserts run.
T _runtime<T>(T value) => value;
