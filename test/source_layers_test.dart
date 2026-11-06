import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks the layer rule of `lib/src` and the export list of the package library.
///
/// Each file under `lib/src` belongs to a layer, ranked from its path: `core/` 0, `edge/` 1, `layout/` 2, `toolbar/` 3,
/// `toolbar/shared/` 4, and the page and shell library (`toolbar/vertical_bar_toolbar.dart` with its parts in
/// `toolbar/page/` and `toolbar/shell/`) 5. A file imports only Dart, Flutter, and files of its own or a lower rank, a
/// part keeps the rank of its library, and the imports form no cycle. Conditional imports and exports are rejected.
/// `/// @docImport` lines are comments and may point upwards.
void main() {
  // Run `fvm flutter test` from the package root.
  const sourceRoot = 'lib/src';
  const packageLibrary = 'lib/duo_rail_kit.dart';

  /// Layer ranks by path prefix below `lib/src`; the longest matching prefix wins.
  const ranks = {
    'core/': 0,
    'edge/': 1,
    'layout/': 2,
    'toolbar/': 3,
    'toolbar/shared/': 4,
    'toolbar/vertical_bar_toolbar.dart': 5,
    'toolbar/page/': 5,
    'toolbar/shell/': 5,
  };

  /// The rank of [path] (relative to `lib/src`), or null when no prefix matches.
  int? rankOf(String path) {
    String? best;
    for (final prefix in ranks.keys) {
      if (path.startsWith(prefix) && (best == null || prefix.length > best.length)) {
        best = prefix;
      }
    }
    return best == null ? null : ranks[best];
  }

  /// Source without its whole-line comments (including `/// @docImport`). Block comments stay, so that a `/*` inside
  /// a line comment, such as `edge/*`, cannot hide the directives after it.
  String code(String path) => File(path).readAsStringSync().replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

  /// The `import`, `export` and `part` directives of [source], each with its first URI and the text up to its `;`.
  List<({String keyword, String uri, String rest})> directives(String source) => [
    for (final m in RegExp(
      r'''^\s*(import|export|part)\s+r?(?:'([^']*)'|"([^"]*)")([^;]*);''',
      multiLine: true,
    ).allMatches(source))
      (keyword: m.group(1)!, uri: m.group(2) ?? m.group(3)!, rest: m.group(4)!),
  ];

  /// [uri] from the file at [path] (relative to `lib`) as a path relative to `lib`, or null for another package.
  String? resolve(String path, String uri) {
    if (uri.startsWith('package:duo_rail_kit/')) {
      return uri.substring('package:duo_rail_kit/'.length);
    }
    if (uri.contains(':')) {
      return null;
    }
    final segments = path.split('/')..removeLast();
    for (final segment in uri.split('/')) {
      if (segment == '..') {
        segments.removeLast();
      } else if (segment != '.') {
        segments.add(segment);
      }
    }
    return segments.join('/');
  }

  test('lib/src imports only Dart, Flutter, and its own or a lower layer, without cycles', () {
    final files = [
      for (final entity in Directory(sourceRoot).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity.path.replaceAll(r'\', '/').substring('lib/'.length),
    ]..sort();
    expect(files, isNotEmpty, reason: 'No Dart files found under $sourceRoot; run the tests from the package root');

    final violations = <String>[];
    final edges = <String, List<String>>{};
    for (final file in files) {
      final rank = rankOf(file.substring('src/'.length));
      if (rank == null) {
        violations.add('$file is in no layer');
        continue;
      }
      final source = code('lib/$file');
      if (RegExp(r'^part\s+of\b', multiLine: true).hasMatch(source)) {
        // A part has no imports of its own; its library's imports are checked.
        continue;
      }
      for (final directive in directives(source)) {
        if (RegExp(r'\bif\s*\(').hasMatch(directive.rest)) {
          violations.add('$file uses a conditional ${directive.keyword}, which this test does not check');
          continue;
        }
        final target = resolve(file, directive.uri);
        if (target == null) {
          if (!directive.uri.startsWith('dart:') && !directive.uri.startsWith('package:flutter/')) {
            violations.add('$file ${directive.keyword}s ${directive.uri}, which is neither Dart nor Flutter');
          }
          continue;
        }
        if (!target.startsWith('src/') || !File('lib/$target').existsSync()) {
          violations.add('$file ${directive.keyword}s ${directive.uri}, which is not a file under $sourceRoot');
          continue;
        }
        final targetRank = rankOf(target.substring('src/'.length));
        if (directive.keyword == 'part') {
          // A part shares its library's imports, so it keeps its library's rank.
          if (targetRank != rank) {
            violations.add('$file (rank $rank) has the part $target (rank $targetRank)');
          }
          continue;
        }
        if (targetRank == null || targetRank > rank) {
          violations.add('$file (rank $rank) ${directive.keyword}s $target (rank $targetRank)');
        }
        (edges[file] ??= []).add(target);
      }
    }
    expect(violations, isEmpty);

    // Depth-first search; a file met again while it is still on the path closes a cycle.
    final cycles = <String>[];
    final done = <String>{};
    final path = <String>[];
    void visit(String file) {
      if (done.contains(file)) {
        return;
      }
      final index = path.indexOf(file);
      if (index != -1) {
        cycles.add([...path.sublist(index), file].join(' -> '));
        return;
      }
      path.add(file);
      edges[file]?.forEach(visit);
      path.removeLast();
      done.add(file);
    }

    files.forEach(visit);
    expect(cycles, isEmpty);
  });

  test('the package library exports only lib/src files, each with a show list', () {
    final exports = [
      for (final directive in directives(code(packageLibrary)))
        if (directive.keyword == 'export') directive,
    ];
    expect(exports, isNotEmpty, reason: 'No exports found in $packageLibrary; run the tests from the package root');

    final violations = <String>[];
    for (final export in exports) {
      final target = resolve('duo_rail_kit.dart', export.uri);
      if (target == null || !target.startsWith('src/') || !File('lib/$target').existsSync()) {
        violations.add('${export.uri} is not a file under $sourceRoot');
      }
      if (!RegExp(r'^\s*show\s+\w').hasMatch(export.rest)) {
        violations.add('${export.uri} is exported without a show list');
      }
      if (RegExp(r'\bhide\b').hasMatch(export.rest)) {
        violations.add('${export.uri} is exported with a hide list');
      }
    }
    expect(violations, isEmpty);
  });
}
