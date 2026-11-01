// Run explicitly from example/: fvm flutter test tool/render_screenshots.dart
// Writes simulated widget renders to build/simulated_previews/ for local layout checks. They are not native
// screenshots; the documentation images in doc/images/ are Simulator screenshots (see doc/images/README.md).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Use the SDK's fonts instead of Flutter tests' Ahem placeholder glyphs.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final packages = (config['packages'] as List<dynamic>).cast<Map<String, dynamic>>();
    final flutterPackage = packages.singleWhere((entry) => entry['name'] == 'flutter');
    final flutterRoot = configFile.uri.resolve(flutterPackage['rootUri'] as String);
    final sdkRoot = Directory.fromUri(flutterRoot).parent.parent;
    final fontRoot = sdkRoot.uri.resolve('bin/cache/artifacts/material_fonts/');
    for (final (family, filename) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(File.fromUri(fontRoot.resolve(filename)).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  const fixtures = [
    (
      file: 'overview.png',
      size: Size(951, 669),
      safeArea: EdgeInsets.only(right: 84, bottom: 34),
      edge: HorizontalEdge.right,
      label: 'Inner landscape',
    ),
    (
      file: 'duo-right.png',
      size: Size(466, 678),
      safeArea: EdgeInsets.only(right: 84, bottom: 34),
      edge: HorizontalEdge.right,
      label: 'Outer portrait',
    ),
    (
      file: 'split-left.png',
      size: Size(469, 669),
      safeArea: EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
      label: 'Left Split View',
    ),
    (
      file: 'phone.png',
      size: Size(393, 852),
      safeArea: EdgeInsets.only(top: 59, bottom: 34),
      edge: null,
      label: 'Phone fallback',
    ),
  ];

  for (final fixture in fixtures) {
    testWidgets('render ${fixture.file}', (tester) async {
      tester.view
        ..physicalSize = fixture.size
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: DuoRailPreviewApp(
            size: fixture.size,
            safeArea: fixture.safeArea,
            edge: fixture.edge,
            label: fixture.label,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // Real IO and image encoding must run outside the widget test fake clock.
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/simulated_previews/${fixture.file}');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          rendered.dispose();
        }
      });
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  }
}
