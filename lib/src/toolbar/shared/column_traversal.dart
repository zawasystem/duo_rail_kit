import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Visits the column layer's group before the page layer's, and otherwise keeps [secondary]'s order.
///
/// Unlike an [OrderedTraversalPolicy] with an order on each layer, it needs no focus orders: both layers
/// see the orders around the page, such as an application shell's around its Navigator, which can then
/// neither move the column after the page nor be compared with an order of another type.
class ColumnFirstTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  ColumnFirstTraversalPolicy({required this.secondary, required this.isColumn});

  /// The ambient policy, which also sorts each layer's own group.
  final FocusTraversalPolicy secondary;

  /// Whether a member of the group is the column layer's group.
  final bool Function(FocusNode node) isColumn;

  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final sorted = secondary.sortDescendants(descendants, currentNode).toList();
    return [...sorted.where(isColumn), ...sorted.where((node) => !isColumn(node))];
  }
}

/// The policies of a page or a shell, kept across frames so that their traversal history survives rebuilds.
class TraversalPolicies {
  TraversalPolicies({required this.isColumn});

  /// Passed to the [ColumnFirstTraversalPolicy]: whether a node is the column layer's group.
  final bool Function(FocusNode node) isColumn;

  FocusTraversalPolicy? _fallback;
  ColumnFirstTraversalPolicy? _columnFirst;

  /// The policy of the nearest [FocusTraversalGroup] above [context], or, without one, a
  /// [ReadingOrderTraversalPolicy] created on the first call without one and kept.
  FocusTraversalPolicy ambientOf(BuildContext context) =>
      FocusTraversalGroup.maybeOf(context) ?? (_fallback ??= ReadingOrderTraversalPolicy());

  /// The column-first policy over [ambient], created again only when [ambient] is another policy. Call it
  /// only while the column is used.
  ColumnFirstTraversalPolicy columnFirstOver(FocusTraversalPolicy ambient) {
    final columnFirst = _columnFirst;
    if (columnFirst != null && identical(columnFirst.secondary, ambient)) {
      return columnFirst;
    }
    return _columnFirst = ColumnFirstTraversalPolicy(secondary: ambient, isColumn: isColumn);
  }
}

/// One layer of a page or a shell: a focus traversal group of its own under [policy], so that focus orders
/// inside it are compared only with each other, and, while [active], a semantics container sorted by
/// [sortKey]. Pass a const [sortKey]: [OrdinalSortKey] has no `==`, so a new one would mark the semantics
/// dirty on every build.
Widget layerGroup({
  required bool active,
  required SemanticsSortKey sortKey,
  required FocusTraversalPolicy policy,
  ValueChanged<FocusNode>? onFocusNodeCreated,
  required Widget child,
}) => FocusTraversalGroup(
  policy: policy,
  onFocusNodeCreated: onFocusNodeCreated,
  child: Semantics(container: active, explicitChildNodes: active, sortKey: active ? sortKey : null, child: child),
);
