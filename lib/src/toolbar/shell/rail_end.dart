part of '../vertical_bar_toolbar.dart';

/// Marks the end of a rail's destinations for the nearest [VerticalBarShell].
///
/// Place it as the last child of the [Flex] that holds the destinations: as [NavigationRail.trailing]
/// with `trailingAtBottom: false` (the default), or after the last destination in a custom rail's
/// [Column]. The shell reads that Flex's top, never below its first destination, as the rail's top and
/// this marker's horizontal centre as the rail's. It has no height, intrinsic size, semantics, focus, or
/// hit area, so it can stay on every device. Debug builds report a second marker, a marker outside a
/// Flex, and a Flex that spreads free space or sets `spacing` (use [SizedBox] gaps instead of `spacing`).
///
/// Destinations that move without laying out the shell, as behind a relayout boundary in the rail, are
/// read when the marker or the shell paints. With a repaint boundary around the marker's Flex and another
/// between the shell and the part that moved, the cells can stay over the old place until the shell lays
/// out again.
class VerticalBarRailEnd extends LeafRenderObjectWidget {
  const VerticalBarRailEnd({super.key});

  @override
  RenderBox createRenderObject(BuildContext context) {
    final marker = _RenderRailEnd()..element = context as Element;
    _attach(context, marker);
    return marker;
  }

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) =>
      _attach(context, renderObject as _RenderRailEnd);

  @override
  void didUnmountRenderObject(RenderBox renderObject) {
    final marker = renderObject as _RenderRailEnd;
    marker.registry?.dropMarker(marker);
    marker
      ..registry = null
      ..element = null;
  }

  /// Registers [marker] with the nearest shell's registry, telling the shells only when it changes.
  void _attach(BuildContext context, _RenderRailEnd marker) {
    final registry = context.getInheritedWidgetOfExactType<_ShellScope>()?.registry;
    final element = context as Element;
    if (identical(registry, marker.registry)) {
      return;
    }
    marker.registry?.removeMarker(marker, element);
    marker.registry = registry;
    registry?.addMarker(marker, element);
  }
}

/// [VerticalBarRailEnd]'s box: the smallest size its parent allows, without intrinsic size, semantics,
/// or hit area. It paints nothing; painting asks the shell to check its cells against the rail.
class _RenderRailEnd extends RenderBox {
  /// The registry of the shell above, if any.
  _ShellRegistry? registry;

  /// The marker's element while mounted, whose scroll views the shell reads.
  Element? element;

  /// Whether the shell found this marker not laid out yet and asked to lay itself out once more.
  bool layoutRequested = false;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void paint(PaintingContext context, Offset offset) => registry?.layout?.checkFromPaint();
}
