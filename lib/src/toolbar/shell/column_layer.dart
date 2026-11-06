part of '../vertical_bar_toolbar.dart';

/// Everything the column layer's builder reads, compared by value so that the layer is rebuilt only
/// when it changes.
@immutable
class _LayerInfo {
  const _LayerInfo({
    required this.active,
    required this.ambient,
    this.owner,
    this.registration,
    this.layout,
    this.interactive = false,
  });

  /// Whether the shell uses the column.
  final bool active;

  /// The traversal policy around the shell, compared by identity.
  final FocusTraversalPolicy ambient;

  /// The page whose cells the layer draws, compared by identity; null for no cells.
  final _VerticalBarPageState? owner;

  /// What [owner] registered.
  final _ShellRegistration? registration;

  /// The cells for [owner]; null when none can be placed.
  final ColumnLayout? layout;

  /// Whether [owner]'s cells take taps, are reached by Tab, and are read: its route is current, no back
  /// swipe runs in its Navigator, and the shell's route is current and not covered.
  final bool interactive;

  @override
  bool operator ==(Object other) =>
      other is _LayerInfo &&
      other.active == active &&
      identical(other.ambient, ambient) &&
      identical(other.owner, owner) &&
      other.registration == registration &&
      other.layout == layout &&
      other.interactive == interactive;

  @override
  int get hashCode =>
      Object.hash(active, identityHashCode(ambient), identityHashCode(owner), registration, layout, interactive);
}

/// The column layer: built during the shell's layout, after the row, from the info the shell sets.
class _ColumnLayer extends AbstractLayoutBuilder<_LayerInfo> {
  const _ColumnLayer({required this.builder});

  @override
  final Widget Function(BuildContext context, _LayerInfo layoutInfo) builder;

  // The info carries every input, so a rebuilt shell does not rebuild the layer by itself.
  @override
  bool updateShouldRebuild(_ColumnLayer oldWidget) => false;

  @override
  _RenderColumnLayer createRenderObject(BuildContext context) => _RenderColumnLayer();
}

class _RenderColumnLayer extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<_LayerInfo, RenderBox> {
  _LayerInfo? _info;

  @override
  _LayerInfo get layoutInfo => _info!;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void performLayout() {
    runLayoutCallback();
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) {
      context.paintChild(child, offset);
    }
  }
}
