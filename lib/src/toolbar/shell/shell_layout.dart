part of '../vertical_bar_toolbar.dart';

class _ShellParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out the shell's row, then its column layer over it.
class _ShellLayout extends MultiChildRenderObjectWidget {
  const _ShellLayout({
    required this.registry,
    required this.used,
    required this.ambient,
    required this.route,
    required this.routeCurrent,
    required super.children,
  });

  final _ShellRegistry registry;
  final _UsedColumn? used;
  final FocusTraversalPolicy ambient;

  /// The shell's route while the column is used.
  final ModalRoute<Object?>? route;

  /// Whether [route] was current when the shell built; true without one.
  final bool routeCurrent;

  @override
  _RenderShellLayout createRenderObject(BuildContext context) {
    final render = _RenderShellLayout(registry, used, ambient, routeCurrent: routeCurrent)..route = route;
    registry.layout = render;
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderShellLayout renderObject) {
    renderObject
      ..used = used
      ..ambient = ambient
      ..route = route
      ..routeCurrent = routeCurrent;
    registry.layout = renderObject;
  }

  @override
  void didUnmountRenderObject(_RenderShellLayout renderObject) {
    if (registry.layout == renderObject) {
      registry.layout = null;
    }
  }
}

/// Children: the row, then the column layer. Paints in that order and hit-tests the layer first.
class _RenderShellLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ShellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ShellParentData> {
  _RenderShellLayout(this.registry, this._used, this._ambient, {required this._routeCurrent});

  /// The pages and markers this shell reads after laying out its row.
  final _ShellRegistry registry;

  /// The shell's route while the column is used, read when an invoke runs and by the debug origin check.
  ModalRoute<Object?>? route;

  /// The owner's Navigator, whose back swipes make the cells inert.
  NavigatorState? _gestureNavigator;

  /// Whether the debug origin check is scheduled for the end of this frame.
  bool _debugOriginCheckScheduled = false;

  /// Whether the row is being laid out: a change that reaches the shell then is read after the row.
  bool layingOutRow = false;

  /// Counts the layouts that read the registrations, so that a deferred notification can tell whether
  /// one has read it since.
  int layoutSerial = 0;

  /// The page that owned the cells after the last layout.
  _VerticalBarPageState? _owner;

  /// The [_UsedColumn], or null where the shell lays out as a [RailSideRow].
  _UsedColumn? get used => _used;
  _UsedColumn? _used;

  set used(_UsedColumn? value) {
    if (value == _used) {
      return;
    }
    _used = value;
    markNeedsLayout();
  }

  FocusTraversalPolicy get ambient => _ambient;
  FocusTraversalPolicy _ambient;

  set ambient(FocusTraversalPolicy value) {
    if (identical(value, _ambient)) {
      return;
    }
    _ambient = value;
    markNeedsLayout();
  }

  /// Whether the shell's route was current when it built; the cells are inert while it is not.
  bool get routeCurrent => _routeCurrent;
  bool _routeCurrent;

  set routeCurrent(bool value) {
    if (value == _routeCurrent) {
      return;
    }
    _routeCurrent = value;
    markNeedsLayout();
  }

  @override
  void dispose() {
    _listenToGestures(null);
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ShellParentData) {
      child.parentData = _ShellParentData();
    }
  }

  RenderBox get _row => firstChild!;

  _RenderColumnLayer get _layer => lastChild! as _RenderColumnLayer;

  @override
  double computeMinIntrinsicWidth(double height) => _row.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _row.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _row.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _row.getMaxIntrinsicHeight(width);

  /// Whether the shell uses the column.
  bool get _active => _used != null;

  /// While the column is used, loose, so that a change inside the rail, such as a keyboard shrinking it,
  /// reaches this box in the same layout pass: a tightly constrained row would be a relayout boundary.
  /// Otherwise as given, so that the row centres children that do not fill its height, as a
  /// [RailSideRow] does.
  BoxConstraints _rowConstraints(BoxConstraints constraints) => _active ? constraints.loosen() : constraints;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_row.getDryLayout(_rowConstraints(constraints)));

  @override
  void performLayout() {
    layingOutRow = true;
    try {
      _row.layout(_rowConstraints(constraints), parentUsesSize: true);
    } finally {
      layingOutRow = false;
    }
    size = constraints.constrain(_row.size);
    var markerAwaitsLayout = false;
    // Reading render objects below the row and dirtying the layer before its layout are allowed only
    // inside a layout callback.
    invokeLayoutCallback<BoxConstraints>((_) {
      final (:info, :awaitsLayout) = _computeInfo();
      markerAwaitsLayout = awaitsLayout;
      if (info != _layer._info) {
        _layer._info = info;
        _layer.markNeedsLayout();
      }
    });
    layoutSerial++;
    // After the serial changes, so that the request outlives this layout.
    if (markerAwaitsLayout) {
      registry._layOutAfterFrame(this);
    }
    _layer.layout(BoxConstraints.tight(size), parentUsesSize: true);
    assert(!_active || _debugScheduleOriginCheck());
  }

  /// The column layer's info, and whether this box should lay out again after the frame for a marker not laid out yet
  /// (asked once per marker, [_readMarkerInLayout]).
  ({_LayerInfo info, bool awaitsLayout}) _computeInfo() {
    final used = _used;
    if (used == null) {
      _owner = null;
      _listenToGestures(null);
      return (info: _LayerInfo(active: false, ambient: _ambient), awaitsLayout: false);
    }
    // Before the owner is chosen, so that the markers' reports come first.
    final (reading: marker, :skipped, :awaitsLayout) = _readMarkerInLayout();
    final owner = _selectOwner();
    final registration = owner == null ? null : registry.pages[owner];
    _listenToGestures(registration?.navigator);
    if (owner == null || registration == null) {
      return (info: _LayerInfo(active: true, ambient: _ambient), awaitsLayout: awaitsLayout);
    }
    // A marker passed over below this box has its own error, or is read after the frame.
    assert(
      marker != null ||
          skipped ||
          registry._debugNote(
            _ShellDiagnostic.noMarker,
            'the rail holds no VerticalBarRailEnd, so only the reserved cells are used. Place one as '
            'NavigationRail.trailing or after the last destination in the rail\'s Column.',
          ),
    );
    final info = _LayerInfo(
      active: true,
      ambient: _ambient,
      owner: owner,
      registration: registration,
      layout: _arrange(used, registration, marker),
      interactive: registry.shellTickerEnabled && _routeCurrent && registration.idle,
    );
    return (info: info, awaitsLayout: awaitsLayout);
  }

  /// Listens to [navigator]'s back swipes in place of the previous owner's Navigator.
  void _listenToGestures(NavigatorState? navigator) {
    if (identical(navigator, _gestureNavigator)) {
      return;
    }
    // Allowed on a disposed notifier, as when the previous owner's Navigator has gone.
    _gestureNavigator?.userGestureInProgressNotifier.removeListener(_handleGestureChange);
    _gestureNavigator = navigator?..userGestureInProgressNotifier.addListener(_handleGestureChange);
  }

  void _handleGestureChange() {
    final shell = registry.shellElement;
    if (shell != null) {
      registry.notify(shell);
    }
  }

  /// The cells for [registration] beside a rail read as [marker].
  static ColumnLayout? _arrange(_UsedColumn used, _ShellRegistration registration, _RailReading? marker) {
    final back = registration.back != null;
    final arranged = arrangeBesideRail(
      column: used.column,
      floorTop: used.floorTop,
      railTop: marker?.top,
      railCentre: marker?.centre,
      back: back,
      actions: registration.actions.length,
      pinned: pinnedIndices(registration.actions, back: back),
    );
    return arranged == null
        ? null
        : (
            column: arranged.column,
            arrangement: arranged.arrangement,
            back: registration.back,
            actions: registration.actions,
          );
  }

  /// Called when a marker or this box paints: lays this box out again after the frame when the marker's
  /// current position gives the owner's cells another arrangement than the layer uses. Arrangements are
  /// compared, not positions, so that scrolling the rail, which moves the marker but not the cells, does
  /// not.
  ///
  /// A destination that moves behind a relayout boundary in the rail does not lay this box out, but it
  /// repaints the marker, or, when a repaint boundary holds the marker's Flex and reuses its layer, this box,
  /// unless another repaint boundary is between them.
  void checkFromPaint() {
    final used = _used;
    final info = _layer._info;
    final registration = info?.registration;
    if (!attached || used == null || info == null || info.owner == null || registration == null) {
      return;
    }
    // A layout after the frame is already due, as for a marker that was not laid out yet; it reads the
    // rail as painted now.
    if (registry.deferredLayoutPendingFor(layoutSerial)) {
      return;
    }
    // A registered marker is detached only while its element waits to unmount, after the paint;
    // [_ShellRegistry.dropMarker] then lays this box out after the frame.
    if (registry.markers.any((marker) => !marker.attached)) {
      return;
    }
    final arranged = _arrange(used, registration, _highest(_scanMarkers()));
    if (arranged?.arrangement == info.layout?.arrangement) {
      return;
    }
    assert(() {
      VerticalBarShellDebugStats.paintFixes++;
      return true;
    }());
    registry._layOutAfterFrame(this);
  }

  /// The page that owns the cells, stored in [_owner]. The kept owner is the previous one while it is
  /// registered.
  ///
  /// - While the shell's own tickers are disabled, as below an opaque route: the kept owner.
  /// - Else the latest mounted of the registered pages whose tickers are enabled and whose route is
  ///   current, with a debug note when there is more than one.
  /// - Else the kept owner while its tickers are enabled and its route is active, as below a popup (a
  ///   route being popped is not active); else none.
  _VerticalBarPageState? _selectOwner() {
    final kept = registry.pages.containsKey(_owner) ? _owner : null;
    final _VerticalBarPageState? owner;
    if (!registry.shellTickerEnabled) {
      owner = kept;
    } else {
      _VerticalBarPageState? latest;
      var current = 0;
      for (final MapEntry(key: page, value: registration) in registry.pages.entries) {
        if (!page._tickerEnabled || !registration.route.isCurrent) {
          continue;
        }
        current++;
        // Mount serials are unique, so the order of the pages does not matter.
        if (latest == null || page._mountSerial > latest._mountSerial) {
          latest = page;
        }
      }
      assert(
        current < 2 ||
            registry._debugNote(
              _ShellDiagnostic.ownerTie,
              'more than one VerticalBarPage below the shell is current with tickers enabled, so the one '
              'mounted last owns the column. Hide inactive branches with TickerMode, or give the other pages '
              'enabled: false.',
            ),
      );
      owner = latest ?? (kept != null && kept._tickerEnabled && registry.pages[kept]!.route.isActive ? kept : null);
    }
    return _owner = owner;
  }

  /// The highest marker's reading ([_highest]) for this layout.
  ///
  /// - Debug builds report a marker outside a [Flex], one in a [Flex] that spreads free space or adds
  ///   spacing, and a second marker.
  /// - `awaitsLayout`: a marker is not laid out yet, as one just added behind a relayout boundary in the
  ///   rail, which lays out after this box; this box lays out again after the frame, once per marker and
  ///   in release builds too.
  /// - `skipped`: a marker was passed over that has its own error or asked for that layout, so that the
  ///   no-marker note is not printed for it too.
  ({_RailReading? reading, bool skipped, bool awaitsLayout}) _readMarkerInLayout() {
    final entries = _scanMarkers().toList();
    var skipped = false;
    var awaitsLayout = false;
    var count = 0;
    for (final entry in entries) {
      switch (entry) {
        case _MarkerOutsideFlex(parent: final flex):
          skipped = true;
          assert(
            registry._debugReportError(_ShellDiagnostic.markerOutsideFlex, [
              ErrorSummary('A VerticalBarRailEnd must be a direct child of the Flex that holds the destinations.'),
              ErrorDescription(
                'Its parent is a ${flex.runtimeType}, so the shell cannot read the top of the rail\'s items.',
              ),
              ErrorHint(
                'Place it as NavigationRail.trailing, or as the last child of the Column that holds the '
                'destinations, without a widget around it. The shell ignores a marker anywhere else.',
              ),
            ]),
          );
        case _MarkerNotLaidOut(:final marker):
          // Once per marker: one that is never laid out, as in a covered route, would ask in every frame.
          if (!marker.layoutRequested) {
            marker.layoutRequested = true;
            awaitsLayout = true;
            skipped = true;
          }
        case _MarkerRead(:final flex):
          count++;
          assert(_debugCheckMarkerFlex(flex));
      }
    }
    assert(
      count < 2 ||
          registry._debugReportError(_ShellDiagnostic.secondMarker, [
            ErrorSummary('A VerticalBarShell found more than one VerticalBarRailEnd below it.'),
            ErrorDescription('It found $count markers; the rail holds one, after its last destination.'),
            ErrorHint('Release builds use the marker whose Flex is highest.'),
          ]),
    );
    return (reading: _highest(entries), skipped: skipped, awaitsLayout: awaitsLayout);
  }

  /// The registered markers below this box, in [_ShellRegistry.markers] order, each as this box can read
  /// it now. A marker outside a [Flex] is not read: its own top is the bottom of the destinations, so
  /// cells would cover them. It has no side effects, so it may be iterated more than once; the reports
  /// and layout requests are [_readMarkerInLayout]'s.
  Iterable<_MarkerEntry> _scanMarkers() sync* {
    for (final marker in registry.markers) {
      if (!marker.attached || !_isSelfOrAncestor(this, marker)) {
        continue;
      }
      final flex = marker.parent;
      if (flex is! RenderFlex) {
        yield _MarkerOutsideFlex(flex);
      } else if (!marker.hasSize) {
        yield _MarkerNotLaidOut(marker);
      } else {
        yield _MarkerRead(flex, _readingOf(marker, flex));
      }
    }
  }

  /// The top of [flex], never below its first child, less a bounce that pulls it down
  /// ([_bounceBelowRest]), and [marker]'s horizontal centre, relative to this box.
  _RailReading _readingOf(_RenderRailEnd marker, RenderFlex flex) {
    final toShell = marker.getTransformTo(this);
    final centre = MatrixUtils.transformPoint(toShell, marker.size.center(Offset.zero)).dx;
    final flexTop = MatrixUtils.transformPoint(flex.getTransformTo(this), Offset.zero).dy;
    final firstTop = MatrixUtils.transformPoint(flex.firstChild!.getTransformTo(this), Offset.zero).dy;
    final top = math.min(flexTop, firstTop) - _bounceBelowRest(marker);
    return (top: top, centre: centre);
  }

  /// The highest reading in [entries]; null without one. Of two markers at the same top, the first in
  /// [entries], so the first in [_ShellRegistry.markers], wins; debug builds report a second marker anyway.
  static _RailReading? _highest(Iterable<_MarkerEntry> entries) {
    _RailReading? highest;
    for (final entry in entries) {
      if (entry case _MarkerRead(:final reading) when highest == null || reading.top < highest.top) {
        highest = reading;
      }
    }
    return highest;
  }

  /// How far the scroll views between [marker] and this box have pulled it below where they can rest, as
  /// an iOS bounce at the rail's top does; 0 for none. Leaving it out keeps the cells as at rest, as
  /// scrolling does, while the items move away from them. A bounce that lifts the items is read as it
  /// is, so that the cells fold below the items' new top.
  double _bounceBelowRest(_RenderRailEnd marker) {
    final shell = registry.shellElement;
    var below = 0.0;
    marker.element?.visitAncestorElements((element) {
      if (identical(element, shell)) {
        return false;
      }
      if (element case StatefulElement(state: final ScrollableState scrollable)) {
        below += _pulledBelowRest(scrollable.position);
      }
      return true;
    });
    return below;
  }

  /// How far [position] has pulled its content below where it can rest; 0 for none, and while it has no
  /// pixels or content dimensions yet.
  static double _pulledBelowRest(ScrollPosition position) {
    if (!position.hasPixels || !position.hasContentDimensions) {
      return 0;
    }
    final beyond = position.pixels - clampDouble(position.pixels, position.minScrollExtent, position.maxScrollExtent);
    // How far the content is below where it would rest.
    final down = switch (position.axisDirection) {
      AxisDirection.down => -beyond,
      AxisDirection.up => beyond,
      AxisDirection.left || AxisDirection.right => 0.0,
    };
    return math.max(0, down);
  }

  /// Reports a marker in [flex] when that Flex spreads free space or adds spacing. Call it in an assert.
  bool _debugCheckMarkerFlex(RenderFlex flex) {
    const spreading = {MainAxisAlignment.spaceBetween, MainAxisAlignment.spaceAround, MainAxisAlignment.spaceEvenly};
    if (spreading.contains(flex.mainAxisAlignment) || flex.spacing != 0) {
      registry._debugReportError(_ShellDiagnostic.spreadingMarker, [
        ErrorSummary('A VerticalBarRailEnd is in a Flex that spreads free space or adds spacing.'),
        ErrorDescription(
          'The Flex has mainAxisAlignment ${flex.mainAxisAlignment.name} and spacing ${flex.spacing}, so the '
          'marker takes a share of the free space or a gap before it, which moves the destinations.',
        ),
        ErrorHint(
          'Place the marker in a Flex that aligns its children at the start, the end, or the centre, without '
          'spacing; put SizedBox gaps between the destinations instead.',
        ),
      ]);
    }
    return true;
  }

  /// Checks, once the frame has ended, that this box starts at the window's top-left corner and spans
  /// the window's width, as the cells are placed in window coordinates. Call it in an assert.
  bool _debugScheduleOriginCheck() {
    if (!_debugOriginCheckScheduled) {
      _debugOriginCheckScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _debugOriginCheckScheduled = false;
        _debugCheckOrigin();
      }, debugLabel: 'VerticalBarShell.originCheck');
    }
    return true;
  }

  void _debugCheckOrigin() {
    final column = _used?.column;
    final route = this.route;
    // A route in a transition or a back swipe moves this box with it, and so does a route of a Navigator
    // around the shell's, as with a ShellRoute around the tab shell. The check also returns, without a
    // report, where a Navigator around the shell's has a top route that is not a ModalRoute holding it,
    // such as a Navigator placed directly in an Overlay.
    if (!attached ||
        !hasSize ||
        column == null ||
        (route != null && !(routeAtRest(route) && holdingRoutesCurrent(route.navigator, test: routeAtRest)))) {
      return;
    }
    final origin = localToGlobal(Offset.zero);
    if (origin.dx.abs() <= geometryTolerance &&
        origin.dy.abs() <= geometryTolerance &&
        (size.width - column.viewSize.width).abs() <= geometryTolerance) {
      return;
    }
    registry._debugReportError(
      _ShellDiagnostic.origin,
      [
        ErrorSummary('A VerticalBarShell must start at the window\'s top-left corner and span its width.'),
        ErrorDescription(
          'It starts at (${origin.dx}, ${origin.dy}) and is ${size.width} wide in a window '
          '${column.viewSize.width} wide, so its cells are not where the column is.',
        ),
        ErrorHint(
          'Use it in place of the RailSideRow of a tab shell that fills the window; it may be shorter, as in '
          'a Scaffold body above a keyboard.',
        ),
      ],
      during: 'after a VerticalBarShell laid out',
    );
  }

  /// [anchor], in this box's coordinates, relative to the overlay of [root], where the menu opens; null
  /// before layout.
  RelativeRect? menuPosition(Rect anchor, NavigatorState root) {
    final overlay = root.overlay?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize || !attached || !hasSize) {
      return null;
    }
    return relativeToOverlay(this, overlay, anchor);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    checkFromPaint();
  }
}

/// The top of the rail's destinations and the rail's horizontal centre, relative to the shell.
typedef _RailReading = ({double top, double centre});

/// A registered marker below the shell, as [_RenderShellLayout._scanMarkers] found it.
sealed class _MarkerEntry {
  const _MarkerEntry();
}

/// A marker whose parent is not a [Flex]; it is not read.
final class _MarkerOutsideFlex extends _MarkerEntry {
  const _MarkerOutsideFlex(this.parent);

  final RenderObject? parent;
}

/// A marker in a [Flex] that is not laid out yet.
final class _MarkerNotLaidOut extends _MarkerEntry {
  const _MarkerNotLaidOut(this.marker);

  final _RenderRailEnd marker;
}

/// A laid-out marker in [flex], read as [reading].
final class _MarkerRead extends _MarkerEntry {
  const _MarkerRead(this.flex, this.reading);

  final RenderFlex flex;
  final _RailReading reading;
}
