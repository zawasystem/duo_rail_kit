part of '../vertical_bar_toolbar.dart';

/// A tab shell's `[left rail | content | right rail]` row whose pages place their back control and
/// actions in the vertical bar column above the rail, as UIKit places a navigation bar's items above the
/// tab bar.
///
/// Use it in place of [RailSideRow], with the same arguments, below [VerticalBarEdge] and
/// [SideStatusBarInsets] and above the content's `MediaQuery.removePadding`. Its box must start at the
/// window's top-left corner and span its width, though it may be shorter, as above a keyboard (debug
/// builds check); it cannot sit under an intrinsic-size query.
///
/// The column is used when [enabled] is true, [VerticalBarColumn.of] returns a column on [railEdge], the
/// status bar is visible, that edge's OS inset is at least the column's width, and the reserved cells
/// (one, or two with [reservesBack]) fit in [VerticalBarColumn.items]. Elsewhere it lays out, paints,
/// and reads as a [RailSideRow]. While the column is used:
///
/// * The current page is the [VerticalBarPage] whose route is current and whose [TickerMode] is enabled,
///   so hidden branches must disable tickers; a popup above it leaves its cells drawn but inert. Place
///   each page above its own [LayoutBuilder]s, or its cells follow a frame late.
/// * The rail takes its top padding from [railPaddingOf], scrolls when it does not fit, and holds one
///   [VerticalBarRailEnd]. Cells are centred on the rail and fill the room above its destinations; the
///   rest go to the overflow menu, and without the marker only the reserved cells are used.
/// * Cell controls build here under the page's themes ([InheritedTheme.captureAll]); other inherited
///   widgets of the page are not visible to them. Menus open on the root Navigator.
/// * Screen readers and Tab visit the cells first, then the rail and the content. The shell is always
///   one focus traversal group, so a sibling such as a floating action button comes before or after it.
class VerticalBarShell extends StatefulWidget {
  const VerticalBarShell({
    super.key,
    required this.railEdge,
    required this.rail,
    required this.content,
    this.enabled = true,
    this.reservesBack = false,
  });

  /// As in [RailSideRow].
  final HorizontalEdge? railEdge;

  /// As in [RailSideRow].
  final Widget rail;

  /// As in [RailSideRow], in its keyed slot.
  final Widget content;

  /// False never uses the column, for example while the pages are two-pane.
  final bool enabled;

  /// Whether pages with a back control, such as pages pushed inside a branch, may use the column.
  /// True reserves a back control and one cell, so the rail's top padding is one group lower on every
  /// tab; false keeps the app bar of a page with a back control.
  final bool reservesBack;

  /// [padding] with its top raised to [VerticalBarColumn.groupGap] below the reserved cells while the
  /// nearest [VerticalBarShell] uses the column, or unchanged. Pass it as the rail's MediaQuery
  /// padding, after [RailLayout.centredSafeArea] or [RailPlacement.centredRailSafeArea] if used. Call it
  /// with a context below the shell, such as a [Builder]'s in the rail; the context that builds the shell
  /// gets [padding] unchanged. The same on every tab; keyboard and text-scale changes do not
  /// rebuild the caller.
  static EdgeInsets railPaddingOf(BuildContext context, EdgeInsets padding) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    final floorTop = scope?.used?.floorTop;
    return floorTop == null ? padding : padding.copyWith(top: math.max(padding.top, floorTop));
  }

  @override
  State<VerticalBarShell> createState() => _VerticalBarShellState();
}

class _VerticalBarShellState extends State<VerticalBarShell> {
  final _ShellRegistry _registry = _ShellRegistry();

  late final TraversalPolicies _policies = TraversalPolicies(isColumn: _isColumnGroup);

  @override
  void initState() {
    super.initState();
    _registry.shellElement = context as Element;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToTickerMode();
  }

  @override
  void activate() {
    super.activate();
    // A shell that moves may have another TickerMode above it.
    _listenToTickerMode();
  }

  @override
  void deactivate() {
    _stopListeningToTickerMode();
    super.deactivate();
  }

  @override
  void dispose() {
    _stopListeningToTickerMode();
    super.dispose();
  }

  /// Listens to the shell's own [TickerMode] without depending on it: while a route covers the shell, the
  /// shell keeps its owner, inert, instead of choosing again.
  void _listenToTickerMode() {
    final notifier = TickerMode.getValuesNotifier(context);
    final previous = _registry.shellTicker;
    if (identical(notifier, previous)) {
      return;
    }
    previous?.removeListener(_handleTickerModeChange);
    _registry.shellTicker = notifier..addListener(_handleTickerModeChange);
  }

  void _stopListeningToTickerMode() {
    _registry.shellTicker?.removeListener(_handleTickerModeChange);
    _registry.shellTicker = null;
  }

  void _handleTickerModeChange() {
    // Where the column is unused, the cells and their owner do not depend on the tickers.
    if (mounted && (_registry.layout?._active ?? false)) {
      _registry.notify(context as Element);
    }
  }

  /// The [_UsedColumn], or null where the shell lays out as a [RailSideRow].
  _UsedColumn? _usedColumn(BuildContext context) {
    if (!widget.enabled) {
      return null;
    }
    final column = VerticalBarColumn.of(context);
    if (column == null || column.edge != widget.railEdge || VerticalBarEdge.statusBarHiddenOf(context)) {
      return null;
    }
    if (!osInsetCoversColumn(context, column, MediaQuery.viewPaddingOf(context))) {
      return null;
    }
    final floorTop = shellFloorTop(column, reservesBack: widget.reservesBack);
    if (floorTop - VerticalBarColumn.groupGap > column.items.bottom + geometryTolerance) {
      return null;
    }
    return (column: column, floorTop: floorTop);
  }

  bool _isColumnGroup(FocusNode node) => identical(node, _registry.columnGroup);

  @override
  Widget build(BuildContext context) {
    final used = _usedColumn(context);
    final active = used != null;
    // Read only while the column is used, so that a shell that never uses it does not depend on its route;
    // once read, the dependency stays until the shell is deactivated. It builds again when its route stops
    // or starts being current.
    final route = active ? ModalRoute.of(context) : null;
    final ambient = _policies.ambientOf(context);
    final policy = active ? _policies.columnFirstOver(ambient) : ambient;
    // Only values change with the column, its edge, and the owner; the tree keeps its shape so the rail
    // and the content keep their States.
    return _ShellScope(
      registry: _registry,
      used: used,
      reservesBack: widget.reservesBack,
      child: Semantics(
        container: active,
        explicitChildNodes: active,
        child: FocusTraversalGroup(
          policy: policy,
          child: _ShellLayout(
            registry: _registry,
            used: used,
            ambient: ambient,
            route: route,
            routeCurrent: route?.isCurrent ?? true,
            children: [
              layerGroup(
                active: active,
                sortKey: const OrdinalSortKey(1),
                policy: ambient,
                child: RailSideRow(railEdge: widget.railEdge, rail: widget.rail, content: widget.content),
              ),
              _ColumnLayer(builder: _buildLayer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayer(BuildContext context, _LayerInfo info) {
    assert(() {
      VerticalBarShellDebugStats.layerBuilds++;
      return true;
    }());
    final owner = info.owner;
    final registration = info.registration;
    final inert = !info.interactive;
    return layerGroup(
      active: info.active,
      sortKey: const OrdinalSortKey(0),
      policy: info.ambient,
      onFocusNodeCreated: (node) => _registry.columnGroup = node,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (owner != null && registration != null)
              // Keyed by the owner, so that pages never share a cell's State, even for equal action ids.
              KeyedSubtree(
                key: ObjectKey(owner),
                child: _inertCells(
                  inert: inert,
                  // The themes between the page and this widget; those above it apply here as they are.
                  child: InheritedTheme.captureAll(
                    owner.context,
                    ColumnCells(
                      layout: info.layout,
                      itemBuilder: registration.page.itemBuilder,
                      backBuilder: registration.page.backBuilder,
                      overflowBuilder: registration.page.overflowBuilder,
                      groupDecoration: registration.page.groupDecoration,
                      owner: _shellCellOwner(owner),
                    ),
                    to: _registry.shellElement,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// How the shell's cells for [owner] act: menus open on the root Navigator, placed by this shell's
  /// layout.
  CellOwner _shellCellOwner(_VerticalBarPageState owner) => CellOwner(
    page: owner,
    canInvoke: () => owner._canInvoke && _registry.isInteractiveOwner(owner),
    useRootNavigator: true,
    menuPosition: (anchor) => _registry.layout?.menuPosition(anchor, Navigator.of(owner.context, rootNavigator: true)),
    waitsForTickers: () => owner._waitsForTickers,
  );
}

/// The column a shell uses and the rail's lowest top padding beside it, from [shellFloorTop].
typedef _UsedColumn = ({VerticalBarColumn column, double floorTop});

/// Inert cells stay drawn, as the rail does below a popup, but take no taps, are skipped by Tab, and are
/// not read. They keep their focus: a cell that loses it in the frame that a route opens from it would
/// take the focus from that route.
Widget _inertCells({required bool inert, required Widget child}) => ExcludeSemantics(
  excluding: inert,
  child: ExcludeFocusTraversal(
    excluding: inert,
    child: IgnorePointer(ignoring: inert, child: child),
  ),
);

/// The values the shell decided in its build, for the pages and the rail below it.
class _ShellScope extends InheritedWidget {
  const _ShellScope({
    required this.registry,
    required this.used,
    required this.reservesBack,
    required super.child,
  });

  final _ShellRegistry registry;

  /// The [_UsedColumn], or null where the shell lays out as a [RailSideRow].
  final _UsedColumn? used;

  final bool reservesBack;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) =>
      registry != oldWidget.registry || used != oldWidget.used || reservesBack != oldWidget.reservesBack;
}
