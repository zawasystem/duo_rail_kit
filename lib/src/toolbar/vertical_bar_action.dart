/// @docImport 'vertical_bar_toolbar.dart';
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/horizontal_edge.dart';

/// Gap, in logical pixels, between a cell and a tooltip placed beside it.
const double _tooltipGap = 8;

/// Called when a column control, or its row in the overflow menu, is invoked.
typedef VerticalBarActionCallback = void Function(VerticalBarInvocation invocation);

/// Builds an application control for one cell: a custom action, the back control, or the overflow cell.
typedef VerticalBarCellBuilder = Widget Function(BuildContext context, VerticalBarCell cell);

/// Builds a standard action's control in a cell; returns null to use the package's default.
typedef VerticalBarItemBuilder = Widget? Function(BuildContext context, VerticalBarAction action, VerticalBarCell cell);

/// How a vertical bar action was invoked.
@immutable
class VerticalBarInvocation {
  const VerticalBarInvocation({required this.anchor, required this.fromOverflowMenu});

  /// The invoking control in window coordinates: the action's cell, or the overflow cell as it was
  /// when its menu opened. Use it as a share-sheet or popover origin.
  final Rect anchor;

  /// Whether the action was chosen from the overflow menu.
  final bool fromOverflowMenu;

  @override
  bool operator ==(Object other) =>
      other is VerticalBarInvocation && other.anchor == anchor && other.fromOverflowMenu == fromOverflowMenu;

  @override
  int get hashCode => Object.hash(anchor, fromOverflowMenu);

  @override
  String toString() => 'VerticalBarInvocation(anchor: $anchor, fromOverflowMenu: $fromOverflowMenu)';
}

/// One cell of the vertical bar column, passed to the builders of application controls. Values are logical
/// pixels.
@immutable
class VerticalBarCell {
  const VerticalBarCell({
    required this.edge,
    required this.rect,
    this.invoke,
    this.overflowed = const <VerticalBarAction>[],
  });

  /// The column's physical edge; the inner side is the opposite one.
  final HorizontalEdge edge;

  /// The 48 x 48 cell in window coordinates.
  final Rect rect;

  /// Invokes the control with this cell as the anchor: the action's [VerticalBarAction.onPressed],
  /// `Navigator.maybePop` for the back control, or the menu of an action with menu items or of the
  /// overflow cell. Null when the control is disabled.
  ///
  /// It may be kept and called later, for example after a confirmation. The back control and the menus
  /// then act only while the page is mounted, no other route (such as a pushed page or a dialog) covers it
  /// or a route that holds its Navigator, and its branch's tickers are enabled ([TickerMode]); under a
  /// [VerticalBarShell], also only while it is the shell's current page and no back swipe runs. A call made
  /// right after an opaque route above the page pops, before the next frame enables the page's tickers
  /// again, acts once that frame has ended.
  final VoidCallback? invoke;

  /// For the overflow cell, the actions in its menu, in order and unmodifiable; empty for every other
  /// cell. Lets an `overflowBuilder` show, for example, a badge that one of them carries.
  final List<VerticalBarAction> overflowed;

  /// Places a tooltip beside this cell on the column's inner side, vertically centred and kept inside the
  /// overlay; tooltips above or below would cover the neighbouring cells. Pass it as
  /// `Tooltip.positionDelegate`, with [tooltipConstraints] as `Tooltip.constraints`. The tooltip follows the
  /// cell in any overlay, also while the page moves, because the target's centre is the cell's (controls are
  /// centred in their cells). The package adds tooltips only to its default controls.
  Offset tooltipPosition(TooltipPositionContext position) {
    final target = position.target;
    final size = position.tooltipSize;
    final x = switch (edge) {
      HorizontalEdge.left => target.dx + rect.width / 2 + _tooltipGap,
      HorizontalEdge.right => target.dx - rect.width / 2 - _tooltipGap - size.width,
    };
    final y = target.dy - size.height / 2;
    final overlay = position.overlaySize;
    return Offset(
      math.max(0, math.min(x, overlay.width - size.width)),
      math.max(0, math.min(y, overlay.height - size.height)),
    );
  }

  /// The widest tooltip that [tooltipPosition] keeps beside this cell on the column's inner side, in a
  /// window [windowWidth] wide: the room between the cell and the window edge on that side, less a gap of
  /// 8, and never below 0.
  ///
  /// [tooltipConstraints] applies it. `Tooltip.constraints` built from it by hand replace Tooltip's default
  /// minimum height (the theme's, else 32 on mobile and 24 on desktop), so give them one as well.
  double tooltipMaxWidth(double windowWidth) => math.max(0, switch (edge) {
    HorizontalEdge.left => windowWidth - rect.right - _tooltipGap,
    HorizontalEdge.right => rect.left - _tooltipGap,
  });

  /// The `Tooltip.constraints` that the package's default controls use: the ones Tooltip would use (the
  /// theme's constraints, else a minimum height from the theme or Flutter's default), limited to
  /// [tooltipMaxWidth] of the window, so that long text wraps on the column's inner side instead of covering
  /// the column. Pass it with [tooltipPosition] to give an application control the same tooltip.
  BoxConstraints tooltipConstraints(BuildContext context) {
    final theme = TooltipTheme.of(context);
    final constraints =
        theme.constraints ??
        BoxConstraints(
          // Tooltip's own fallback still honours the deprecated theme height, so these tooltips do too.
          // ignore: deprecated_member_use
          minHeight: theme.height ?? _defaultTooltipHeight(Theme.of(context).platform),
        );
    return constraints.enforce(BoxConstraints(maxWidth: tooltipMaxWidth(MediaQuery.sizeOf(context).width)));
  }
}

/// Tooltip's default minimum height, which passing `Tooltip.constraints` replaces. A copy of Flutter's
/// private default; the tests compare it with a plain Tooltip's on mobile and desktop.
double _defaultTooltipHeight(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS || TargetPlatform.linux || TargetPlatform.windows => 24,
  TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.iOS => 32,
};

/// One page action shown in the vertical bar column, or in its overflow menu.
@immutable
class VerticalBarAction {
  const VerticalBarAction({
    required this.id,
    required Widget this.icon,
    required this.label,
    this.onPressed,
    this.selected,
    this.pinned = false,
    this.menuItems,
  }) : cellBuilder = null,
       assert(label != ''),
       assert(menuItems == null || onPressed == null);

  /// An application-built control, such as a button with a progress ring or a long-press menu.
  /// [icon] and [label] are used only for its overflow menu row; [onPressed] is called by the cell's
  /// `invoke` and by that row, and null disables both.
  const VerticalBarAction.custom({
    required this.id,
    required this.label,
    required VerticalBarCellBuilder this.cellBuilder,
    this.icon,
    this.onPressed,
    this.pinned = false,
  }) : selected = null,
       menuItems = null,
       assert(label != '');

  /// Unique within a page and stable across rebuilds; the cell is keyed with it.
  final Object id;

  /// Required for standard actions, for example `Icon(...)` or `Badge.count(count: n, child: Icon(...))`;
  /// optional for [VerticalBarAction.custom], which shows it only in its overflow menu row.
  final Widget? icon;

  /// Non-empty. The overflow menu text; for standard actions also the tooltip and semantics label.
  final String label;

  /// Null disables the action unless [menuItems] has an enabled item. Must be null when [menuItems] is set.
  final VerticalBarActionCallback? onPressed;

  /// Non-null makes the action a toggle with this state; its overflow menu row shows a check mark, when
  /// selected, in place of the icon.
  final bool? selected;

  /// Kept out of the overflow menu while another action can move there instead.
  final bool pinned;

  /// When non-null, pressing opens a menu with these items from the action's cell. Must not be empty.
  ///
  /// Chosen from the overflow menu, the action opens these items as a second menu at the same place
  /// once the overflow menu has closed, unless the page has gone or is no longer on top by then.
  final List<VerticalBarMenuItem>? menuItems;

  /// Builds the control of a [VerticalBarAction.custom] action; null for standard actions.
  final VerticalBarCellBuilder? cellBuilder;

  /// Whether the action can be invoked: [onPressed] is non-null, or [menuItems] has an enabled item.
  bool get enabled => onPressed != null || (menuItems?.any((item) => item.enabled) ?? false);
}

/// One row of a [VerticalBarAction]'s menu.
@immutable
class VerticalBarMenuItem {
  const VerticalBarMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  /// The row's text.
  final String label;

  /// Called when the row is chosen; not called when the page is gone by then.
  final VoidCallback onSelected;

  /// Shown before [label] when non-null.
  final Widget? icon;

  /// Whether the row can be chosen.
  final bool enabled;

  /// Uses the theme's error colour.
  final bool destructive;
}

/// [actions] without the later actions whose id an earlier one already uses, in their order.
///
/// Returns [actions] itself when every id is unique. Debug builds assert unique ids before this
/// runs; release builds drop the duplicates.
List<VerticalBarAction> uniqueVerticalBarActions(List<VerticalBarAction> actions) {
  final ids = <Object>{};
  final unique = [
    for (final action in actions)
      if (ids.add(action.id)) action,
  ];
  return unique.length == actions.length ? actions : unique;
}

/// Flattened indices of the pinned [actions], counted after the back control when [back].
Set<int> pinnedIndices(List<VerticalBarAction> actions, {required bool back}) {
  final first = back ? 1 : 0;
  return {
    for (final (index, action) in actions.indexed)
      if (action.pinned) first + index,
  };
}
