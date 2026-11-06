/// @docImport 'vertical_bar_toolbar.dart';
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'vertical_bar_column.dart';

/// The rail's lowest top padding beside a shell's cells ([VerticalBarShell.railPaddingOf]):
/// [VerticalBarColumn.groupGap] below the first cell, or below the second when [reservesBack] keeps a cell
/// for the back control. Each cell takes [VerticalBarColumn.cellExtent] plus [VerticalBarColumn.groupGap];
/// the rail adds its own spacing below this.
double shellFloorTop(VerticalBarColumn column, {required bool reservesBack}) =>
    column.items.top + (reservesBack ? 2 : 1) * (VerticalBarColumn.cellExtent + VerticalBarColumn.groupGap);

/// Arranges a back group and an action group above a bottom-aligned rail in [column].
///
/// The cells are centred on [railCentre] (window x), or on [column]'s items when it is null, and end
/// [VerticalBarColumn.groupGap] above [railTop], or above [floorTop] when [railTop] is null or higher.
/// [pinned] holds flattened indices, the back control first. Returns the column with its items moved
/// to that centre, and the arrangement in it; null when there is neither back nor an action, or when
/// nothing can be placed.
({VerticalBarColumn column, VerticalBarArrangement arrangement})? arrangeBesideRail({
  required VerticalBarColumn column,
  required double floorTop,
  required double? railTop,
  required double? railCentre,
  required bool back,
  required int actions,
  Set<int> pinned = const <int>{},
}) {
  final groups = [if (back) 1, if (actions > 0) actions];
  if (groups.isEmpty) {
    return null;
  }
  final dx = (railCentre ?? column.items.center.dx) - column.items.center.dx;
  final shifted = VerticalBarColumn(
    edge: column.edge,
    viewSize: column.viewSize,
    column: column.column,
    items: column.items.shift(Offset(dx, 0)),
  );
  final arrangement = shifted.arrange(
    groups,
    bottom: math.max(railTop ?? floorTop, floorTop) - VerticalBarColumn.groupGap,
    keepFirstGroup: back,
    pinned: pinned,
  );
  return arrangement == null ? null : (column: shifted, arrangement: arrangement);
}
