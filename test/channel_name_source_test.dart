import 'dart:io';

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the Swift method-channel contract against [VerticalBarEdge].
///
/// Flutter unit/widget tests do not compile Swift. A channel mismatch otherwise
/// silently falls back to width-based placement. This source check complements,
/// but does not replace, compiling and running an iOS host application.
void main() {
  // Run `fvm flutter test` from the package root.
  const swiftPath = 'ios/duo_rail_kit/Sources/duo_rail_kit/DuoRailKitPlugin.swift';

  /// Source with block comments and full-line comments removed.
  String code() => File(
    swiftPath,
  ).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '').replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

  test('Swift declares the same channel name as Dart', () {
    final literals = RegExp(r'static\s+let\s+channelName\s*=\s*"([^"]*)"').allMatches(code()).toList();
    expect(literals, hasLength(1), reason: 'Expected exactly one DuoRailKitPlugin.channelName declaration');
    expect(literals.single.group(1), VerticalBarEdge.channel.name);
  });

  test('Swift creates the channel using the shared constant without duplicate literals', () {
    final source = code();
    expect(source, contains('FlutterMethodChannel(name: channelName,'));
    // Reject additional reverse-domain channel names outside the shared constant.
    final names = [for (final m in RegExp(r'"(com\.[^"]*)"').allMatches(source)) m.group(1)!];
    expect(names, [VerticalBarEdge.channel.name]);
  });

  // A mismatched query falls back as MissingPluginException; a mismatched event is ignored.
  test('Swift handles getEdge and emits edgeChanged using the Dart method names', () {
    final source = code();
    expect(VerticalBarEdge.getEdgeMethod, 'getEdge');
    expect(VerticalBarEdge.edgeChangedMethod, 'edgeChanged');
    expect(
      source,
      contains('case "${VerticalBarEdge.getEdgeMethod}":'),
      reason: 'Swift must handle the Dart query ${VerticalBarEdge.getEdgeMethod}',
    );
    expect(
      source,
      contains('invokeMethod("${VerticalBarEdge.edgeChangedMethod}"'),
      reason: 'Swift must emit the Dart notification ${VerticalBarEdge.edgeChangedMethod}',
    );
  });

  test('Swift includes the edge, statusBarHidden, and sequence keys consumed by Dart', () {
    final source = code();
    // Keys consumed by Dart edge/visibility parsing and sequence ordering.
    for (final key in ['edge', 'statusBarHidden', 'sequence']) {
      expect(
        source,
        contains('"$key"'),
        reason: 'The native payload must include "$key" for Dart parsing and ordering',
      );
    }
    expect(
      source,
      contains('statusBarManager?.isStatusBarHidden'),
      reason: 'Read visibility from the native status bar',
    );
  });
}
