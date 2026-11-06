part of '../vertical_bar_toolbar.dart';

/// Draws a full-window page's back control and actions in the vertical bar column.
///
/// Wrap the page root, above its Scaffold, where MediaQuery still describes the window and the page's
/// Navigator starts at the window's top-left corner (below a [VerticalBarShell], the shell needs that
/// instead). Outside a shell, wrap only pushed pages. Where the column is used, it needs
/// [MaterialLocalizations] (a `CupertinoApp` can add [DefaultMaterialLocalizations.delegate]), an
/// [Overlay], and a [Navigator]. The root is a [LayoutBuilder], so it cannot sit under an intrinsic-size
/// query, such as [AlertDialog] content. The column covers a Drawer and a persistent bottom sheet; pass
/// `enabled: false` on pages with them. The default controls assume Material 3; under Material 2 use
/// [itemBuilder], [backBuilder], and [overflowBuilder].
///
/// The column is used when [enabled] is true, [VerticalBarColumn.of] returns a column, the route is a
/// [PageRoute] outside a Cupertino sheet, in a Navigator that no translucent route (such as a dialog or a
/// bottom sheet) holds, no ancestor [VerticalBarPage] uses the column, and the back control or an action
/// fits. Without a shell, the page must also be as wide as the window and the OS inset on the column's edge
/// must be at least the column's width (not so in the left Split View window); below a shell, the shell
/// checks those, and a back control needs [VerticalBarShell.reservesBack]. Actions that do not fit go to the
/// overflow menu. Elsewhere the page lays out, paints, reads, and traverses as without this widget.
///
/// Menus open 8 logical pixels beside the column's inner edge, on the page's Navigator (the root
/// Navigator below a shell). A choice made after the page is gone is dropped.
class VerticalBarPage extends StatefulWidget {
  const VerticalBarPage({
    super.key,
    this.enabled = true,
    this.back = VerticalBarBack.automatic,
    this.actions = const <VerticalBarAction>[],
    this.itemBuilder,
    this.backBuilder,
    this.overflowBuilder,
    this.groupDecoration,
    required this.builder,
  });

  /// False keeps everything in the app bar, for example in two-pane layouts or on pages with a Drawer.
  final bool enabled;

  /// The back control placed first in the column.
  final VerticalBarBack back;

  /// In app-bar order: left to right becomes top to bottom.
  final List<VerticalBarAction> actions;

  /// Draws standard actions; the package's default control is used when null or when it returns null.
  final VerticalBarItemBuilder? itemBuilder;

  /// Draws the back control; the package's default is used when null. Its cell's `invoke` pops.
  final VerticalBarCellBuilder? backBuilder;

  /// Draws the overflow cell; the package's default is used when null. Its cell's `invoke` opens the menu.
  final VerticalBarCellBuilder? overflowBuilder;

  /// Painted behind each group, never hit-tested; none by default.
  final Decoration? groupDecoration;

  /// Builds the page, usually its Scaffold, with this frame's slots. The context is below this
  /// widget, so [VerticalBarSlots.maybeOf] returns `slots` there.
  final Widget Function(BuildContext context, VerticalBarSlots slots) builder;

  @override
  State<VerticalBarPage> createState() => _VerticalBarPageState();
}

/// What the page's app bar should leave out in this frame.
@immutable
class VerticalBarSlots {
  const VerticalBarSlots({this.column, this.backInColumn = false}) : assert(!backInColumn || column != null);

  /// The window's column while the page's controls are in it, or null when the app bar is used as usual.
  /// A [VerticalBarShell] draws a tab page's cells, centred on the rail; [VerticalBarCell.rect] gives
  /// their positions.
  final VerticalBarColumn? column;

  /// Whether the page's actions are in the column; the app bar should then omit them. Below a
  /// [VerticalBarShell] they are drawn while the page is the shell's current page.
  bool get active => column != null;

  /// Whether the column shows the back control; pass `automaticallyImplyLeading: !backInColumn`.
  final bool backInColumn;

  /// The slots of the nearest [VerticalBarPage], for widgets deep in the page such as a sliver app bar.
  ///
  /// Null outside a [VerticalBarPage].
  static VerticalBarSlots? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VerticalBarPageScope>()?.slots;

  @override
  bool operator ==(Object other) =>
      other is VerticalBarSlots && other.column == column && other.backInColumn == backInColumn;

  @override
  int get hashCode => Object.hash(column, backInColumn);

  @override
  String toString() => 'VerticalBarSlots(column: $column, backInColumn: $backInColumn)';
}

/// The back control placed first in the column.
///
/// Not an enum, so that other kinds, such as a custom action, can be added without a breaking change.
@immutable
// ignore: use_enums, see the class doc.
final class VerticalBarBack {
  const VerticalBarBack._(this._kind);

  /// Same rule as AppBar's implied leading: a back button when the route implies dismissal
  /// (`ModalRoute.impliesAppBarDismissal`), a close button for a fullscreen dialog. Pressing calls
  /// `Navigator.maybePop` with the page's context, so `PopScope` applies.
  static const VerticalBarBack automatic = VerticalBarBack._(_BackKind.automatic);

  /// No back control in the column; the app bar keeps its own leading.
  static const VerticalBarBack none = VerticalBarBack._(_BackKind.none);

  final _BackKind _kind;

  @override
  String toString() => 'VerticalBarBack.${_kind.name}';
}

enum _BackKind { automatic, none }

class _VerticalBarPageState extends State<VerticalBarPage> {
  static int _nextMountSerial = 0;

  /// Orders the pages by when their States were created: of two current pages below a shell, the
  /// later one owns the column.
  final int _mountSerial = _nextMountSerial++;

  /// The page subtree built for [_pageWidget] and [_pageSlots], reused while both are unchanged.
  Widget? _page;
  VerticalBarPage? _pageWidget;
  VerticalBarSlots? _pageSlots;

  late final TraversalPolicies _policies = TraversalPolicies(isColumn: _isColumnGroup);

  /// The column layer's group node, which the column-first policy sorts first.
  FocusNode? _columnGroup;

  /// The shell this page is registered with: while its slots there are active.
  _ShellRegistry? _shellRegistry;

  /// Listened to while registered, so that the shell learns when the page's branch is hidden or shown
  /// without this page depending on its [TickerMode].
  ValueListenable<TickerModeData>? _tickerNotifier;

  @override
  void deactivate() {
    // A page that moves is built again once it is active, and registers there.
    _leaveShell();
    super.deactivate();
  }

  @override
  void dispose() {
    _leaveShell();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugCheckActions(widget.actions));
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    final _BelowShell? belowShell;
    if (scope == null) {
      _leaveShell();
      belowShell = null;
    } else {
      // In this build, not in the frame below: a registration made inside a LayoutBuilder could reach
      // the shell only after its layout.
      final ancestorUsesColumn =
          context.dependOnInheritedWidgetOfExactType<_VerticalBarPageScope>()?.columnInUse ?? false;
      final registration = _registrationBelow(scope, ancestorUsesColumn: ancestorUsesColumn);
      if (registration == null) {
        _leaveShell();
      } else {
        _joinShell(scope.registry, registration);
      }
      belowShell = (slots: registration?.slots ?? const VerticalBarSlots(), ancestorUsesColumn: ancestorUsesColumn);
    }
    return LayoutBuilder(builder: (context, constraints) => _buildFrame(context, constraints, belowShell));
  }

  Widget _buildFrame(BuildContext context, BoxConstraints constraints, _BelowShell? belowShell) {
    final bool ancestorUsesColumn;
    final ColumnLayout? layout;
    final VerticalBarSlots slots;
    if (belowShell != null) {
      // The shell draws the cells, so both layers stay inactive and empty.
      ancestorUsesColumn = belowShell.ancestorUsesColumn;
      layout = null;
      slots = belowShell.slots;
    } else {
      ancestorUsesColumn = context.dependOnInheritedWidgetOfExactType<_VerticalBarPageScope>()?.columnInUse ?? false;
      layout = ancestorUsesColumn ? null : _layoutFor(context, constraints);
      slots = layout != null
          ? VerticalBarSlots(column: layout.column, backInColumn: layout.back != null)
          : const VerticalBarSlots();
    }
    final active = layout != null;
    final page = _cachedPage(slots);
    final ambient = _policies.ambientOf(context);
    final policy = active ? _policies.columnFirstOver(ambient) : ambient;
    // Only values change with the column, its edge, and its width; the tree keeps its shape so the
    // page keeps its State.
    //
    // Each layer is a group of its own under the ambient policy, so that focus orders inside it are
    // compared only with each other, as without this widget. The package adds no FocusTraversalOrder: one
    // would be the nearest order for every node below it without its own (FocusTraversalOrder.maybeOf
    // does not stop at groups), also where no column applies.
    return _VerticalBarPageScope(
      slots: slots,
      columnInUse: ancestorUsesColumn || slots.active,
      child: FocusTraversalGroup(
        policy: policy,
        child: Stack(
          alignment: Alignment.topLeft,
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            layerGroup(active: active, sortKey: const OrdinalSortKey(1), policy: ambient, child: page),
            _columnLayer(context, layout, ambient),
          ],
        ),
      ),
    );
  }

  /// [_page] for [slots]; see [_page] for when it is built again.
  Widget _cachedPage(VerticalBarSlots slots) {
    var page = _page;
    if (page == null || !identical(widget, _pageWidget) || slots != _pageSlots) {
      final builder = widget.builder;
      page = _page = Builder(builder: (context) => builder(context, slots));
      _pageWidget = widget;
      _pageSlots = slots;
    }
    return page;
  }

  /// The column layer above the page: the cells of [layout], or none, in the group that the column-first
  /// policy visits first. [context] is the LayoutBuilder's.
  Widget _columnLayer(BuildContext context, ColumnLayout? layout, FocusTraversalPolicy ambient) {
    return Positioned.fill(
      child: layerGroup(
        active: layout != null,
        sortKey: const OrdinalSortKey(0),
        policy: ambient,
        onFocusNodeCreated: (node) => _columnGroup = node,
        // Only the current page takes taps in its cells. The incoming route's modal barrier
        // already blocks taps on a lower page during a push; this also covers routes
        // without a barrier.
        child: IgnorePointer(
          ignoring: !(ModalRoute.isCurrentOf(context) ?? false),
          child: Material(
            type: MaterialType.transparency,
            child: ColumnCells(
              layout: layout,
              itemBuilder: widget.itemBuilder,
              backBuilder: widget.backBuilder,
              overflowBuilder: widget.overflowBuilder,
              groupDecoration: widget.groupDecoration,
              owner: CellOwner(
                page: this,
                canInvoke: () => _canInvoke,
                useRootNavigator: false,
                menuPosition: _menuPosition,
                waitsForTickers: () => _waitsForTickers,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isColumnGroup(FocusNode node) => identical(node, _columnGroup);

  /// The column's content, or null when this page leaves everything in the app bar.
  ColumnLayout? _layoutFor(BuildContext context, BoxConstraints constraints) {
    if (!widget.enabled) {
      return null;
    }
    final column = VerticalBarColumn.of(context);
    if (column == null) {
      return null;
    }
    // Before the route lookups, so that narrower pages, such as branch pages, add no dependencies.
    if ((constraints.maxWidth - column.viewSize.width).abs() > geometryTolerance) {
      return null;
    }
    final route = _pageRouteOf(context)?.route;
    if (route == null) {
      return null;
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (!osInsetCoversColumn(context, column, viewPadding)) {
      return null;
    }
    final controls = _controlsFor(route);
    if (controls == null) {
      return null;
    }
    final (:back, :actions) = controls;
    final arrangement = column.arrange(
      [if (back != null) 1, if (actions.isNotEmpty) actions.length],
      bottom: constraints.maxHeight - viewPadding.bottom,
      keepFirstGroup: back != null,
      pinned: pinnedIndices(actions, back: back != null),
    );
    if (arrangement == null) {
      return null;
    }
    return (column: column, arrangement: arrangement, back: back, actions: actions);
  }

  /// The back control the column shows for [route] and the actions with unique ids, or null when there is
  /// neither.
  ({BackGlyph? back, List<VerticalBarAction> actions})? _controlsFor(PageRoute<Object?> route) {
    final back = widget.back._kind == _BackKind.automatic && route.impliesAppBarDismissal
        ? (route.fullscreenDialog ? BackGlyph.close : BackGlyph.back)
        : null;
    final actions = uniqueVerticalBarActions(widget.actions);
    return back == null && actions.isEmpty ? null : (back: back, actions: actions);
  }

  /// The page's registration with [scope]'s shell, or null when its slots there are inactive. They are
  /// active when the page is enabled, the shell uses the column, no ancestor page uses it, the route is a
  /// [PageRoute] outside a Cupertino sheet in a Navigator whose holding route, if any, is opaque, there is a
  /// back control or an action, and a back control only where the shell reserves it. The window's width and
  /// the page's own inset are the shell's to check. Nothing here depends on which page owns the cells, on the
  /// rail, or on a keyboard. Registers nothing: [build] joins or leaves the shell.
  _ShellRegistration? _registrationBelow(_ShellScope scope, {required bool ancestorUsesColumn}) {
    final column = scope.used?.column;
    // Before the route lookups, so that pages below a shell that does not use the column add no
    // dependencies on their routes.
    if (!widget.enabled || column == null || ancestorUsesColumn) {
      return null;
    }
    // Depends on the route's status, so that the page registers again when the route stops or starts
    // being current.
    final pageRoute = _pageRouteOf(context);
    if (pageRoute == null) {
      return null;
    }
    final (:route, :navigator) = pageRoute;
    final controls = _controlsFor(route);
    if (controls == null || (controls.back != null && !scope.reservesBack)) {
      return null;
    }
    final (:back, :actions) = controls;
    // Last, so that a page that fails a check adds no dependency on its theme.
    return _ShellRegistration(
      route: route,
      isCurrent: route.isCurrent,
      navigator: navigator,
      slots: VerticalBarSlots(column: column, backInColumn: back != null),
      back: back,
      actions: actions,
      page: widget,
      theme: Theme.of(context),
    );
  }

  void _joinShell(_ShellRegistry registry, _ShellRegistration registration) {
    if (!identical(registry, _shellRegistry)) {
      _leaveShell();
      _shellRegistry = registry;
    }
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(notifier, _tickerNotifier)) {
      _tickerNotifier?.removeListener(_handleTickerModeChange);
      _tickerNotifier = notifier..addListener(_handleTickerModeChange);
    }
    registry.register(this, registration);
  }

  void _leaveShell() {
    _tickerNotifier?.removeListener(_handleTickerModeChange);
    _tickerNotifier = null;
    final registry = _shellRegistry;
    if (registry != null) {
      _shellRegistry = null;
      registry.unregister(this);
    }
  }

  void _handleTickerModeChange() {
    if (mounted) {
      _shellRegistry?.notify(context as Element);
    }
  }

  /// Whether both [_onTop] and [_tickerEnabled] are true. Read when an invoke runs, as the framework
  /// allows from callbacks; none of it adds a dependency.
  bool get _canInvoke => _onTop && _tickerEnabled;

  /// Whether the page is still there and on top of its Navigator and of every Navigator that holds it.
  bool get _onTop =>
      mounted && ModalRoute.isCurrentOf(context) != false && holdingRoutesCurrent(Navigator.maybeOf(context));

  /// Whether the page's tickers are enabled. Only while mounted.
  bool get _tickerEnabled => TickerMode.getValuesNotifier(context).value.enabled;

  /// Whether only disabled tickers keep the page from acting: while its branch is hidden, but also for a
  /// frame after an opaque route above it pops. That route leaves the routes at once, while its Overlay
  /// turns the tickers below it back on only when it next rebuilds.
  bool get _waitsForTickers => _onTop && !_tickerEnabled;

  /// [anchor], in this page's coordinates, relative to the overlay of the page's Navigator, where
  /// the menu opens; null before layout.
  RelativeRect? _menuPosition(Rect anchor) {
    final overlay = Navigator.maybeOf(context)?.overlay?.context.findRenderObject();
    final page = context.findRenderObject();
    if (overlay is! RenderBox || page is! RenderBox || !overlay.hasSize || !page.hasSize) {
      return null;
    }
    return relativeToOverlay(page, overlay, anchor);
  }
}

/// What a page below a [VerticalBarShell] decides in its build: its slots there, and whether an ancestor page
/// uses the column. Without a shell, the frame decides both.
typedef _BelowShell = ({VerticalBarSlots slots, bool ancestorUsesColumn});

/// The route of the page at [context] and the Navigator that holds it, when the route is a [PageRoute]
/// outside a Cupertino sheet and the route that holds the Navigator, if any, is opaque; else null.
({PageRoute<Object?> route, NavigatorState? navigator})? _pageRouteOf(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route is! PageRoute || CupertinoSheetRoute.hasParentSheet(context)) {
    return null;
  }
  // A Navigator inside a dialog or bottom sheet can be as wide as the window. Only the opaque aspect is
  // read: any other dependency of the Navigator on its route would make it rebuild every route it holds
  // whenever that route's status changes, for example on each root dialog.
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && ModalRoute.opaqueOf(navigator.context) == false) {
    return null;
  }
  return (route: route, navigator: navigator);
}

/// Checks in debug builds what the constructor cannot: unique ids and non-empty menus.
bool _debugCheckActions(List<VerticalBarAction> actions) {
  final ids = <Object>{};
  final duplicates = <Object>{
    for (final action in actions)
      if (!ids.add(action.id)) action.id,
  };
  if (duplicates.isNotEmpty) {
    throw FlutterError.fromParts([
      ErrorSummary('VerticalBarPage actions must have unique ids.'),
      ErrorDescription('Duplicated ids: ${duplicates.join(', ')}.'),
      ErrorHint('Release builds drop the later actions with the same id.'),
    ]);
  }
  final emptyMenus = [
    for (final action in actions)
      if (action.menuItems?.isEmpty ?? false) action.id,
  ];
  if (emptyMenus.isNotEmpty) {
    throw FlutterError.fromParts([
      ErrorSummary('VerticalBarAction.menuItems must not be empty.'),
      ErrorDescription('Actions with empty menus: ${emptyMenus.join(', ')}.'),
      ErrorHint('Release builds draw these actions disabled.'),
    ]);
  }
  return true;
}

/// Shares the page's slots, and whether it or an ancestor page uses the column, with descendants.
class _VerticalBarPageScope extends InheritedWidget {
  const _VerticalBarPageScope({required this.slots, required this.columnInUse, required super.child});

  final VerticalBarSlots slots;

  final bool columnInUse;

  @override
  bool updateShouldNotify(_VerticalBarPageScope oldWidget) =>
      oldWidget.slots != slots || oldWidget.columnInUse != columnInUse;
}
