/// @docImport '../edge/bar_regions.dart';
/// @docImport 'rail_layout.dart';
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/horizontal_edge.dart';
import '../edge/vertical_bar_edge.dart';
import 'side_status_bar_insets.dart';

/// Selects a rail's physical edge, occupied width, and safe-area padding.
///
/// Use the same placement and safe-area values for the rail and adjacent overlays, so that widths match and no spacing
/// is left over when the rail is absent. [RailLayout] reads both together from one context. Values are logical pixels.
@immutable
class RailPlacement {
  const RailPlacement({required this.edge, required this.followsSystemBar, this.statusBarHidden = false});

  /// Lower edge of the status display in the status column.
  ///
  /// One conservative value for every Duo screen (the inner display's ends near 98, the outer's near 151): the window
  /// size cannot tell outer portrait from Split View, and UIKit's `statusBarFrame` does not cover the status column.
  /// [centredRailSafeArea] reserves it while the status bar is visible, so centred destinations can sit lower than
  /// needed on the inner display.
  static const double statusColumnBottom = 152;

  /// Width of the status column on every Duo screen that has one; matches UIKit on iPhone Duo.
  ///
  /// A rail that follows the system bar uses [systemRailWidth] instead.
  static const double statusColumnWidth = 84;

  /// Width of a rail that follows the system bar.
  ///
  /// Flush with its edge, the rail is centred 48 from that edge, on the vertical bar's items ([VerticalBarRegion]) and
  /// the status display. [occupiedWidth] therefore takes 12 more than [statusColumnWidth] from the body.
  static const double systemRailWidth = 96;

  /// The physical edge containing the rail.
  final HorizontalEdge edge;

  /// Whether the rail follows the native vertical bar edge.
  ///
  /// A rail that follows it covers that edge's status column ([occupiedWidth]); a width-based rail sits left of the
  /// body, after the left inset. Centred and tall bottom-aligned destinations need [centredRailSafeArea].
  final bool followsSystemBar;

  /// Whether the system status bar is hidden, from [VerticalBarEdge.statusBarHiddenOf].
  ///
  /// Relevant only when [followsSystemBar] is true; false for width-based rails. Duo outer landscape keeps a status
  /// column while it hides the status display.
  final bool statusBarHidden;

  /// Selects the rail placement for [context], or null for bottom navigation.
  ///
  /// A native edge from [VerticalBarEdge.of] takes precedence. Otherwise, [showsRailByWidth] selects a left rail or no
  /// rail from the full window width ([MediaQuery.sizeOf]), not from a pane's layout constraints.
  static RailPlacement? of(BuildContext context, {required bool Function(double windowWidth) showsRailByWidth}) {
    final systemEdge = VerticalBarEdge.of(context);
    if (systemEdge != null) {
      return RailPlacement(
        edge: systemEdge,
        followsSystemBar: true,
        statusBarHidden: VerticalBarEdge.statusBarHiddenOf(context),
      );
    }
    if (showsRailByWidth(MediaQuery.sizeOf(context).width)) {
      return const RailPlacement(edge: HorizontalEdge.left, followsSystemBar: false);
    }
    return null;
  }

  /// The safe area that sizes and positions the rail.
  ///
  /// With [receivesAddedTop] false, the spacing added by [SideStatusBarInsets] is removed. With true, it is kept only
  /// where the OS safe area has exactly one horizontal inset, for example to align the rail's first controls with an
  /// AppBar; the column-free left Split View window always gets the OS insets, so its rail does not move when the body
  /// gets top spacing.
  ///
  /// Read it in the shell's or rail's [context], before the body's occupied horizontal inset is removed, and pass this
  /// same value to [occupiedWidth] and [centredRailSafeArea].
  static EdgeInsets railSafeAreaOf(BuildContext context, {required bool receivesAddedTop}) {
    final padding = MediaQuery.paddingOf(context);
    final os = SideStatusBarInsets.removeAdded(context, padding);
    return receivesAddedTop && SideStatusBarInsets.applies(os) ? padding : os;
  }

  /// Width the rail occupies from the screen edge, safe area included.
  ///
  /// [railSafeArea] must come from [railSafeAreaOf]; [railWidth] is the rail's own width. A width-based rail adds its
  /// width to the edge's inset. A rail that follows the system bar covers the status column and takes the larger of
  /// the two, also where Split View gives that edge no status column.
  double occupiedWidth(EdgeInsets railSafeArea, double railWidth) {
    final inset = edge.insetOf(railSafeArea);
    return followsSystemBar ? math.max(inset, railWidth) : inset + railWidth;
  }

  /// MediaQuery padding for a centred or tall bottom-aligned rail.
  ///
  /// [railSafeArea] must come from [railSafeAreaOf]; pass that original value, not this result, to [occupiedWidth].
  /// Width-based rails get it unchanged. Rails that follow the system bar drop their own edge's inset, which the outer
  /// box already covers, and, while that edge has a status column with a visible status bar, raise the top to at least
  /// [statusColumnBottom]. A rail taller than the remaining height must scroll, for example
  /// `NavigationRail(scrollable: true)`.
  ///
  /// Without it, the application must drop the rail's own inset and keep its controls below the status display itself.
  EdgeInsets centredRailSafeArea(EdgeInsets railSafeArea) {
    if (!followsSystemBar) {
      return railSafeArea;
    }
    final ownEdgeInset = edge.insetOf(railSafeArea);
    final withoutOwnEdge = edge.withoutInset(railSafeArea);
    if (ownEdgeInset <= 0 || statusBarHidden) {
      return withoutOwnEdge;
    }
    return withoutOwnEdge.copyWith(top: math.max(withoutOwnEdge.top, statusColumnBottom));
  }

  @override
  bool operator ==(Object other) =>
      other is RailPlacement &&
      other.edge == edge &&
      other.followsSystemBar == followsSystemBar &&
      other.statusBarHidden == statusBarHidden;

  @override
  int get hashCode => Object.hash(edge, followsSystemBar, statusBarHidden);

  @override
  String toString() =>
      'RailPlacement(edge: $edge, followsSystemBar: $followsSystemBar, statusBarHidden: $statusBarHidden)';
}
