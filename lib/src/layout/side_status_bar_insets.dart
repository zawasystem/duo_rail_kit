/// @docImport 'rail_layout.dart';
/// @docImport 'rail_placement.dart';
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../edge/vertical_bar_edge.dart';

/// Adds top safe-area spacing to windows with a side status bar.
///
/// Where [applies] holds for the OS padding, raises the top of MediaQuery's padding and viewPadding to at least
/// [minTop], so AppBars, SafeAreas, dialogs, and sheets stay aligned; left, right, and bottom are unchanged. It is a
/// geometry rule, not a device check. Rails read the OS values with [removeAdded], [RailPlacement.railSafeAreaOf], or
/// [RailLayout.of].
///
/// Wrap the application once, inside [VerticalBarEdge]: `VerticalBarEdge(child: SideStatusBarInsets(child: ...))`.
/// The native edge is null until the first native reply, so the column-free left Split View window gets its spacing
/// only then; a window with one status column gets it from its geometry at once.
class SideStatusBarInsets extends StatelessWidget {
  const SideStatusBarInsets({super.key, required this.child});

  final Widget child;

  /// Minimum top spacing, in logical pixels, to keep controls off the screen edge.
  static const double minTop = 16;

  /// Whether the original OS [padding] needs top spacing.
  ///
  /// Requires a zero top inset and either exactly one horizontal inset, or none with [systemBarEdge] true (such as
  /// the left Split View window). Two horizontal insets are always excluded; status bar visibility does not matter.
  static bool applies(EdgeInsets padding, {bool systemBarEdge = false}) =>
      padding.top == 0 &&
      (((padding.left > 0) != (padding.right > 0)) || (systemBarEdge && padding.left == 0 && padding.right == 0));

  /// Raises [padding]'s top to [minTop] when [applies]; leaves other edges unchanged.
  static EdgeInsets adjust(EdgeInsets padding, {bool systemBarEdge = false}) {
    if (!applies(padding, systemBarEdge: systemBarEdge)) {
      return padding;
    }
    return padding.copyWith(top: math.max(padding.top, minTop));
  }

  /// The top inset added above [context], or [EdgeInsets.zero] if none was added.
  static EdgeInsets addedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SideStatusBarScope>()?.added ?? EdgeInsets.zero;

  /// Subtracts this wrapper's added inset from [padding], clamping at zero.
  ///
  /// For components, such as rails, that need the OS safe area.
  static EdgeInsets removeAdded(BuildContext context, EdgeInsets padding) {
    final added = addedOf(context);
    return EdgeInsets.fromLTRB(
      math.max(0, padding.left - added.left),
      math.max(0, padding.top - added.top),
      math.max(0, padding.right - added.right),
      math.max(0, padding.bottom - added.bottom),
    );
  }

  /// Whether this wrapper added spacing above [context].
  ///
  /// True does not imply a status column: the column-free left Split View window gets spacing too. To detect a
  /// column, read the horizontal insets that [removeAdded] restores; the adjusted MediaQuery top cannot tell.
  static bool isActiveOf(BuildContext context) => addedOf(context) != EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    // Keyboard changes affect the bottom only; use padding to test the top and
    // horizontal insets, then apply the same top adjustment to viewPadding.
    final padding = adjust(data.padding, systemBarEdge: VerticalBarEdge.of(context) != null);
    final view = data.viewPadding;
    // Keep the scope and MediaQuery even when no adjustment is needed. Changing
    // wrapper types would recreate descendant state as geometry or the edge changes.
    return _SideStatusBarScope(
      added: padding - data.padding,
      child: MediaQuery(
        data: padding == data.padding
            ? data
            : data.copyWith(
                padding: padding,
                viewPadding: view.copyWith(top: math.max(view.top, padding.top)),
              ),
        child: child,
      ),
    );
  }
}

/// Exposes the inset added by [SideStatusBarInsets] to descendants.
class _SideStatusBarScope extends InheritedWidget {
  const _SideStatusBarScope({required this.added, required super.child});

  final EdgeInsets added;

  @override
  bool updateShouldNotify(_SideStatusBarScope oldWidget) => oldWidget.added != added;
}
