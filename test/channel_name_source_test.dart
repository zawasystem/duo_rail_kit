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

  /// Matches `<key> <separator> <value>` with any spacing around the separator.
  RegExp entry(String key, String separator, String value) =>
      RegExp('${RegExp.escape(key)}\\s*${RegExp.escape(separator)}\\s*${RegExp.escape(value)}');

  /// The braced body of the Swift declaration starting with [signature].
  ///
  /// Scoping a check to one function keeps an identical fragment elsewhere from satisfying it.
  String functionBody(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: 'Missing Swift declaration: $signature');
    final open = source.indexOf('{', start);
    var depth = 0;
    var inString = false;
    for (var i = open; i < source.length; i++) {
      final char = source[i];
      if (char == '"' && source[i - 1] != r'\') {
        inString = !inString;
      } else if (!inString && char == '{') {
        depth++;
      } else if (!inString && char == '}' && --depth == 0) {
        return source.substring(open, i + 1);
      }
    }
    fail('Unbalanced braces after $signature');
  }

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

  // A misspelled or dropped region key silently yields null regions in Dart. Keys such as "left"
  // also appear elsewhere in the source, so each key is matched with the value it must carry.
  test('Swift writes each region key parsed by Dart with its value', () {
    final source = code();
    final fields = functionBody(source, 'func fields(of rect: CGRect, in view: UIView)');
    for (final (key, value) in [
      ('left', 'Double(rect.minX)'),
      ('top', 'Double(rect.minY)'),
      ('right', 'Double(rect.maxX)'),
      ('bottom', 'Double(rect.maxY)'),
      ('viewWidth', 'Double(view.bounds.width)'),
      ('viewHeight', 'Double(view.bounds.height)'),
    ]) {
      expect(fields, matches(entry('"$key"', ':', value)), reason: 'Region fields must map "$key" to $value');
    }
    final topBar = functionBody(source, 'static func topBarRegion(in view: UIView)');
    expect(topBar, contains('fields(of: frame, in: view)'));
    expect(topBar, matches(entry('result["safeTop"]', '=', 'Double(safeTop)')));
    expect(
      functionBody(source, 'static func verticalBarRegion(in view: UIView'),
      contains('fields(of: frame, in: view)'),
    );
    final payload = functionBody(source, 'static func value(of viewController: UIViewController?)');
    expect(payload, matches(entry('value["topBar"]', '=', 'topBar')), reason: 'The payload must carry "topBar"');
    expect(
      payload,
      matches(entry('value["verticalBar"]', '=', 'verticalBar')),
      reason: 'The payload must carry "verticalBar"',
    );
  });

  test('Swift samples the top bar region with the explicit 27.1 API on the phone idiom only', () {
    final source = code();
    expect(
      source,
      contains('UIRectEdge.top, extent:'),
      reason: 'bar(onEdge:extent:) is the iOS 27.1 API; an unqualified .top is ambiguous with directional edges',
    );
    expect(source, contains('static let barExtent: CGFloat = 48'), reason: 'The row matches the 27.2 default extent');
    // Both the payload and the probe must check the idiom; one check does not cover the other.
    for (final signature in [
      'static func value(of viewController: UIViewController?)',
      'private func attachRegionProbe(to view: UIView?)',
    ]) {
      expect(
        functionBody(source, signature),
        contains('userInterfaceIdiom == .phone'),
        reason: 'iPad and iPad apps on a Mac report no regions and get no probe: $signature',
      );
    }
    expect(source, contains('#available(iOS 27.1, *)'), reason: 'Region APIs are guarded for iOS 27.1');
  });

  // Dart starts the vertical bar column's first cell at max(region top, topBarTop).
  test('Swift adds the top bar row top to the vertical bar region without a safe-area condition', () {
    final source = code();
    final verticalBar = functionBody(source, 'static func verticalBarRegion(in view: UIView, edge: String)');
    expect(
      verticalBar,
      contains('bar(onEdge: UIRectEdge.top, extent: barExtent)'),
      reason: 'topBarTop is the top of the same 48-point top bar region that the probe follows',
    );
    expect(
      verticalBar,
      matches(entry('result["topBarTop"]', '=', 'Double(row.minY)')),
      reason: 'The verticalBar entry must carry "topBarTop" for parseVerticalBarRegion',
    );
    expect(verticalBar, contains('row.minY >= 0'), reason: 'Dart accepts only 0 <= topBarTop < bottom');
    expect(verticalBar, contains('row.minY < frame.maxY'), reason: 'Dart accepts only 0 <= topBarTop < bottom');
    expect(verticalBar, contains('return result'));
    expect(
      verticalBar,
      isNot(contains('safeAreaInsets')),
      reason: 'Unlike topBar, topBarTop is reported whatever the top safe-area inset',
    );
    expect(
      verticalBar,
      isNot(contains('layoutGuide(for:')),
      reason: 'Regions are read with edgeInsets(for:); the probe already follows the top bar guide',
    );
    expect(
      RegExp(r'layoutGuide\(for:').allMatches(source),
      hasLength(1),
      reason: 'topBarTop must not add a layout guide or probe view',
    );
  });

  test('Swift creates the top bar layout guide only while installing its probe', () {
    final source = code();
    expect(
      RegExp(r'\.layoutGuide\(for:').allMatches(source),
      hasLength(1),
      reason: 'layoutGuide(for:) may add a guide per call; regions are read with edgeInsets(for:)',
    );
    expect(source, contains('edgeInsets(for: region)'));
    expect(source, contains('isUserInteractionEnabled = false'));
    expect(source, contains('accessibilityElementsHidden = true'));
  });
}
