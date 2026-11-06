part of '../vertical_bar_toolbar.dart';

/// What a [VerticalBarPage] below a shell hands to it in its build, compared by value so that an
/// unchanged page does not lay the shell out again.
@immutable
class _ShellRegistration {
  const _ShellRegistration({
    required this.route,
    required this.isCurrent,
    required this.navigator,
    required this.slots,
    required this.back,
    required this.actions,
    required this.page,
    required this.theme,
  });

  /// The page's route; the shell reads whether it is current or active when it chooses the owner.
  final PageRoute<Object?> route;

  /// Whether [route] was current when the page built. A route stops or starts being current without
  /// any other change, as when a push is popped before it completes, so the page registers again.
  final bool isCurrent;

  /// The page's Navigator.
  final NavigatorState? navigator;

  /// The slots the page builds with.
  final VerticalBarSlots slots;

  final BackGlyph? back;

  /// The page's actions with unique ids.
  final List<VerticalBarAction> actions;

  /// The page's widget, whose builders draw the cells; compared by identity.
  final VerticalBarPage page;

  /// The page's theme, so that a change of it builds the cells again.
  final ThemeData theme;

  /// Whether [route] is current and no back swipe runs in [navigator]. Read live.
  bool get idle => route.isCurrent && !(navigator?.userGestureInProgress ?? false);

  @override
  bool operator ==(Object other) =>
      other is _ShellRegistration &&
      identical(other.route, route) &&
      other.isCurrent == isCurrent &&
      identical(other.navigator, navigator) &&
      other.slots == slots &&
      other.back == back &&
      listEquals(other.actions, actions) &&
      identical(other.page, page) &&
      // ThemeData compares every field; Theme.of returns the same instance while the theme is unchanged.
      (identical(other.theme, theme) || other.theme == theme);

  @override
  int get hashCode => Object.hash(
    identityHashCode(route),
    isCurrent,
    identityHashCode(navigator),
    slots,
    back,
    Object.hashAll(actions),
    identityHashCode(page),
    theme,
  );
}

/// The kinds of debug diagnostics a shell reports, each once.
enum _ShellDiagnostic {
  deferredNotification,
  nestedPage,
  ownerTie,
  noMarker,
  secondMarker,
  spreadingMarker,
  markerOutsideFlex,
  origin,
}

/// What a [VerticalBarShell] shares with the pages, rail end markers, and rail below it.
///
/// Pages, markers, the shell's own TickerMode, and back swipes in the owner's Navigator report changes
/// with [notify], which lays the shell out again:
/// - at once from the shell's build scope (in the build phase, or in a layout callback above the shell);
/// - not at all while the shell lays out its row, since it reads everything after the row;
/// - else after the frame, as from a LayoutBuilder below the shell.
///
/// An unmounted marker ([dropMarker]) and a paint that finds the cells out of date
/// ([_RenderShellLayout.checkFromPaint]) also lay it out after the frame.
class _ShellRegistry {
  /// The shell's layout, while mounted.
  _RenderShellLayout? layout;

  /// The shell's element, set once its State is created.
  Element? shellElement;

  /// The column layer's group node, which the shell's column-first policy sorts first.
  FocusNode? columnGroup;

  /// The shell's own [TickerMode] values, which the shell listens to while it is in the tree; a change lays
  /// it out again only while it uses the column.
  ValueListenable<TickerModeData>? shellTicker;

  /// Whether the shell's tickers are enabled: false while a route covers the shell or it is in a hidden
  /// branch, when the shell keeps its owner, inert, instead of choosing again.
  bool get shellTickerEnabled => shellTicker?.value.enabled ?? true;

  /// The registered pages: those whose slots are active below this shell.
  final Map<_VerticalBarPageState, _ShellRegistration> pages = <_VerticalBarPageState, _ShellRegistration>{};

  /// The rail end markers below this shell.
  final Set<_RenderRailEnd> markers = <_RenderRailEnd>{};

  /// The diagnostics already reported.
  final Set<_ShellDiagnostic> _reported = <_ShellDiagnostic>{};

  bool _deferredLayoutScheduled = false;

  /// The layout's [_RenderShellLayout.layoutSerial] when a layout after the frame was last asked for.
  int _deferredSerial = 0;

  void register(_VerticalBarPageState page, _ShellRegistration registration) {
    if (pages[page] == registration) {
      return;
    }
    pages[page] = registration;
    notify(page.context as Element);
  }

  void unregister(_VerticalBarPageState page) {
    if (pages.remove(page) != null) {
      notify(page.context as Element);
    }
  }

  void addMarker(_RenderRailEnd marker, Element element) {
    if (markers.add(marker)) {
      notify(element);
    }
  }

  void removeMarker(_RenderRailEnd marker, Element element) {
    if (markers.remove(marker)) {
      notify(element);
    }
  }

  /// Whether [page] owns the cells that the column layer shows and they may act now: its registration is
  /// [_ShellRegistration.idle] and the shell's route is current. Read live, when an invoke runs.
  bool isInteractiveOwner(_VerticalBarPageState page) {
    final layout = this.layout;
    final registration = pages[page];
    return layout != null &&
        layout.attached &&
        identical(layout._layer._info?.owner, page) &&
        registration != null &&
        registration.idle &&
        (layout.route?.isCurrent ?? true);
  }

  /// Forgets an unmounted [marker] and lays the shell out again: behind a relayout boundary in the rail,
  /// nothing else would. Elements unmount after the frame's layout, where dirtying the shell would not
  /// schedule another frame, so it is laid out after the frame, from whichever build scope the marker
  /// was in.
  void dropMarker(_RenderRailEnd marker) {
    final layout = this.layout;
    if (markers.remove(marker) && layout != null && layout.attached) {
      _layOutAfterFrame(layout);
    }
  }

  /// Lays the shell out again for a change that [source] made.
  void notify(Element source) {
    final layout = this.layout;
    if (layout == null || !layout.attached || layout.layingOutRow) {
      return;
    }
    if (_mayDirtyNow(source, layout)) {
      layout.markNeedsLayout();
      return;
    }
    assert(() {
      VerticalBarShellDebugStats.deferredNotifications++;
      // An outer page builds inside its own LayoutBuilder, which the app cannot move.
      if (_debugInsidePageBelowShell(source)) {
        return _debugNote(
          _ShellDiagnostic.nestedPage,
          'a VerticalBarPage built inside another VerticalBarPage below the shell uses the column, so its '
          'cells follow a frame late. Remove the outer VerticalBarPage, or give it the actions and keep it '
          'enabled.',
        );
      }
      return _debugNote(
        _ShellDiagnostic.deferredNotification,
        'a change reached the shell from inside a LayoutBuilder below it, so its cells follow a frame late. '
        'Place each VerticalBarPage above the page\'s own LayoutBuilders.',
      );
    }());
    _layOutAfterFrame(layout);
  }

  /// Whether [layout] may be dirtied at once for a change that [source] made: [source] is in the shell's
  /// build scope and, in debug builds, no layout callback other than the shell's or an ancestor's is running.
  bool _mayDirtyNow(Element source, _RenderShellLayout layout) {
    var sameScope = identical(source.buildScope, shellElement?.buildScope);
    assert(() {
      // Inside a layout callback that is neither the shell's nor an ancestor's, the shell may not be
      // dirtied, as when a GlobalKey moves a page there.
      final activeLayout = RenderObject.debugActiveLayout;
      if (activeLayout != null && !_isSelfOrAncestor(activeLayout, layout)) {
        sameScope = false;
      }
      return true;
    }());
    return sameScope;
  }

  /// Whether [source] is below a [VerticalBarPage] that is itself below the shell. Call it in an assert.
  bool _debugInsidePageBelowShell(Element source) {
    final shell = shellElement;
    final page = source.getElementForInheritedWidgetOfExactType<_VerticalBarPageScope>();
    return shell != null && page != null && page.depth > shell.depth;
  }

  /// Lays [layout] out again once the frame has ended, unless it has been laid out since this call.
  void _layOutAfterFrame(_RenderShellLayout layout) {
    _deferredSerial = layout.layoutSerial;
    if (_deferredLayoutScheduled) {
      return;
    }
    _deferredLayoutScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _deferredLayoutScheduled = false;
        final current = this.layout;
        // A layout since the latest request has read the change.
        if (current != null && current.attached && current.layoutSerial == _deferredSerial) {
          current.markNeedsLayout();
        }
      }, debugLabel: 'VerticalBarShell.deferredLayout')
      ..ensureVisualUpdate();
  }

  /// Whether a layout after the frame is scheduled and was last asked for at layout [serial].
  bool deferredLayoutPendingFor(int serial) => _deferredLayoutScheduled && _deferredSerial == serial;

  /// Prints `VerticalBarShell: ` and [message] the first time for [kind]. Call it in an assert.
  bool _debugNote(_ShellDiagnostic kind, String message) {
    if (_reported.add(kind)) {
      debugPrint('VerticalBarShell: $message');
    }
    return true;
  }

  /// Reports an error made of [parts], found [during] what the shell did, the first time for [kind]. Call it
  /// in an assert.
  bool _debugReportError(
    _ShellDiagnostic kind,
    List<DiagnosticsNode> parts, {
    String during = 'while a VerticalBarShell read its rail',
  }) {
    if (_reported.add(kind)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts(parts),
          library: 'duo_rail_kit',
          context: ErrorDescription(during),
        ),
      );
    }
    return true;
  }
}

/// Whether [candidate] is [node] or one of its ancestors.
bool _isSelfOrAncestor(RenderObject candidate, RenderObject node) {
  for (RenderObject? current = node; current != null; current = current.parent) {
    if (identical(current, candidate)) {
      return true;
    }
  }
  return false;
}
