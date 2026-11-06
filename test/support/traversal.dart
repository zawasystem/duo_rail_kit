import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The root node of the semantics tree that the first Navigator belongs to. Needs semantics on.
SemanticsNode semanticsRootOf(WidgetTester tester) =>
    tester.renderObject(find.byType(Navigator).first).owner!.semanticsOwner!.rootSemanticsNode!;

/// The children of [node] in traversal order.
List<SemanticsNode> semanticsChildren(SemanticsNode node) =>
    node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);

/// [node] and every node below it, depth first in traversal order.
Iterable<SemanticsNode> semanticsNodesFrom(SemanticsNode node) sync* {
  yield node;
  for (final child in semanticsChildren(node)) {
    yield* semanticsNodesFrom(child);
  }
}

/// The labels, or tooltips where there is no label, of [node] and the nodes below it.
List<String> textsFrom(SemanticsNode node) => [
  for (final each in semanticsNodesFrom(node))
    if (each.label.isNotEmpty) each.label else if (each.tooltip.isNotEmpty) each.tooltip,
];

/// Whether [node] belongs to a semantics container: the render object that owns it is a semantics boundary, as
/// `Semantics(container: true)` makes it. The node tree alone does not show this, because a node also forms where
/// an annotated widget sits below one with `explicitChildNodes`.
bool isSemanticsContainer(WidgetTester tester, SemanticsNode node) {
  RenderObject? owner;
  void visit(RenderObject object) {
    if (owner == null && identical(object.debugSemantics, node)) {
      owner = object;
    }
    object.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  expect(owner, isNotNull, reason: 'a render object owns $node');
  final boundary = owner!.toDiagnosticsNode().getProperties().singleWhere((p) => p.name == 'isSemanticBoundary');
  return boundary.value == true;
}

/// The semantics tree in traversal order, without node ids and identity hashes. Needs semantics on.
String semanticsTreeOf(WidgetTester tester) =>
    semanticsRootOf(tester).toStringDeep().replaceAll(RegExp('#[0-9a-f]+'), '');

/// Labels, or tooltips where there is no label, in traversal order.
///
/// A repeated text is listed once: on Android a back button's tooltip node also carries the label.
List<String> readingOrderOf(WidgetTester tester) {
  final texts = <String>[];
  void visit(SemanticsNode node) {
    final text = node.label.isNotEmpty ? node.label : node.tooltip;
    if (text.isNotEmpty && (texts.isEmpty || texts.last != text)) {
      texts.add(text);
    }
    node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder).forEach(visit);
  }

  visit(semanticsRootOf(tester));
  return texts;
}

/// Global rectangles of the focused node after each of [presses] Tab presses.
Future<List<Rect>> tabOrderOf(WidgetTester tester, int presses) async {
  final rects = <Rect>[];
  for (var press = 0; press < presses; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    rects.add(FocusManager.instance.primaryFocus?.rect ?? Rect.zero);
  }
  return rects;
}

/// The rectangles Tab visits once round, from the first press of [order].
List<Rect> tabCycleOf(List<Rect> order) {
  final cycle = <Rect>[];
  for (final rect in order) {
    if (cycle.isNotEmpty && rect == cycle.first) {
      break;
    }
    cycle.add(rect);
  }
  return cycle;
}

/// Whether the nearest IgnorePointer above the widget [finder] finds ignores pointers.
bool ignoresPointersAbove(WidgetTester tester, Finder finder) {
  bool? ignoring;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is IgnorePointer) {
      ignoring = widget.ignoring;
      return false;
    }
    return true;
  });
  return ignoring!;
}
