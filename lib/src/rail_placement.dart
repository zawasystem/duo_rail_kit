import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'side_status_bar_insets.dart';
import 'vertical_bar_edge.dart';

/// Selects a rail's physical edge, occupied width, and safe-area padding.
///
/// Use the same placement and safe-area values for the rail and adjacent overlays
/// to avoid mismatched widths or leftover spacing when the rail is absent.
@immutable
class RailPlacement {
  const RailPlacement({required this.edge, required this.followsSystemBar, this.statusBarHidden = false});

  /// Conservative lower boundary of the visible status display, in logical pixels.
  ///
  /// Measured on the iOS 27.1 Duo simulator: the inner display ends near 98 and
  /// outer portrait near 151. A shared 152-pixel boundary covers both because
  /// window size cannot reliably distinguish outer portrait from Split View,
  /// and UIKit's statusBarFrame does not describe the vertical column.
  ///
  /// [centredRailSafeArea] reserves this band when the status bar is visible.
  /// It may place centered items lower, or make tall bottom-aligned groups
  /// scroll sooner, than strictly necessary on the inner display.
  static const double statusColumnBottom = 152;

  /// Width of the side status column, in logical pixels.
  ///
  /// Measured as 84 on the iOS 27.1 Duo simulator in inner landscape, outer
  /// portrait/landscape, and right Split View. Use this as the system rail width
  /// so [occupiedWidth] consumes the column once without narrowing the body again.
  static const double statusColumnWidth = 84;

  /// The physical edge containing the rail.
  final HorizontalEdge edge;

  /// Whether the rail follows the native vertical-bar edge.
  ///
  /// A system rail fits inside that edge's safe-area column via [occupiedWidth].
  /// A width-based fallback rail sits left of the body, after the edge's inset.
  /// The application chooses item alignment; centered or tall bottom-aligned
  /// groups should use [centredRailSafeArea].
  final bool followsSystemBar;

  /// Whether the system status bar is hidden, from [VerticalBarEdge.statusBarHiddenOf].
  ///
  /// Relevant only when [followsSystemBar] is true; false for width-based rails.
  /// Duo outer landscape retains a side column while hiding its status display.
  final bool statusBarHidden;

  /// Selects the rail placement for [context], or null for bottom navigation.
  ///
  /// A native edge from [VerticalBarEdge.of] takes precedence. Otherwise,
  /// [showsRailByWidth] selects a left rail or no rail using the full window
  /// width from [MediaQuery.sizeOf], not a pane's layout constraints.
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

  /// Returns the safe area used to size and position the rail.
  ///
  /// With [receivesAddedTop] false, removes the spacing added by
  /// [SideStatusBarInsets]. With true, keeps it only for a single-column shape,
  /// for example to align leading rail controls with an AppBar. A column-free
  /// left Split View window always uses the original OS insets so its rail
  /// does not move when top spacing is added to the body.
  ///
  /// Read from the shell or rail [context], before removing the body's occupied
  /// horizontal inset. Pass this same result to [occupiedWidth].
  static EdgeInsets railSafeAreaOf(BuildContext context, {required bool receivesAddedTop}) {
    final padding = MediaQuery.paddingOf(context);
    final os = SideStatusBarInsets.removeAdded(context, padding);
    return receivesAddedTop && SideStatusBarInsets.applies(os) ? padding : os;
  }

  /// Width occupied from the screen edge, including any relevant safe area.
  ///
  /// [railSafeArea] must come from [railSafeAreaOf]; [railWidth] is the rail's
  /// fixed width. A width-based rail adds its width to the edge inset. A system
  /// rail fits inside the column and takes the larger of its width and the inset,
  /// including when Split View provides no column on that edge.
  double occupiedWidth(EdgeInsets railSafeArea, double railWidth) {
    final inset = edge == HorizontalEdge.left ? railSafeArea.left : railSafeArea.right;
    return followsSystemBar ? math.max(inset, railWidth) : inset + railWidth;
  }

  /// MediaQuery padding for a centered or tall bottom-aligned rail.
  ///
  /// [railSafeArea] must come from [railSafeAreaOf]. Pass the original value,
  /// not this adjusted result, to [occupiedWidth].
  ///
  /// Width-based rails keep their safe area. System rails clear their own edge's
  /// inset because the outer box already accounts for that column. Counting it
  /// again inside a SafeArea can collapse a left rail's available width.
  /// The opposite edge and bottom remain unchanged.
  ///
  /// Only when the rail's column exists and its status bar is visible is the
  /// top raised to at least [statusColumnBottom]. Column-free Split View and hidden
  /// status bars add no band. Bottom-aligned groups that already fit below the
  /// band stay in place; taller groups need a scrollable rail, such as
  /// `NavigationRail(scrollable: true)`.
  ///
  /// Use this for centered rails and bottom-aligned groups that may reach the
  /// status display at large text sizes or with a keyboard-shortened window.
  /// If omitted, the application must clear the rail's own horizontal inset and
  /// verify that its controls stay below the status display in every layout.
  EdgeInsets centredRailSafeArea(EdgeInsets railSafeArea) {
    if (!followsSystemBar) {
      return railSafeArea;
    }
    final onLeft = edge == HorizontalEdge.left;
    final ownEdgeInset = onLeft ? railSafeArea.left : railSafeArea.right;
    final withoutOwnEdge = onLeft ? railSafeArea.copyWith(left: 0) : railSafeArea.copyWith(right: 0);
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
