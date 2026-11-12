import 'dart:async';

import 'package:flutter/material.dart'; // ignore: deprecated_member_use, unnecessary_ignore

import '../../core/horizontal_edge.dart';
import '../vertical_bar_action.dart';
import '../vertical_bar_column.dart';
import 'cell_owner.dart';
import 'column_menus.dart';
import 'default_controls.dart';

/// Which back glyph the column shows.
enum BackGlyph { back, close }

/// The column's content in one frame.
typedef ColumnLayout = ({
  VerticalBarColumn column,
  VerticalBarArrangement arrangement,
  BackGlyph? back,
  List<VerticalBarAction> actions,
});

/// The column's group decorations and cells for [layout], drawn with the page's builders for [owner].
class ColumnCells extends StatelessWidget {
  const ColumnCells({
    super.key,
    required this.layout,
    required this.itemBuilder,
    required this.backBuilder,
    required this.overflowBuilder,
    required this.groupDecoration,
    required this.owner,
  });

  /// The column's content, or null for no cells.
  final ColumnLayout? layout;

  /// The page's `VerticalBarPage.itemBuilder`.
  final VerticalBarItemBuilder? itemBuilder;

  /// The page's `VerticalBarPage.backBuilder`.
  final VerticalBarCellBuilder? backBuilder;

  /// The page's `VerticalBarPage.overflowBuilder`.
  final VerticalBarCellBuilder? overflowBuilder;

  /// The page's `VerticalBarPage.groupDecoration`.
  final Decoration? groupDecoration;

  final CellOwner owner;

  @override
  Widget build(BuildContext context) {
    final layout = this.layout;
    return Stack(clipBehavior: Clip.none, children: layout == null ? const [] : _columnChildren(layout));
  }

  /// Group decorations, then cells from top to bottom, each keyed so that its State survives
  /// reordering, moves to and from the overflow menu, and edge swaps.
  List<Widget> _columnChildren(ColumnLayout layout) {
    final column = layout.column;
    final arrangement = layout.arrangement;
    final first = layout.back == null ? 0 : 1;
    final decoration = groupDecoration;
    final decorations = <Widget>[];
    final cells = <Widget>[];
    for (final (index, group) in arrangement.groups.indexed) {
      if (group == null) {
        continue;
      }
      if (decoration != null) {
        decorations.add(
          Positioned.fromRect(
            key: _ColumnKey(_ColumnChild.group, index),
            rect: group.rect,
            child: IgnorePointer(child: DecoratedBox(decoration: decoration)),
          ),
        );
      }
      final rects = group.cells;
      for (final (position, item) in group.shown.indexed) {
        final rect = rects[position];
        cells.add(
          item < first
              ? _backCell(layout.back!, rect, column.edge)
              : _actionCell(layout.actions[item - first], rect, column),
        );
      }
      if (group.endsWithOverflow) {
        final overflow = [for (final item in arrangement.overflow) layout.actions[item - first]];
        cells.add(_overflowCell(overflow, rects.last, column));
      }
    }
    return [...decorations, ...cells];
  }

  Widget _backCell(BackGlyph glyph, Rect rect, HorizontalEdge edge) {
    final cell = VerticalBarCell(
      edge: edge,
      rect: rect,
      invoke: () => owner.whenInvokable(() => Navigator.maybePop(owner.page.context)),
    );
    final backBuilder = this.backBuilder;
    return _placed(
      const _ColumnKey(_ColumnChild.back),
      rect,
      (context) => backBuilder?.call(context, cell) ?? DefaultBackControl(cell: cell, close: glyph == BackGlyph.close),
    );
  }

  Widget _actionCell(VerticalBarAction action, Rect rect, VerticalBarColumn column) {
    final onPressed = action.onPressed;
    final menuItems = action.menuItems;
    final VoidCallback? invoke;
    if (!action.enabled) {
      invoke = null;
    } else if (menuItems != null) {
      final anchor = menuAnchor(column, rect);
      invoke = () => owner.whenInvokable(() => unawaited(openActionMenu(owner, menuItems, anchor)));
    } else {
      invoke = () => onPressed!(VerticalBarInvocation(anchor: rect, fromOverflowMenu: false));
    }
    final cell = VerticalBarCell(edge: column.edge, rect: rect, invoke: invoke);
    final cellBuilder = action.cellBuilder;
    final itemBuilder = this.itemBuilder;
    return _placed(
      _ColumnKey(_ColumnChild.action, action.id),
      rect,
      (context) => cellBuilder != null
          ? cellBuilder(context, cell)
          : itemBuilder?.call(context, action, cell) ?? DefaultActionControl(action: action, cell: cell),
    );
  }

  Widget _overflowCell(List<VerticalBarAction> overflow, Rect rect, VerticalBarColumn column) {
    final anchor = menuAnchor(column, rect);
    final cell = VerticalBarCell(
      edge: column.edge,
      rect: rect,
      invoke: () => owner.whenInvokable(() => unawaited(openOverflowMenu(owner, overflow, rect, anchor))),
      overflowed: List.unmodifiable(overflow),
    );
    final overflowBuilder = this.overflowBuilder;
    return _placed(
      const _ColumnKey(_ColumnChild.overflow),
      rect,
      (context) => overflowBuilder?.call(context, cell) ?? DefaultOverflowControl(cell: cell),
    );
  }

  /// Places a control in a cell: centred, with loose constraints up to the cell, never scaled down.
  Widget _placed(Key key, Rect rect, WidgetBuilder builder) => Positioned.fromRect(
    key: key,
    rect: rect,
    child: Center(child: Builder(builder: builder)),
  );
}

enum _ColumnChild { group, back, action, overflow }

/// Keys the children of the column layer; kinds never collide with each other or with action ids.
@immutable
class _ColumnKey extends LocalKey {
  const _ColumnKey(this.kind, [this.value]);

  final _ColumnChild kind;

  /// The action id or the group index.
  final Object? value;

  @override
  bool operator ==(Object other) => other is _ColumnKey && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => '[${kind.name}${value == null ? '' : ' $value'}]';
}
