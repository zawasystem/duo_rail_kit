import 'package:flutter/widgets.dart';

import 'vertical_bar_edge.dart';

/// Places a rail in a stable `[left slot, content, right slot]` row.
///
/// The rail occupies the [railEdge] slot; unused slots are empty. The keyed content
/// always stays in the middle so changing edges or removing the rail preserves its
/// state. Keep [contentKey]: when both end slots change, an unkeyed middle child
/// can otherwise be recreated.
///
/// Edges are physical, even in RTL. Only the row order is forced to LTR; the
/// content retains its inherited text direction.
class RailSideRow extends StatelessWidget {
  const RailSideRow({super.key, required this.railEdge, required this.rail, required this.content});

  /// The physical rail edge, or null to omit the rail and use bottom navigation.
  final HorizontalEdge? railEdge;

  final Widget rail;

  /// The content, expanded to fill the remaining width.
  final Widget content;

  /// The stable content-slot key; callers do not need to provide another key.
  static const Key contentKey = ValueKey('duo-rail-kit-content');

  @override
  Widget build(BuildContext context) => Row(
    // Keep physical edges independent of the surrounding text direction.
    textDirection: TextDirection.ltr,
    children: [
      if (railEdge == HorizontalEdge.left) rail else const SizedBox.shrink(),
      Expanded(key: contentKey, child: content),
      if (railEdge == HorizontalEdge.right) rail else const SizedBox.shrink(),
    ],
  );
}
