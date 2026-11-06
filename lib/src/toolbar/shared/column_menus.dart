import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/horizontal_edge.dart';
import '../vertical_bar_action.dart';
import '../vertical_bar_column.dart';
import 'cell_owner.dart';

/// Gap, in logical pixels, between the column's inner edge and its menus.
const double _menuGap = 8;

/// How long the package's menus take to open and to close.
const Duration _menuDuration = Duration(milliseconds: 300);

/// Opens the menu of an action's [items] at [anchor] for [owner], which may act now.
Future<void> openActionMenu(CellOwner owner, List<VerticalBarMenuItem> items, Rect anchor) async {
  final position = owner.menuPosition(anchor);
  if (position != null) {
    await _showItemMenu(owner, items, position);
  }
}

/// Opens the menu of the actions in [overflow] at [anchor] for [owner], which may act now. A chosen action
/// is invoked with the overflow [cell] as it was when the menu opened; one with menu items opens them at
/// the same anchor.
Future<void> openOverflowMenu(CellOwner owner, List<VerticalBarAction> overflow, Rect cell, Rect anchor) async {
  final position = owner.menuPosition(anchor);
  if (position == null) {
    return;
  }
  final reserveIcon = overflow.any((action) => action.icon != null || action.selected != null);
  final chosen = await _showMenu(owner, [
    for (final (index, action) in overflow.indexed) _actionRow(index, action, reserveIcon: reserveIcon),
  ], position);
  // The owner's State, not the cell, waits: the cell may be gone by now, as after a rotation.
  if (chosen == null || !owner.page.mounted) {
    return;
  }
  final action = overflow[chosen];
  final menuItems = action.menuItems;
  if (menuItems == null) {
    action.onPressed?.call(VerticalBarInvocation(anchor: cell, fromOverflowMenu: true));
    return;
  }
  // The overflow menu is popped but still closing; the second menu opens once it has closed, unless
  // the page has gone or is no longer on top by then, as while it is popped.
  await Future<void>.delayed(_menuDuration);
  owner.whenInvokable(() => unawaited(_showItemMenu(owner, menuItems, position)));
}

/// Shows [items] at [position] for [owner] and calls the chosen one, from a copy taken now.
Future<void> _showItemMenu(CellOwner owner, List<VerticalBarMenuItem> items, RelativeRect position) async {
  final snapshot = List.of(items);
  if (snapshot.isEmpty) {
    return;
  }
  final reserveIcon = snapshot.any((item) => item.icon != null);
  final chosen = await _showMenu(owner, [
    for (final (index, item) in snapshot.indexed)
      PopupMenuItem<int>(
        value: index,
        enabled: item.enabled,
        child: _MenuRow(
          icon: item.icon,
          reserveIcon: reserveIcon,
          label: item.label,
          enabled: item.enabled,
          destructive: item.destructive,
        ),
      ),
  ], position);
  if (chosen != null && owner.page.mounted) {
    snapshot[chosen].onSelected();
  }
}

Future<int?> _showMenu(CellOwner owner, List<PopupMenuEntry<int>> items, RelativeRect position) => showMenu<int>(
  context: owner.page.context,
  position: position,
  items: items,
  // With false the menu stacks above the page on the page's own Navigator, so it is dismissed with the page
  // when the page is popped or its Page removed; for a page in the root Navigator both values are the same.
  // With true it opens on the root Navigator and can outlive the page. Either way a choice made after the
  // page is gone is dropped.
  useRootNavigator: owner.useRootNavigator,
  // The default, stated because a second menu waits this long for the first to close.
  popUpAnimationStyle: const AnimationStyle(duration: _menuDuration),
);

/// Where menus opened from [cell] are anchored: a zero-width rectangle as tall as the cell, [_menuGap]
/// beside the column's inner edge. A menu aligns its edge with the anchor's on the side of the
/// nearer window edge and grows inward, so it never covers the column. UIKit opens over the column.
Rect menuAnchor(VerticalBarColumn column, Rect cell) {
  final x = switch (column.edge) {
    HorizontalEdge.left => column.column.right + _menuGap,
    HorizontalEdge.right => column.column.left - _menuGap,
  };
  return Rect.fromLTRB(x, cell.top, x, cell.bottom);
}

/// [anchor], in [box]'s coordinates, relative to [overlay], as [showMenu] takes a menu's position.
RelativeRect relativeToOverlay(RenderBox box, RenderBox overlay, Rect anchor) => RelativeRect.fromRect(
  Rect.fromPoints(
    box.localToGlobal(anchor.topLeft, ancestor: overlay),
    box.localToGlobal(anchor.bottomRight, ancestor: overlay),
  ),
  Offset.zero & overlay.size,
);

/// An overflow menu row for [action], returning [index] when chosen. [reserveIcon] as in [_MenuRow].
PopupMenuEntry<int> _actionRow(int index, VerticalBarAction action, {required bool reserveIcon}) {
  final selected = action.selected;
  if (selected != null) {
    // The check mark takes the leading column, where the other rows show their icons.
    return CheckedPopupMenuItem<int>(
      value: index,
      checked: selected,
      enabled: action.enabled,
      child: Text(action.label),
    );
  }
  return PopupMenuItem<int>(
    value: index,
    enabled: action.enabled,
    child: _MenuRow(icon: action.icon, reserveIcon: reserveIcon, label: action.label, enabled: action.enabled),
  );
}

/// A menu row: the icon, then the label.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.reserveIcon,
    required this.label,
    required this.enabled,
    this.destructive = false,
  });

  final Widget? icon;

  /// Whether a row without [icon] keeps a blank one, so that its label lines up with the labels of the
  /// menu's rows with an icon or a check mark. In a menu without either, labels start where icons would.
  final bool reserveIcon;

  final String label;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    // As in CheckedPopupMenuItem, so that checked rows and these rows line up.
    return ListTile(
      enabled: enabled,
      leading: icon ?? (reserveIcon ? const Icon(null) : null),
      title: Text(label),
      iconColor: color,
      textColor: color,
    );
  }
}
