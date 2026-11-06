import 'package:flutter/painting.dart';

import 'horizontal_edge.dart';

/// Tolerance, in logical pixels, for native values compared with each other, with MediaQuery, and with layout.
const double geometryTolerance = 0.5;

/// Whether [a] and [b] differ by at most [geometryTolerance] in each dimension.
bool withinTolerance(Size a, Size b) =>
    (a.width - b.width).abs() <= geometryTolerance && (a.height - b.height).abs() <= geometryTolerance;

/// Insets on a physical edge.
extension HorizontalEdgeInsets on HorizontalEdge {
  /// [padding]'s inset on this edge.
  double insetOf(EdgeInsets padding) => switch (this) {
    HorizontalEdge.left => padding.left,
    HorizontalEdge.right => padding.right,
  };

  /// [padding]'s inset on the opposite edge.
  double oppositeInsetOf(EdgeInsets padding) => switch (this) {
    HorizontalEdge.left => padding.right,
    HorizontalEdge.right => padding.left,
  };

  /// [padding] with this edge's inset set to 0.
  EdgeInsets withoutInset(EdgeInsets padding) => switch (this) {
    HorizontalEdge.left => padding.copyWith(left: 0),
    HorizontalEdge.right => padding.copyWith(right: 0),
  };
}
