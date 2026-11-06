/// @docImport '../toolbar/vertical_bar_column.dart';
/// @docImport 'vertical_bar_edge.dart';
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/horizontal_edge.dart';

/// The system's top bar region, the band beside the status display in the top safe area, sampled from iOS.
///
/// UIKit's `UIView.LayoutRegion.bar(onEdge: .top, extent: 48)` on iOS 27.1 and later, where UIKit places its own
/// navigation bar; on iPhone Duo inner portrait it lies left of the status display. An application can draw its first
/// toolbar row there instead of below the safe area. It exists only on the phone idiom, when it starts above the top
/// safe-area inset and ends inside it; ordinary iPhones, Duo inner landscape, iPads, and other platforms have none.
///
/// Values are logical pixels in window coordinates with physical left/right. Read it with [of], which rejects samples
/// that no longer match the current window.
@immutable
class TopBarRegion {
  const TopBarRegion({required this.rect, required this.safeTop, required this.viewSize});

  /// The window-space rectangle the system reserves for a top bar beside the status display.
  final Rect rect;

  /// The top safe-area inset when the region was sampled.
  final double safeTop;

  /// The window size when the region was sampled.
  final Size viewSize;

  /// Insets that place a bar row of [pane] inside [rect]: left, top, and right; bottom is 0.
  ///
  /// [pane] uses the same window coordinates, for example the global rectangle of a header that
  /// starts at the top of the window. Edges where [pane] already lies inside [rect] receive 0; no
  /// inset is negative. A row of [rect]'s height starts at the returned top inset.
  EdgeInsets paddingFor(Rect pane) => EdgeInsets.fromLTRB(
    math.max(0, rect.left - pane.left),
    math.max(0, rect.top - pane.top),
    math.max(0, pane.right - rect.right),
    0,
  );

  /// The region for [context], or null when the current screen has none or no sample has arrived yet (the first frame).
  ///
  /// Also null when the sample does not match the current [MediaQuery] size and top view padding within 0.5, for
  /// example right after a rotation or below a widget that removed the top padding, such as a Scaffold body below an
  /// app bar. Depends only on [BarRegionScope], [MediaQuery.sizeOf], and [MediaQuery.viewPaddingOf], so keyboard
  /// changes do not rebuild the caller.
  static TopBarRegion? of(BuildContext context) {
    final region = context.dependOnInheritedWidgetOfExactType<BarRegionScope>()?.topBar;
    if (region == null) {
      return null;
    }
    final size = MediaQuery.maybeSizeOf(context);
    final viewPadding = MediaQuery.maybeViewPaddingOf(context);
    if (size == null || viewPadding == null || !withinTolerance(region.viewSize, size)) {
      return null;
    }
    return (viewPadding.top - region.safeTop).abs() <= geometryTolerance ? region : null;
  }

  @override
  bool operator ==(Object other) =>
      other is TopBarRegion && other.rect == rect && other.safeTop == safeTop && other.viewSize == viewSize;

  @override
  int get hashCode => Object.hash(rect, safeTop, viewSize);

  @override
  String toString() => 'TopBarRegion(rect: $rect, safeTop: $safeTop, viewSize: $viewSize)';
}

/// The system's item region in the vertical bar on a physical [edge], sampled from iOS.
///
/// UIKit's `UIView.LayoutRegion.bar(onEdge: .left/.right, extent: 48)` on the phone idiom while [VerticalBarEdge.of]
/// reports an edge. On iPhone Duo inner landscape it is the part of the right status column below the status display,
/// where UIKit places navigation bar buttons. [VerticalBarColumn] is built from it.
///
/// Values are logical pixels in window coordinates. Read it with [of], which rejects samples that no longer match the
/// current window size.
@immutable
class VerticalBarRegion {
  const VerticalBarRegion({required this.rect, required this.edge, required this.viewSize, this.topBarTop});

  /// The window-space rectangle the system reserves for vertical bar items.
  final Rect rect;

  /// The physical edge of the vertical bar, matching [VerticalBarEdge.of] for the same sample.
  final HorizontalEdge edge;

  /// The window size when the region was sampled.
  final Size viewSize;

  /// The top of the system's top bar region (`bar(onEdge: .top, extent: 48)`) in the same sample, or null when the
  /// payload has no usable value.
  ///
  /// Unlike [TopBarRegion], it carries no safe-area condition. When present it is at least 0 and above [rect]'s bottom.
  final double? topBarTop;

  /// The region for [context], or null when there is none or the sample does not match the
  /// current [MediaQuery] size within 0.5.
  ///
  /// Depends only on [BarRegionScope] and [MediaQuery.sizeOf].
  static VerticalBarRegion? of(BuildContext context) {
    final region = context.dependOnInheritedWidgetOfExactType<BarRegionScope>()?.verticalBar;
    if (region == null) {
      return null;
    }
    final size = MediaQuery.maybeSizeOf(context);
    return size != null && withinTolerance(region.viewSize, size) ? region : null;
  }

  @override
  bool operator ==(Object other) =>
      other is VerticalBarRegion &&
      other.rect == rect &&
      other.edge == edge &&
      other.viewSize == viewSize &&
      other.topBarTop == topBarTop;

  @override
  int get hashCode => Object.hash(rect, edge, viewSize, topBarTop);

  @override
  String toString() => 'VerticalBarRegion(rect: $rect, edge: $edge, viewSize: $viewSize, topBarTop: $topBarTop)';
}

/// Provides sampled bar regions to descendants; tests can inject a scope directly.
///
/// [VerticalBarEdge] always builds one below its [VerticalBarEdgeScope], whether or not a region
/// exists. Read the values through [TopBarRegion.of] and [VerticalBarRegion.of], which also check
/// them against the current [MediaQuery].
class BarRegionScope extends InheritedWidget {
  const BarRegionScope({super.key, this.topBar, this.verticalBar, required super.child});

  /// The sampled top bar region, or null when there is none.
  final TopBarRegion? topBar;

  /// The sampled vertical bar region, or null when there is none.
  final VerticalBarRegion? verticalBar;

  @override
  bool updateShouldNotify(BarRegionScope oldWidget) =>
      oldWidget.topBar != topBar || oldWidget.verticalBar != verticalBar;
}

/// Whether [rect] is non-empty and inside a view of [size], allowing the tolerance at the far edges.
bool _fitsView(Rect rect, Size size) =>
    size.width > 0 &&
    size.height > 0 &&
    rect.left < rect.right &&
    rect.top < rect.bottom &&
    rect.left >= 0 &&
    rect.top >= 0 &&
    rect.right <= size.width + geometryTolerance &&
    rect.bottom <= size.height + geometryTolerance;

/// Parses the `topBar` entry of a native payload.
///
/// Null for a missing entry, a missing or non-finite number, an empty rectangle, a rectangle outside the view, or one
/// that does not start above `safeTop` and end at most 0.5 below it.
TopBarRegion? parseTopBarRegion(Object? payload) {
  final entry = payload is Map ? payload['topBar'] : null;
  final frame = _frameOf(entry);
  final safeTop = entry is Map ? _number(entry['safeTop']) : null;
  if (frame == null || safeTop == null) {
    return null;
  }
  final (rect, viewSize) = frame;
  if (rect.top >= safeTop || rect.bottom > safeTop + geometryTolerance) {
    return null;
  }
  return TopBarRegion(rect: rect, safeTop: safeTop, viewSize: viewSize);
}

/// Parses the `verticalBar` entry of a native payload for [edge].
///
/// Null without an edge, for a missing entry, a missing or non-finite number, an empty rectangle, or a rectangle
/// outside the view. A `topBarTop` that is missing, not finite, negative, or not above the rectangle's bottom makes
/// only [VerticalBarRegion.topBarTop] null; the region is kept.
VerticalBarRegion? parseVerticalBarRegion(Object? payload, HorizontalEdge? edge) {
  if (edge == null) {
    return null;
  }
  final entry = payload is Map ? payload['verticalBar'] : null;
  final frame = _frameOf(entry);
  if (frame == null) {
    return null;
  }
  final (rect, viewSize) = frame;
  final topBarTop = entry is Map ? _number(entry['topBarTop']) : null;
  return VerticalBarRegion(
    rect: rect,
    edge: edge,
    viewSize: viewSize,
    topBarTop: topBarTop != null && topBarTop >= 0 && topBarTop < rect.bottom ? topBarTop : null,
  );
}

double? _number(Object? value) => value is num && value.isFinite ? value.toDouble() : null;

/// The rectangle and view size of either entry; null unless all six numbers are finite and [_fitsView] holds.
(Rect, Size)? _frameOf(Object? entry) {
  if (entry is! Map) {
    return null;
  }
  final left = _number(entry['left']);
  final top = _number(entry['top']);
  final right = _number(entry['right']);
  final bottom = _number(entry['bottom']);
  final width = _number(entry['viewWidth']);
  final height = _number(entry['viewHeight']);
  if (left == null || top == null || right == null || bottom == null || width == null || height == null) {
    return null;
  }
  final rect = Rect.fromLTRB(left, top, right, bottom);
  final viewSize = Size(width, height);
  return _fitsView(rect, viewSize) ? (rect, viewSize) : null;
}
