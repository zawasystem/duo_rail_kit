import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use, unnecessary_ignore
import 'package:flutter_test/flutter_test.dart';

import 'duo_windows.dart';
import 'traversal.dart';

/// Which rail a [ShellHost] draws.
enum HarnessRailKind { navigationRail, scrolling, movable }

/// A rail fixture: a bottom-aligned [NavigationRail], a custom scrolling rail, or a rail with a relayout
/// boundary inside.
@immutable
class HarnessRail {
  const HarnessRail._(
    this.kind, {
    this.destinations = 4,
    this.labelType = NavigationRailLabelType.all,
    this.groupAlignment = 1,
    this.scrollable = true,
    this.minWidth = 84,
    this.movableItems = MovableItems.plain,
    this.width = 84,
  });

  final HarnessRailKind kind;

  /// Destinations of a [NavigationRail], or items of the other rails (always 4).
  final int destinations;

  final NavigationRailLabelType labelType;
  final double groupAlignment;
  final bool scrollable;
  final double minWidth;

  /// What holds the movable rail's items Column.
  final MovableItems movableItems;

  /// The width of a [NavigationRail]'s box, or of the scrolling rail and its destinations.
  final double width;
}

/// A [NavigationRail] in a `SizedBox(width: width)`, bottom-aligned by default.
HarnessRail navigationRail({
  required int destinations,
  NavigationRailLabelType labelType = NavigationRailLabelType.all,
  double groupAlignment = 1,
  bool scrollable = true,
  double minWidth = 84,
  double width = 84,
}) => HarnessRail._(
  HarnessRailKind.navigationRail,
  destinations: destinations,
  labelType: labelType,
  groupAlignment: groupAlignment,
  scrollable: scrollable,
  minWidth: minWidth,
  width: width,
);

/// A custom rail: four destinations, 56 high, at the bottom of a scroll view that pads the keyboard itself.
const HarnessRail scrollingRail = HarnessRail._(HarnessRailKind.scrolling);

/// [scrollingRail] with the rail and its destinations [width] wide.
HarnessRail scrollingRailWithWidth(double width) => HarnessRail._(HarnessRailKind.scrolling, width: width);

/// Four 56-point items above a gap, in a tight 669-point box: a relayout boundary inside the rail.
const HarnessRail movableRail = HarnessRail._(HarnessRailKind.movable);

/// What holds the items Column of [MovableRail].
enum MovableItems {
  /// Nothing: the Column sits in the rail's outer Column.
  plain,

  /// A [RepaintBoundary], which the rail moves without painting the items again.
  repaintBoundary,

  /// A [SingleChildScrollView] as tall as the items, whose viewport is a repaint boundary.
  scrollView,
}

/// [movableRail] with its items Column held by [items].
HarnessRail movableRailWith(MovableItems items) => HarnessRail._(HarnessRailKind.movable, movableItems: items);

/// How the branches are shown: an indexed stack or a fade-through.
enum ShellContainer { indexedStack, fadeThrough }

/// Where the shell sits: in a `Scaffold(resizeToAvoidBottomInset: true)` body, or directly in the route
/// beside a rail that pads the keyboard itself.
enum ShellShape { inBody, outside }

/// The labels of each branch's actions: Home with four, a second tab with two, and Settings with none.
const List<List<String>> defaultBranchActions = [
  ['a0', 'b0', 'c0', 'd0'],
  ['a1', 'b1'],
  <String>[],
];

/// The key of the focusable sibling that [miniPlayerAround] places below the root Navigator.
const Key miniPlayerKey = ValueKey('miniPlayer');

/// The key of the focusable bar that `shellApp(playerBelowShell: true)` places below the shell, in the
/// shell's route.
const Key routePlayerKey = ValueKey('routePlayer');

/// The key of the button that `shellApp(floatingButton: true)` floats beside an inBody shell.
const Key floatingButtonKey = ValueKey('floatingButton');

/// The height of the player bars.
const double playerHeight = 56;

/// A full-width focusable player bar.
Widget _playerBar(Key key) => Material(
  child: SizedBox(
    height: playerHeight,
    child: Center(
      child: TextButton(key: key, onPressed: () {}, child: const Text('Player')),
    ),
  ),
);

/// Places a focusable player bar below the root Navigator, as an application's mini player. Screen
/// readers reach it; Tab does not, since it is outside every route's focus scope.
Widget miniPlayerAround(BuildContext context, Widget? child) => Column(
  children: [
    Expanded(child: child!),
    _playerBar(miniPlayerKey),
  ],
);

/// Keys and States of one harness app, the taps its controls recorded, and the slots its pages built
/// with.
class ShellHarness {
  final GlobalKey<ShellHostState> hostKey = GlobalKey<ShellHostState>();
  final GlobalKey<MovableRailState> movableKey = GlobalKey<MovableRailState>();
  final Map<int, BranchRootState> branches = <int, BranchRootState>{};
  final List<String> taps = <String>[];

  /// The slots each [harnessPage] last built with, by title.
  final Map<String, VerticalBarSlots> slots = <String, VerticalBarSlots>{};

  ShellHostState get host => hostKey.currentState!;
}

/// Builds a branch's first page in place of [harnessPage]; [BranchRootState.actions] holds its labels.
typedef BranchPageBuilder = Widget Function(BranchRootState branch);

/// A tab app for [window]: a [VerticalBarShell] (or, with [plain], a [RailSideRow] whose rail never
/// calls [VerticalBarShell.railPaddingOf] and never holds a [VerticalBarRailEnd]) with [rail] on
/// [railEdge] and one Navigator per entry of [branchActions], each rooted in a [BranchRoot] that shows
/// [branchPage] or a [harnessPage]. The shell's rail holds a [VerticalBarRailEnd] unless [marker] is
/// false. [layoutBuilderAboveShell] builds the root Navigator inside a LayoutBuilder, as a player host
/// may do; [around] wraps the root Navigator. [playerBelowShell] puts a focusable player bar
/// ([routePlayerKey]) below the shell in its route, and [floatingButton] a floating action button
/// ([floatingButtonKey]) in the inBody Scaffold: focusable siblings that Tab reaches.
/// [contentSemanticsContainer] puts the branches in a `Semantics(container: true)`. The themes and
/// [textDirection] go to [duoApp].
Widget shellApp(
  DuoWindow window,
  ShellHarness harness, {
  required HorizontalEdge? railEdge,
  HarnessRail rail = scrollingRail,
  ShellContainer container = ShellContainer.indexedStack,
  ShellShape shape = ShellShape.outside,
  bool reservesBack = false,
  bool enabled = true,
  bool layoutBuilderAboveShell = false,
  bool pagesInLayoutBuilder = false,
  bool textField = false,
  bool plain = false,
  bool playerBelowShell = false,
  bool floatingButton = false,
  bool marker = true,
  bool contentSemanticsContainer = false,
  List<List<String>> branchActions = defaultBranchActions,
  BranchPageBuilder? branchPage,
  TransitionBuilder? around,
  bool? statusBarHidden,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  AnimationStyle? themeAnimationStyle,
  TextDirection? textDirection,
}) => duoApp(
  window,
  statusBarHidden: statusBarHidden,
  theme: theme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  themeAnimationStyle: themeAnimationStyle,
  textDirection: textDirection,
  around: around == null && !layoutBuilderAboveShell
      ? null
      : (context, child) {
          final navigator = around == null ? child! : around(context, child);
          return layoutBuilderAboveShell ? LayoutBuilder(builder: (context, constraints) => navigator) : navigator;
        },
  home: ShellHost(
    key: harness.hostKey,
    harness: harness,
    railEdge: railEdge,
    rail: rail,
    container: container,
    shape: shape,
    reservesBack: reservesBack,
    enabled: enabled,
    pagesInLayoutBuilder: pagesInLayoutBuilder,
    textField: textField,
    plain: plain,
    playerBelowShell: playerBelowShell,
    floatingButton: floatingButton,
    marker: marker,
    contentSemanticsContainer: contentSemanticsContainer,
    branchActions: branchActions,
    branchPage: branchPage,
  ),
);

/// The shell, its rail, and its branches; see [shellApp].
class ShellHost extends StatefulWidget {
  const ShellHost({
    super.key,
    required this.harness,
    required this.railEdge,
    required this.rail,
    required this.container,
    required this.shape,
    required this.reservesBack,
    required this.enabled,
    required this.pagesInLayoutBuilder,
    required this.textField,
    required this.plain,
    required this.playerBelowShell,
    required this.floatingButton,
    required this.marker,
    this.contentSemanticsContainer = false,
    required this.branchActions,
    required this.branchPage,
  });

  final ShellHarness harness;
  final HorizontalEdge? railEdge;
  final HarnessRail rail;
  final ShellContainer container;
  final ShellShape shape;
  final bool reservesBack;
  final bool enabled;
  final bool pagesInLayoutBuilder;
  final bool textField;
  final bool plain;
  final bool playerBelowShell;

  /// Only with [ShellShape.inBody].
  final bool floatingButton;

  /// Whether the shell's rail holds a [VerticalBarRailEnd]; never with [plain].
  final bool marker;

  /// Whether the branches sit in a `Semantics(container: true)`, which keeps the routes' modal barriers
  /// from hiding a rail painted before them.
  final bool contentSemanticsContainer;
  final List<List<String>> branchActions;
  final BranchPageBuilder? branchPage;

  @override
  State<ShellHost> createState() => ShellHostState();
}

class ShellHostState extends State<ShellHost> {
  /// The selected branch.
  int index = 0;

  /// The rail's edge: the widget's until [setRailEdge].
  late HorizontalEdge? railEdge = widget.railEdge;

  void select(int value) => setState(() => index = value);

  void setRailEdge(HorizontalEdge? value) => setState(() => railEdge = value);

  bool get _marker => widget.marker && !widget.plain;

  int get _branchCount => widget.branchActions.length;

  late final List<Widget> _navigators = [
    for (var branch = 0; branch < _branchCount; branch++)
      Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BranchRoot(
            harness: widget.harness,
            index: branch,
            actions: widget.branchActions[branch],
            inLayoutBuilder: widget.pagesInLayoutBuilder,
            textField: widget.textField,
            page: widget.branchPage,
          ),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final rail = switch (widget.rail.kind) {
      HarnessRailKind.navigationRail => _navigationRail(),
      HarnessRailKind.scrolling => _scrollingRail(),
      HarnessRailKind.movable => MovableRail(
        key: widget.harness.movableKey,
        selected: index,
        onSelected: select,
        marker: _marker,
        items: widget.rail.movableItems,
      ),
    };
    final branches = switch (widget.container) {
      ShellContainer.indexedStack => GoRouterIndexedStack(currentIndex: index, children: _navigators),
      ShellContainer.fadeThrough => BranchFadeThrough(currentIndex: index, children: _navigators),
    };
    final content = widget.contentSemanticsContainer ? Semantics(container: true, child: branches) : branches;
    final row = widget.plain
        ? RailSideRow(railEdge: railEdge, rail: rail, content: content)
        : VerticalBarShell(
            railEdge: railEdge,
            rail: rail,
            content: content,
            enabled: widget.enabled,
            reservesBack: widget.reservesBack,
          );
    // Stretched, so that the shell keeps tight constraints above the player.
    final body = widget.playerBelowShell
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: row),
              _playerBar(routePlayerKey),
            ],
          )
        : row;
    assert(!widget.floatingButton || widget.shape == ShellShape.inBody, 'A floating button needs a Scaffold.');
    return switch (widget.shape) {
      ShellShape.inBody => Scaffold(
        resizeToAvoidBottomInset: true,
        body: body,
        floatingActionButton: widget.floatingButton
            ? FloatingActionButton(key: floatingButtonKey, onPressed: () {}, child: const Icon(Icons.add))
            : null,
      ),
      ShellShape.outside => body,
    };
  }

  /// The rail's safe area: from [VerticalBarShell.railPaddingOf] unless plain.
  EdgeInsets _railPadding(BuildContext context, EdgeInsets padding) =>
      widget.plain ? padding : VerticalBarShell.railPaddingOf(context, padding);

  void _selectItem(int item) => select(item % _branchCount);

  Widget _navigationRail() => Builder(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final rail = widget.rail;
      return MediaQuery(
        data: mediaQuery.copyWith(padding: _railPadding(context, mediaQuery.padding)),
        child: SizedBox(
          width: rail.width,
          child: NavigationRail(
            selectedIndex: index < rail.destinations ? index : null,
            groupAlignment: rail.groupAlignment,
            labelType: rail.labelType,
            scrollable: rail.scrollable,
            minWidth: rail.minWidth,
            onDestinationSelected: _selectItem,
            destinations: [
              for (var item = 0; item < rail.destinations; item++)
                NavigationRailDestination(
                  icon: Icon(Icons.circle_outlined, key: ValueKey('rail:$item')),
                  selectedIcon: Icon(Icons.circle, key: ValueKey('rail:$item')),
                  label: Text('Tab $item'),
                ),
            ],
            trailing: _marker ? const VerticalBarRailEnd() : null,
          ),
        ),
      );
    },
  );

  Widget _scrollingRail() => Builder(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final safeArea = _railPadding(context, mediaQuery.padding);
      return MediaQuery(
        data: mediaQuery.copyWith(padding: safeArea),
        child: Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: SafeArea(
            bottom: false,
            right: false,
            left: false,
            child: SizedBox(
              width: widget.rail.width,
              child: Material(
                child: LayoutBuilder(
                  key: const ValueKey('railViewport'),
                  builder: (context, constraints) => SingleChildScrollView(
                    key: const ValueKey('railScroll'),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Flexible(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var item = 0; item < 4; item++)
                                      SizedBox(
                                        key: ValueKey('rail:$item'),
                                        width: widget.rail.width,
                                        height: 56,
                                        child: InkWell(
                                          onTap: () => _selectItem(item),
                                          child: Icon(
                                            item == index ? Icons.circle : Icons.circle_outlined,
                                            semanticLabel: 'Tab $item',
                                          ),
                                        ),
                                      ),
                                    if (_marker) const VerticalBarRailEnd(),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: safeArea.bottom),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A rail with a relayout boundary inside (a tight SizedBox), whose items move without relaying out
/// the shell.
class MovableRail extends StatefulWidget {
  const MovableRail({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.marker,
    this.items = MovableItems.plain,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  /// Whether the items' Column ends with a [VerticalBarRailEnd].
  final bool marker;

  /// What holds the items' Column.
  final MovableItems items;

  @override
  State<MovableRail> createState() => MovableRailState();
}

class MovableRailState extends State<MovableRail> {
  double gap = 34;

  /// Whether the items' Column ends with a [VerticalBarRailEnd]: the widget's until [setMarker].
  late bool marker = widget.marker;

  /// The marker's key, which [replaceMarker] changes.
  int markerKey = 0;

  void setGap(double value) => setState(() => gap = value);

  void setMarker({required bool value}) => setState(() => marker = value);

  /// Replaces the marker with a new one, which the rail lays out after the shell.
  void replaceMarker() => setState(() => markerKey++);

  @override
  Widget build(BuildContext context) {
    final items = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var item = 0; item < 4; item++) SizedBox(key: ValueKey('rail:$item'), width: 84, height: 56),
        if (marker) VerticalBarRailEnd(key: ValueKey(markerKey)),
      ],
    );
    return SizedBox(
      width: 84,
      height: 669,
      child: ColoredBox(
        color: const Color(0xFFEEEEEE),
        child: Column(
          children: [
            const Spacer(),
            switch (widget.items) {
              MovableItems.plain => items,
              MovableItems.repaintBoundary => RepaintBoundary(child: items),
              MovableItems.scrollView => SizedBox(height: 224, child: SingleChildScrollView(child: items)),
            },
            SizedBox(height: gap),
          ],
        ),
      ),
    );
  }
}

/// The branch container of go_router's indexed-stack shell: hidden branches offstage, tickers disabled.
class GoRouterIndexedStack extends StatelessWidget {
  const GoRouterIndexedStack({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: currentIndex,
    children: [
      for (var index = 0; index < children.length; index++)
        Offstage(
          offstage: index != currentIndex,
          child: TickerMode(enabled: index == currentIndex, child: children[index]),
        ),
    ],
  );
}

/// A branch container that fades between branches and disables tickers in hidden ones.
class BranchFadeThrough extends StatefulWidget {
  const BranchFadeThrough({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<BranchFadeThrough> createState() => _BranchFadeThroughState();
}

class _BranchFadeThroughState extends State<BranchFadeThrough> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Durations.medium1,
    value: 1,
  )..addStatusListener(_onStatusChanged);
  int? _outgoingIndex;

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoingIndex != null) {
      setState(() => _outgoingIndex = null);
    }
  }

  @override
  void didUpdateWidget(covariant BranchFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == oldWidget.currentIndex) {
      return;
    }
    _outgoingIndex = oldWidget.currentIndex;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final isAnimating = !_controller.isCompleted;
      final t = _controller.value;
      final fadeOut = 1 - const Interval(0, 0.55, curve: Easing.standardAccelerate).transform(t);
      final fadeIn = const Interval(0.2, 1, curve: Easing.standardDecelerate).transform(t);
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < widget.children.length; index++)
            Offstage(
              offstage: index != widget.currentIndex && !(isAnimating && index == _outgoingIndex),
              child: IgnorePointer(
                ignoring: index != widget.currentIndex,
                child: Opacity(
                  opacity: index == widget.currentIndex
                      ? fadeIn
                      : (isAnimating && index == _outgoingIndex ? fadeOut : 0.0),
                  child: TickerMode(enabled: index == widget.currentIndex, child: widget.children[index]),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A branch's first page: a [VerticalBarPage] whose app bar keeps its actions unless the slots are
/// active. Its actions and app-bar buttons record their taps in [ShellHarness.taps].
class BranchRoot extends StatefulWidget {
  const BranchRoot({
    super.key,
    required this.harness,
    required this.index,
    required this.actions,
    required this.inLayoutBuilder,
    required this.textField,
    this.page,
  });

  final ShellHarness harness;
  final int index;

  /// The labels, which are also the ids, of the page's actions.
  final List<String> actions;

  /// Builds the page inside the root's own LayoutBuilder, so its cell updates arrive a frame late.
  final bool inLayoutBuilder;

  final bool textField;

  /// Builds the page in place of a [harnessPage].
  final BranchPageBuilder? page;

  @override
  State<BranchRoot> createState() => BranchRootState();
}

class BranchRootState extends State<BranchRoot> {
  late List<String> actions = widget.actions;

  void setActions(List<String> value) => setState(() => actions = value);

  /// Pushes a page with one action, 'pushed', in this branch's Navigator.
  void push() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => harnessPage(widget.harness, title: 'Pushed', actions: const ['pushed']),
    ),
  );

  void pop() => Navigator.of(context).pop();

  @override
  void initState() {
    super.initState();
    widget.harness.branches[widget.index] = this;
  }

  Widget _page(List<String> actions) =>
      widget.page?.call(this) ??
      harnessPage(
        widget.harness,
        title: 'Branch ${widget.index}',
        actions: actions,
        body: widget.textField
            ? Center(child: TextField(key: ValueKey('field:${widget.index}')))
            : Center(child: Text('Body ${widget.index}')),
      );

  @override
  Widget build(BuildContext context) {
    final actions = this.actions;
    return widget.inLayoutBuilder ? LayoutBuilder(builder: (context, constraints) => _page(actions)) : _page(actions);
  }
}

/// A [VerticalBarPage] with [actions] (labels and ids, those in [pinned] pinned) whose app bar shows
/// them as icon buttons, keyed `appBar:<id>`, unless the slots are active. Records its slots in
/// [ShellHarness.slots] under [title].
Widget harnessPage(
  ShellHarness harness, {
  required String title,
  required List<String> actions,
  Widget? body,
  bool enabled = true,
  Set<String> pinned = const <String>{},
}) => VerticalBarPage(
  enabled: enabled,
  actions: [
    for (final id in actions)
      VerticalBarAction(
        id: id,
        icon: const Icon(Icons.star),
        label: id,
        pinned: pinned.contains(id),
        onPressed: (invocation) => harness.taps.add(id),
      ),
  ],
  builder: (context, slots) {
    harness.slots[title] = slots;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: !slots.backInColumn,
        actions: slots.active
            ? null
            : [
                for (final id in actions)
                  IconButton(
                    key: ValueKey('appBar:$id'),
                    tooltip: id,
                    onPressed: () => harness.taps.add('appBar:$id'),
                    icon: const Icon(Icons.star),
                  ),
              ],
      ),
      body: body ?? Center(child: Text(title)),
    );
  },
);

/// What must stay identical where the shell does not use the column.
typedef ShellSnapshot = ({List<Rect> rects, String semantics, List<Rect> tabOrder});

/// Global rectangles of every laid-out [Text], [Icon], [IconButton], [TextButton], [TextField],
/// [NavigationRail], [Scaffold], and [Navigator], in tree order, offstage ones included.
List<Rect> harnessRects(WidgetTester tester) => [
  for (final element
      in find
          .byWidgetPredicate(
            (widget) =>
                widget is Text ||
                widget is Icon ||
                widget is IconButton ||
                widget is TextButton ||
                widget is TextField ||
                widget is NavigationRail ||
                widget is Scaffold ||
                widget is Navigator,
            skipOffstage: false,
          )
          .evaluate())
    if (element.renderObject case final RenderBox box when box.hasSize && box.attached)
      box.localToGlobal(Offset.zero) & box.size,
];

/// Pumps [app], settles, records what must stay identical, and removes the app again.
Future<ShellSnapshot> harnessSnapshot(WidgetTester tester, Widget app, {int presses = 12}) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  final rects = harnessRects(tester);
  final semantics = semanticsTreeOf(tester);
  final tabOrder = await tabOrderOf(tester, presses);
  await tester.pumpWidget(const SizedBox());
  return (rects: rects, semantics: semantics, tabOrder: tabOrder);
}
