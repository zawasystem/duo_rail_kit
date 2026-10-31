import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A physical screen edge, independent of text direction.
enum HorizontalEdge { left, right }

/// Exposes the native edge for vertical navigation bars on iPhone Duo.
///
/// Reads iOS 27.1's `UITraitCollection.verticalBarEdge` through the plugin. Outer
/// portrait and inner landscape use the right edge; outer landscape can use
/// either edge; Split View uses each window's outer edge. Environments without
/// a vertical bar report null and can use an application-defined width fallback.
///
/// Receives native trait events and queries again when window size or viewPadding
/// changes, and when the app resumes. Wrap the application once, outside
/// `SideStatusBarInsets`, which also needs the edge:
/// `VerticalBarEdge(child: SideStatusBarInsets(child: ...))`.
///
/// Edges are physical left/right. Native leading/trailing values are converted
/// using UIKit's layout direction, so RTL does not swap the reported edges.
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

  /// Whether the native status bar is hidden.
  ///
  /// Used to decide whether the side column contains a status display. Unknown
  /// values, unsupported environments, and missing scopes default to false.
  /// [VerticalBarEdge] also resets this to false when there is no vertical edge.
  ///
  /// This is a sampled value, not an independent visibility stream. Native code
  /// reads it on queries and trait changes; Dart queries on size/viewPadding
  /// changes and app resume. A visibility-only change can remain stale until
  /// the next refresh.
  static bool statusBarHiddenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VerticalBarEdgeScope>()?.statusBarHidden ?? false;

  /// Parses the edge from a native payload.
  ///
  /// Payload: `{edge: "left" | "right" | "none", statusBarHidden: bool, sequence: int}`.
  /// Unknown values or payload shapes return null.
  @visibleForTesting
  static HorizontalEdge? parse(Object? value) => value is Map
      ? switch (value['edge']) {
          'left' => HorizontalEdge.left,
          'right' => HorizontalEdge.right,
          _ => null,
        }
      : null;

  /// Parses status-bar visibility; missing or non-boolean values return false.
  @visibleForTesting
  static bool parseStatusBarHidden(Object? value) => value is Map && value['statusBarHidden'] == true;

  @override
  State<VerticalBarEdge> createState() => _VerticalBarEdgeState();
}

class _VerticalBarEdgeState extends State<VerticalBarEdge> with WidgetsBindingObserver {
  /// The state that owns the channel's single method-call handler.
  ///
  /// A replacement state's initState can run before the old state's dispose.
  /// Only the current owner may remove the handler, or new events would be lost.
  static _VerticalBarEdgeState? _channelOwner;

  HorizontalEdge? _edge;

  /// Visibility sampled and ordered together with the edge value.
  bool _statusBarHidden = false;

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
    // A replacement state may already own the handler when this state disposes.
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

  /// Applies a native value while rejecting duplicate or older sequence numbers.
  ///
  /// Query replies and trait events may arrive out of creation order. Payloads
  /// without a sequence number remain compatible and use arrival order.
  /// When there is no vertical edge, normalize visibility to false to avoid
  /// irrelevant rebuilds on ordinary devices that hide their status bar.
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
    final statusBarHidden = edge != null && VerticalBarEdge.parseStatusBarHidden(value);
    if (edge == _edge && statusBarHidden == _statusBarHidden) {
      return;
    }
    setState(() {
      _edge = edge;
      _statusBarHidden = statusBarHidden;
    });
  }

  // Keep the inherited scope mounted so edge changes preserve descendant state.
  @override
  Widget build(BuildContext context) =>
      VerticalBarEdgeScope(edge: _edge, statusBarHidden: _statusBarHidden, child: widget.child);
}

/// Provides edge values to descendants; tests can inject a scope directly.
class VerticalBarEdgeScope extends InheritedWidget {
  const VerticalBarEdgeScope({super.key, required this.edge, this.statusBarHidden = false, required super.child});

  /// The physical native edge, or null when no vertical bar is used.
  final HorizontalEdge? edge;

  /// Sampled status-bar visibility; see [VerticalBarEdge.statusBarHiddenOf].
  final bool statusBarHidden;

  @override
  bool updateShouldNotify(VerticalBarEdgeScope oldWidget) =>
      oldWidget.edge != edge || oldWidget.statusBarHidden != statusBarHidden;
}
