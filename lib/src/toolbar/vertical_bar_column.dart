import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/horizontal_edge.dart';
import '../edge/bar_regions.dart';
import '../edge/vertical_bar_edge.dart';
import '../layout/side_status_bar_insets.dart';

/// The vertical bar column of the current window, and where UIKit places bar items in it.
///
/// Built from [VerticalBarRegion]. Cells are [cellExtent] square, one every [cellPitch] within a group, with
/// [groupGap] between groups, from the top of [items] down, centred on [items] whatever its width; the
/// metrics match UIKit on iPhone Duo. Values are logical pixels in window coordinates with physical
/// left/right.
@immutable
class VerticalBarColumn {
  const VerticalBarColumn({required this.edge, required this.viewSize, required this.column, required this.items});

  /// Side of one square cell: the tap target of one item and the width of the item region.
  static const double cellExtent = 48;

  /// Distance between the tops of adjacent cells in one group, leaving a gap of 4.
  static const double cellPitch = 52;

  /// Gap between groups.
  static const double groupGap = 12;

  /// Visible size of a UIKit bar button inside its cell; a style hint for controls.
  static const double buttonExtent = 38;

  /// Gap between the item region and the column's inner edge.
  static const double innerMargin = 12;

  /// The physical edge of the column.
  final HorizontalEdge edge;

  /// The window size of the sample.
  final Size viewSize;

  /// The whole column at full window height: from the window edge to the item region's inner side
  /// plus [innerMargin], or to the edge's OS safe-area inset when that is wider.
  final Rect column;

  /// Where cells go: the region's horizontal range, from the first cell's top to the region's bottom.
  final Rect items;

  /// The width of [column].
  double get width => column.width;

  /// The column for [context], or null when this window has no usable vertical bar.
  ///
  /// Read where MediaQuery still describes the window, below [VerticalBarEdge] and
  /// [SideStatusBarInsets]. Depends only on [VerticalBarEdgeScope], [BarRegionScope], the inset scope
  /// of [SideStatusBarInsets], [MediaQuery.sizeOf], and [MediaQuery.viewPaddingOf]; keyboard and
  /// text-scale changes do not rebuild the caller.
  static VerticalBarColumn? of(BuildContext context) {
    final region = VerticalBarRegion.of(context);
    if (region == null) {
      return null;
    }
    // A region implies a MediaQuery: VerticalBarRegion.of returns null without one.
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return resolve(
      region: region,
      edge: VerticalBarEdge.of(context),
      osViewPadding: SideStatusBarInsets.removeAdded(context, viewPadding),
      windowSize: size,
    );
  }

  /// The rule behind [of]. [osViewPadding] is the window's view padding without the spacing that
  /// [SideStatusBarInsets] added.
  ///
  /// Returns null when [region] is null; when [edge] is null or differs from the region's edge; when
  /// the sampled window size differs from [windowSize] by more than 0.5; when the OS top inset or
  /// the inset on the opposite side exceeds 0.5; when the region is not in its own half of the
  /// window; or when [items] would be more than 0.5 shorter than [cellExtent].
  static VerticalBarColumn? resolve({
    required VerticalBarRegion? region,
    required HorizontalEdge? edge,
    required EdgeInsets osViewPadding,
    required Size windowSize,
  }) {
    if (region == null || edge == null || region.edge != edge) {
      return null;
    }
    final viewSize = region.viewSize;
    if ((viewSize.width - windowSize.width).abs() > geometryTolerance ||
        (viewSize.height - windowSize.height).abs() > geometryTolerance) {
      return null;
    }
    // A top inset means portrait or a sample mixed from a rotation; insets on both sides are not
    // a single status column.
    final rect = region.rect;
    final ownInset = edge.insetOf(osViewPadding);
    final oppositeInset = edge.oppositeInsetOf(osViewPadding);
    if (osViewPadding.top > geometryTolerance || oppositeInset > geometryTolerance) {
      return null;
    }
    final inOwnHalf = switch (edge) {
      HorizontalEdge.left => rect.right <= windowSize.width / 2,
      HorizontalEdge.right => rect.left >= windowSize.width / 2,
    };
    if (!inOwnHalf) {
      return null;
    }
    final items = Rect.fromLTRB(rect.left, math.max(rect.top, region.topBarTop ?? rect.top), rect.right, rect.bottom);
    // The same 0.5 as [capacity] and the column's placement, so every column holds at least one cell.
    if (items.height + geometryTolerance < cellExtent) {
      return null;
    }
    final column = switch (edge) {
      HorizontalEdge.left => Rect.fromLTRB(0, 0, math.max(ownInset, rect.right + innerMargin), viewSize.height),
      HorizontalEdge.right => Rect.fromLTRB(
        viewSize.width - math.max(ownInset, viewSize.width - rect.left + innerMargin),
        0,
        viewSize.width,
        viewSize.height,
      ),
    };
    return VerticalBarColumn(edge: edge, viewSize: viewSize, column: column, items: items);
  }

  /// Cells of one group that fit in [extent], allowing 0.5, as the column's placement does; 0 when not even
  /// one cell fits, including for negative extents and [double.negativeInfinity]. Throws an [ArgumentError]
  /// for [double.infinity].
  static int capacity(double extent) {
    // Also 0 for NaN, which fails every comparison.
    if (!(extent + geometryTolerance >= cellExtent)) {
      return 0;
    }
    if (extent == double.infinity) {
      throw ArgumentError.value(extent, 'extent', 'Must be finite');
    }
    return ((extent + geometryTolerance - cellExtent) / cellPitch).floor() + 1;
  }

  /// Height of a group of [cells] cells: `cellExtent + cellPitch * (cells - 1)`, or 0 for none.
  static double groupExtent(int cells) => cells <= 0 ? 0 : cellExtent + cellPitch * (cells - 1);

  @override
  bool operator ==(Object other) =>
      other is VerticalBarColumn &&
      other.edge == edge &&
      other.viewSize == viewSize &&
      other.column == column &&
      other.items == items;

  @override
  int get hashCode => Object.hash(edge, viewSize, column, items);

  @override
  String toString() => 'VerticalBarColumn(edge: $edge, viewSize: $viewSize, column: $column, items: $items)';
}

/// Whether the OS inset on [column]'s edge, [viewPadding] without the spacing [SideStatusBarInsets] adds,
/// is at least the column's width, within [geometryTolerance]. Not so in the left Split View window, where
/// cells would cover the page or the content.
bool osInsetCoversColumn(BuildContext context, VerticalBarColumn column, EdgeInsets viewPadding) =>
    !(column.edge.insetOf(SideStatusBarInsets.removeAdded(context, viewPadding)) < column.width - geometryTolerance);

/// How the page and the shell place cells in a [VerticalBarColumn]; internal to the package.
extension VerticalBarColumnArrangement on VerticalBarColumn {
  /// Places groups of [groupSizes] items from the top of [items] down, or returns null when they
  /// cannot be placed even with an overflow cell.
  ///
  /// No cell ends below [bottom] (window y) or below [items]. Pass a page's bottom, or, beside a
  /// bottom-aligned rail in the same column, the rail's first item top minus [VerticalBarColumn.groupGap].
  /// [bottom] must not be NaN; release builds treat NaN like null.
  /// Items count in flattened top-to-bottom order. When everything does not fit, items move to one
  /// overflow cell from the end of that order, skipping [pinned] indices while another item can move
  /// instead. With [keepFirstGroup], the first group never moves.
  VerticalBarArrangement? arrange(
    List<int> groupSizes, {
    double? bottom,
    bool keepFirstGroup = false,
    Set<int> pinned = const <int>{},
  }) {
    assert(groupSizes.every((size) => size > 0), 'Every group needs at least one item: $groupSizes');
    assert(bottom == null || !bottom.isNaN, 'bottom must not be NaN');
    // Release builds treat a non-positive size as an empty group.
    final groupOf = <int>[
      for (var group = 0; group < groupSizes.length; group++)
        for (var item = 0; item < groupSizes[group]; item++) group,
    ];
    if (groupOf.isEmpty) {
      return VerticalBarArrangement(groups: List.filled(groupSizes.length, null), overflow: const []);
    }
    // math.min with NaN is NaN, and no cell bottom compares greater than NaN.
    final limit = math.min(items.bottom, (bottom == null || bottom.isNaN) ? items.bottom : bottom) + geometryTolerance;
    final firstMovable = keepFirstGroup ? math.max(0, groupSizes.first) : 0;
    final movable = [
      for (var item = groupOf.length - 1; item >= firstMovable; item--)
        if (!pinned.contains(item)) item,
      for (var item = groupOf.length - 1; item >= firstMovable; item--)
        if (pinned.contains(item)) item,
    ];
    for (var moved = 0; moved <= movable.length; moved++) {
      final overflow = movable.take(moved).toList()..sort();
      final groups = _place(groupSizes.length, groupOf, overflow, limit);
      if (groups != null) {
        return VerticalBarArrangement(groups: groups, overflow: overflow);
      }
    }
    return null;
  }

  /// Lays out the groups with the sorted [overflow] items moved, or returns null when a cell would
  /// end below [limit].
  List<VerticalBarGroupSlot?>? _place(int groupCount, List<int> groupOf, List<int> overflow, double limit) {
    final moved = overflow.toSet();
    // The overflow cell ends the group of the first moved item in flattened order.
    final overflowGroup = overflow.isEmpty ? null : groupOf[overflow.first];
    final shown = List.generate(groupCount, (_) => <int>[]);
    for (var item = 0; item < groupOf.length; item++) {
      if (!moved.contains(item)) {
        shown[groupOf[item]].add(item);
      }
    }
    final left = items.center.dx - VerticalBarColumn.cellExtent / 2;
    final groups = <VerticalBarGroupSlot?>[];
    double? end;
    for (var group = 0; group < groupCount; group++) {
      final endsWithOverflow = group == overflowGroup;
      final cells = shown[group].length + (endsWithOverflow ? 1 : 0);
      if (cells == 0) {
        groups.add(null);
        continue;
      }
      final top = end == null ? items.top : end + VerticalBarColumn.groupGap;
      final rect = Rect.fromLTWH(left, top, VerticalBarColumn.cellExtent, VerticalBarColumn.groupExtent(cells));
      if (rect.bottom > limit) {
        return null;
      }
      end = rect.bottom;
      groups.add(VerticalBarGroupSlot(rect: rect, shown: shown[group], endsWithOverflow: endsWithOverflow));
    }
    return groups;
  }
}

/// Where [VerticalBarColumnArrangement.arrange] placed each group, and which items moved to the overflow menu.
@immutable
class VerticalBarArrangement {
  /// Wraps both lists in [List.unmodifiable].
  VerticalBarArrangement({required List<VerticalBarGroupSlot?> groups, required List<int> overflow})
    : groups = List.unmodifiable(groups),
      overflow = List.unmodifiable(overflow);

  /// One entry per input group, top to bottom; null when all of its items are in the overflow and
  /// it does not hold the overflow cell.
  final List<VerticalBarGroupSlot?> groups;

  /// Flattened indices of the items in the overflow menu, in input order; empty when all are shown.
  final List<int> overflow;

  /// The overflow cell in window coordinates, or null when [overflow] is empty.
  Rect? get overflowCell {
    if (overflow.isEmpty) {
      return null;
    }
    for (final group in groups) {
      if (group != null && group.endsWithOverflow) {
        return group.cells.last;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is VerticalBarArrangement && listEquals(other.groups, groups) && listEquals(other.overflow, overflow);

  @override
  int get hashCode => Object.hash(Object.hashAll(groups), Object.hashAll(overflow));

  @override
  String toString() => 'VerticalBarArrangement(groups: $groups, overflow: $overflow)';
}

/// One group of cells in a [VerticalBarArrangement].
@immutable
class VerticalBarGroupSlot {
  /// Wraps [shown] in [List.unmodifiable].
  VerticalBarGroupSlot({required this.rect, required List<int> shown, required this.endsWithOverflow})
    : shown = List.unmodifiable(shown);

  /// The group's capsule in window coordinates, [VerticalBarColumn.cellExtent] wide.
  final Rect rect;

  /// Flattened indices of the items shown in this group's cells, top to bottom.
  final List<int> shown;

  /// Whether this group's last cell is the overflow cell.
  final bool endsWithOverflow;

  /// Cell rectangles, top to bottom: one per [shown] item, then the overflow cell when [endsWithOverflow].
  List<Rect> get cells => List.unmodifiable([
    for (var cell = 0; cell < shown.length + (endsWithOverflow ? 1 : 0); cell++)
      Rect.fromLTWH(
        rect.left,
        rect.top + VerticalBarColumn.cellPitch * cell,
        VerticalBarColumn.cellExtent,
        VerticalBarColumn.cellExtent,
      ),
  ]);

  @override
  bool operator ==(Object other) =>
      other is VerticalBarGroupSlot &&
      other.rect == rect &&
      listEquals(other.shown, shown) &&
      other.endsWithOverflow == endsWithOverflow;

  @override
  int get hashCode => Object.hash(rect, Object.hashAll(shown), endsWithOverflow);

  @override
  String toString() => 'VerticalBarGroupSlot(rect: $rect, shown: $shown, endsWithOverflow: $endsWithOverflow)';
}
