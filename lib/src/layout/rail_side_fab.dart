import 'package:flutter/material.dart'; // ignore: deprecated_member_use, unnecessary_ignore

/// Shares FAB placement with content beside a bottom-aligned rail that follows the system bar.
///
/// Use [locationOf] for the content Scaffold and [enabledOf] to reserve space in scrollable content, both from a
/// context below this widget. The FAB sits [RailSideFabLocation.bottomMargin] above the content bottom, without the
/// bottom safe-area inset.
///
/// Always keep this widget in the tree and change only [enabled]; wrapping the content conditionally can recreate its
/// state. Leave it disabled for width-based rails and bottom bars.
class RailSideFab extends InheritedWidget {
  const RailSideFab({super.key, required this.enabled, required super.child});

  /// Whether the content is beside a bottom-aligned rail that follows the system bar.
  final bool enabled;

  /// Whether an enabled [RailSideFab] is above [context]; false if absent.
  ///
  /// Use it with [locationOf] to keep content clear of the FAB: when true, reserve the FAB height plus
  /// [RailSideFabLocation.bottomMargin] above the content bottom, without the bottom safe-area inset.
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
/// The content bottom may be the screen edge, an application panel, or the keyboard. The bottom safe-area inset is not
/// added: with an inset of 34 logical pixels and no panel or keyboard, the FAB overlaps that band by 10. Horizontal
/// placement follows [FloatingActionButtonLocation.endFloat], including its right-to-left behaviour.
///
/// Use `const RailSideFabLocation()`: a new instance is unequal by identity and can start a Scaffold FAB transition on
/// every rebuild.
class RailSideFabLocation extends FloatingActionButtonLocation {
  const RailSideFabLocation();

  /// The gap between the FAB bottom and the content bottom.
  static const double bottomMargin = 24;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) => Offset(
    FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry).dx,
    scaffoldGeometry.contentBottom - bottomMargin - scaffoldGeometry.floatingActionButtonSize.height,
  );

  @override
  String toString() => 'RailSideFabLocation';
}
