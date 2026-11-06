import 'dart:async';

import 'package:flutter/widgets.dart';

/// The page whose cells a `ColumnCells` draws, and how its controls act.
@immutable
class CellOwner {
  const CellOwner({
    required this.page,
    required this.canInvoke,
    required this.useRootNavigator,
    required this.menuPosition,
    required this.waitsForTickers,
  });

  /// Pops and opens menus with its context; a choice made once it is unmounted is dropped.
  final State<StatefulWidget> page;

  /// Whether the back control and the menus may act now, including the [page]'s own gate:
  /// - read only through [whenInvokable]: by the back cell, the menu cells, and the item menu that the
  ///   overflow menu opens;
  /// - when false they do not act now, since an application may call a cell's public `invoke` after an
  ///   await, when they would act on another route ([whenInvokable] may decide again after the next frame).
  final bool Function() canInvoke;

  /// Whether menus open on the root Navigator instead of the page's own.
  final bool useRootNavigator;

  /// The anchor, in the cells' coordinates, relative to the overlay where the menu opens; null before
  /// layout.
  final RelativeRect? Function(Rect anchor) menuPosition;

  /// Whether only the [page]'s disabled tickers keep it from acting.
  final bool Function() waitsForTickers;

  /// Calls [act] at once if [canInvoke] passes. When only the page's disabled tickers stop it, as right
  /// after an opaque route above the page pops, decides again once the next frame has ended; tickers
  /// still disabled then mean a hidden branch, and [act] is dropped.
  void whenInvokable(VoidCallback act) {
    if (canInvoke()) {
      act();
    } else if (waitsForTickers()) {
      final binding = WidgetsBinding.instance..scheduleFrame();
      unawaited(
        binding.endOfFrame.then((_) {
          if (canInvoke()) {
            act();
          }
        }),
      );
    }
  }
}
