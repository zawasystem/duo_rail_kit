import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'vertical_bar_edge.dart';

/// Adds top safe-area spacing to windows with a side status bar.
///
/// When the original top inset is zero, [applies] accepts either a single
/// horizontal safe-area column or no horizontal insets with a native vertical
/// edge. The latter includes the left Split View window. Two horizontal insets
/// are excluded, even if a native edge is reported. This is a geometry rule,
/// not a device-model check.
///
/// Raises the top of both MediaQuery padding and viewPadding to at least [minTop],
/// keeping AppBars, SafeAreas, dialogs, and sheets aligned. Left, right, and bottom remain
/// unchanged. Rails can opt out via [removeAdded] or `RailPlacement.railSafeAreaOf`.
///
/// Wrap the application once, inside [VerticalBarEdge]:
/// `VerticalBarEdge(child: SideStatusBarInsets(child: ...))`.
/// The native edge is initially null, so a column-free Split View window receives
/// spacing only after the first native reply. A single-column shape can receive
/// spacing immediately from its geometry. Other shapes are unchanged.
class SideStatusBarInsets extends StatelessWidget {
  const SideStatusBarInsets({super.key, required this.child});

  final Widget child;

  /// Minimum top spacing, in logical pixels, to keep controls off the screen edge.
  static const double minTop = 16;

  /// Whether the original OS [padding] needs top spacing.
  ///
  /// Requires a zero top inset and either exactly one horizontal inset, or no
  /// horizontal insets with [systemBarEdge] true. Status-bar visibility does not
  /// matter. Two horizontal insets are always excluded.
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
  /// Use this for components such as rails that need the original OS safe area.
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
  /// True does not imply a horizontal status column: a column-free left Split
  /// View window also receives spacing. To detect a column, inspect the original
  /// horizontal insets restored by [removeAdded]. The adjusted MediaQuery top
  /// alone cannot tell whether spacing was added.
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
