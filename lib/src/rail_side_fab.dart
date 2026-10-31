import 'package:flutter/material.dart';

/// Shares FAB placement settings with content beside a bottom-aligned system rail.
///
/// Use [locationOf] for the content Scaffold and [enabledOf] to reserve space in
/// scrollable content. The FAB sits [RailSideFabLocation.bottomMargin] above the
/// content bottom without adding the bottom safe-area inset.
///
/// Always keep this wrapper in the tree and change only [enabled]; conditionally
/// wrapping content can recreate its state. Enable it only beside a bottom-aligned
/// rail that follows the system edge, not for width-based rails or bottom bars.
/// Read these helpers from a context below this widget.
class RailSideFab extends InheritedWidget {
  const RailSideFab({super.key, required this.enabled, required super.child});

  /// Whether the content is beside a bottom-aligned system rail.
  final bool enabled;

  /// Whether an enabled [RailSideFab] is above [context]; false if absent.
  ///
  /// Use the same signal as [locationOf] to keep content clear of the FAB. When
  /// true, reserve the FAB height plus [RailSideFabLocation.bottomMargin] above
  /// the content bottom, without adding the bottom safe-area inset.
  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RailSideFab>()?.enabled ?? false;

  /// The [Scaffold.floatingActionButtonLocation], or null for default placement.
  static FloatingActionButtonLocation? locationOf(BuildContext context) =>
      enabledOf(context) ? const RailSideFabLocation() : null;

  @override
  bool updateShouldNotify(RailSideFab oldWidget) => oldWidget.enabled != enabled;
}

/// Places the FAB [bottomMargin] above the Scaffold's content bottom.
///
/// The content bottom may be the screen edge, an application panel, or the
/// keyboard. The bottom safe-area inset is not added: with an inset of 34 and no
/// panel or keyboard, the FAB overlaps that band by 10 logical pixels.
/// Horizontal placement follows [FloatingActionButtonLocation.endFloat],
/// including its RTL behavior.
///
/// Use `const RailSideFabLocation()`. A fresh instance is unequal by identity and
/// can trigger an unwanted Scaffold FAB transition on every rebuild.
class RailSideFabLocation extends FloatingActionButtonLocation {
  const RailSideFabLocation();

  /// The gap, in logical pixels, between the FAB bottom and the content bottom.
  static const double bottomMargin = 24;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) => Offset(
    FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry).dx,
    scaffoldGeometry.contentBottom - bottomMargin - scaffoldGeometry.floatingActionButtonSize.height,
  );

  @override
  String toString() => 'RailSideFabLocation';
}
