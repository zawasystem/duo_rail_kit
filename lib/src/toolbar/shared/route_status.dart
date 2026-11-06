import 'package:flutter/widgets.dart';

/// Whether, for [navigator] and each Navigator around it up to the root, the route that holds it is the
/// top route of the Navigator around it and, if given, passes [test].
///
/// Reads the routes without depending on them: `ModalRoute.isCurrentOf` with a Navigator's context would
/// rebuild that Navigator, and every route it holds, whenever its route's status changes. The top route
/// is the one [Route.isCurrent] means, found with a `popUntil` that stops at it, so nothing pops.
bool holdingRoutesCurrent(NavigatorState? navigator, {bool Function(ModalRoute<dynamic> route)? test}) {
  for (var inner = navigator; inner != null;) {
    // Not Navigator.maybeOf, which returns the Navigator itself for its own context.
    final outer = inner.context.findAncestorStateOfType<NavigatorState>();
    if (outer == null) {
      return true;
    }
    Route<dynamic>? top;
    outer.popUntil((route) {
      top = route;
      return true;
    });
    final holding = switch (top) {
      final ModalRoute<dynamic> route => route,
      _ => null,
    };
    final subtree = holding?.subtreeContext;
    if (holding == null || subtree == null || !_isAncestor(subtree, inner.context) || !(test?.call(holding) ?? true)) {
      return false;
    }
    inner = outer;
  }
  return true;
}

/// Whether [route] is current and at rest: not in a transition, below a route in one, or in a back swipe.
bool routeAtRest(ModalRoute<Object?> route) {
  final animation = route.animation?.status;
  final secondary = route.secondaryAnimation?.status;
  return route.isCurrent &&
      (animation == null || animation == AnimationStatus.completed) &&
      (secondary == null || secondary == AnimationStatus.dismissed) &&
      !(route.navigator?.userGestureInProgress ?? false);
}

bool _isAncestor(BuildContext ancestor, BuildContext context) {
  var found = false;
  context.visitAncestorElements((element) {
    found = identical(element, ancestor);
    return !found;
  });
  return found;
}
