import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/horizontal_edge.dart';
import 'bar_regions.dart';

/// Exposes the native edge for vertical navigation bars on iPhone Duo, with the system bar regions sampled with it.
///
/// Reads iOS 27.1's `UITraitCollection.verticalBarEdge` through the plugin, from native trait events and from queries
/// when the window size or view padding changes and when the app resumes. Where there is no vertical bar the edge is
/// null, and an application can fall back to a width rule. Edges are physical left/right: UIKit's leading/trailing is
/// converted with its layout direction, so right-to-left text does not swap them.
///
/// Wrap the application once, outside `SideStatusBarInsets`, which also needs the edge:
/// `VerticalBarEdge(child: SideStatusBarInsets(child: ...))`. Read the values with [of], [statusBarHiddenOf],
/// [TopBarRegion.of], and [VerticalBarRegion.of].
class VerticalBarEdge extends StatefulWidget {
  const VerticalBarEdge({super.key, required this.child});

  final Widget child;

  /// The channel shared with `DuoRailKitPlugin.swift`; keep both sides in sync.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('com.zawasystem.fleet/vertical_bar_edge');

  /// Requests the current native value; matches the Swift handler's method name.
  @visibleForTesting
  static const String getEdgeMethod = 'getEdge';

  /// Receives native updates; matches the Swift notification method name.
  @visibleForTesting
  static const String edgeChangedMethod = 'edgeChanged';

  /// The native edge, or null when no vertical bar or inherited scope is present.
  ///
  /// [VerticalBarEdgeScope] can provide the value directly in tests.
  static HorizontalEdge? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VerticalBarEdgeScope>()?.edge;

  /// Whether the native status bar is hidden, which decides whether the status column shows the status display.
  ///
  /// False without a vertical edge, for an unknown value, on other platforms, and without a scope. It is sampled with
  /// the edge, on queries and trait changes, so a change of visibility alone can stay stale until the next one.
  static bool statusBarHiddenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VerticalBarEdgeScope>()?.statusBarHidden ?? false;

  /// Parses the edge from a native payload; an unknown value or payload shape gives null.
  ///
  /// Payload: `{edge: "left" | "right" | "none", statusBarHidden: bool, sequence: int, topBar?, verticalBar?}`.
  @visibleForTesting
  static HorizontalEdge? parse(Object? value) => value is Map
      ? switch (value['edge']) {
          'left' => HorizontalEdge.left,
          'right' => HorizontalEdge.right,
          _ => null,
        }
      : null;

  /// Parses status bar visibility; missing or non-boolean values return false.
  @visibleForTesting
  static bool parseStatusBarHidden(Object? value) => value is Map && value['statusBarHidden'] == true;

  @override
  State<VerticalBarEdge> createState() => _VerticalBarEdgeState();
}

class _VerticalBarEdgeState extends State<VerticalBarEdge> with WidgetsBindingObserver {
  /// The channel handler's owner; only it removes the handler, as a new state's initState can precede the old dispose.
  static _VerticalBarEdgeState? _channelOwner;

  /// The applied sample: the edge with the visibility and bar regions parsed and ordered together with it.
  _Sample _sample = (edge: null, statusBarHidden: false, topBar: null, verticalBar: null);

  /// The last applied native sequence number; used to reject stale updates.
  int _sequence = 0;

  /// Window size and OS safe area at the last geometry-triggered query.
  (Size, EdgeInsets)? _geometry;

  /// Only iOS has the native trait; tests can override the target platform.
  bool get _supported => defaultTargetPlatform == TargetPlatform.iOS;

  /// Tracks observer registration independently of the overridable platform.
  bool _observingLifecycle = false;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _channelOwner = this;
      VerticalBarEdge.channel.setMethodCallHandler(_onNativeCall);
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_supported) {
      return;
    }
    // Query initially and on size/viewPadding changes, not keyboard-driven
    // viewInsets or padding changes.
    final geometry = (MediaQuery.sizeOf(context), MediaQuery.viewPaddingOf(context));
    if (geometry != _geometry) {
      _geometry = geometry;
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh on resume only; sequence checks still reject stale replies.
    if (state == AppLifecycleState.resumed && _supported) {
      _refresh();
    }
  }

  @override
  void dispose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    if (identical(_channelOwner, this)) {
      _channelOwner = null;
      VerticalBarEdge.channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    Object? value;
    try {
      value = await VerticalBarEdge.channel.invokeMethod<Object?>(VerticalBarEdge.getEdgeMethod);
    } on PlatformException {
      return;
    } on MissingPluginException {
      // Leave the current value unchanged if native code is unavailable.
      return;
    }
    _apply(value);
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == VerticalBarEdge.edgeChangedMethod) {
      _apply(call.arguments);
    }
  }

  /// Applies a native payload, dropping one whose sequence number is not newer than the last applied one.
  ///
  /// * Query replies and trait events can arrive out of order; a payload without a sequence number applies in
  ///   arrival order.
  /// * Without an edge, visibility is false, so devices that hide their status bar do not rebuild for it. The top bar
  ///   region is kept: Duo inner portrait has one without an edge.
  void _apply(Object? value) {
    if (!mounted) {
      return;
    }
    if (value is Map && value['sequence'] is int) {
      final sequence = value['sequence'] as int;
      if (sequence <= _sequence) {
        return;
      }
      _sequence = sequence;
    }
    final edge = VerticalBarEdge.parse(value);
    final sample = (
      edge: edge,
      statusBarHidden: edge != null && VerticalBarEdge.parseStatusBarHidden(value),
      topBar: parseTopBarRegion(value),
      verticalBar: parseVerticalBarRegion(value, edge),
    );
    if (sample == _sample) {
      return;
    }
    setState(() => _sample = sample);
  }

  // Keep both inherited scopes mounted so value changes preserve descendant state.
  // The scopes notify separately: a region-only change does not rebuild edge dependants.
  @override
  Widget build(BuildContext context) => VerticalBarEdgeScope(
    edge: _sample.edge,
    statusBarHidden: _sample.statusBarHidden,
    child: BarRegionScope(topBar: _sample.topBar, verticalBar: _sample.verticalBar, child: widget.child),
  );
}

/// One native payload as [_VerticalBarEdgeState] applies it.
typedef _Sample = ({HorizontalEdge? edge, bool statusBarHidden, TopBarRegion? topBar, VerticalBarRegion? verticalBar});

/// Provides edge values to descendants; tests can inject a scope directly.
class VerticalBarEdgeScope extends InheritedWidget {
  const VerticalBarEdgeScope({super.key, required this.edge, this.statusBarHidden = false, required super.child});

  /// The physical native edge, or null when no vertical bar is used.
  final HorizontalEdge? edge;

  /// Sampled status bar visibility; see [VerticalBarEdge.statusBarHiddenOf].
  final bool statusBarHidden;

  @override
  bool updateShouldNotify(VerticalBarEdgeScope oldWidget) =>
      oldWidget.edge != edge || oldWidget.statusBarHidden != statusBarHidden;
}
