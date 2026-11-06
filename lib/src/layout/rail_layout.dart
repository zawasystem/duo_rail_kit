/// @docImport '../edge/bar_regions.dart';
library;

import 'package:flutter/widgets.dart';

import '../core/horizontal_edge.dart';
import 'rail_placement.dart';

/// A rail's placement, width, and safe area, read together from one context.
///
/// [RailLayout.of] makes the [RailPlacement] calls a rail needs in a fixed order and keeps their results, so the rail,
/// the body, and adjacent overlays use the same values: [occupiedWidth] and [centredSafeArea] always take the
/// [safeArea] read here, and without a rail the getters return neutral values (no edge, 0, [safeArea]). Widths are in
/// logical pixels.
///
/// Call it in the context that sizes the rail, before the body's occupied horizontal inset is removed (the context in
/// which [RailPlacement.railSafeAreaOf] would be read). [RailPlacement] stays the lower-level API.
@immutable
class RailLayout {
  const RailLayout._({required this.placement, required this.width, required this.safeArea});

  /// Reads the rail layout for [context].
  ///
  /// Reads [RailPlacement.of] with [showsRailByWidth], then [RailPlacement.railSafeAreaOf] with [receivesAddedTop].
  /// [railWidth] is the width of a width-based rail; a rail that follows the system bar uses [systemRailWidth]
  /// instead, which defaults to [RailPlacement.systemRailWidth]. Both must be greater than 0. Pass
  /// [RailPlacement.statusColumnWidth] as [systemRailWidth] to keep a system rail at the status column's width.
  factory RailLayout.of(
    BuildContext context, {
    required bool Function(double windowWidth) showsRailByWidth,
    required double railWidth,
    double systemRailWidth = RailPlacement.systemRailWidth,
    bool receivesAddedTop = false,
  }) {
    final placement = RailPlacement.of(context, showsRailByWidth: showsRailByWidth);
    final safeArea = RailPlacement.railSafeAreaOf(context, receivesAddedTop: receivesAddedTop);
    return RailLayout._(
      placement: placement,
      width: placement?.followsSystemBar == true ? systemRailWidth : railWidth,
      safeArea: safeArea,
    );
  }

  /// The rail's placement, or null for bottom navigation.
  final RailPlacement? placement;

  /// The rail's own width: `systemRailWidth` while the rail follows the system bar, else `railWidth`, also without a
  /// rail. Greater than 0 when the widths passed to [RailLayout.of] are, so it can be a `NavigationRail.minWidth`.
  final double width;

  /// The safe area from [RailPlacement.railSafeAreaOf], used to size and position the rail.
  final EdgeInsets safeArea;

  /// The physical edge containing the rail, or null without a rail.
  HorizontalEdge? get edge => placement?.edge;

  /// Whether the rail follows the native vertical bar edge; false without a rail.
  bool get followsSystemBar => placement?.followsSystemBar ?? false;

  /// Width the rail occupies from the screen edge, from [RailPlacement.occupiedWidth]; 0 without a rail.
  double get occupiedWidth => placement?.occupiedWidth(safeArea, width) ?? 0;

  /// The rail's MediaQuery padding, from [RailPlacement.centredRailSafeArea]; [safeArea] without a rail.
  EdgeInsets get centredSafeArea => placement?.centredRailSafeArea(safeArea) ?? safeArea;

  /// The window of [windowSize] without [occupiedWidth] on the rail's edge, in window coordinates, as
  /// [TopBarRegion.paddingFor] expects.
  Rect contentRect(Size windowSize) => Rect.fromLTRB(
    edge == HorizontalEdge.left ? occupiedWidth : 0,
    0,
    windowSize.width - (edge == HorizontalEdge.right ? occupiedWidth : 0),
    windowSize.height,
  );

  /// [data] without the padding on the rail's edge, for the body beside the rail.
  MediaQueryData removeRailEdge(MediaQueryData data) =>
      data.removePadding(removeLeft: edge == HorizontalEdge.left, removeRight: edge == HorizontalEdge.right);

  @override
  bool operator ==(Object other) =>
      other is RailLayout && other.placement == placement && other.width == width && other.safeArea == safeArea;

  @override
  int get hashCode => Object.hash(placement, width, safeArea);

  @override
  String toString() => 'RailLayout(placement: $placement, width: $width, safeArea: $safeArea)';
}
