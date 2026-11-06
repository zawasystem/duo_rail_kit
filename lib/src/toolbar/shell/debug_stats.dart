part of '../vertical_bar_toolbar.dart';

/// Counters that the package's tests read, changed only in debug builds.
@visibleForTesting
// ignore: avoid_classes_with_only_static_members, one name for tests to import.
abstract final class VerticalBarShellDebugStats {
  /// Notifications that reached a shell from another build scope while it was not laying out its row,
  /// so that it laid out again after the frame.
  static int deferredNotifications = 0;

  /// Paint-phase checks that found the cells' arrangement out of date and laid the shell out again.
  static int paintFixes = 0;

  /// Builds of the shells' column layers.
  static int layerBuilds = 0;

  /// Sets every counter to 0.
  static void reset() {
    deferredNotifications = 0;
    paintFixes = 0;
    layerBuilds = 0;
  }
}
