import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cells on screen, top to bottom: the tooltip of each cell control and its rectangle. App bar
/// buttons are left out.
List<(String, Rect)> cellsOf(WidgetTester tester) {
  final inAppBars = find.descendant(of: find.byType(AppBar), matching: find.byType(Tooltip)).evaluate().toSet();
  return [
    for (final element in find.byType(Tooltip).evaluate())
      if (!inAppBars.contains(element)) ((element.widget as Tooltip).message!, globalRect(element)),
  ]..sort((a, b) => a.$2.top.compareTo(b.$2.top));
}

/// The tooltips of [cellsOf], top to bottom.
List<String> cellLabels(WidgetTester tester) => [for (final (label, _) in cellsOf(tester)) label];

/// The rectangle of [element]'s render box in window coordinates.
Rect globalRect(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The visible button of the default control centred in [cell], which is what Tab focuses.
Rect button(Rect cell) => Rect.fromCenter(
  center: cell.center,
  width: VerticalBarColumn.buttonExtent,
  height: VerticalBarColumn.buttonExtent,
);

/// The open menu that holds the row labelled [row].
Rect menuRect(WidgetTester tester, String row) =>
    tester.getRect(find.ancestor(of: find.text(row), matching: find.byType(Material)).first);

/// The top of the Flex that holds the rail's marker: the rail top that the shell reads.
double markerFlexTop(WidgetTester tester) =>
    tester.getRect(find.ancestor(of: find.byType(VerticalBarRailEnd), matching: find.byType(Column)).first).top;

/// The shell's render object, which lays out the row and then the column layer.
RenderObject shellLayout(WidgetTester tester) =>
    tester.allRenderObjects.firstWhere((object) => object.runtimeType.toString() == '_RenderShellLayout');
