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
      topBar: null,
      verticalBar: null,
      detail: false,
    ),
    (
      file: 'top-band.png',
      size: Size(669, 951),
      safeArea: EdgeInsets.only(top: 82, bottom: 34),
      edge: null,
      label: 'Inner portrait band',
      topBar: TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 82, viewSize: Size(669, 951)),
      verticalBar: null,
      detail: false,
    ),
    (
      file: 'duo-right.png',
      size: Size(466, 678),
      safeArea: EdgeInsets.only(right: 84, bottom: 34),
      edge: HorizontalEdge.right,
      label: 'Outer portrait',
      topBar: null,
      verticalBar: null,
      detail: false,
    ),
    (
      file: 'split-left.png',
      size: Size(469, 669),
      safeArea: EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
      label: 'Left Split View',
      topBar: null,
      verticalBar: null,
      detail: false,
    ),
    (
      file: 'phone.png',
      size: Size(393, 852),
      safeArea: EdgeInsets.only(top: 59, bottom: 34),
      edge: null,
      label: 'Phone fallback',
      topBar: null,
      verticalBar: null,
      detail: false,
    ),
    (
      file: 'vertical-toolbar.png',
      size: Size(951, 669),
      safeArea: EdgeInsets.only(right: 84, bottom: 34),
      edge: HorizontalEdge.right,
      label: 'Inner landscape detail',
      topBar: null,
      // The inner landscape region; the top of the top bar region was measured in a UIKit window.
      verticalBar: VerticalBarRegion(
        rect: Rect.fromLTRB(879, 124, 927, 635),
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
        topBarTop: 24,
      ),
      // Pushes the detail page from Overview before rendering.
      detail: true,
    ),
    (
      file: 'vertical-tabs.png',
      size: Size(951, 669),
      safeArea: EdgeInsets.only(right: 84, bottom: 34),
      edge: HorizontalEdge.right,
      label: 'Inner landscape tabs',
      topBar: null,
      // The same region: the Overview tab's actions are drawn in the column above the rail.
      verticalBar: VerticalBarRegion(
        rect: Rect.fromLTRB(879, 124, 927, 635),
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
        topBarTop: 24,
      ),
      detail: false,
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
            topBar: fixture.topBar,
            verticalBar: fixture.verticalBar,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (fixture.detail) {
        final openDetail = find.byKey(const ValueKey('open-detail'));
        await tester.ensureVisible(openDetail);
        await tester.pumpAndSettle();
        await tester.tap(openDetail);
        await tester.pumpAndSettle();
      }
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
